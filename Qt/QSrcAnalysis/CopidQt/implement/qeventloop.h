#ifndef QEVENTLOOP_H
#define QEVENTLOOP_H

#include <QtCore/qobject.h>

QT_BEGIN_NAMESPACE


class QEventLoopPrivate;
// 在 Dialog 的 exec 方法里面, 首先会调用 show 方法, 进行 dialog 的显示. 然后, 会在后面明显的生成一个 eventLoop 对象.
class Q_CORE_EXPORT QEventLoop : public QObject
{
    Q_OBJECT
    Q_DECLARE_PRIVATE(QEventLoop)

public:
    explicit QEventLoop(QObject *parent = Q_NULLPTR);
    ~QEventLoop();

    enum ProcessEventsFlag {
        AllEvents = 0x00,
        ExcludeUserInputEvents = 0x01,
        ExcludeSocketNotifiers = 0x02,
        WaitForMoreEvents = 0x04,
        X11ExcludeTimers = 0x08,
        EventLoopExec = 0x20,
        DialogExec = 0x40
    };
    Q_DECLARE_FLAGS(ProcessEventsFlags, ProcessEventsFlag)

    bool processEvents(ProcessEventsFlags flags = AllEvents);
    void processEvents(ProcessEventsFlags flags, int maximumTime);

    int exec(ProcessEventsFlags flags = AllEvents);
    void exit(int returnCode = 0);
    bool isRunning() const;

    void wakeUp();

    bool event(QEvent *event) Q_DECL_OVERRIDE;

public Q_SLOTS:
    void quit();
};

Q_DECLARE_OPERATORS_FOR_FLAGS(QEventLoop::ProcessEventsFlags)


class QEventLoopLockerPrivate;

class Q_CORE_EXPORT QEventLoopLocker
{
public:
    QEventLoopLocker();
    explicit QEventLoopLocker(QEventLoop *loop);
    explicit QEventLoopLocker(QThread *thread);
    ~QEventLoopLocker();

private:
    Q_DISABLE_COPY(QEventLoopLocker)
    QEventLoopLockerPrivate *d_ptr;
};

QT_END_NAMESPACE

#endif // QEVENTLOOP_H
