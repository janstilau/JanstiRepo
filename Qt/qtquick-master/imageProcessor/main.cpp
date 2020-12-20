#include <QGuiApplication>
#include <QtQuick/QQuickView>
#include <QtQml>
#include "imageProcessor.h"
#include <QQuickItem>
#include <QDebug>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // 在这里, 把 C++ 的处理类, 注册给了 QML 环境.
    qmlRegisterType<ImageProcessor>("an.qt.ImageProcessor", 1, 0,"ImageProcessor");

    QQuickView viewer;
    viewer.setResizeMode(QQuickView::SizeRootObjectToView);
    //viewer.rootContext()->setContextProperty("imageProcessor", new ImageProcessor);    
    viewer.setSource(QUrl("qrc:///main.qml"));
    viewer.show();

    /*
    QQuickItem * rootItem = viewer.rootObject();
    qDebug() << rootItem->findChild<QObject*>("imageViewer");
    */

    return app.exec();
}
