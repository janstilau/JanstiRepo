#ifndef QRUNNABLE_H
#define QRUNNABLE_H

#include <QtCore/qglobal.h>

QT_BEGIN_NAMESPACE

// 其实这就是一个抽象数据类, 最主要的是有一个 run 方法.
// 各个子类, 添加自己对于可执行对象, 以及相应数据的包装.
// 在 ThreadPool 里面, 是面向的 QRunnable 的接口进行的编程.
class Q_CORE_EXPORT QRunnable
{
    int ref;

    friend class QThreadPool;
    friend class QThreadPoolPrivate;
    friend class QThreadPoolThread;
public:
    virtual void run() = 0;

    QRunnable() : ref(0) { }
    virtual ~QRunnable();

    // 之所以有这个 autoDelete 的设计, 主要是为了方便 C++ 的内存管理.
    // QThreadPool 里面, 一定是 QRunnable 的指针, 这样才能多态调用到 run. 所以, 有了这样的一个设计, 因为大部分情况下, 我们是提交任务, 并不关心任务的回收使用的. 所以, 在这种场景下, 应该设置 autoDelete 为 true.
    bool autoDelete() const { return ref != -1; }
    void setAutoDelete(bool _autoDelete) { ref = _autoDelete ? 0 : -1; }
};

QT_END_NAMESPACE

#endif
