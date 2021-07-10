// Created by liugquoqiang at 2020-12-8

#ifndef YDOPERATION_H
#define YDOPERATION_H

#include <QObject>
#include <functional>
#include <QMutex>

class YdOperation: public QObject
{
    Q_OBJECT
public:
    explicit YdOperation(bool isExecuteInMain, bool isBarrier);
    ~YdOperation();

    bool isExecuteInMain() const;
    bool isBarrier() const;
    bool isFinished() const;
    bool isExecuting() const;

    void setTask(std::function<void(void)> task);

    void execute();
    void finish();

signals:
    void started(YdOperation*);
    void finished(YdOperation*);

private:
    bool mIsExecuting = false;
    bool mIsFinished = false;

    std::function<void(void)> mTask = nullptr;
    bool mIsExecuteInMain = false;
    bool mIsBarrier = false;
};

#endif // YDOPERATION_H
