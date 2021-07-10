// Created by liugquoqiang at 2020-12-7

#include "YdHttpUtil.h"
#include <QJsonDocument>
#include <QJsonObject>

void YdHttpUtil::sendToDingTalkNetinfo(QString netInfo)
{
    QJsonObject paramsM = QJsonObject();
    paramsM["msgtype"] = "text";
    QJsonObject contentParam = QJsonObject();
    QString content = QString("jansti: %1").arg(netInfo);
    contentParam["content"] = content;
    paramsM["text"] = contentParam;
    QJsonDocument document;
    document.setObject(paramsM);
    YdNetwork.post("https://oapi.dingtalk.com/robot/send?access_token=92b514de181016e6e7b35c1b1aee4ab219a8d0425c22417e88e5a1b698db8fe7",
                   QString(document.toJson()));
}

void YdHttpUtil::sendToDingTalkDebugInfo(QString debugInfo) {
    QJsonObject paramsM = QJsonObject();
    paramsM["msgtype"] = "text";
    QJsonObject contentParam = QJsonObject();
    QString content = QString("Jansti: %1").arg(debugInfo);
    contentParam["content"] = content;
    paramsM["text"] = contentParam;
    QJsonDocument document;
    document.setObject(paramsM);
    YdNetwork.post("https://oapi.dingtalk.com/robot/send?access_token=92e7bac882a85a0bccfb986c97c29fab226dccbb25bf80e5f0879d336bb67fd2",
               QString(document.toJson()));
}
