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
      quitNow(false), canWait(true), isAdopted(false), requiresCoreApplication(true)
{
}

QThreadData::~QThreadData()
{
    Q_ASSERT(_ref.load() == 0);

    // In the odd case that Qt is running on a secondary thread, the main
    // thread instance will have been dereffed asunder because of the deref in
    // QThreadData::current() and the deref in the pthread_destroy. To avoid
    // crashing during QCoreApplicationData's global static cleanup we need to
    // safeguard the main thread here.. This fix is a bit crude, but it solves
    // the problem...
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
    (void) _ref.ref();
}

void QThreadData::deref()
{
    if (!_ref.deref())
        delete this;
}

/*
  QThreadPrivate
*/

QThreadPrivate::QThreadPrivate(QThreadData *d)
    : QObjectPrivate(), running(false), finished(false),
      isInFinish(false), interruptionRequested(false),
      exited(false), returnCode(-1),
      stackSize(0), priority(QThread::InheritPriority), data(d)
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

// 类方法, 获取当前线程所对应的 QThread.
// 其实就是全局表里面, 查找当前 threadid 对应的数据.
// 或者使用, getSepecific 来获取.
QThread *QThread::currentThread()
{
    QThreadData *data = QThreadData::current();
    return data->thread;
}

QThread::QThread(QObject *parent)
    : QObject(*(new QThreadPrivate), parent)
{
    Q_D(QThread);
    d->data->thread = this;
}


/*!
    Destroys the QThread.

    Note that deleting a QThread object will not stop the execution
    of the thread it manages. Deleting a running QThread (i.e.
    isFinished() returns \c false) will result in a program
    crash. Wait for the finished() signal before deleting the
    QThread.
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

// 最主要的是, 开启了一个事件循环.
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

    //运行循环, 是一个耗时操作. 在之前, 进行 unlock 的操作.

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
    // 在这里, 将所有的事件循环退出了.
    for (int i = 0; i < d->data->eventLoops.size(); ++i) {
        QEventLoop *eventLoop = d->data->eventLoops.at(i);
        eventLoop->exit(returnCode);
    }
}

void QThread::quit()
{ exit(); }

// 线程的入口函数, 会调用到 QThread::run 方法. 和 NSThread 类似的场景.
// 在真正执行 run 之前, 会做各种关于 thread 数据的准备工作.
// 和 NSThread 不同的是, Qt 的 thread 可以重复 start.
// 默认, QThread 启动一个运行循环.
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

// d->interruptionRequested , 如果不在 run 方法里面, 周期性的判断该值, 那么这个值是没有作用的.
// 默认在 eventloop 里面, 这个值是不会被考虑的.
void QThread::requestInterruption()
{
    Q_D(QThread);
    QMutexLocker locker(&d->mutex);
    if (!d->running || d->finished || d->isInFinish)
        return;
    if (this == QCoreApplicationPrivate::theMainThread) {
        // 主线程, 不能退出.
        return;
    }
    d->interruptionRequested = true;
}

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
