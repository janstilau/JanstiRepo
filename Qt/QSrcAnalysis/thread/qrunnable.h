#ifndef QRUNNABLE_H
#define QRUNNABLE_H

#include <QtCore/qglobal.h>

QT_BEGIN_NAMESPACE

class Q_CORE_EXPORT QRunnable
{
    int ref;

    friend class QThreadPool;
    friend class QThreadPoolPrivate;
    friend class QThreadPoolThread;
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    Q_DISABLE_COPY(QRunnable)
#endif
public:
    virtual void run() = 0;

    QRunnable() : ref(0) { }
    virtual ~QRunnable();

    bool autoDelete() const { return ref != -1; }
    void setAutoDelete(bool _autoDelete) { ref = _autoDelete ? 0 : -1; }
};

QT_END_NAMESPACE

#endif
