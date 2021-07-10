// Created by liugquoqiang at 2020-12-8

#include "YdOperation.h"
#include <QMutexLocker>
#include <QDebug>
#include <QThread>

static int YdOperationId = 0;

YdOperation::YdOperation(bool isExecuteInMain, bool isBarrier):
    QObject(nullptr),
    mIsExecuteInMain(isExecuteInMain),
    mIsBarrier(isBarrier)
{
    YdOperationId++;
    setObjectName(QString("YdOperation : %1").arg(YdOperationId));
}

YdOperation::~YdOperation()
{
//    qDebug() << objectName() << "Ended";
}

bool YdOperation::isFinished() const
{
    return mIsFinished;
}

bool YdOperation::isExecuting() const
{
    return mIsExecuting;
}

bool YdOperation::isExecuteInMain() const
{
    return mIsExecuteInMain;
}

bool YdOperation::isBarrier() const
{
    return mIsBarrier;
}

void YdOperation::setTask(std::function<void(void)> task)
{
    mTask = task;
}

void YdOperation::execute()
{
    if (mIsExecuting || mIsFinished)  { return; }
    mIsExecuting = true;
    emit started(this);
    if (mTask) {
        mTask();
    }

//#ifdef QT_DEBUG
//    QString debugInfo;
//    debugInfo.append(objectName()).append(" Run ");
//    debugInfo.append(" in ").append(QThread::currentThread()->objectName());
//    if (mIsExecuteInMain) {
//        debugInfo.append(" inMain ");
//    }
//    if (mIsBarrier) {
//        debugInfo.append(" isBarrier ");
//    }
//    qDebug() << debugInfo;
//#endif
}

void YdOperation::finish()
{
    mIsExecuting = false;
    mIsFinished = true;
    emit finished(this);
}

