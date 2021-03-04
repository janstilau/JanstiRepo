#ifndef QRUNNABLE_H
#define QRUNNABLE_H

#include <QtCore/qglobal.h>
#include <functional>

QT_BEGIN_NAMESPACE

class Q_CORE_EXPORT QRunnable
{
    int ref; // Qt6: Make this a bool, or make autoDelete() virtual.

    friend class QThreadPool;
    friend class QThreadPoolPrivate;
    friend class QThreadPoolThread;
    Q_DISABLE_COPY(QRunnable)
public:
    virtual void run() = 0;

    QRunnable() : ref(0) { }
    virtual ~QRunnable();
    static QRunnable *create(std::function<void()> functionToRun);

    bool autoDelete() const { return ref != -1; }
    void setAutoDelete(bool _autoDelete) { ref = _autoDelete ? 0 : -1; }
};

QT_END_NAMESPACE

#endif
