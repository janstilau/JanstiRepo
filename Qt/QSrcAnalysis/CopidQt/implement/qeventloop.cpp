#include "qeventloop.h"

#include "qabstracteventdispatcher.h"
#include "qcoreapplication.h"
#include "qcoreapplication_p.h"
#include "qelapsedtimer.h"

#include "qobject_p.h"
#include "qeventloop_p.h"
#include <private/qthread_p.h>

QT_BEGIN_NAMESPACE

// Qt 里面的 Runloop, 是把各个事件的处理, 放到了 runLoop 的内部.
// 但是在这里, QEventLoop 仅仅是起了一个死循环的作用, 真正的对于事件的处理, 在 eventDispatcher 中.
// 不过, 基本的思想, 还是填充数据, 死循环, 抽取数据.

QEventLoop::QEventLoop(QObject *parent)
    : QObject(*new QEventLoopPrivate, parent)
{
    Q_D(QEventLoop);
    if (!QCoreApplication::instance() && QCoreApplicationPrivate::threadRequiresCoreApplication()) {
        qWarning("QEventLoop: Cannot be used without QApplication");
    } else if (!d->threadData->eventDispatcher.load()) {
        QThreadPrivate::createEventDispatcher(d->threadData);
    }
}

QEventLoop::~QEventLoop()
{ }


/*!
   仅仅是对于 QAbstractEventDispatcher::processEvents() 的简单包装而已.
*/
bool QEventLoop::processEvents(ProcessEventsFlags flags)
{
    Q_D(QEventLoop);
    if (!d->threadData->eventDispatcher.load())
        return false;
    return d->threadData->eventDispatcher.load()->processEvents(flags);
}

int QEventLoop::exec(ProcessEventsFlags flags)
{
    Q_D(QEventLoop);
    //we need to protect from race condition with QThread::exit
    QMutexLocker locker(&static_cast<QThreadPrivate *>(QObjectPrivate::get(d->threadData->thread))->mutex);
    if (d->threadData->quitNow)
        return -1;

    if (d->inExec) {
        qWarning("QEventLoop::exec: instance %p has already called exec()", this);
        return -1;
    }


    // 在函数里面, 定义了一个对象. 利用这个对象的构造析构函数, 管理资源.
    struct LoopReference {
        QEventLoopPrivate *d;
        QMutexLocker &locker;

        bool exceptionCaught;
        LoopReference(QEventLoopPrivate *d, QMutexLocker &locker) : d(d), locker(locker), exceptionCaught(true)
        {
            d->inExec = true;
            d->exit.storeRelease(false);
            ++d->threadData->loopLevel;
            d->threadData->eventLoops.push(d->q_func());
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
            QEventLoop *eventLoop = d->threadData->eventLoops.pop();
            Q_ASSERT_X(eventLoop == d->q_func(), "QEventLoop::exec()", "internal error");
            Q_UNUSED(eventLoop); // --release warning
            d->inExec = false;
            --d->threadData->loopLevel;
        }
    };
    LoopReference ref(d, locker);

    // remove posted quit events when entering a new event loop
    QCoreApplication *app = QCoreApplication::instance();
    if (app && app->thread() == thread())
        QCoreApplication::removePostedEvents(app, QEvent::Quit);

    // 如果, exit 这标记值没有标记退出, 就不断的调用 processEvents 这个函数,
    // 而 processEvents 这个函数, 将对于积压的事件的处理, 交给了 eventDispatcher
    while (!d->exit.loadAcquire())  // 这里应该是加锁解锁的操作.
        processEvents(flags | WaitForMoreEvents | EventLoopExec); // 这里有一个死循环, 不断地调用 processEvents 函数.

    ref.exceptionCaught = false;
    return d->returnCode.load();
}

/*!
    这个函数, 还是不断地调用 processEvents 函数, 只不过每一次都进行一次时间的判断.
    任何这种, 有着过期时间的方法, 基本都是这样实现的. 死循环加时间判断.
*/
void QEventLoop::processEvents(ProcessEventsFlags flags, int maxTime)
{
    Q_D(QEventLoop);
    if (!d->threadData->eventDispatcher.load())
        return;

    QElapsedTimer start;
    start.start();
    while (processEvents(flags & ~WaitForMoreEvents)) {
        if (start.elapsed() > maxTime)
            break;
    }
}

// 这个函数, 会在 thread 的 exit, quit 函数里面调用.
// 在这里, 修改 event loop 的状态量, 这样, 在 exec 里面, while 循环判断 false, 跳出事件循环.
void QEventLoop::exit(int returnCode)
{
    Q_D(QEventLoop);
    if (!d->threadData->eventDispatcher.load())
        return;
    d->returnCode.store(returnCode);
    d->exit.storeRelease(true); // 在这里, 改变了值.
    d->threadData->eventDispatcher.load()->interrupt();
}


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
    if (!d->threadData->eventDispatcher.load())
        return;
    d->threadData->eventDispatcher.load()->wakeUp();
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
