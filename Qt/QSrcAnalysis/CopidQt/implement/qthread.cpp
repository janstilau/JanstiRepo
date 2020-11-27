#include "qthread.h"
#include "qthreadstorage.h"
#include "qmutex.h"
#include "qreadwritelock.h"
#include "qabstracteventdispatcher.h"

#include <qeventloop.h>

#include "qthread_p.h"
#include "private/qcoreapplication_p.h"

QT_BEGIN_NAMESPACE

QThreadData::QThreadData(int initialRefCount)
    : _ref(initialRefCount), loopLevel(0), scopeLevel(0),
      eventDispatcher(0),
      quitNow(false),
      canWait(true),
      isAdopted(false),
      requiresCoreApplication(true)
{
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

    // 当一个线程退出时, 如果还有没有处理的 PostEvent, 这里要进行一些清理工作.
    for (int i = 0; i < postEventList.size(); ++i) {
        const QPostEvent &pe = postEventList.at(i);
        if (pe.event) {
            --pe.receiver->d_func()->postedEvents;
            pe.event->posted = false;
            delete pe.event;
        }
    }
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
    if (!data)
        data = new QThreadData;
}

QThreadPrivate::~QThreadPrivate()
{
    data->deref();
}

//! QThreadData::current 的实现, 类似于 NSThread 的实现, 通过 getSpecific 获取到和线程绑定的值.
//! 和线程绑定的值, 在 Qt 环境下, 是 QThreadData.
QThread *QThread::currentThread()
{
    QThreadData *data = QThreadData::current();
    return data->thread;
}

//! 各个类库的线程类, 只是为了方便管理线程而创建出来的对象. 线程的概念还是操作系统的概念. 线程类对象的周期和线程的生命周期一定要区分开.
QThread::QThread(QObject *parent)
    : QObject(*(new QThreadPrivate), parent)
{
    Q_D(QThread);
    // fprintf(stderr, "QThreadData %p created for thread %p\n", d->data, this);
    d->data->thread = this;
}

QThread::QThread(QThreadPrivate &dd, QObject *parent)
    : QObject(dd, parent)
{
    Q_D(QThread);
    d->data->thread = this;
}

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

// 调用这个方法的, 一定是创建线程对象的线程, 而线程对象状态的改变, 会是在线程对象管理的线程中, 所以一定要加锁.
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
    // 所以, 使用 QThread 不重写它的 run 方法, 开启的线程是不会结束的.
    // 通过 QThread::terminate 是使用了线程的原语强制结束的线程. 线程自己运转是不会走向终点的
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
    // 转移, 这里是在另外的一个线程, 调用的该方法.
    // 在另外的线程, 改变了线程内的数据, 这样在 exec 里面一直运行的死循环, 就能够跳出了.
    for (int i = 0; i < d->data->eventLoops.size(); ++i) {
        QEventLoop *eventLoop = d->data->eventLoops.at(i);
        eventLoop->exit(returnCode);
    }
}

void QThread::quit()
{ exit(); }

// 默认 run 是有实现的, 就是 exec 内部开启运行循环.
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
