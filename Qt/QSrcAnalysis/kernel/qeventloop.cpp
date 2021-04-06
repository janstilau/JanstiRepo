#include "qeventloop.h"

#include "qabstracteventdispatcher.h"
#include "qcoreapplication.h"
#include "qcoreapplication_p.h"
#include "qelapsedtimer.h"

#include "qobject_p.h"
#include "qeventloop_p.h"
#include <private/qthread_p.h>

#ifdef Q_OS_WASM
#include <emscripten.h>
#endif

QT_BEGIN_NAMESPACE


QEventLoop::QEventLoop(QObject *parent)
    : QObject(*new QEventLoopPrivate, parent)
{
    Q_D(QEventLoop);
    if (!QCoreApplication::instance() && QCoreApplicationPrivate::threadRequiresCoreApplication()) {
        qWarning("QEventLoop: Cannot be used without QApplication");
    } else {
        d->threadData.loadRelaxed()->ensureEventDispatcher();
    }
}


QEventLoop::~QEventLoop()
{ }


// Runloop 的事件处理, 主要是调用 Thread 的事件分发器, 做任务处理.
bool QEventLoop::processEvents(ProcessEventsFlags flags)
{
    Q_D(QEventLoop);
    auto threadData = d->threadData.loadRelaxed();
    if (!threadData->hasEventDispatcher())
        return false;
    return threadData->eventDispatcher.loadRelaxed()->processEvents(flags);
}

/*!
    Enters the main event loop and waits until exit() is called.
    Returns the value that was passed to exit().

    这里, flags 的作用, 不就是 Runloop 里面的 Mode 的作用了.
    If \a flags are specified, only events of the types allowed by
    the \a flags will be processed.

    It is necessary to call this function to start event handling. The
    main event loop receives events from the window system and
    dispatches these to the application widgets.

    这里, 其实就是模态对话框必须完成操作的原因所在.
    在模态对话框里面, eventLoop 卡住了代码的 flow, 所以, 后面的代码, 必须等对话框里面的 eventLoop 退出之后才能够执行.
    而对话框的事件处理就是, 如果不是自己 frame 内的点击事件, 不处理.
    填写完对话框内的信息之后, 点击特定按钮, 会修改 eventLoop 的退出标记, 这个时候, 对话框的信息已经收集完毕了.
    Code Flow 继续, 可以直接从对话框里面读取信息.
    对话框内的 eventloop, 保证了程序的事件处理可以继续执行, 又卡住了 Code 的 Flow. 因为, Qt 里面的异步程序, 都是通过事件的方式, 也就是依赖于 eventLoop, 所以, Pen 的下载任务, 网络请求 也使用了类似的方式, 来达到卡住 code flow, 又能够进行异步操作的处理流程.
    Generally speaking, no user interaction can take place before
    calling exec(). As a special case, modal widgets like QMessageBox
    can be used before calling exec(), because modal widgets
    use their own local event loop.

    之前程涛的话, 就是在这里来的.
    To make your application perform idle processing (i.e. executing a
    special function whenever there are no pending events), use a
    QTimer with 0 timeout. More sophisticated idle processing schemes
    can be achieved using processEvents().

    \sa QCoreApplication::quit(), exit(), processEvents()
*/
int QEventLoop::exec(ProcessEventsFlags flags)
{
    Q_D(QEventLoop);
    auto threadData = d->threadData.loadRelaxed();

    //we need to protect from race condition with QThread::exit
    QMutexLocker locker(&static_cast<QThreadPrivate *>(QObjectPrivate::get(threadData->thread.loadAcquire()))->mutex);
    if (threadData->quitNow)
        return -1;

    if (d->inExec) {
        qWarning("QEventLoop::exec: instance %p has already called exec()", this);
        return -1;
    }

    // 在方法的内部, 专门建立一个 RAII 控制的类, 避免多出口的带来的资源泄漏问题.
    struct LoopReference {
        QEventLoopPrivate *d;
        QMutexLocker &locker;

        bool exceptionCaught;
        LoopReference(QEventLoopPrivate *d, QMutexLocker &locker) : d(d), locker(locker), exceptionCaught(true)
        {
            d->inExec = true;
            d->exit.storeRelease(false);

            auto threadData = d->threadData.loadRelaxed();
            ++threadData->loopLevel;
            threadData->eventLoops.push(d->q_func());

            locker.unlock();
        }

        ~LoopReference()
        {
            if (exceptionCaught) {
                qWarning("Qt has caught an exception thrown from an event handler. Throwing\n"
                         "exceptions from an event handler is not supported in Qt.\n"
                         "You must not let any exception whatsoever propagate through Qt code.\n"
                         "If that is not possible, in Qt 5 you must at least reimplement\n"
                         "QCoreApplication::notify() and catch all exceptions there.\n");
            }
            locker.relock();
            auto threadData = d->threadData.loadRelaxed();
            QEventLoop *eventLoop = threadData->eventLoops.pop();
            Q_ASSERT_X(eventLoop == d->q_func(), "QEventLoop::exec()", "internal error");
            Q_UNUSED(eventLoop); // --release warning
            d->inExec = false;
            --threadData->loopLevel;
        }
    };
    LoopReference ref(d, locker);

    // remove posted quit events when entering a new event loop

    QCoreApplication *app = QCoreApplication::instance();
    if (app && app->thread() == thread())
        QCoreApplication::removePostedEvents(app, QEvent::Quit);

    // 如果, 这个 eventLoop 的退出标记没有执行的话, 就一直进行 processEvents 的处理.
    while (!d->exit.loadAcquire()) {
        processEvents(flags | WaitForMoreEvents | EventLoopExec);
    }
    ref.exceptionCaught = false;
    return d->returnCode.loadRelaxed();
}

void QEventLoop::processEvents(ProcessEventsFlags flags, int maxTime)
{
    Q_D(QEventLoop);
    if (!d->threadData.loadRelaxed()->hasEventDispatcher())
        return;

    QElapsedTimer start;
    start.start();
    while (processEvents(flags & ~WaitForMoreEvents)) {
        if (start.elapsed() > maxTime)
            break;
    }
}

/*!
    Tells the event loop to exit with a return code.

    After this function has been called, the event loop returns from
    the call to exec(). The exec() function returns \a returnCode.

    By convention, a \a returnCode of 0 means success, and any non-zero
    value indicates an error.

    Note that unlike the C library function of the same name, this
    function \e does return to the caller -- it is event processing that
    stops.

    \sa QCoreApplication::quit(), quit(), exec()
*/
void QEventLoop::exit(int returnCode)
{
    Q_D(QEventLoop);
    auto threadData = d->threadData.loadAcquire();
    if (!threadData->hasEventDispatcher())
        return;

    d->returnCode.storeRelaxed(returnCode);
    d->exit.storeRelease(true);
    threadData->eventDispatcher.loadRelaxed()->interrupt();
}

/*!
    Returns \c true if the event loop is running; otherwise returns
    false. The event loop is considered running from the time when
    exec() is called until exit() is called.

    \sa exec(), exit()
 */
bool QEventLoop::isRunning() const
{
    Q_D(const QEventLoop);
    return !d->exit.loadAcquire();
}

/*!
    Wakes up the event loop.

    \sa QAbstractEventDispatcher::wakeUp()
*/
void QEventLoop::wakeUp()
{
    Q_D(QEventLoop);
    auto threadData = d->threadData.loadAcquire();
    if (!threadData->hasEventDispatcher())
        return;
    threadData->eventDispatcher.loadRelaxed()->wakeUp();
}


/*!
    \reimp
*/
bool QEventLoop::event(QEvent *event)
{
    if (event->type() == QEvent::Quit) {
        quit();
        return true;
    } else {
        return QObject::event(event);
    }
}

/*!
    Tells the event loop to exit normally.

    Same as exit(0).

    \sa QCoreApplication::quit(), exit()
*/
void QEventLoop::quit()
{ exit(0); }


class QEventLoopLockerPrivate
{
public:
    explicit QEventLoopLockerPrivate(QEventLoopPrivate *loop)
      : loop(loop), type(EventLoop)
    {
        loop->ref();
    }

    explicit QEventLoopLockerPrivate(QThreadPrivate *thread)
      : thread(thread), type(Thread)
    {
        thread->ref();
    }

    explicit QEventLoopLockerPrivate(QCoreApplicationPrivate *app)
      : app(app), type(Application)
    {
        app->ref();
    }

    ~QEventLoopLockerPrivate()
    {
        switch (type)
        {
        case EventLoop:
            loop->deref();
            break;
        case Thread:
            thread->deref();
            break;
        default:
            app->deref();
            break;
        }
    }

private:
    union {
        QEventLoopPrivate * loop;
        QThreadPrivate * thread;
        QCoreApplicationPrivate * app;
    };
    enum Type {
        EventLoop,
        Thread,
        Application
    };
    const Type type;
};

/*!
    \class QEventLoopLocker
    \inmodule QtCore
    \brief The QEventLoopLocker class provides a means to quit an event loop when it is no longer needed.
    \since 5.0

    The QEventLoopLocker operates on particular objects - either a QCoreApplication
    instance, a QEventLoop instance or a QThread instance.

    This makes it possible to, for example, run a batch of jobs with an event loop
    and exit that event loop after the last job is finished. That is accomplished
    by keeping a QEventLoopLocker with each job instance.

    The variant which operates on QCoreApplication makes it possible to finish
    asynchronously running jobs after the last gui window has been closed. This
    can be useful for example for running a job which uploads data to a network.

    \sa QEventLoop, QCoreApplication
*/

/*!
    Creates an event locker operating on the QCoreApplication.

    The application will quit when there are no more QEventLoopLockers operating on it.

    \sa QCoreApplication::quit(), QCoreApplication::isQuitLockEnabled()
 */
QEventLoopLocker::QEventLoopLocker()
  : d_ptr(new QEventLoopLockerPrivate(static_cast<QCoreApplicationPrivate*>(QObjectPrivate::get(QCoreApplication::instance()))))
{

}

/*!
    Creates an event locker operating on the \a loop.

    This particular QEventLoop will quit when there are no more QEventLoopLockers operating on it.

    \sa QEventLoop::quit()
 */
QEventLoopLocker::QEventLoopLocker(QEventLoop *loop)
  : d_ptr(new QEventLoopLockerPrivate(static_cast<QEventLoopPrivate*>(QObjectPrivate::get(loop))))
{

}

/*!
    Creates an event locker operating on the \a thread.

    This particular QThread will quit when there are no more QEventLoopLockers operating on it.

    \sa QThread::quit()
 */
QEventLoopLocker::QEventLoopLocker(QThread *thread)
  : d_ptr(new QEventLoopLockerPrivate(static_cast<QThreadPrivate*>(QObjectPrivate::get(thread))))
{

}

/*!
    Destroys this event loop locker object
 */
QEventLoopLocker::~QEventLoopLocker()
{
    delete d_ptr;
}

QT_END_NAMESPACE

#include "moc_qeventloop.cpp"
