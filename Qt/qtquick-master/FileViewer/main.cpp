#include <QApplication>
#include <QQmlApplicationEngine>
#include <QIcon>
#include "colormaker.h"
#include "YdNotificationCenter.h"
#include <QQmlContext>

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setWindowIcon(QIcon(":/res/eye.png"));

    qmlRegisterType<ColorMaker>("an.qt.ColorMaker", 1, 0, "ColorMaker");


    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("notiCenter", &YdNotificationCenter::instance());
    engine.load(QUrl(QStringLiteral("qrc:///rect.qml")));

    return app.exec();
}
