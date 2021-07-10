// Created by liugquoqiang at 2020-11-28

#ifdef YD_HOMEWORK

#include "YdNotification.h"

YdNotification::YdNotification()
{
    mThread = QThread::currentThread();
}

QObject * YdNotification::sender() const
{
    if (mSender.isNull()) {
        return nullptr;
    } else {
        return mSender.data();
    }
}

QString YdNotification::name() const
{
    return mName;
}

const QMap<QString, QVariant>& YdNotification::notiInfo() const
{
    return mInfo;
}

QThread* YdNotification::postTimeThread() const
{
    if (mThread.isNull()) {
        return nullptr;
    } else {
        return mThread.data();
    }
}

void YdNotification::setSender(QObject *sender)
{
    mSender = sender;
}

void YdNotification::setName(QString name)
{
    mName = name;
}

void YdNotification::setInfo(const QMap<QString, QVariant> info)
{
    mInfo = info;
}

#endif
