/****************************************************************************
**
** Copyright (C) 2016 The Qt Company Ltd.
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

#ifndef QFUTUREINTERFACE_P_H
#define QFUTUREINTERFACE_P_H

//
//  W A R N I N G
//  -------------
//
// This file is not part of the Qt API.  It exists purely as an
// implementation detail.  This header file may change from version to
// version without notice, or even be removed.
//
// We mean it.
//

#include <QtCore/private/qglobal_p.h>
#include <QtCore/qelapsedtimer.h>
#include <QtCore/qcoreevent.h>
#include <QtCore/qlist.h>
#include <QtCore/qwaitcondition.h>
#include <QtCore/qrunnable.h>
#include <QtCore/qthreadpool.h>

QT_REQUIRE_CONFIG(future);

QT_BEGIN_NAMESPACE

class QFutureCallOutEvent : public QEvent
{
public:
    enum CallOutType {
        Started,
        Finished,
        Canceled,
        Paused,
        Resumed,
        Progress,
        ProgressRange,
        ResultsReady
    };

    QFutureCallOutEvent()
        : QEvent(QEvent::FutureCallOut), callOutType(CallOutType(0)), index1(-1), index2(-1)
    { }
    explicit QFutureCallOutEvent(CallOutType callOutType, int index1 = -1)
        : QEvent(QEvent::FutureCallOut), callOutType(callOutType), index1(index1), index2(-1)
    { }
    QFutureCallOutEvent(CallOutType callOutType, int index1, int index2)
        : QEvent(QEvent::FutureCallOut), callOutType(callOutType), index1(index1), index2(index2)
    { }

    QFutureCallOutEvent(CallOutType callOutType, int index1, const QString &text)
        : QEvent(QEvent::FutureCallOut),
          callOutType(callOutType),
          index1(index1),
          index2(-1),
          text(text)
    { }

    CallOutType callOutType;
    int index1;
    int index2;
    QString text;

    QFutureCallOutEvent *clone() const
    {
        return new QFutureCallOutEvent(callOutType, index1, index2, text);
    }

private:
    QFutureCallOutEvent(CallOutType callOutType,
                        int index1,
                        int index2,
                        const QString &text)
        : QEvent(QEvent::FutureCallOut),
          callOutType(callOutType),
          index1(index1),
          index2(index2),
          text(text)
    { }
};

class QFutureCallOutInterface
{
public:
    virtual ~QFutureCallOutInterface() {}
    virtual void postCallOutEvent(const QFutureCallOutEvent &) = 0;
    virtual void callOutInterfaceDisconnected() = 0;
};

// 这个类, 应该充当的是, 共享数据的作用.
class QFutureInterfaceBasePrivate
{
public:
    QFutureInterfaceBasePrivate(QFutureInterfaceBase::State initialState);

    // When the last QFuture<T> reference is removed, we need to make
    // sure that data stored in the ResultStore is cleaned out.
    // Since QFutureInterfaceBasePrivate can be shared between QFuture<T>
    // and QFuture<void> objects, we use a separate ref. counter
    // to keep track of QFuture<T> objects.
    class RefCount
    {
    public:
        inline RefCount(int r = 0, int rt = 0)
            : m_refCount(r), m_refCountT(rt) {}
        // Default ref counter for QFIBP
        inline bool ref() { return m_refCount.ref(); }
        inline bool deref() { return m_refCount.deref(); }
        inline int load() const { return m_refCount.loadRelaxed(); }
        // Ref counter for type T
        inline bool refT() { return m_refCountT.ref(); }
        inline bool derefT() { return m_refCountT.deref(); }
        inline int loadT() const { return m_refCountT.loadRelaxed(); }

    private:
        QAtomicInt m_refCount;
        QAtomicInt m_refCountT;
    };

    // T: accessed from executing thread
    // Q: accessed from the waiting/querying thread
    RefCount refCount;

    mutable QMutex m_mutex;
    QWaitCondition waitCondition;
    /*
     * 上面的这两个值, 应该就是线程同步所使用的两个锁和条件变量.
     */

    QRunnable *runnable;
    QThreadPool *m_pool;
    /*
     * 上面的这两个值, 就是真正的异步操作任务的包装.
     */

    QAtomicInt state; // reads and writes can happen unprotected, both must be atomic
    /*
     * 表示任务的当前状态, 类的内部, 应该正确的维护该值. 各种函数操作, 以 state 值作为操作的起始的判断依据.
     */

    int m_progressValue; // TQ
    int m_progressMinimum; // TQ
    int m_progressMaximum; // TQ
    int m_expectedResultCount;
    /*
     * Qt 自己设计的进度管理相关的数据.
     */

    QtPrivate::ResultStoreBase m_results;
    /*
     * 真正的 Result 值存储的位置. 当产生了数据之后, 应该改变里面的内容, 然后进行 report 操作.
     * 其他线程, 可以 waitForIndex, 这样, 可以逐步的产生数据, 逐步的唤起其他线程.
     */

    QtPrivate::ExceptionStore m_exceptionStore;
    /*
     * 异常存储, 各种 get value 的操作, 首先会进行异常的验证. 如果已经产生了异常, 直接进行 raise 处理.
     */

    QElapsedTimer progressTime;
    QWaitCondition pausedWaitCondition;
    bool manualProgress; // only accessed from executing thread
    QString m_progressText;


    QList<QFutureCallOutInterface *> outputConnections;

    /*
     * 整个 QFutureInterfaceBasePrivate 就是一个大的状态管理设计.
     * 在这个设计里面, 将异步结果进行存储, 异常结果进行了存储.
     * 将异步控制的 锁, 条件变量等信息进行了存储.
     *
     * 各 Future 类, 仅仅是
     */



    inline QThreadPool *pool() const
    { return m_pool ? m_pool : QThreadPool::globalInstance(); }

    // Internal functions that does not change the mutex state.
    // The mutex must be locked when calling these.
    int internal_resultCount() const;
    bool internal_isResultReadyAt(int index) const;
    bool internal_waitForNextResult();
    bool internal_updateProgress(int progress, const QString &progressText = QString());
    void internal_setThrottled(bool enable);
    void sendCallOut(const QFutureCallOutEvent &callOut);
    void sendCallOuts(const QFutureCallOutEvent &callOut1, const QFutureCallOutEvent &callOut2);
    void connectOutputInterface(QFutureCallOutInterface *iface);
    void disconnectOutputInterface(QFutureCallOutInterface *iface);

    void setState(QFutureInterfaceBase::State state);
};

QT_END_NAMESPACE

#endif
