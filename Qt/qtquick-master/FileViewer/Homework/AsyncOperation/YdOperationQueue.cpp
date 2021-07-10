// Created by liugquoqiang at 2020-12-8

#include "YdOperationQueue.h"
#include <QMutexLocker>
#include <QApplication>
#include <QDeadlineTimer>
#include <QDebug>

static int YdOperationRunnerIdx = 0;

YdOperationRunner::YdOperationRunner(QObject *parent,
                                     QSharedPointer<QWaitCondition> condition,
                                     QSharedPointer<QMutex> lock,
                                     QSharedPointer<QLinkedList<YdOperation*>> queue,
                                     QSharedPointer<QSet<YdOperation*>> executings):
    QThread(parent),
    mThreadCondition(condition),
    mThreadRunningLock(lock),
    mPendingQueue(queue),
    mExecutingSet(executings)
{
    YdOperationRunnerIdx++;
    setObjectName(QString("YdThreadId: %1").arg(YdOperationRunnerIdx));
}

YdOperationRunner::~YdOperationRunner()
{
    qDebug() << objectName() << " Dealloc";
}

void YdOperationRunner::run()
{
    while (true) {
        if (isInterruptionRequested()) { return; }
        mThreadRunningLock->lock();
        while (mPendingQueue->isEmpty()) {
            if (isInterruptionRequested()) {
                mThreadRunningLock->unlock();
                return;
            }
            bool wakeUp = mThreadCondition->wait(mThreadRunningLock.data(), 5000);
            if (!wakeUp) {
                mThreadRunningLock->unlock();
                return;
            }
        }

        YdOperation *aThreadTask = mPendingQueue->front();
        mPendingQueue->pop_front();
        if (!mPendingQueue->isEmpty()) {
            mThreadCondition->notify_all();
        }
        mThreadRunningLock->unlock();

        if (isInterruptionRequested()) { return; }
        if (aThreadTask->isExecuteInMain()) {
            emit needExecuteInMain(aThreadTask);
        } else {
            mThreadRunningLock->lock();
            mExecutingSet->insert(aThreadTask);
            mThreadRunningLock->unlock();
            aThreadTask->execute();
            mThreadRunningLock->lock();
            mExecutingSet->remove(aThreadTask);
            mThreadRunningLock->unlock();
            aThreadTask->finish();
        }
    }
}

#pragma mark - YdOperationQueue Implementation

YdOperationQueue& YdOperationQueue::instance()
{
    static YdOperationQueue mInstance;
    return mInstance;
}

YdOperationQueue::YdOperationQueue() :
    QObject(nullptr),
    mPendingQueue(new QLinkedList<YdOperation*>),
    mExecutingSet(new QSet<YdOperation*>),
    mThreadCondition(new QWaitCondition),
    mLock(new QMutex(QMutex::Recursive)),
    mRunningLock(new QMutex())
{
    // YdOperationQueue 对象本身为主线程环境, 用来处理主线程任务调用.
    if (this->thread() != QApplication::instance()->thread()) {
        this->moveToThread(QApplication::instance()->thread());
    }
}

YdOperationQueue::~YdOperationQueue()
{
    mLock->lock();
    {
        cancelAll();
        auto runingThreads = mExecutingThreads;
        for (auto aThread: runingThreads) {
            aThread->disconnect(this);
            aThread->requestInterruption();
            mThreadCondition->notify_all();
        }

        mRunningLock->lock();
        for (auto aOperation: *mPendingQueue.data()) {
            aOperation->deleteLater();
        }
        mPendingQueue.clear();
        mRunningLock->unlock();
    }
    mLock->unlock();

    if (mLock) {
        delete mLock;
        mLock = nullptr;
    }
}

void YdOperationQueue::asyncSubmit(std::function<void(void)> task, bool runInMain, bool barrier)
{
    YdOperation *aOperation = new YdOperation(runInMain, barrier);
    aOperation->setTask(task);
    connect(aOperation, &YdOperation::finished,
            this, &YdOperationQueue::onOperationFinished, Qt::AutoConnection);

    mLock->lock();
    mWaitingQueue.append(aOperation);
    mLock->unlock();
    dispatch();
}

int YdOperationQueue::waitingCount() const
{
    QMutexLocker locker(mLock);
    return mWaitingQueue.size();
}

int YdOperationQueue::executingCount() const
{
    QMutexLocker locker(mLock);
    QMutexLocker runningLocker(mRunningLock.data());
    return mPendingQueue->size() + mExecutingSet->size();
}

void YdOperationQueue::suspend()
{
    QMutexLocker locker(mLock);
    mIsSuspended = true;
}

void YdOperationQueue::resume()
{
    QMutexLocker locker(mLock);
    mIsSuspended = false;
    dispatch();
}

bool YdOperationQueue::isSuspended() const
{
    QMutexLocker locker(mLock);
    return mIsSuspended;
}

int YdOperationQueue::maxExecutingCount() const
{
    QMutexLocker locker(mLock);
    return mMaxExecutingCount;
}

void YdOperationQueue::setMaxEcecuteCount(int count)
{
    if (count <= 0) { return; }

    QMutexLocker locker(mLock);
    mMaxExecutingCount = count;
    dispatch();
}

void YdOperationQueue::cancelAll()
{
    QMutexLocker locker(mLock);
    for (auto aOperation: mWaitingQueue) {
        aOperation->deleteLater();
    }
    mWaitingQueue.clear();
}

#pragma mark - Slots

void YdOperationQueue::onOperationFinished(YdOperation *operation)
{
    if (!operation) { return; }
    QMutexLocker locker(mLock);
    if (operation->isBarrier()) {
        mIsInBarrier = false;
    }
    dispatch();
    operation->deleteLater();
}

void YdOperationQueue::onOperationExecuteInMain(YdOperation *aOperation)
{
    if (!aOperation || aOperation->isFinished() || aOperation->isExecuting()) { return; }
    mRunningLock->lock();
    mExecutingSet->insert(aOperation);
    mRunningLock->unlock();
    aOperation->execute();
    mRunningLock->lock();
    mExecutingSet->insert(aOperation);
    mRunningLock->unlock();
    aOperation->finish();
}

void YdOperationQueue::onThreadFinished()
{
    QMutexLocker locker(mLock);
    mExecutingThreads.remove(QThread::currentThread());
}

#pragma mark - DispatchAlgorithm

static const int kMaxThreadCount = 3;

//! mWaitingQueue 正在等待调度的任务.
//! mPendingQueue 即将开始运行的任务, 子线程只会从该队列取任务执行. 进入到该队列的任务, 无法取消, 暂停.
//! mExecutingSet 已经开始运行的任务
//! suspend, resume, barrier 均是控制 mWaitingQueue 是否可以转移任务到 mPendingQueue 为基础逻辑实现.
//! Barrier 的实现逻辑:
//! mIsInBarrier 状态代表着当前正在运行 barrier 任务, 只会运行这一个任务.
//! 如果当前已经是 mIsInBarrier 状态, 任务调度暂停, 直到当前 barrier 任务运行结束退出 mIsInBarrier 状态, 重新调度.
//! 如果下一个任务是 barrier 任务而此时还有其他任务在运行, 任务调度暂停, 等待当前运行任务全部完成后, 重新调度. 在该任务, 进入到 mPendingQueue 队列之后, 设置进入 mIsInBarrier 状态, 单独运行该任务.
void YdOperationQueue::dispatch()
{
    QMutexLocker locker(mLock);
    if (mIsSuspended) { return; }
    if (mIsInBarrier) { return; }
    if (mWaitingQueue.isEmpty()) { return; }

    YdOperation* waitingFrontOperation = mWaitingQueue.front();
    if (waitingFrontOperation->isBarrier() && executingCount() > 0) {
        return;
    }

    QMutexLocker runningLocker(mRunningLock.data());
    while (mMaxExecutingCount > mPendingQueue->size() + mExecutingSet->size() &&
           !mWaitingQueue.isEmpty()) {
        YdOperation* frontOperation = mWaitingQueue.front();
        mPendingQueue->append(frontOperation);
        mWaitingQueue.pop_front();
        if (kMaxThreadCount > mExecutingThreads.size()) {
            YdOperationRunner *thread = new YdOperationRunner(nullptr,
                                                              mThreadCondition,
                                                              mRunningLock,
                                                              mPendingQueue,
                                                              mExecutingSet);
            connect(thread, &YdOperationRunner::needExecuteInMain,
                    this, &YdOperationQueue::onOperationExecuteInMain, Qt::QueuedConnection);
            connect(thread, &YdOperationRunner::finished,
                    this, &YdOperationQueue::onThreadFinished, Qt::DirectConnection);
            connect(thread, &YdOperationRunner::finished, thread, &YdOperationRunner::deleteLater);
            thread->start();
            mExecutingThreads.insert(thread);
        }
        mThreadCondition->notify_all();
        if (frontOperation->isBarrier()) {
            mIsInBarrier = true;
            break;
        }
    }
}

QString YdOperationQueue::description() const
{
    QString result;
    result.append("Waiting: ").append(QString("%1").arg(mWaitingQueue.size())).append("\n");
    result.append("Pending: ").append(QString("%1").arg(mPendingQueue->size())).append("\n");
    result.append("Executing: ").append(QString("%1").arg(mExecutingSet->size())).append("\n");
    result.append("Threads: ").append(QString("%1").arg(mExecutingThreads.size())).append(" ~~ ");
    for (auto aThread: mExecutingThreads) {
        result.append(aThread->objectName()).append("   ");
    }
    result.append("\n");
    return result;
}
