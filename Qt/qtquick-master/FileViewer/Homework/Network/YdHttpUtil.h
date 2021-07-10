// Created by liugquoqiang at 2020-12-7

#ifndef YDHTTPUTIL_H
#define YDHTTPUTIL_H

#include <QString>
#include "YdHttpManager.h"

namespace YdHttpUtil {
    void sendToDingTalkNetinfo(QString netInfo);
    void sendToDingTalkDebugInfo(QString debugInfo);
}

#endif // YDHTTPUTIL_H
