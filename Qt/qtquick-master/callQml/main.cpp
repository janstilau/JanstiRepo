#include <QtGui/QGuiApplication>
//#include <QtQuick/QQuickView>
#include <QQmlApplicationEngine>
#include "changeColor.h"
#include <QMetaObject>
#include <QDebug>
#include <QColor>
#include <QVariant>
//#include <QtQml>

// 在 C++ 里面, 使用 QML 实在太麻烦了.
int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    /*
    QQuickView viewer;
    viewer.setResizeMode(QQuickView::SizeRootObjectToView);
    viewer.setSource(QUrl("qrc:///main.qml"));
    viewer.show();
    */
    QQmlApplicationEngine engine;
    engine.load(QUrl("qrc:///main.qml"));

    QObject * root = NULL;//= qobject_cast<QObject*>(viewer.rootObject());
    QList<QObject*> rootObjects = engine.rootObjects();
    int count = rootObjects.size();
    qDebug() << "rootObjects- " << count;
    for(int i = 0; i < count; i++)
    {
        if(rootObjects.at(i)->objectName() == "rootObject")
        {
            root = rootObjects.at(i);
            break;
        }
    }

    //  这里, 找到了 quit Btn, QML 环境下的, 然后将 btn 的信号, 和 App 的 quit 槽函数进行了连接.
    new ChangeQmlColor(root);
    QObject * quitButton = root->findChild<QObject*>("quitButton");
    if(quitButton)
    {
        QObject::connect(quitButton, SIGNAL(clicked()), &app, SLOT(quit()));
    }

    QObject *textLabel = root->findChild<QObject*>("textLabel");
    if(textLabel)
    {
        //1. failed call, 因为 textLabel 没有该方法.
        bool bRet = QMetaObject::invokeMethod(textLabel, "setText", Q_ARG(QString, "world hello"));
        qDebug() << "call setText return - " << bRet;
        // 使用 setProperty, 修改了 QML 里面的属性.
        textLabel->setProperty("color", QColor::fromRgb(255,0,0));

        bRet = QMetaObject::invokeMethod(textLabel, "doLayout");
        qDebug() << "call doLayout return - " << bRet;
    }

    return app.exec();
}
