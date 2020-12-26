#ifndef QRUNNABLE_H
#define QRUNNABLE_H

#include <QtCore/qglobal.h>

QT_BEGIN_NAMESPACE

// 类似于 NSOperation 的一个类, 添加异步任务的.
// 没有 NSOperation 复杂.
// 真正的, 数据就 ref 这个值, 记录着是否应该在执行完删除. 如果是 ARC 环境, 这个类就是一个纯接口类了.
class Q_CORE_EXPORT QRunnable
{
    int ref;

    friend class QThreadPool;
    friend class QThreadPoolPrivate;
    friend class QThreadPoolThread;

public:
    virtual void run() = 0; // 纯虚函数.

    QRunnable() : ref(0) { }
    virtual ~QRunnable(); // 有着虚函数的类, 析构一定要是虚函数的. 不然会有内存问题.

    bool autoDelete() const { return ref != -1; }
    void setAutoDelete(bool _autoDelete) { ref = _autoDelete ? 0 : -1; }
};

QT_END_NAMESPACE

#endif
