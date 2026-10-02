#include "LeafAnalyzer.hpp"

#include <QFile>
#include <QImageReader>
#include <QJsonArray>
#include <QJsonDocument>
#include <algorithm>
#include <numeric>

#include "cropdx/classifier.hpp"

namespace {
// Exponential smoothing for live video: steadies the label without much lag.
constexpr float kLiveSmoothing = 0.35f;  // weight of the newest frame
}  // namespace

LeafAnalyzer::LeafAnalyzer(const QString& infoJsonPath, QObject* parent) : QObject(parent) {
  qRegisterMetaType<InferenceResult>();

  QFile f(infoJsonPath);
  if (f.open(QIODevice::ReadOnly)) {
    const auto root = QJsonDocument::fromJson(f.readAll()).object();
    m_info = root.value("classes").toObject();
    m_disclaimer = root.value("disclaimer").toString();
  }

  m_worker = new InferenceWorker;
  m_worker->moveToThread(&m_thread);
  connect(&m_thread, &QThread::finished, m_worker, &QObject::deleteLater);
  connect(this, &LeafAnalyzer::requestLoad, m_worker, &InferenceWorker::load);
  connect(this, &LeafAnalyzer::requestProcess, m_worker, &InferenceWorker::process);
  connect(m_worker, &InferenceWorker::loaded, this,
          [this](const QString& name, int size, const QStringList& labels) {
            m_modelName = name;
            m_inputSize = size;
            m_labels = QVector<QString>(labels.begin(), labels.end());
            m_ready = true;
            setError({});
            emit modelChanged();
          });
  connect(m_worker, &InferenceWorker::failed, this, [this](const QString& e) {
    m_inFlight = false;
    setError(e);
  });
  connect(m_worker, &InferenceWorker::finished, this, &LeafAnalyzer::onResult);
  m_thread.setObjectName("inference");
  m_thread.start();
}

LeafAnalyzer::~LeafAnalyzer() {
  m_thread.quit();
  m_thread.wait();
}

void LeafAnalyzer::loadModel(const QString& model, const QString& labels, int threads) {
  if (!QFile::exists(model) || !QFile::exists(labels)) {
    setError(tr("Model not found. Pass --model/--labels or set CROPDX_MODELS"));
    return;
  }
  emit requestLoad(model, labels, threads);
}

void LeafAnalyzer::setError(const QString& e) {
  if (e == m_error) return;
  m_error = e;
  emit errorChanged();
}

void LeafAnalyzer::setLive(bool live) {
  if (live == m_live) return;
  m_live = live;
  m_smoothed.clear();  // don't blend still-image and camera results
  m_fps = 0;
  m_fpsClock.invalidate();
  if (live && !m_stillImage.isEmpty()) {
    m_stillImage.clear();
    emit stillImageChanged();
  }
  emit liveChanged();
  emit resultChanged();
}

void LeafAnalyzer::setVideoSink(QObject* sink) {
  auto* s = qobject_cast<QVideoSink*>(sink);
  if (s == m_sink) return;
  if (m_sink) disconnect(m_sink, nullptr, this, nullptr);
  m_sink = s;
  if (m_sink) connect(m_sink, &QVideoSink::videoFrameChanged, this, &LeafAnalyzer::onFrame);
  emit videoSinkChanged();
}

void LeafAnalyzer::onFrame(const QVideoFrame& frame) {
  // Natural back-pressure: drop frames while the previous one is in flight.
  if (!m_live || !m_ready || m_inFlight || !frame.isValid()) return;
  QImage image = frame.toImage();
  if (image.isNull()) return;
  m_inFlight = true;
  emit requestProcess(image, true);
}

void LeafAnalyzer::analyzeFile(const QUrl& url) {
  const QString path = url.isLocalFile() ? url.toLocalFile() : url.toString();
  QImageReader reader(path);
  reader.setAutoTransform(true);  // honour EXIF orientation, like the mobile app
  const QImage image = reader.read();
  if (image.isNull()) {
    setError(tr("Cannot open image: %1").arg(reader.errorString()));
    return;
  }
  setLive(false);
  m_smoothed.clear();
  m_stillImage = QUrl::fromLocalFile(path);
  emit stillImageChanged();
  m_inFlight = true;
  emit requestProcess(image, false);
}

void LeafAnalyzer::onResult(const InferenceResult& r) {
  m_inFlight = false;
  if (r.live != m_live) return;  // mode switched while this frame was running
  m_labels = r.labels;

  if (r.live && m_smoothed.size() == r.probabilities.size()) {
    for (int i = 0; i < m_smoothed.size(); ++i)
      m_smoothed[i] = (1 - kLiveSmoothing) * m_smoothed[i] + kLiveSmoothing * r.probabilities[i];
  } else {
    m_smoothed = r.probabilities;
  }

  const auto res = cropdx::make_result(
      std::vector<float>(m_smoothed.begin(), m_smoothed.end()),
      std::vector<std::string>([&] {
        std::vector<std::string> v;
        for (const auto& l : m_labels) v.push_back(l.toStdString());
        return v;
      }()));

  m_topLabel = QString::fromStdString(res.top().label);
  m_confidence = res.top().probability;
  m_uncertain = res.uncertain();
  m_scores.clear();
  for (size_t i = 0; i < std::min<size_t>(3, res.scores.size()); ++i) {
    const QString id = QString::fromStdString(res.scores[i].label);
    m_scores << QVariantMap{{"label", id},
                            {"name", info(id).value("name").toString()},
                            {"p", res.scores[i].probability}};
  }
  m_inferenceMs = r.inferenceMs;
  m_preprocessMs = r.preprocessMs;

  if (r.live) {
    if (m_fpsClock.isValid()) {
      const double instant = 1000.0 / std::max<qint64>(1, m_fpsClock.restart());
      m_fps = m_fps > 0 ? 0.8 * m_fps + 0.2 * instant : instant;
    } else {
      m_fpsClock.start();
    }
  }
  setError({});
  emit resultChanged();
}

QVariantMap LeafAnalyzer::info(const QString& label) const {
  const QJsonObject o = m_info.value(label).toObject();
  if (o.isEmpty()) {
    return {{"name", QString(label).replace('_', ' ')}, {"cause", ""}, {"type", ""},
            {"symptoms", QVariantList{}}, {"management", QVariantList{}}};
  }
  return o.toVariantMap();
}
