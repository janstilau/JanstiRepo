#include "qthread.h"
#include "qplatformdefs.h"
#include "qthreadstorage.h"
#include "qthread_p.h"
#include "qdebug.h"

#ifdef __GLIBCXX__
#include <cxxabi.h>
#endif

#include <sched.h>
#include <errno.h>

QT_BEGIN_NAMESPACE


Q_STATIC_ASSERT(sizeof(pthread_t) <= sizeof(Qt::HANDLE));

enum { ThreadPriorityResetFlag = 0x80000000 };

static pthread_once_t current_thread_data_once = PTHREAD_ONCE_INIT;
static pthread_key_t current_thread_data_key;

// 线程消亡的时候的清理函数, 在这里, 调用了 finish 方法.
// 这种回调的设置, 使得 QThread 类的内部, 不用关心什么时候调用 finish.
// 这其实就是编程的逻辑, 设计一套算法, 然后安插数据. 只要算法里面有相关的实现, 提供了数据控制逻辑的切口所在, 那么就可以起到分离复杂度的目的.
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
        thread_p->finish(thread); // 在这里, 调用了 finish 函数.
    }
    data->deref();

    // ... but we must reset it to zero before returning so we aren't
    // called again (POSIX allows implementations to call destructor
    // functions repeatedly until all values are zero)
    pthread_setspecific(current_thread_data_key,
#if defined(Q_OS_VXWORKS)
                                                 (void *)1);
#else
                                                 0);
#endif
}

static void create_current_thread_data_key()
{
    // 在这里, 注册了一个清理函数, 会在线程消亡的时候被调用.
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


//! 通过 pthread_getspecific, pthread_setspecific, 将一个 QThreadData 数据对象, 和真正的线程绑定在一起.
static QThreadData *get_thread_data()
{
    pthread_once(&current_thread_data_once, create_current_thread_data_key);
    return reinterpret_cast<QThreadData *>(pthread_getspecific(current_thread_data_key));
}

static void set_thread_data(QThreadData *data)
{
    pthread_once(&current_thread_data_once, create_current_thread_data_key);
    pthread_setspecific(create_current_thread_data_key, data);
}

static void clear_thread_data()
{
#ifdef HAVE_TLS
    currentThreadData = 0;
#endif
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
    // 类似于一个懒加载的实现.
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

QAbstractEventDispatcher *QThreadPrivate::createEventDispatcher(QThreadData *data)
{
    bool ok = false;
    int value = qEnvironmentVariableIntValue("QT_EVENT_DISPATCHER_CORE_FOUNDATION", &ok);
    if (ok && value > 0)
        return new QEventDispatcherCoreFoundation;
    else
        return new QEventDispatcherUNIX;
}


//! 真正的函数, 用来开启一个线程.C++ 可以通过 类名::函数名的方式, 来定位到对应的函数.
void *QThreadPrivate::start(void *arg)
{
    // 新创建的线程, 不能被其他线程, 随便 cancel.
    pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, NULL);
    pthread_cleanup_push(QThreadPrivate::finish, arg);
    {
        QThread *thr = reinterpret_cast<QThread *>(arg);
        // 这种, 定义一个变量, 然后 {} 内处理这个变量相关的逻辑, 在 Qt 源码里面, 也会使用.
        QThreadData *data = QThreadData::get2(thr);
        {
            // 这个时候, 已经在子线程里面了, 所以, 对于线程对象数据的任何修改, 都要加锁.
            QMutexLocker locker(&thr->d_func()->mutex);

            if (int(thr->d_func()->priority) & ThreadPriorityResetFlag) {
                thr->d_func()->setPriority(QThread::Priority(thr->d_func()->priority & ~ThreadPriorityResetFlag));
            }

            data->threadId.store(to_HANDLE(pthread_self()));
            set_thread_data(data);
            data->ref();
            data->quitNow = thr->d_func()->exited;
        }

        emit thr->started(QThread::QPrivateSignal());
        pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, NULL);
        pthread_testcancel();

        // 以上, 都是对于线程对象内部数据的控制, 只有这里, 才是真正的使用了用户定义的函数开始线程.
        thr->run();
    }
    pthread_cleanup_pop(1);

    return 0;
}

// 线程的销毁, 大部分逻辑, 都是在做状态值的更改.
void QThreadPrivate::finish(void *arg)
{
#ifndef QT_NO_EXCEPTIONS
    try
#endif
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
#ifndef QT_NO_EXCEPTIONS
    catch (...) {
        qTerminate();
    }
#endif // QT_NO_EXCEPTIONS
}

Qt::HANDLE QThread::currentThreadId() Q_DECL_NOTHROW
{
    // requires a C cast here otherwise we run into trouble on AIX
    return to_HANDLE(pthread_self());
}

#if defined(QT_LINUXBASE) && !defined(_SC_NPROCESSORS_ONLN)
// LSB doesn't define _SC_NPROCESSORS_ONLN.
#  define _SC_NPROCESSORS_ONLN 84
#endif

int QThread::idealThreadCount() Q_DECL_NOTHROW
{
    int cores = 1;

#if defined(Q_OS_HPUX)
#elif defined(Q_OS_BSD4)
    // FreeBSD, OpenBSD, NetBSD, BSD/OS, OS X, iOS
    size_t len = sizeof(cores);
    int mib[2];
    mib[0] = CTL_HW;
    mib[1] = HW_NCPU;
    if (sysctl(mib, 2, &cores, &len, NULL, 0) != 0) {
        perror("sysctl");
    }
#elif defined(Q_OS_INTEGRITY)
#endif
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


#ifdef QT_HAS_THREAD_PRIORITY_SCHEDULING
#endif

//! Qt 里面的各个类, 实现文件有可能分为好几份. start 函数是和操作系统息息相关的, 所以在 Unix 的目录下.
void QThread::start(Priority priority)
{
    Q_D(QThread);
    QMutexLocker locker(&d->mutex);

    if (d->isInFinish)
        d->thread_done.wait(locker.mutex());
    if (d->running)
        return;

    // 首先是一些状态值的改变, 这些状态值, 和真正的线程状态之间, 要在算法里面保持同步.
    d->running = true;
    d->finished = false;
    d->returnCode = 0;
    d->exited = false;
    d->interruptionRequested = false;

    // 真正的线程属性的设置. 这里, 线程被设置为分离态, 也就是运营完之后就销毁 PCB 了.
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);

    d->priority = priority;

    if (d->stackSize > 0) {
        int code = pthread_attr_setstacksize(&attr, d->stackSize);
        if (code) {
            d->running = false;
            d->finished = false;
            return;
        }
    }

    // 使用线程原语
    pthread_t threadId;
    int code = pthread_create(&threadId, &attr, QThreadPrivate::start, this);

    // 在 pthread_create 之后, 下面的还会在原来的线程执行.
    if (code == EPERM) {
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

void QThread::terminate()
{
    Q_D(QThread);
    QMutexLocker locker(&d->mutex);

    if (!d->data->threadId.load())
        return;

    // 利用 pthread_cancel, 取消线程.
    int code = pthread_cancel(from_HANDLE<pthread_t>(d->data->threadId.load()));
    if (code) {
        qWarning("QThread::start: Thread termination error: %s",
                 qPrintable(qt_error_string((code))));
    }
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
        // 这里, 是使用了里面的 condition 完成的
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
#if defined(Q_OS_ANDROID)
    Q_UNUSED(enabled);
#else
    pthread_setcancelstate(enabled ? PTHREAD_CANCEL_ENABLE : PTHREAD_CANCEL_DISABLE, NULL);
    if (enabled)
        pthread_testcancel();
#endif
}

// 调用 pthread 方法, 改变线程的优先级.
void QThreadPrivate::setPriority(QThread::Priority threadPriority)
{
    priority = threadPriority;
#ifdef QT_HAS_THREAD_PRIORITY_SCHEDULING
    int sched_policy;
    sched_param param;

    if (pthread_getschedparam(from_HANDLE<pthread_t>(data->threadId.load()), &sched_policy, &param) != 0) {
        // failed to get the scheduling policy, don't bother setting
        // the priority
        qWarning("QThread::setPriority: Cannot get scheduler parameters");
        return;
    }

    int prio;
    if (!calculateUnixPriority(priority, &sched_policy, &prio)) {
        // failed to get the scheduling parameters, don't
        // bother setting the priority
        qWarning("QThread::setPriority: Cannot determine scheduler priority range");
        return;
    }

    param.sched_priority = prio;
    int status = pthread_setschedparam(from_HANDLE<pthread_t>(data->threadId.load()), sched_policy, &param);

# ifdef SCHED_IDLE
    // were we trying to set to idle priority and failed?
    if (status == -1 && sched_policy == SCHED_IDLE && errno == EINVAL) {
        // reset to lowest priority possible
        pthread_getschedparam(from_HANDLE<pthread_t>(data->threadId.load()), &sched_policy, &param);
        param.sched_priority = sched_get_priority_min(sched_policy);
        pthread_setschedparam(from_HANDLE<pthread_t>(data->threadId.load()), sched_policy, &param);
    }
# else
    Q_UNUSED(status);
# endif // SCHED_IDLE
#endif
}


QT_END_NAMESPACE

