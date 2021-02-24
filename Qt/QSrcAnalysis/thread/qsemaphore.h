#ifndef QSEMAPHORE_H
#define QSEMAPHORE_H

#include <QtCore/qglobal.h>

QT_BEGIN_NAMESPACE

//! 信号量, 并不是用来做互斥的, 它更多地是一个唤起的概念.V 操作, 可以唤起被 P 操作所等待的线程.
//! 互斥, 可以看做是特殊的一种唤起操作, 当一个线程离开临界区之后, 可以通知其他线程重新进入临界区.
//! 之前的代码里面, 取资源操作在子线程里面, 返回资源在主线程里面, 主线程 P 操作, 子线程取值并 V 操作, 其实就是子线程唤醒主线程.
//! 消费者生产者问题, 一定要有两个信号量, 一个互斥锁, 互斥锁保证的是, 共享资源的操作是线程独有的, 而信号量则是进行的唤醒操作.
//! 信号量, 能够保证 PV 操作是原子操作, 也就是改变的是信号量内的 avaiable 数据,生产者消费者问题中的信号量, 主要是用来通知的, P 操作成功后, 对于共享资源的访问, 还是要互斥量来保证.


#ifndef QT_NO_THREAD

class QSemaphorePrivate;

class Q_CORE_EXPORT QSemaphore
{
public:
    explicit QSemaphore(int n = 0);
    ~QSemaphore();

    void acquire(int n = 1); // P 操作.
    bool tryAcquire(int n = 1);
    bool tryAcquire(int n, int timeout);

    void release(int n = 1); // V 操作

    int available() const; // 返回可用资源

private:
    QSemaphorePrivate *d;
};

#endif // QT_NO_THREAD

QT_END_NAMESPACE

#endif // QSEMAPHORE_H
