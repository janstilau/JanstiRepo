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

#include "qthread.h"
#include "qthreadstorage.h"
#include "qmutex.h"
#include "qreadwritelock.h"
#include "qabstracteventdispatcher.h"

#include <qeventloop.h>

#include "qthread_p.h"
#include "private/qcoreapplication_p.h"

QT_BEGIN_NAMESPACE

/*
  QThreadData
*/

QThreadData::QThreadData(int initialRefCount)
    : _ref(initialRefCount), loopLevel(0), scopeLevel(0),
      eventDispatcher(0),
      quitNow(false),
      canWait(true),
      isAdopted(false),
      requiresCoreApplication(true)
{
    // fprintf(stderr, "QThreadData %p created\n", this);
}

QThreadData::~QThreadData()
{
    Q_ASSERT(_ref.load() == 0);

    if (this->thread == QCoreApplicationPrivate::theMainThread) {
       QCoreApplicationPrivate::theMainThread = 0;
       QThreadData::clearCurrentThreadData();
    }
    QThread *t = thread;
    thread = 0;
    delete t;

    for (int i = 0; i < postEventList.size(); ++i) {
        const QPostEvent &pe = postEventList.at(i);
        if (pe.event) {
            --pe.receiver->d_func()->postedEvents;
            pe.event->posted = false;
            delete pe.event;
        }
    }

    // fprintf(stderr, "QThreadData %p destroyed\n", this);
}

void QThreadData::ref()
{
#ifndef QT_NO_THREAD
    (void) _ref.ref();
    Q_ASSERT(_ref.load() != 0);
#endif
}

void QThreadData::deref()
{
#ifndef QT_NO_THREAD
    if (!_ref.deref())
        delete this;
#endif
}

/*
  QThreadPrivate
*/

QThreadPrivate::QThreadPrivate(QThreadData *d)
    : QObjectPrivate(),
      running(false),
      finished(false),
      isInFinish(false),
      interruptionRequested(false),
      exited(false),
      returnCode(-1),
      stackSize(0),
      priority(QThread::InheritPriority),
      data(d)
{

// INTEGRITY doesn't support self-extending stack. The default stack size for
// a pthread on INTEGRITY is too small so we have to increase the default size
// to 128K.
#ifdef Q_OS_INTEGRITY
    stackSize = 128 * 1024;
#endif

#if defined (Q_OS_WIN)
    handle = 0;
#  ifndef Q_OS_WINRT
    id = 0;
#  endif
    waiters = 0;
    terminationEnabled = true;
    terminatePending = false;
#endif

    if (!data)
        data = new QThreadData;
}

QThreadPrivate::~QThreadPrivate()
{
    data->deref();
}

/*!
    Returns a pointer to a QThread which manages the currently
    executing thread.
*/
QThread *QThread::currentThread()
{
    QThreadData *data = QThreadData::current();
    Q_ASSERT(data != 0);
    return data->thread;
}

/*!
    Constructs a new QThread to manage a new thread. The \a parent
    takes ownership of the QThread. The thread does not begin
    executing until start() is called.

    \sa start()
*/
QThread::QThread(QObject *parent)
    : QObject(*(new QThreadPrivate), parent)
{
    Q_D(QThread);
    // fprintf(stderr, "QThreadData %p created for thread %p\n", d->data, this);
    d->data->thread = this;
}

/*!
    \internal
 */
QThread::QThread(QThreadPrivate &dd, QObject *parent)
    : QObject(dd, parent)
{
    Q_D(QThread);
    // fprintf(stderr, "QThreadData %p taken from private data for thread %p\n", d->data, this);
    d->data->thread = this;
}

/*!
    这里就和 NSThread 一样, QThread 的对象的生命周期, 和线程的声明周期是不一致的.
    QThread 仅仅是一个方便管理 pThread 的对象而已.
*/
QThread::~QThread()
{
    Q_D(QThread);
    {
        QMutexLocker locker(&d->mutex);
        if (d->isInFinish) {
            locker.unlock();
            wait();
            locker.relock();
        }
        if (d->running && !d->finished && !d->data->isAdopted)
            qFatal("QThread: Destroyed while thread is still running");

        d->data->thread = 0;
    }
}


bool QThread::isFinished() const
{
    Q_D(const QThread);
    QMutexLocker locker(&d->mutex);
    return d->finished || d->isInFinish;
}

bool QThread::isRunning() const
{
    Q_D(const QThread);
    QMutexLocker locker(&d->mutex);
    return d->running && !d->isInFinish;
}

void QThread::setStackSize(uint stackSize)
{
    Q_D(QThread);
    QMutexLocker locker(&d->mutex);
    Q_ASSERT_X(!d->running, "QThread::setStackSize",
               "cannot change stack size while the thread is running");
    d->stackSize = stackSize;
}

uint QThread::stackSize() const
{
    Q_D(const QThread);
    QMutexLocker locker(&d->mutex);
    return d->stackSize;
}

int QThread::exec()
{
    Q_D(QThread);
    QMutexLocker locker(&d->mutex);
    d->data->quitNow = false;
    if (d->exited) {
        d->exited = false;
        return d->returnCode;
    }
    locker.unlock();

    // 在这里, 开启了一个新的运行循环.
    QEventLoop eventLoop;
    int returnCode = eventLoop.exec();

    locker.relock();
    d->exited = false;
    d->returnCode = -1;
    return returnCode;
}

void QThread::exit(int returnCode)
{
    Q_D(QThread);
    QMutexLocker locker(&d->mutex);
    d->exited = true;
    d->returnCode = returnCode;
    d->data->quitNow = true;
    // 这里把线程相关的全部循环关闭了
    for (int i = 0; i < d->data->eventLoops.size(); ++i) {
        QEventLoop *eventLoop = d->data->eventLoops.at(i);
        eventLoop->exit(returnCode);
    }
}

void QThread::quit()
{ exit(); }

void QThread::run()
{
    (void) exec();
}

void QThread::setPriority(Priority priority)
{
    Q_D(QThread);
    QMutexLocker locker(&d->mutex);
    if (!d->running) {
        qWarning("QThread::setPriority: Cannot set priority, thread is not running");
        return;
    }
    d->setPriority(priority);
}


QThread::Priority QThread::priority() const
{
    Q_D(const QThread);
    QMutexLocker locker(&d->mutex);

    // mask off the high bits that are used for flags
    return Priority(d->priority & 0xffff);
}

int QThread::loopLevel() const
{
    Q_D(const QThread);
    return d->data->eventLoops.size();
}

#else // QT_NO_THREAD

QThread::QThread(QObject *parent)
    : QObject(*(new QThreadPrivate), (QObject*)0){
    Q_D(QThread);
    d->data->thread = this;
}

QThread *QThread::currentThread()
{
    return QThreadData::current()->thread;
}

QThreadData* QThreadData::current()
{
    static QThreadData *data = 0; // reinterpret_cast<QThreadData *>(pthread_getspecific(current_thread_data_key));
    if (!data) {
        QScopedPointer<QThreadData> newdata(new QThreadData);
        newdata->thread = new QAdoptedThread(newdata.data());
        data = newdata.take();
        data->deref();
    }
    return data;
}

/*!
    \internal
 */
QThread::QThread(QThreadPrivate &dd, QObject *parent)
    : QObject(dd, parent)
{
    Q_D(QThread);
    // fprintf(stderr, "QThreadData %p taken from private data for thread %p\n", d->data, this);
    d->data->thread = this;
}

#endif // QT_NO_THREAD

/*!
    \since 5.0

    Returns a pointer to the event dispatcher object for the thread. If no event
    dispatcher exists for the thread, this function returns 0.
*/
QAbstractEventDispatcher *QThread::eventDispatcher() const
{
    Q_D(const QThread);
    return d->data->eventDispatcher.load();
}

/*!
    \since 5.0

    Sets the event dispatcher for the thread to \a eventDispatcher. This is
    only possible as long as there is no event dispatcher installed for the
    thread yet. That is, before the thread has been started with start() or, in
    case of the main thread, before QCoreApplication has been instantiated.
    This method takes ownership of the object.
*/
void QThread::setEventDispatcher(QAbstractEventDispatcher *eventDispatcher)
{
    Q_D(QThread);
    if (d->data->hasEventDispatcher()) {
        qWarning("QThread::setEventDispatcher: An event dispatcher has already been created for this thread");
    } else {
        eventDispatcher->moveToThread(this);
        if (eventDispatcher->thread() == this) // was the move successful?
            d->data->eventDispatcher = eventDispatcher;
        else
            qWarning("QThread::setEventDispatcher: Could not move event dispatcher to target thread");
    }
}

/*!
    \reimp
*/
bool QThread::event(QEvent *event)
{
    if (event->type() == QEvent::Quit) {
        quit();
        return true;
    } else {
        return QObject::event(event);
    }
}

/*!
    \since 5.2

    Request the interruption of the thread.
    That request is advisory and it is up to code running on the thread to decide
    if and how it should act upon such request.
    This function does not stop any event loop running on the thread and
    does not terminate it in any way.

    \sa isInterruptionRequested()
*/

void QThread::requestInterruption()
{
    Q_D(QThread);
    QMutexLocker locker(&d->mutex);
    if (!d->running || d->finished || d->isInFinish)
        return;
    if (this == QCoreApplicationPrivate::theMainThread) {
        qWarning("QThread::requestInterruption has no effect on the main thread");
        return;
    }
    d->interruptionRequested = true;
}

/*!
    \since 5.2

    Return true if the task running on this thread should be stopped.
    An interruption can be requested by requestInterruption().

    This function can be used to make long running tasks cleanly interruptible.
    Never checking or acting on the value returned by this function is safe,
    however it is advisable do so regularly in long running functions.
    Take care not to call it too often, to keep the overhead low.

    \code
    void long_task() {
         forever {
            if ( QThread::currentThread()->isInterruptionRequested() ) {
                return;
            }
        }
    }
    \endcode

    \sa currentThread() requestInterruption()
*/
bool QThread::isInterruptionRequested() const
{
    Q_D(const QThread);
    QMutexLocker locker(&d->mutex);
    if (!d->running || d->finished || d->isInFinish)
        return false;
    return d->interruptionRequested;
}



QT_END_NAMESPACE

#include "moc_qthread.cpp"
