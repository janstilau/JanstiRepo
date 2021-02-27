#include "qatomic.h"
#include "qmutexpool_p.h"

#ifndef QT_NO_THREAD

QT_BEGIN_NAMESPACE

Q_GLOBAL_STATIC_WITH_ARGS(QMutexPool, globalMutexPool, (QMutex::Recursive))


QMutexPool::QMutexPool(QMutex::RecursionMode recursionMode, int size)
    : mutexes(size), recursionMode(recursionMode)
{
    // 在构造函数里面, 将数组显式地进行清空.
    for (int index = 0; index < mutexes.count(); ++index) {
        mutexes[index].store(0);
    }
}

// 在析构函数里面, 才会对每个 mutex 进行释放.
// 在 Pool 里面的 mutex, 并不是和 Obj 绑定的. 它是公用的. 所以, 存活的时间应该多一些.
QMutexPool::~QMutexPool()
{
    for (int index = 0; index < mutexes.count(); ++index)
        delete mutexes[index].load();
}

QMutexPool *QMutexPool::instance()
{
    return globalMutexPool();
}

// 机制就是填充缓存区的机制. 只不过这里有 Atomic 相关的东西.
QMutex *QMutexPool::createMutex(int index)
{
    // mutex not created, create one
    QMutex *newMutex = new QMutex(recursionMode);
    if (!mutexes[index].testAndSetRelease(0, newMutex))
        delete newMutex;
    return mutexes[index].load();
}

// 一个简便的方法, 使用 global 对象
QMutex *QMutexPool::globalInstanceGet(const void *address)
{
    QMutexPool * const globalInstance = globalMutexPool();
    if (globalInstance == 0)
        return 0;
    return globalInstance->get(address);
}

QT_END_NAMESPACE

#endif // QT_NO_THREAD
