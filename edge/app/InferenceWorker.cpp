#include "InferenceWorker.hpp"

#include <QFileInfo>
#include <QStringList>

InferenceWorker::~InferenceWorker() = default;

void InferenceWorker::load(const QString& model, const QString& labels, int threads) {
  try {
    m_classifier = std::make_unique<cropdx::Classifier>(
        model.toStdString(), labels.toStdString(), cropdx::Options{threads});
    QStringList names;
    for (const auto& l : m_classifier->labels()) names << QString::fromStdString(l);
    emit loaded(QFileInfo(model).fileName(), m_classifier->input_size(), names);
  } catch (const std::exception& e) {
    m_classifier.reset();
    emit failed(QString::fromUtf8(e.what()));
  }
}

void InferenceWorker::process(const QImage& image, bool live) {
  if (!m_classifier || image.isNull()) {
    emit failed(QStringLiteral("No model loaded or empty image"));
    return;
  }
  try {
    const QImage rgb = image.format() == QImage::Format_RGB888
                           ? image
                           : image.convertToFormat(QImage::Format_RGB888);
    const auto r = m_classifier->classify(rgb.constBits(), rgb.width(), rgb.height(),
                                          static_cast<int>(rgb.bytesPerLine()));
    // Return probabilities in model label order so the UI can smooth them.
    InferenceResult out;
    out.live = live;
    out.preprocessMs = r.preprocess_ms;
    out.inferenceMs = r.inference_ms;
    for (const auto& label : m_classifier->labels()) {
      out.labels << QString::fromStdString(label);
      float p = 0;
      for (const auto& s : r.scores)
        if (s.label == label) p = s.probability;
      out.probabilities << p;
    }
    emit finished(out);
  } catch (const std::exception& e) {
    emit failed(QString::fromUtf8(e.what()));
  }
}
