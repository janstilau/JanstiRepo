#include "qtconcurrentthreadengine.h"

#if !defined(QT_NO_CONCURRENT) || defined(Q_CLANG_QDOC)

QT_BEGIN_NAMESPACE

namespace QtConcurrent {

ThreadEngineBarrier::ThreadEngineBarrier()
:count(0) { }

void ThreadEngineBarrier::acquire()
{
    forever {
        int localCount = count.loadRelaxed();
        if (localCount < 0) {
            if (count.testAndSetOrdered(localCount, localCount -1))
                return;
        } else {
            if (count.testAndSetOrdered(localCount, localCount + 1))
                return;
        }
    }
}

int ThreadEngineBarrier::release()
{
    forever {
        int localCount = count.loadRelaxed();
        if (localCount == -1) {
            if (count.testAndSetOrdered(-1, 0)) {
                semaphore.release();
                return 0;
            }
        } else if (localCount < 0) {
            if (count.testAndSetOrdered(localCount, localCount + 1))
                return qAbs(localCount + 1);
        } else {
            if (count.testAndSetOrdered(localCount, localCount - 1))
                return localCount - 1;
        }
    }
}

// Wait until all threads have been released
void ThreadEngineBarrier::wait()
{
    forever {
        int localCount = count.loadRelaxed();
        if (localCount == 0)
            return;

        Q_ASSERT(localCount > 0); // multiple waiters are not allowed.
        if (count.testAndSetOrdered(localCount, -localCount)) {
            semaphore.acquire();
            return;
        }
    }
}

int ThreadEngineBarrier::currentCount()
{
    return count.loadRelaxed();
}

// releases a thread, unless this is the last thread.
// returns true if the thread was released.
bool ThreadEngineBarrier::releaseUnlessLast()
{
    forever {
        int localCount = count.loadRelaxed();
        if (qAbs(localCount) == 1) {
            return false;
        } else if (localCount < 0) {
            if (count.testAndSetOrdered(localCount, localCount + 1))
                return true;
        } else {
            if (count.testAndSetOrdered(localCount, localCount - 1))
                return true;
        }
    }
}

ThreadEngineBase::ThreadEngineBase()
:futureInterface(0), threadPool(QThreadPool::globalInstance())
{
    setAutoDelete(false);
}

ThreadEngineBase::~ThreadEngineBase() {}

void ThreadEngineBase::startSingleThreaded()
{
    start();
    while (threadFunction() != ThreadFinished)
        ;
    finish();
}

void ThreadEngineBase::startBlocking()
{
    start();
    barrier.acquire();
    startThreads();

    bool throttled = false;
#ifndef QT_NO_EXCEPTIONS
    try {
#endif
        while (threadFunction() == ThrottleThread) {
            if (threadThrottleExit()) {
                throttled = true;
                break;
            }
        }
#ifndef QT_NO_EXCEPTIONS
    } catch (QException &e) {
        handleException(e);
    } catch (...) {
        handleException(QUnhandledException());
    }
#endif

    if (throttled == false) {
        barrier.release();
    }

    barrier.wait();
    finish();
    exceptionStore.throwPossibleException();
}

void ThreadEngineBase::startThread()
{
    startThreadInternal();
}

void ThreadEngineBase::acquireBarrierSemaphore()
{
    barrier.acquire();
}

bool ThreadEngineBase::isCanceled()
{
    if (futureInterface)
        return futureInterface->isCanceled();
    else
        return false;
}

void ThreadEngineBase::waitForResume()
{
    if (futureInterface)
        futureInterface->waitForResume();
}

bool ThreadEngineBase::isProgressReportingEnabled()
{
    // If we don't have a QFuture, there is no-one to report the progress to.
    return (futureInterface != 0);
}

void ThreadEngineBase::setProgressValue(int progress)
{
    if (futureInterface)
        futureInterface->setProgressValue(progress);
}

void ThreadEngineBase::setProgressRange(int minimum, int maximum)
{
    if (futureInterface)
        futureInterface->setProgressRange(minimum, maximum);
}

bool ThreadEngineBase::startThreadInternal()
{
    if (this->isCanceled())
        return false;

    barrier.acquire();
    if (!threadPool->tryStart(this)) {
        barrier.release();
        return false;
    }
    return true;
}

void ThreadEngineBase::startThreads()
{
    // 这里就是把能够开启的线程都开了.
    while (shouldStartThread() && startThreadInternal()) {}
}

void ThreadEngineBase::threadExit()
{
    const bool asynchronous = futureInterface != 0;
    const int lastThread = (barrier.release() == 0);

    if (lastThread && asynchronous)
        this->asynchronousFinish();
}

// Called by a worker thread that wants to be throttled. If the current number
// of running threads is larger than one the thread is allowed to exit and
// this function returns one.
bool ThreadEngineBase::threadThrottleExit()
{
    return barrier.releaseUnlessLast();
}

void ThreadEngineBase::run() // implements QRunnable.
{
    if (this->isCanceled()) {
        threadExit();
        return;
    }

    startThreads();

    //  threadFunction 里面, 做各个类专属的业务.
    while (threadFunction() == ThrottleThread) {
        // threadFunction returning ThrottleThread means it that the user
        // struct wants to be throttled by making a worker thread exit.
        // Respect that request unless this is the only worker thread left
        // running, in which case it has to keep going.
        if (threadThrottleExit())
            return;
    }

    threadExit();
}

#ifndef QT_NO_EXCEPTIONS

void ThreadEngineBase::handleException(const QException &exception)
{
    if (futureInterface)
        futureInterface->reportException(exception);
    else
        exceptionStore.setException(exception);
}
#endif


} // namepsace QtConcurrent

QT_END_NAMESPACE

#endif // QT_NO_CONCURRENT
