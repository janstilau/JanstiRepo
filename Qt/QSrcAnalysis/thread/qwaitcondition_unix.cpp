#include "qplatformdefs.h"
#include "qwaitcondition.h"
#include "qmutex.h"
#include "qreadwritelock.h"
#include "qatomic.h"
#include "qstring.h"
#include "qelapsedtimer.h"
#include "private/qcore_unix_p.h"

#include "qmutex_p.h"
#include "qreadwritelock_p.h"

#include <errno.h>
#include <sys/time.h>
#include <time.h>

#ifndef QT_NO_THREAD

QT_BEGIN_NAMESPACE

// 这其实是一个不太好的设计, 在一个方法的参数里面, 调用另外一个方法.
// 这样让代码的流程比较混乱.
static void report_error(int code, const char *where, const char *what)
{
    if (code != 0)
        qWarning("%s: %s failure: %s", where, what, qPrintable(qt_error_string(code)));
}

void qt_initialize_pthread_cond(pthread_cond_t *cond, const char *where)
{
    pthread_condattr_t condattr;
    pthread_condattr_init(&condattr);
    pthread_cond_init(cond, &condattr);
    pthread_condattr_destroy(&condattr);
}

void qt_abstime_for_timeout(timespec *ts, int timeout)
{
    // on Mac, qt_gettime() (on qelapsedtimer_mac.cpp) returns ticks related to the Mach absolute time
    // that doesn't work with pthread
    // Mac also doesn't have clock_gettime
    struct timeval tv;
    gettimeofday(&tv, 0);
    ts->tv_sec = tv.tv_sec;
    ts->tv_nsec = tv.tv_usec * 1000;


    ts->tv_sec += timeout / 1000;
    ts->tv_nsec += timeout % 1000 * Q_UINT64_C(1000) * 1000;
    normalizedTimespec(*ts);
}

class QWaitConditionPrivate {
public:
    pthread_mutex_t innerMutex;
    pthread_cond_t innerCondition;
    int waiters;
    int wakeups;

    int wait_relative(unsigned long time)
    {
        timespec ti;
        qt_abstime_for_timeout(&ti, time);
        return pthread_cond_timedwait(&innerCondition, &innerMutex, &ti);
    }

    bool wait(unsigned long time)
    {
        int code;
        forever {
            if (time != ULONG_MAX) {
                code = wait_relative(time);
            } else {
                code = pthread_cond_wait(&innerCondition, &innerMutex);
            }
            if (code == 0 && wakeups == 0) {
                // many vendors warn of spurious wakeups from
                // pthread_cond_wait(), especially after signal delivery,
                // even though POSIX doesn't allow for it... sigh
                continue;
            }
            break;
        }

        --waiters;
        if (code == 0) {
            --wakeups;
        }
        report_error(pthread_mutex_unlock(&innerMutex), "QWaitCondition::wait()", "mutex unlock");

        if (code && code != ETIMEDOUT)
            report_error(code, "QWaitCondition::wait()", "cv wait");

        return (code == 0);
    }
};

// 整个 QWaitCondition, 还是使用的 <pthread> 中的 API 的设计, 由 pthread 库做各个平台的兼容的工作.
// 不太理解, d->waiters, d->wakeups 到底有什么意义, 还需要专门有一个 innerMutex 做这两个数据的工作.

QWaitCondition::QWaitCondition()
{
    d = new QWaitConditionPrivate;
    // 构造函数里面, 初始化 mutex, 初始化 condition.
    pthread_mutex_init(&d->innerMutex, NULL);
    qt_initialize_pthread_cond(&d->innerCondition, "QWaitCondition");
    d->waiters = d->wakeups = 0;
}


QWaitCondition::~QWaitCondition()
{
    pthread_cond_destroy(&d->innerCondition);
    pthread_mutex_destroy(&d->innerMutex);
    delete d;
}

void QWaitCondition::wakeOne()
{
    pthread_mutex_lock(&d->innerMutex);
    d->wakeups = qMin(d->wakeups + 1, d->waiters);
    pthread_cond_signal(&d->innerCondition);
    pthread_mutex_unlock(&d->innerMutex);
}

void QWaitCondition::wakeAll()
{
    pthread_mutex_lock(&d->innerMutex);
    d->wakeups = d->waiters;
    pthread_cond_broadcast(&d->innerCondition);
    pthread_mutex_unlock(&d->innerMutex);
}

bool QWaitCondition::wait(QMutex *outterMuex, unsigned long time)
{
    pthread_mutex_lock(&d->innerMutex);
    ++d->waiters;
    outterMuex->unlock(); // 显示外部进行 unlock
    // 在 d->wait 里面, 是使用了 innerLock 和 condition 进行的配合使用. 不太理解为什么.
    bool returnValue = d->wait(time); // wait
    outterMuex->lock(); // 外部重新进行 lock
    return returnValue;
}

bool QWaitCondition::wait(QReadWriteLock *readWriteLock, unsigned long time)
{
    if (!readWriteLock)
        return false;
    auto previousState = readWriteLock->stateForWaitCondition();
    if (previousState == QReadWriteLock::Unlocked)
        return false;
    if (previousState == QReadWriteLock::RecursivelyLocked) {
        qWarning("QWaitCondition: cannot wait on QReadWriteLocks with recursive lockForWrite()");
        return false;
    }

    report_error(pthread_mutex_lock(&d->innerMutex), "QWaitCondition::wait()", "mutex lock");
    ++d->waiters;

    readWriteLock->unlock();

    bool returnValue = d->wait(time);

    if (previousState == QReadWriteLock::LockedForWrite)
        readWriteLock->lockForWrite();
    else
        readWriteLock->lockForRead();

    return returnValue;
}

QT_END_NAMESPACE

#endif // QT_NO_THREAD
