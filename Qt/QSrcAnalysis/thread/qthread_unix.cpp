#include "qthread.h"

#include "qplatformdefs.h"


QT_BEGIN_NAMESPACE

#ifndef QT_NO_THREAD

Q_STATIC_ASSERT(sizeof(pthread_t) <= sizeof(Qt::HANDLE));

enum { ThreadPriorityResetFlag = 0x80000000 };


static pthread_once_t current_thread_data_once = PTHREAD_ONCE_INIT;
static pthread_key_t current_thread_data_key;

static void destroy_current_thread_data(void *p)
{
    // POSIX says the value in our key is set to zero before calling
    // this destructor function, so we need to set it back to the
    // right value...
    pthread_setspecific(current_thread_data_key, p);
    QThreadData *data = static_cast<QThreadData *>(p);
    if (data->isAdopted) {
        QThread *thread = data->thread;
        Q_ASSERT(thread);
        QThreadPrivate *thread_p = static_cast<QThreadPrivate *>(QObjectPrivate::get(thread));
        Q_ASSERT(!thread_p->finished);
        thread_p->finish(thread);
    }
    data->deref();

    // ... but we must reset it to zero before returning so we aren't
    // called again (POSIX allows implementations to call destructor
    // functions repeatedly until all values are zero)
    pthread_setspecific(current_thread_data_key, 0);
}

static void create_current_thread_data_key()
{
    pthread_key_create(&current_thread_data_key, destroy_current_thread_data);
}

static void destroy_current_thread_data_key()
{
    pthread_once(&current_thread_data_once, create_current_thread_data_key);
    pthread_key_delete(current_thread_data_key);

    // Reset current_thread_data_once in case we end up recreating
    // the thread-data in the rare case of QObject construction
    // after destroying the QThreadData.
    pthread_once_t pthread_once_init = PTHREAD_ONCE_INIT;
    current_thread_data_once = pthread_once_init;
}
Q_DESTRUCTOR_FUNCTION(destroy_current_thread_data_key)


// 实际上, 就是使用了 pthread_getspecific 获取到的对应的数据.
static QThreadData *get_thread_data()
{
    pthread_once(&current_thread_data_once, create_current_thread_data_key);
    return reinterpret_cast<QThreadData *>(pthread_getspecific(current_thread_data_key));
}

static void set_thread_data(QThreadData *data)
{
    pthread_once(&current_thread_data_once, create_current_thread_data_key);
    pthread_setspecific(current_thread_data_key, data);
}

static void clear_thread_data()
{
    pthread_setspecific(current_thread_data_key, 0);
}

template <typename T>
static typename std::enable_if<QTypeInfo<T>::isIntegral, Qt::HANDLE>::type to_HANDLE(T id)
{
    return reinterpret_cast<Qt::HANDLE>(static_cast<intptr_t>(id));
}

template <typename T>
static typename std::enable_if<QTypeInfo<T>::isIntegral, T>::type from_HANDLE(Qt::HANDLE id)
{
    return static_cast<T>(reinterpret_cast<intptr_t>(id));
}

template <typename T>
static typename std::enable_if<QTypeInfo<T>::isPointer, Qt::HANDLE>::type to_HANDLE(T id)
{
    return id;
}

template <typename T>
static typename std::enable_if<QTypeInfo<T>::isPointer, T>::type from_HANDLE(Qt::HANDLE id)
{
    return static_cast<T>(id);
}

void QThreadData::clearCurrentThreadData()
{
    clear_thread_data();
}

QThreadData *QThreadData::current(bool createIfNecessary)
{
    QThreadData *data = get_thread_data();
    if (!data && createIfNecessary) {
        data = new QThreadData;
        QT_TRY {
            set_thread_data(data);
            data->thread = new QAdoptedThread(data);
        } QT_CATCH(...) {
            clear_thread_data();
            data->deref();
            data = 0;
            QT_RETHROW;
        }
        data->deref();
        data->isAdopted = true;
        data->threadId.store(to_HANDLE(pthread_self()));
        if (!QCoreApplicationPrivate::theMainThread)
            QCoreApplicationPrivate::theMainThread = data->thread.load();
    }
    return data;
}


void QAdoptedThread::init()
{
}

/*
   QThreadPrivate
*/

extern "C" {
typedef void*(*QtThreadCallback)(void*);
}

#endif // QT_NO_THREAD

// 在线程创建的时候, 进行了事件分发的指定工作.
void QThreadPrivate::createEventDispatcher(QThreadData *data)
{
#if defined(Q_OS_DARWIN)
    bool ok = false;
    int value = qEnvironmentVariableIntValue("QT_EVENT_DISPATCHER_CORE_FOUNDATION", &ok);
    if (ok && value > 0)
        data->eventDispatcher.storeRelease(new QEventDispatcherCoreFoundation);
    else
        data->eventDispatcher.storeRelease(new QEventDispatcherUNIX);
#elif !defined(QT_NO_GLIB)
    if (qEnvironmentVariableIsEmpty("QT_NO_GLIB")
        && qEnvironmentVariableIsEmpty("QT_NO_THREADED_GLIB")
        && QEventDispatcherGlib::versionSupported())
        data->eventDispatcher.storeRelease(new QEventDispatcherGlib);
    else
        data->eventDispatcher.storeRelease(new QEventDispatcherUNIX);
#else
    data->eventDispatcher.storeRelease(new QEventDispatcherUNIX);
#endif

    data->eventDispatcher.load()->startingUp();
}

#ifndef QT_NO_THREAD


// 真正的启动线程的启动函数.
void *QThreadPrivate::start(void *arg)
{
    QThread *thr = reinterpret_cast<QThread *>(arg);
    QThreadData *data = QThreadData::get2(thr);

    {
        QMutexLocker locker(&thr->d_func()->mutex);

        // do we need to reset the thread priority?
        if (int(thr->d_func()->priority) & ThreadPriorityResetFlag) {
            thr->d_func()->setPriority(QThread::Priority(thr->d_func()->priority & ~ThreadPriorityResetFlag));
        }

        data->threadId.store(to_HANDLE(pthread_self()));
        set_thread_data(data);

        data->ref();
        data->quitNow = thr->d_func()->exited;
    }

    if (data->eventDispatcher.load()) // custom event dispatcher set?
        data->eventDispatcher.load()->startingUp();
    else
        createEventDispatcher(data);

    emit thr->started(QThread::QPrivateSignal());

    // 前面都是一些数据的设置, 在这里, 使用 QThread -> run , 一般情况下, QThread 的子类, 就是重写该方法.
    thr->run();

    pthread_cleanup_pop(1);

    return 0;
}

void QThreadPrivate::finish(void *arg)
{
    QThread *thr = reinterpret_cast<QThread *>(arg);
    QThreadPrivate *d = thr->d_func();

    QMutexLocker locker(&d->mutex);

    d->isInFinish = true;
    d->priority = QThread::InheritPriority;
    void *data = &d->data->tls;
    locker.unlock();
    emit thr->finished(QThread::QPrivateSignal());
    QCoreApplication::sendPostedEvents(0, QEvent::DeferredDelete);
    QThreadStorageData::finish((void **)data);
    locker.relock();

    QAbstractEventDispatcher *eventDispatcher = d->data->eventDispatcher.load();
    if (eventDispatcher) {
        d->data->eventDispatcher = 0;
        locker.unlock();
        eventDispatcher->closingDown();
        delete eventDispatcher;
        locker.relock();
    }

    d->running = false;
    d->finished = true;
    d->interruptionRequested = false;

    d->isInFinish = false;
    d->thread_done.wakeAll();
}




/**************************************************************************
 ** QThread
 *************************************************************************/

Qt::HANDLE QThread::currentThreadId() Q_DECL_NOTHROW
{
    // requires a C cast here otherwise we run into trouble on AIX
    return to_HANDLE(pthread_self());
}

int QThread::idealThreadCount() Q_DECL_NOTHROW
{
    int cores = 1;
    return cores;
}

void QThread::yieldCurrentThread()
{
    sched_yield();
}

static timespec makeTimespec(time_t secs, long nsecs)
{
    struct timespec ts;
    ts.tv_sec = secs;
    ts.tv_nsec = nsecs;
    return ts;
}

void QThread::sleep(unsigned long secs)
{
    qt_nanosleep(makeTimespec(secs, 0));
}

void QThread::msleep(unsigned long msecs)
{
    qt_nanosleep(makeTimespec(msecs / 1000, msecs % 1000 * 1000 * 1000));
}

void QThread::usleep(unsigned long usecs)
{
    qt_nanosleep(makeTimespec(usecs / 1000 / 1000, usecs % (1000*1000) * 1000));
}

// 线程的起始函数.
void QThread::start(Priority priority)
{
    Q_D(QThread);
    QMutexLocker locker(&d->mutex);
    if (d->isInFinish)
        d->thread_done.wait(locker.mutex());

    if (d->running)
        return;

    d->running = true;
    d->finished = false;
    d->returnCode = 0;
    d->exited = false;
    d->interruptionRequested = false;

    pthread_attr_t attr;
    pthread_attr_init(&attr);
    // 直接就是 Detach 的状态.
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);

    d->priority = priority;

    pthread_t threadId;

    // 前面都是数据的设置, 这里, 是使用 pthread_create 创建线程. 统一的 start 作为起始函数, 传递 QThread 对象

    int code = pthread_create(&threadId, &attr, QThreadPrivate::start, this);
    if (code == EPERM) {
        // caller does not have permission to set the scheduling
        // parameters/policy
        code = pthread_create(&threadId, &attr, QThreadPrivate::start, this);
    }
    d->data->threadId.store(to_HANDLE(threadId));

    pthread_attr_destroy(&attr);

    if (code) {
        qWarning("QThread::start: Thread creation error: %s", qPrintable(qt_error_string(code)));

        d->running = false;
        d->finished = false;
        d->data->threadId.store(nullptr);
    }
}

// 直接调用的 pthread_cancel 方法
void QThread::terminate()
{
#if !defined(Q_OS_ANDROID)
    Q_D(QThread);
    QMutexLocker locker(&d->mutex);

    if (!d->data->threadId.load())
        return;

    int code = pthread_cancel(from_HANDLE<pthread_t>(d->data->threadId.load()));
    if (code) {
        qWarning("QThread::start: Thread termination error: %s",
                 qPrintable(qt_error_string((code))));
    }
#endif
}

bool QThread::wait(unsigned long time)
{
    Q_D(QThread);
    QMutexLocker locker(&d->mutex);

    if (from_HANDLE<pthread_t>(d->data->threadId.load()) == pthread_self()) {
        qWarning("QThread::wait: Thread tried to wait on itself");
        return false;
    }

    if (d->finished || !d->running)
        return true;

    while (d->running) {
        if (!d->thread_done.wait(locker.mutex(), time))
            return false;
    }
    return true;
}

void QThread::setTerminationEnabled(bool enabled)
{
    QThread *thr = currentThread();
    Q_ASSERT_X(thr != 0, "QThread::setTerminationEnabled()",
               "Current thread was not started with QThread.");

    Q_UNUSED(thr)

    pthread_setcancelstate(enabled ? PTHREAD_CANCEL_ENABLE : PTHREAD_CANCEL_DISABLE, NULL);
    if (enabled)
        pthread_testcancel();
}

// Caller must lock the mutex
void QThreadPrivate::setPriority(QThread::Priority threadPriority)
{
    priority = threadPriority;
}

#endif // QT_NO_THREAD

QT_END_NAMESPACE

