#include <QtGui/QGuiApplication>
#include <QtQuick/QQuickView>
#include <QtQml>
#include "colorMaker.h"


int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    qmlRegisterType<ColorMaker>("an.qt.ColorMaker", 1, 0, "ColorMaker");

    QQuickView viewer;
    QObject::connect(viewer.engine(), SIGNAL(quit()), &app, SLOT(quit()));  
    viewer.setResizeMode(QQuickView::SizeRootObjectToView);
//    viewer.rootContext()->setContextProperty("colorMaker", new ColorMaker); // 这种方式, 就类似于写了一个全局变量.
    viewer.setSource(QUrl("qrc:///main.qml")); // 将 View 的 qml 文件绑定在一起.
    viewer.show();

    return app.exec();
}
