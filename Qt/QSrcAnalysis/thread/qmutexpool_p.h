#ifndef QMUTEXPOOL_P_H
#define QMUTEXPOOL_P_H


#include <QtCore/private/qglobal_p.h>
#include "QtCore/qatomic.h"
#include "QtCore/qmutex.h"
#include "QtCore/qvarlengtharray.h"

#ifndef QT_NO_THREAD

QT_BEGIN_NAMESPACE

/*
    Typical use of a QMutexPool is in situations where it is not
    possible or feasible to use one QMutex for every protected object.
    The mutex pool will return a mutex based on the address of the
    object that needs protection.

    如果, 一个对象, 本身不是线程安全的, 又是在多线程的环境下使用, 那么就应该有一把锁和这个对象绑定, 在每次使用这个对象的方法的时候, lock, unlock.
    QMutexPool 就是提供的这样一个映射. 自然, 应该使用 globalInstanceGet, 不同的 pool 对象, get 返回不同的锁, 根本起不到互斥的目的.
    Pool 的设计很简单, 就是一个简单的数组和内存地址的映射转变.
    Pool 这个对象没有必要设计为线程安全的, 是通过这个对象获取到 mutex, mutex 保证临界区互斥.
  */

class Q_CORE_EXPORT QMutexPool
{
public:
    explicit QMutexPool(QMutex::RecursionMode recursionMode = QMutex::NonRecursive, int size = 131);
    ~QMutexPool();

    // 一个简单的 Hash 算法, 会有冲突, 但是获取的是锁这个东西, 几个相同的 Obj, 使用同一个 mutex 也没有问题.
    inline QMutex *get(const void *address) {
        int index = uint(quintptr(address)) % mutexes.count();
        QMutex *m = mutexes[index].load();
        if (m)
            return m;
        else
            return createMutex(index);
    }
    static QMutexPool *instance();
    static QMutex *globalInstanceGet(const void *address);

private:
    QMutex *createMutex(int index);
    // QVarLengthArray 应该就是 Qt 版本的 Array, 里面存放的是, AtomicPointer.
    QVarLengthArray<QAtomicPointer<QMutex>, 131> mutexes;
    QMutex::RecursionMode recursionMode; // 存放, 生成的 Mutex 的模式.
};

QT_END_NAMESPACE

#endif // QT_NO_THREAD

#endif // QMUTEXPOOL_P_H
