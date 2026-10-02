// CroHeal Edge: Qt 6 / QML front-end for the LiteRT leaf-disease classifier.
//
//   cropdx-app                         # live camera (if any) + open-image button
//   cropdx-app --image leaf.jpg        # analyse a still image at startup
//   cropdx-app --model m.tflite --labels labels.txt --threads 4
//   cropdx-app --image leaf.jpg --screenshot out.png   # headless capture (CI/docs)

#include <QCommandLineParser>
#include <QDir>
#include <QFileInfo>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QTimer>

#include "LeafAnalyzer.hpp"

namespace {

/// Looks for the shared models/ folder next to the binary, then up the tree
/// (build dir, repo checkout), then in $CROPDX_MODELS.
QString findModelsDir() {
  QStringList candidates;
  if (const QByteArray env = qgetenv("CROPDX_MODELS"); !env.isEmpty())
    candidates << QString::fromLocal8Bit(env);
  QDir dir(QCoreApplication::applicationDirPath());
  for (int up = 0; up < 4; ++up) {
    candidates << dir.filePath("models");
    if (!dir.cdUp()) break;
  }
  candidates << "/usr/share/cropdx/models";
  for (const QString& c : candidates)
    if (QFileInfo::exists(c + "/labels.txt")) return QDir(c).absolutePath();
  return {};
}

}  // namespace

int main(int argc, char* argv[]) {
  QGuiApplication app(argc, argv);
  app.setApplicationName("CroHeal Edge");
  app.setApplicationVersion("2.0.0");

  QCommandLineParser cli;
  cli.setApplicationDescription("On-device tomato leaf disease classifier");
  cli.addHelpOption();
  cli.addVersionOption();
  const QCommandLineOption modelOpt("model", "LiteRT model (.tflite).", "file");
  const QCommandLineOption labelsOpt("labels", "Labels file.", "file");
  const QCommandLineOption infoOpt("info", "Disease guide JSON.", "file");
  const QCommandLineOption threadsOpt("threads", "Inference threads.", "n", "4");
  const QCommandLineOption imageOpt("image", "Analyse this image at startup.", "file");
  const QCommandLineOption cameraOpt("camera", "Start in live camera mode.");
  const QCommandLineOption shotOpt("screenshot", "Save a window capture and exit.", "png");
  cli.addOptions({modelOpt, labelsOpt, infoOpt, threadsOpt, imageOpt, cameraOpt, shotOpt});
  cli.process(app);

  const QString models = findModelsDir();
  if (models.isEmpty() && !(cli.isSet(modelOpt) && cli.isSet(labelsOpt)))
    qWarning("models/ folder not found: pass --model and --labels, or set CROPDX_MODELS");
  auto pick = [&](const QCommandLineOption& o, const QString& file) {
    return cli.isSet(o) ? cli.value(o) : QDir(models).filePath(file);
  };
  const QString modelPath = pick(modelOpt, "crop_disease_int8.tflite");
  const QString labelsPath = pick(labelsOpt, "labels.txt");
  const QString infoPath = pick(infoOpt, "disease_info.json");

  const int interId = QFontDatabase::addApplicationFont("/usr/share/fonts/opentype/inter/Inter.ttc");
  if (interId < 0) QFontDatabase::addApplicationFont("/usr/share/fonts/truetype/inter/Inter.ttc");

  LeafAnalyzer analyzer(infoPath);
  analyzer.loadModel(modelPath, labelsPath, cli.value(threadsOpt).toInt());

  QQmlApplicationEngine engine;
  engine.rootContext()->setContextProperty("analyzer", &analyzer);
  engine.rootContext()->setContextProperty("startLive", cli.isSet(cameraOpt));
  QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                   [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
  engine.load(QUrl(QStringLiteral("qrc:/CropDx/qml/Main.qml")));
  if (engine.rootObjects().isEmpty()) return 1;

  if (cli.isSet(imageOpt)) {
    const QUrl url = QUrl::fromLocalFile(QFileInfo(cli.value(imageOpt)).absoluteFilePath());
    QObject::connect(&analyzer, &LeafAnalyzer::modelChanged, &analyzer,
                     [&analyzer, url] { analyzer.analyzeFile(url); }, Qt::SingleShotConnection);
  }

  if (cli.isSet(shotOpt)) {
    const QString out = cli.value(shotOpt);
    auto* window = qobject_cast<QQuickWindow*>(engine.rootObjects().first());
    auto save = [window, out] {
      QTimer::singleShot(600, window, [window, out] {  // let images/animations settle
        const bool ok = window->grabWindow().save(out);
        QCoreApplication::exit(ok ? 0 : 1);
      });
    };
    QObject::connect(&analyzer, &LeafAnalyzer::resultChanged, window, save, Qt::SingleShotConnection);
    QObject::connect(&analyzer, &LeafAnalyzer::errorChanged, window, save, Qt::SingleShotConnection);
    QTimer::singleShot(15000, &app, [] { QCoreApplication::exit(2); });  // safety net
  }
  return app.exec();
}
