// Created by liugquoqiang at 2020-12-1

#include "mainwindow.h"
#include "testform.h"

#include <QApplication>

int main(int argc, char *argv[])
{
    QApplication a(argc, argv);
//    MainWindow w;
//    w.show();

    TestForm w;
    w.show();
    w.updateMath();
    w.showMaximized();

    return a.exec();
}
