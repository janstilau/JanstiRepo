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

static void report_error(int code, const char *where, const char *what)
{
    if (code != 0)
        qWarning("%s: %s failure: %s", where, what, qPrintable(qt_error_string(code)));
}

void qt_initialize_pthread_cond(pthread_cond_t *cond, const char *where)
{
    pthread_condattr_t condattr;

    pthread_condattr_init(&condattr);
    report_error(pthread_cond_init(cond, &condattr), where, "cv init");
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
    pthread_mutex_t innerMutex; // 这个互斥锁, 是为了内部数据改变使用的, wait 的时候, 是传过来一个外部 互斥锁, wait 操作, 会解锁那个外部互斥锁, 然后 wiat cond, 在被唤醒之后, 还会加锁那个外部互斥锁. 这个内部互斥锁, 是一些需要操作内部数据的时候, 进行的加锁解锁.
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


QWaitCondition::QWaitCondition()
{
    d = new QWaitConditionPrivate;
    report_error(pthread_mutex_init(&d->innerMutex, NULL), "QWaitCondition", "mutex init");
    qt_initialize_pthread_cond(&d->innerCondition, "QWaitCondition");
    d->waiters = d->wakeups = 0;
}


QWaitCondition::~QWaitCondition()
{
    report_error(pthread_cond_destroy(&d->innerCondition), "QWaitCondition", "cv destroy");
    report_error(pthread_mutex_destroy(&d->innerMutex), "QWaitCondition", "mutex destroy");
    delete d;
}

void QWaitCondition::wakeOne()
{
    report_error(pthread_mutex_lock(&d->innerMutex), "Q WaitCondition::wakeOne()", "mutex lock");
    d->wakeups = qMin(d->wakeups + 1, d->waiters);
    report_error(pthread_cond_signal(&d->innerCondition), "QWaitCondition::wakeOne()", "cv signal");
    report_error(pthread_mutex_unlock(&d->innerMutex), "QWaitCondition::wakeOne()", "mutex unlock");
}

void QWaitCondition::wakeAll()
{
    report_error(pthread_mutex_lock(&d->innerMutex), "QWaitCondition::wakeAll()", "mutex lock");
    d->wakeups = d->waiters;
    report_error(pthread_cond_broadcast(&d->innerCondition), "QWaitCondition::wakeAll()", "cv broadcast");
    report_error(pthread_mutex_unlock(&d->innerMutex), "QWaitCondition::wakeAll()", "mutex unlock");
}

bool QWaitCondition::wait(QMutex *outterMuex, unsigned long time)
{
    report_error(pthread_mutex_lock(&d->innerMutex), "QWaitCondition::wait()", "mutex lock");
    ++d->waiters;
    outterMuex->unlock(); // 显示外部进行 unlock

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
