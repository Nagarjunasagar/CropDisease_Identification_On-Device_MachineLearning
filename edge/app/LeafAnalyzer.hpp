#pragma once

#include <QElapsedTimer>
#include <QJsonObject>
#include <QObject>
#include <QPointer>
#include <QThread>
#include <QUrl>
#include <QVariantList>
#include <QVector>
#include <QVideoFrame>
#include <QVideoSink>

#include "InferenceWorker.hpp"

/// QML-facing controller: feeds camera frames or still images to the worker
/// thread and publishes the (temporally smoothed) result as properties.
class LeafAnalyzer : public QObject {
  Q_OBJECT
  Q_PROPERTY(bool ready READ ready NOTIFY modelChanged)
  Q_PROPERTY(QString error READ error NOTIFY errorChanged)
  Q_PROPERTY(QString modelName READ modelName NOTIFY modelChanged)
  Q_PROPERTY(int inputSize READ inputSize NOTIFY modelChanged)
  Q_PROPERTY(QString disclaimer READ disclaimer CONSTANT)

  Q_PROPERTY(bool live READ live WRITE setLive NOTIFY liveChanged)
  Q_PROPERTY(QObject* videoSink READ videoSink WRITE setVideoSink NOTIFY videoSinkChanged)
  Q_PROPERTY(QUrl stillImage READ stillImage NOTIFY stillImageChanged)

  Q_PROPERTY(bool hasResult READ hasResult NOTIFY resultChanged)
  Q_PROPERTY(QString topLabel READ topLabel NOTIFY resultChanged)
  Q_PROPERTY(double confidence READ confidence NOTIFY resultChanged)
  Q_PROPERTY(bool uncertain READ uncertain NOTIFY resultChanged)
  Q_PROPERTY(QVariantList scores READ scores NOTIFY resultChanged)
  Q_PROPERTY(double inferenceMs READ inferenceMs NOTIFY resultChanged)
  Q_PROPERTY(double preprocessMs READ preprocessMs NOTIFY resultChanged)
  Q_PROPERTY(double fps READ fps NOTIFY resultChanged)

 public:
  LeafAnalyzer(const QString& infoJsonPath, QObject* parent = nullptr);
  ~LeafAnalyzer() override;

  void loadModel(const QString& model, const QString& labels, int threads);

  bool ready() const { return m_ready; }
  QString error() const { return m_error; }
  QString modelName() const { return m_modelName; }
  int inputSize() const { return m_inputSize; }
  QString disclaimer() const { return m_disclaimer; }

  bool live() const { return m_live; }
  void setLive(bool live);
  QObject* videoSink() const { return m_sink; }
  void setVideoSink(QObject* sink);
  QUrl stillImage() const { return m_stillImage; }

  bool hasResult() const { return !m_smoothed.isEmpty(); }
  QString topLabel() const { return m_topLabel; }
  double confidence() const { return m_confidence; }
  bool uncertain() const { return m_uncertain; }
  QVariantList scores() const { return m_scores; }
  double inferenceMs() const { return m_inferenceMs; }
  double preprocessMs() const { return m_preprocessMs; }
  double fps() const { return m_fps; }

  /// Disease guidance for a class id: {name, cause, type, symptoms, management}.
  Q_INVOKABLE QVariantMap info(const QString& label) const;
  Q_INVOKABLE void analyzeFile(const QUrl& url);

 signals:
  void modelChanged();
  void errorChanged();
  void liveChanged();
  void videoSinkChanged();
  void stillImageChanged();
  void resultChanged();
  void requestLoad(const QString& model, const QString& labels, int threads);
  void requestProcess(const QImage& image, bool live);

 private:
  void onFrame(const QVideoFrame& frame);
  void onResult(const InferenceResult& r);
  void setError(const QString& e);

  QThread m_thread;
  InferenceWorker* m_worker = nullptr;  // lives on m_thread
  QPointer<QVideoSink> m_sink;
  QJsonObject m_info;
  QString m_disclaimer;

  bool m_ready = false;
  bool m_live = false;
  bool m_inFlight = false;
  QString m_error, m_modelName;
  int m_inputSize = 0;
  QUrl m_stillImage;

  QVector<QString> m_labels;
  QVector<float> m_smoothed;
  QString m_topLabel;
  double m_confidence = 0, m_inferenceMs = 0, m_preprocessMs = 0, m_fps = 0;
  bool m_uncertain = true;
  QVariantList m_scores;
  QElapsedTimer m_fpsClock;
};
