/****************************************************************************
**
** Copyright (C) 2016 The Qt Company Ltd.
** Copyright (C) 2016 Intel Corporation.
** Contact: https://www.qt.io/licensing/
**
** This file is part of the QtCore module of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:LGPL$
** Commercial License Usage
** Licensees holding valid commercial Qt licenses may use this file in
** accordance with the commercial license agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and The Qt Company. For licensing terms
** and conditions see https://www.qt.io/terms-conditions. For further
** information use the contact form at https://www.qt.io/contact-us.
**
** GNU Lesser General Public License Usage
** Alternatively, this file may be used under the terms of the GNU Lesser
** General Public License version 3 as published by the Free Software
** Foundation and appearing in the file LICENSE.LGPL3 included in the
** packaging of this file. Please review the following information to
** ensure the GNU Lesser General Public License version 3 requirements
** will be met: https://www.gnu.org/licenses/lgpl-3.0.html.
**
** GNU General Public License Usage
** Alternatively, this file may be used under the terms of the GNU
** General Public License version 2.0 or (at your option) the GNU General
** Public license version 3 or any later version approved by the KDE Free
** Qt Foundation. The licenses are as published by the Free Software
** Foundation and appearing in the file LICENSE.GPL2 and LICENSE.GPL3
** included in the packaging of this file. Please review the following
** information to ensure the GNU General Public License requirements will
** be met: https://www.gnu.org/licenses/gpl-2.0.html and
** https://www.gnu.org/licenses/gpl-3.0.html.
**
** $QT_END_LICENSE$
**
****************************************************************************/

#include "qtimer.h"
#include "qabstracteventdispatcher.h"
#include "qcoreapplication.h"
#include "qobject_p.h"

QT_BEGIN_NAMESPACE


static const int INV_TIMER = -1;                // invalid timer id

// 初始化一个 QTimer 类, 在这个类里面, id 作为了 Timer 是否有效的标志.
QTimer::QTimer(QObject *parent)
    : QObject(parent), id(INV_TIMER), inter(0), del(0), single(0), nulltimer(0), type(Qt::CoarseTimer)
{
    Q_UNUSED(del);  // ### Qt 6: remove field
}


// 在类的析构方法里面, 应该去管理类所管理的资源.
QTimer::~QTimer()
{
    if (id != INV_TIMER)                        // stop running timer
        stop();
}

// 可以看到, 其实还是用了 QObject::startTimer 作为最终的实现, 这个类, 仅仅是用面向对象的方式, 增加了一层包装而已.
void QTimer::start()
{
    if (id != INV_TIMER)                        // stop running timer
        stop();
    nulltimer = (!inter && single);
    id = QObject::startTimer(inter, Qt::TimerType(type));
}


void QTimer::start(int msec)
{
    inter = msec;
    start();
}

void QTimer::stop()
{
    if (id != INV_TIMER) {
        QObject::killTimer(id);
        id = INV_TIMER; // 在 Timer 失效时候, 将 id 重置为 INV_TIMER, 用来表示, 该 timer 处于失效的状态.
    }
}

// 为什么 QTimer 能够发射 timeOut 信号的原因就在这里了. 还是在 timerEvent 里面, 用 id 进行判断之后, 主动的进行发送.
// 现在需要找到, 为什么事件处理的过程中, 会到这里.
void QTimer::timerEvent(QTimerEvent *e)
{
    if (e->timerId() == id) {
        if (single) {
            stop();
        }
        emit timeout(QPrivateSignal());
    }
}

// 修改 Interval, 会将 timer 重新注册到事件循环里面.
void QTimer::setInterval(int msec)
{
    inter = msec;
    if (id != INV_TIMER) {                        // create new timer
        QObject::killTimer(id);                        // restart timer
        id = QObject::startTimer(msec, Qt::TimerType(type));
    }
}

// 直接去线程里面询问, 当前的 Timer 的剩余时间. 因为, Timer 这个概念, 本身就是线程提供的.
int QTimer::remainingTime() const
{
    if (id != INV_TIMER) {
        return QAbstractEventDispatcher::instance()->remainingTime(id);
    }

    return -1;
}

//! 一个很特殊的类, 专门应对单次事件的调用. 和 dispatch_after 的作用是一样的.
class QSingleShotTimer : public QObject
{
    Q_OBJECT
    int timerId;
    bool hasValidReceiver;
    QPointer<const QObject> receiver;
    QtPrivate::QSlotObjectBase *slotObj;
public:
    ~QSingleShotTimer();
    QSingleShotTimer(int msec, Qt::TimerType timerType, const QObject *r, const char * m);
    QSingleShotTimer(int msec, Qt::TimerType timerType, const QObject *r, QtPrivate::QSlotObjectBase *slotObj);

Q_SIGNALS:
    void timeout();
protected:
    void timerEvent(QTimerEvent *) Q_DECL_OVERRIDE;
};


// 基本思路是, 在构造方法里面, 创建一个定时器, 然后将 timeout 信号和 receiver 进行关联.
// 这里有个疑问, QSingleShotTimer 对象自己的生命周期是如何进行的管理.
QSingleShotTimer::QSingleShotTimer(int msec, Qt::TimerType timerType, const QObject *r, const char *member)
    : QObject(QAbstractEventDispatcher::instance()), hasValidReceiver(true), slotObj(0)
{
    timerId = startTimer(msec, timerType);
    connect(this, SIGNAL(timeout()), r, member);
}

QSingleShotTimer::QSingleShotTimer(int msec, Qt::TimerType timerType, const QObject *r, QtPrivate::QSlotObjectBase *slotObj)
    : QObject(QAbstractEventDispatcher::instance()), hasValidReceiver(r), receiver(r), slotObj(slotObj)
{
    timerId = startTimer(msec, timerType);
    if (r && thread() != r->thread()) {
        // Avoid leaking the QSingleShotTimer instance in case the application exits before the timer fires
        // 这里, 在 Application 的 aboutToQuit 信号发出来的时候, 会做一次清理工作.
        connect(QCoreApplication::instance(), &QCoreApplication::aboutToQuit, this, &QObject::deleteLater);
        setParent(0);
        moveToThread(r->thread());
    }
}

QSingleShotTimer::~QSingleShotTimer()
{
    if (timerId > 0)
        killTimer(timerId);
    if (slotObj)
        slotObj->destroyIfLastRef();
}

// 在 timerEvent 发生之后, 立马进行 killTimer.
// 如果注册了回调对象, 就调用相应的函数, 如果没有, 就发出一个信号.
void QSingleShotTimer::timerEvent(QTimerEvent *)
{
    // need to kill the timer _before_ we emit timeout() in case the
    // slot connected to timeout calls processEvents()
    if (timerId > 0)
        killTimer(timerId);
    timerId = -1;

    if (slotObj) {
        // If the receiver was destroyed, skip this part
        if (Q_LIKELY(!receiver.isNull() || !hasValidReceiver)) {
            // We allocate only the return type - we previously checked the function had
            // no arguments.
            void *args[1] = { 0 };
            slotObj->call(const_cast<QObject*>(receiver.data()), args);
        }
    } else {
        emit timeout();
    }

    // we would like to use delete later here, but it feels like a
    // waste to post a new event to handle this event, so we just unset the flag
    // and explicitly delete...
    qDeleteInEventHandler(this);
}

// 使用对象的构造函数, 进行方法的调用.
void QTimer::singleShotImpl(int msec, Qt::TimerType timerType,
                            const QObject *receiver,
                            QtPrivate::QSlotObjectBase *slotObj)
{
    new QSingleShotTimer(msec, timerType, receiver, slotObj);
}


void QTimer::singleShot(int msec, const QObject *receiver, const char *member)
{
    // coarse timers are worst in their first firing
    // so we prefer a high precision timer for something that happens only once
    // unless the timeout is too big, in which case we go for coarse anyway
    singleShot(msec, msec >= 2000 ? Qt::CoarseTimer : Qt::PreciseTimer, receiver, member);
}

void QTimer::singleShot(int msec, Qt::TimerType timerType, const QObject *receiver, const char *member)
{
    if (Q_UNLIKELY(msec < 0)) {
        qWarning("QTimer::singleShot: Timers cannot have negative timeouts");
        return;
    }
    if (receiver && member) {
        if (msec == 0) { // 如果没有时间间隔, 直接调用方法.
            // special code shortpath for 0-timers
            const char* bracketPosition = strchr(member, '(');
            if (!bracketPosition || !(member[0] >= '0' && member[0] <= '2')) {
                qWarning("QTimer::singleShot: Invalid slot specification");
                return;
            }
            QByteArray methodName(member+1, bracketPosition - 1 - member); // extract method name
            QMetaObject::invokeMethod(const_cast<QObject *>(receiver), methodName.constData(), Qt::QueuedConnection);
            return;
        }
        (void) new QSingleShotTimer(msec, timerType, receiver, member);
    }
}


QT_END_NAMESPACE

#include "qtimer.moc"
#include "moc_qtimer.cpp"
