// Created by liugquoqiang at 2020-12-8

#ifndef YDOPERATIONQUEUE_H
#define YDOPERATIONQUEUE_H

#include <QObject>
#include "YdOperation.h"
#include <QWaitCondition>
#include <QMutex>
#include <QLinkedList>
#include <QSet>
#include <QThread>
#include <QSharedPointer>

/*!
 * 模仿 NSOperation 和 GCD 编写的异步任务提交机制.
 * https://developer.apple.com/documentation/foundation/nsoperationqueue
 * https://developer.apple.com/documentation/dispatch/dispatchqueue
 *
 * Qt 中多线程编程, 要使用 QThread 类. 1子类化该类, 2创建一个QThread对象, 开启运行循环, 然后业务类 moveToThread 到新开辟的线程.
 * 对于一些小任务, 例如, 清理缓存文件, 这种方式过于繁琐.
 * YdOperationQueue 可以使用 lambda 闭包提交任务, 这样可以在任何业务场景以统一的方式提交异步任务.
 * 所有的任务都为异步执行, 提交函数及时返回. YdOperationQueue 内部维护几个线程, 调度任务队列并执行其中的闭包, 所以默认执行环境为子线程.
 * 可以设置主线程调用, 可以设置栅栏调用. 栅栏调用的意思是, 此任务, 单独执行, 会等到前面所有提交的任务执行完后执行, 后面提交的任务会等待该任务执行结束才能执行.
 * 由于都是提交异步任务, 所以可以在 lambda 闭包中嵌套提交异步任务, 不会造成死锁.
 * 由于 c++ 的闭包, 不会对引用语义对象进行引用计数操作, 所以如果任务调用时对象已经释放, 会引起崩溃. 需要特别注意.
 */

class YdOperationQueue;

class YdOperationRunner: public QThread
{
    Q_OBJECT
public:
    explicit YdOperationRunner(QObject *parent,
                               QSharedPointer<QWaitCondition> condition,
                               QSharedPointer<QMutex>  lock,
                               QSharedPointer<QLinkedList<YdOperation*>> queue,
                               QSharedPointer<QSet<YdOperation*>> executings);
    ~YdOperationRunner();

signals:
    void needExecuteInMain(YdOperation*);

private:
    // YdOperationRunner 应该由 YdOperationQueue 管理, 但是线程的生命周期, 是操作系统来决定的.
    // 很有可能发生, YdOperationQueue 已经 deelte 了, 但是线程还会调度的情况. 所以, 共享的资源, 都是计数管理.
    QSharedPointer<QWaitCondition> mThreadCondition = nullptr;
    QSharedPointer<QMutex> mThreadRunningLock = nullptr;
    QSharedPointer<QLinkedList<YdOperation*>> mPendingQueue;
    QSharedPointer<QSet<YdOperation*>> mExecutingSet;

protected:
    void run() override;
};

class YdOperationQueue : public QObject
{
    Q_OBJECT
public:
    static YdOperationQueue &instance(); // global default queue.
    YdOperationQueue();
    ~YdOperationQueue();

    void asyncSubmit(std::function<void(void)> task, bool runInMain = false, bool barrier = false);

    int waitingCount() const;
    int executingCount() const;

    void suspend();
    void resume();
    bool isSuspended() const;
    void cancelAll();

    int maxExecutingCount() const;
    void setMaxEcecuteCount(int count);

    QString description() const;

private slots:
    void onOperationFinished(YdOperation*);
    void onOperationExecuteInMain(YdOperation*);
    void onThreadFinished();

private:
    void dispatch();

    YdOperationQueue(const YdOperationQueue&) = delete;
    YdOperationQueue(YdOperationQueue&&) = delete;
    YdOperationQueue& operator=(const YdOperationQueue&) = delete;
    YdOperationQueue& operator=(YdOperationQueue&&) = delete;

private:
    bool mIsInBarrier = false;
    bool mIsSuspended = false;

    int mMaxExecutingCount = 5;

    QLinkedList<YdOperation*> mWaitingQueue;
    QSharedPointer<QLinkedList<YdOperation*>> mPendingQueue;
    QSharedPointer<QSet<YdOperation*>> mExecutingSet;
    QSet<QThread*> mExecutingThreads;

    QSharedPointer<QWaitCondition> mThreadCondition = nullptr;
    QMutex *mLock = nullptr;
    QSharedPointer<QMutex> mRunningLock = nullptr;
};

#endif // YDOPERATIONQUEUE_H
