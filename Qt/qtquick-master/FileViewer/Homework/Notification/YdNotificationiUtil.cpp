// Created by liugquoqiang at 2020-12-5

#include "YdNotificationiUtil.h"
#include <QThread>
#include <QApplication>

bool isInMainThread()
{
    return QThread::currentThread() == QApplication::instance()->thread();
}

qlonglong pointerToLonglong(QObject *obj)
{
    return reinterpret_cast<qlonglong>(obj);
}

QObject *longlongToPointer(qlonglong pointer)
{
    return reinterpret_cast<QObject*>(pointer);
}
