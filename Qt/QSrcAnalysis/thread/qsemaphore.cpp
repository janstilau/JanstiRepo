#include "qsemaphore.h"

#ifndef QT_NO_THREAD
#include "qmutex.h"
#include "qwaitcondition.h"
#include "qdeadlinetimer.h"
#include "qdatetime.h"

QT_BEGIN_NAMESPACE

class QSemaphorePrivate {
public:
    inline QSemaphorePrivate(int n) : avail(n) { }
    QMutex mutex; // 一个 Mutex, 用作保护临界区
    QWaitCondition cond; // 一个 condition, 用来做同步操作.
    int avail;
};

QSemaphore::QSemaphore(int n)
{
    d = new QSemaphorePrivate(n);
}

QSemaphore::~QSemaphore()
{ delete d; }

// P 操作, 首先获取 Mutex 进去临界区. 然后检测, 所需的资源大于当前有效资源, wait, wait 函数内, 会放开 mutex.
// 外界进行 v 操作的时候, 会进行 wakeAll. 再次获取 mutex, 再次判断 while 循环.
// 资源足够跳出循环, 进行资源量的修改
// 资源不足继续 wait, 放开 mutex.
void QSemaphore::acquire(int n)
{
    QMutexLocker locker(&d->mutex);
    while (n > d->avail) {
        d->cond.wait(locker.mutex());
    }
    d->avail -= n;
}

// V 操作, 首先获取 mutex 进入临界区.
// 进行资源量的修改.
// 进行唤醒操作.
void QSemaphore::release(int n)
{
    QMutexLocker locker(&d->mutex);
    d->avail += n;
    d->cond.wakeAll();
}

// Get 方法, 首先获取 mutex 进入临界区, 获取当前的资源数, 返回.
int QSemaphore::available() const
{
    QMutexLocker locker(&d->mutex);
    return d->avail;
}

// Try 方法一般用在有等待操作的类型上, try 代表的含义就是, 不等待, 通过 book 值来判断是否达到了目的.
bool QSemaphore::tryAcquire(int n)
{
    QMutexLocker locker(&d->mutex);
    if (n > d->avail)
        return false;
    d->avail -= n;
    return true;
}

bool QSemaphore::tryAcquire(int n, int timeout)
{

    // We're documented to accept any negative value as "forever"
    // but QDeadlineTimer only accepts -1.
    timeout = qMax(timeout, -1);

    QDeadlineTimer timer(timeout);
    QMutexLocker locker(&d->mutex);
    qint64 remainingTime = timer.remainingTime();
    // wait 可能会多次唤醒, 但是唤醒了不一定是满足条件了, 所以循环重新判断.
    // QWaitCondition 提供的仅仅是一个简单的唤醒机制, 唤醒之后是否满足要求, 都是在这个唤醒机制上的附加逻辑.
    // 一般来说, 就是循环判断条件, 如果不满足, 继续 wait.
    while (n > d->avail && remainingTime != 0) {
        if (!d->cond.wait(locker.mutex(), remainingTime))
            return false;
        remainingTime = timer.remainingTime();
    }
    if (n > d->avail)
        return false;
    d->avail -= n;
    return true;
}

QT_END_NAMESPACE

#endif // QT_NO_THREAD
