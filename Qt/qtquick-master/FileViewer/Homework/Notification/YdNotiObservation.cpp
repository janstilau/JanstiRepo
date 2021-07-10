// Created by liugquoqiang at 2020-12-5

#include "YdNotiObservation.h"

YdNotiObservation::YdNotiObservation(const QString &notiName,
                                     QObject *observer,
                                     const QString &handlerFunc,
                                     const QMetaObject *observerMeta,
                                     const QMetaMethod &handleFuncMeta)
    :mNotiName(notiName),
      mObserver(QPointer<QObject>(observer)),
      mHandler(handlerFunc),
      mObserverMeta(observerMeta),
      mHandlerMeta(handleFuncMeta)
{
}

QObject * YdNotiObservation::observer() const
{
    if (mObserver.isNull()) {
        return nullptr;
    } else {
        return mObserver.data();
    }
}

QMetaMethod YdNotiObservation::handlerFuncMeta() const
{
    return mHandlerMeta;
}

QString YdNotiObservation::description() const
{
    QString result;
    result.reserve(50);
    QString address = QString("0x%1").arg((quintptr)mObserver.data(), QT_POINTER_SIZE * 2, 16, QChar('0'));
    result.append(QString("Observer: %1 %2").arg(mObserverMeta->className()).arg(address)).append("\n");
    result.append("handler: ").append(mHandlerMeta.name()).append("\n");
    return result;
}
