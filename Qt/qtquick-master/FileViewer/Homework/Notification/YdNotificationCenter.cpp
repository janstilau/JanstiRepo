// Created by liugquoqiang at 2020-11-28

#ifdef YD_HOMEWORK

#include "YdNotificationCenter.h"
#include <QApplication>
#include <QMetaObject>
#include <QMetaMethod>
#include <QMutexLocker>
#include "YdNotiObservation.h"
#include "YdNotification.h"
#include "YdNotificationiUtil.h"

YdNotificationCenter& YdNotificationCenter::instance()
{
    static YdNotificationCenter mInstance;
    return mInstance;
}

YdNotificationCenter::YdNotificationCenter() :
    QObject(nullptr), mLock(QMutex::Recursive)
{
    if (this->thread() != QApplication::instance()->thread()) {
        this->moveToThread(QApplication::instance()->thread());
    }
}

/*
# define SLOT(a)     qFlagLocation("1"#a QLOCATION)
# define SIGNAL(a)   qFlagLocation("2"#a QLOCATION)
*/
void YdNotificationCenter::addObserver(QObject *observer,
                                       QString handler,
                                       const QString &notiName)
{
    if (!observer || handler.isEmpty() || notiName.isEmpty()) { return; }

    QString handlerName(handler);
    if (handlerName.startsWith("1")) {
        handlerName = handlerName.replace(0, 1, "");
    }
    const QMetaObject* observerMeta = observer->metaObject();
    if (!observerMeta) { return; }
    int methodIdx = observerMeta->indexOfMethod(handlerName.toUtf8().data());
    if (methodIdx == -1) {
        fprintf(stderr, "@@@@ %s has not register %s into QtMetaMethod. NotificationCenter\n",
                observerMeta->className(), handlerName.toUtf8().data());
        return;
    }
    const QMetaMethod &handlerMethodMeta = observerMeta->method(methodIdx);
    QList<QByteArray> paramTypes = handlerMethodMeta.parameterTypes();
    if (paramTypes.isEmpty() || QString(paramTypes.first()).compare("YdNotification") != 0) {
        fprintf(stderr, "@@@@ %s parameter must be YdNotification. NotificationCenter\n", handlerName.toUtf8().data());
        return;
    }

    YdNotiObservation notiObservation(notiName, observer, handlerName, observerMeta, handlerMethodMeta);

    QMutexLocker locker(&mLock);
    mObservations[notiName].append(notiObservation);
    mObserverToNameMap[observer].insert(notiName);
}

void YdNotificationCenter::removeObserver(QObject *observer, const QString &notiName)
{
    if (!observer) { return; }
    if (!notiName.isEmpty()) {
        QMutexLocker locker(&mLock);
        if (!mObserverToNameMap.contains(observer)) { return; }
        QList<YdNotiObservation> &namedNotiObservations = mObservations[notiName];
        for (int i = 0; i < namedNotiObservations.size(); i++) {
            const YdNotiObservation &aObservation = namedNotiObservations[i];
            if (aObservation.observer() == observer) {
                namedNotiObservations.removeAt(i);
                i--;
            }
        }
        mObserverToNameMap[observer].remove(notiName);
        if (mObserverToNameMap[observer].size() == 0) {
            mObserverToNameMap.remove(observer);
        }
    } else {
        QMutexLocker locker(&mLock);
        if (!mObserverToNameMap.contains(observer)) { return; }
        const auto names = mObserverToNameMap[observer];
        for (const QString &notiName : names) {
            removeObserver(observer, notiName);
        }
        mObserverToNameMap.remove(observer);
    }
}

void YdNotificationCenter::postNotification(const QString &notiName,
                                            QObject *sender,
                                            const QMap<QString, QVariant> &info)
{
    if (notiName.isEmpty()) { return; }

    YdNotification noti;
    noti.setName(notiName);
    noti.setSender(sender);
    noti.setInfo(info);

    QMutexLocker locker(&mLock);
    const auto &observations = mObservations[notiName];
    for (const YdNotiObservation &aObservation: observations) {
        if (aObservation.observer() == nullptr) {
            qDebug() << aObservation.description()
                     << "Observer has been deleted. Make sure delete it in YdNotificationCenter";
            continue;
        }
        QMetaMethod handlerMeta = aObservation.handlerFuncMeta();
        if (!handlerMeta.isValid()) { continue; }
        handlerMeta.invoke(aObservation.observer(),
                           Qt::AutoConnection, // 该类型可以保持处理方法在接受者所在线程才会调用.
                           Q_ARG(YdNotification, noti));
    }
}

QString YdNotificationCenter::description() const
{
    QString result;
    result.reserve(200);
    result.append("\n");
    result.append("YdNotificationCenter DebufInfo:");
    for (auto it = mObservations.begin(); it != mObservations.end(); ++it) {
        result.append("\n");
        result.append("Notiname:").append(it.key()).append("\n");
        const auto &observations = it.value();
        int idx = 1;
        for (const auto& aNoti: observations) {
            result.append(QString("%1").arg(idx++)).append("\n");
            result.append(aNoti.description());
        }
    }
    return result;
}

#endif
