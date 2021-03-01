#ifndef QEVENTLOOP_P_H
#define QEVENTLOOP_P_H


#include "qcoreapplication.h"
#include "qobject_p.h"

QT_BEGIN_NAMESPACE

class QEventLoopPrivate : public QObjectPrivate
{
    Q_DECLARE_PUBLIC(QEventLoop)
public:
    inline QEventLoopPrivate()
        : inExec(false)
    {
        returnCode.store(-1);
        exit.store(true);
    }

    // 作为数据部分, eventLoop 并不存储实际的业务数据, 它只是存储, 当前的状态值.
    QAtomicInt quitLockRef;
    bool inExec;
    QBasicAtomicInt exit; // bool
    QBasicAtomicInt returnCode;

    void ref()
    {
        quitLockRef.ref();
    }

    void deref()
    {
        if (!quitLockRef.deref() && inExec) {
            qApp->postEvent(q_ptr, new QEvent(QEvent::Quit));
        }
    }
};

QT_END_NAMESPACE

#endif // QEVENTLOOP_P_H
