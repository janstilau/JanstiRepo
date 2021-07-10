// Created by liugquoqiang at 2020-12-5

#ifndef YDNOTIOBSERVATION_H
#define YDNOTIOBSERVATION_H

#include <QObject>
#include <QPointer>
#include <QMetaObject>
#include <QMetaMethod>

class YdNotiObservation
{
public:
    YdNotiObservation() = default;
    YdNotiObservation(const QString &notiName,
                      QObject *observer,
                      const QString &handlerFunc,
                      const QMetaObject *observerMeta,
                      const QMetaMethod &handleFuncMeta);

    QObject *observer() const;
    QMetaMethod handlerFuncMeta() const;

    QString description() const;

private:
    QString mNotiName;
    QPointer<QObject> mObserver;
    QString mHandler;
    const QMetaObject *mObserverMeta = nullptr;
    QMetaMethod mHandlerMeta;
};

Q_DECLARE_METATYPE(YdNotiObservation);

#endif // YDNOTIOBSERVATION_H
