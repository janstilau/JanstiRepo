// Created by liugquoqiang at 2020-12-5

#ifndef YDNOTFICATIONIUTIL_H
#define YDNOTFICATIONIUTIL_H
#include "YdNotificationCenter.h"

namespace YdNotiUtil {
    bool isInMainThread();
    qlonglong pointerToLonglong(QObject *obj);
    QObject *longlongToPointer(qlonglong pointer);
}


#endif // YDNOTFICATIONIUTIL_H
