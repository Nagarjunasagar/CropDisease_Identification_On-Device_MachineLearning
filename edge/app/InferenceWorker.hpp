#pragma once

#include <QImage>
#include <QObject>
#include <QString>
#include <QVector>
#include <memory>

#include "cropdx/classifier.hpp"

/// Plain result passed from the worker thread back to the UI thread.
struct InferenceResult {
  QVector<QString> labels;      // model output order
  QVector<float> probabilities; // same order as labels
  double preprocessMs = 0;
  double inferenceMs = 0;
  bool live = false;
};
Q_DECLARE_METATYPE(InferenceResult)

/// Owns the LiteRT classifier on a dedicated thread so the QML scene graph
/// never waits on inference.
class InferenceWorker : public QObject {
  Q_OBJECT
 public:
  using QObject::QObject;
  ~InferenceWorker() override;

 public slots:
  void load(const QString& model, const QString& labels, int threads);
  void process(const QImage& image, bool live);

 signals:
  void loaded(const QString& modelName, int inputSize, const QStringList& labels);
  void failed(const QString& message);
  void finished(const InferenceResult& result);

 private:
  std::unique_ptr<cropdx::Classifier> m_classifier;
};
