#include "qplatformdefs.h"
#include "qmutex.h"

#if !defined(QT_NO_THREAD)

#include "qmutex_p.h"

#include <mach/mach.h>
#include <mach/task.h>

#include <errno.h>

QT_BEGIN_NAMESPACE

QMutexPrivate::QMutexPrivate()
{
    kern_return_t r = semaphore_create(mach_task_self(), &mach_semaphore, SYNC_POLICY_FIFO, 0);
    if (r != KERN_SUCCESS)
        qWarning("QMutex: failed to create semaphore, error %d", r);
}

QMutexPrivate::~QMutexPrivate()
{
    kern_return_t r = semaphore_destroy(mach_task_self(), mach_semaphore);
    if (r != KERN_SUCCESS)
        qWarning("QMutex: failed to destroy semaphore, error %d", r);
}

bool QMutexPrivate::wait(int timeout)
{
    kern_return_t r;
    if (timeout < 0) {
        do {
            r = semaphore_wait(mach_semaphore);
        } while (r == KERN_ABORTED);
        Q_ASSERT(r == KERN_SUCCESS);
    } else {
        mach_timespec_t ts;
        ts.tv_nsec = ((timeout % 1000) * 1000) * 1000;
        ts.tv_sec = (timeout / 1000);
        r = semaphore_timedwait(mach_semaphore, ts);
    }
    return (r == KERN_SUCCESS);
}

void QMutexPrivate::wakeUp() Q_DECL_NOTHROW
{
    semaphore_signal(mach_semaphore);
}


QT_END_NAMESPACE

#endif //QT_NO_THREAD
