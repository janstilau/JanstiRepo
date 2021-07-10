// Created by liugquoqiang at 2020-11-28

#ifdef YD_HOMEWORK

#ifndef YDNOFITICATIONCENTER_H
#define YDNOFITICATIONCENTER_H

#include <QObject>
#include "YdNotiObservation.h"
#include "YdSystemCommon.h"
#include <QMutex>

/*!
 * 模仿 NSNotificationCenter 编写的 Qt 广播机制实现.
 * https://developer.apple.com/documentation/foundation/nsnotificationcenter
 *
 * Qt 的信号槽机制, 会在 sender, receiver 中建立连接, 解决了耦合问题. 但这种线性连接, 导致特定事件的传输, 必须通过 connect 函数组成的链条.
 * 如果发送信号, 槽函数所在对象, 分别在两个 Module 的底层, 那么消息传递会是一个 leftBottom - LeftTop - RightTop - RightBottom 的过程.
 * 这样后果可能是:
 * 1. 一个超大的 中介对象, 承担所有的信号接受和中转, 所有的业务对象都需要被这个中介对象管理, 该对象承担太多的责任, 代码臃肿难以维护.
 * 2. 或者每一中间层都要承担上下层信号的转发工作, 转发工作不做任何其他处理, 仅仅是为了信号能够正常的接受.
 *
 * iOS, Android 都有广播机制的处理方法. 广播中心, 侵入到各个业务类的处理逻辑中. 各业务类注册监听某个特定的广播消息进行处理; 也可以随时发送新的广播通知. 通知的发送, 监听, 都只通过广播中心一层中转环节.
 * 通知的过度使用, 会让数据的流转变得难以追踪, 但是减少数据的流转路径. 例如, 低电量警告这一消息, 各观察者在监听到警告消息之后直接进行对应的处理, 并不需要关心到底是哪里发出的信号. 而一般情况下, 发出这个信号的对象, 也不太关心到底接受者如何处理. 这和信号槽的解耦思想是相同.
 * YdNotificationCenter 内部没有使用信号槽作为实现方式, 通过几个简单的接口, 管理映射关系, 最终监听是通过 QMetaMethod invoke 方法调用.
 */

class YdNotiObservation;

class YdNotificationCenter : public QObject
{
    Q_OBJECT
public:
    static YdNotificationCenter& instance();

    //! 注册监听对象, 监听函数到消息中心.
    //! 监听函数应该注册到 Qt MetaMethod 体系中. 固定接受一个参数 YdNotification. 建议使用 SLOT 宏进行包裹, IDE 会有特殊显示.
    //! e.g. YdNotificationCenter::instance.addObserver(this, SLOT(onNotification(YdNotification)), "YdBatteryLowWarning")
    Q_INVOKABLE void addObserver(QObject *observer,
                     QString handler,
                     const QString &notiName);

    //! 注销监听对象. 如果 notiName 有值, 只会注销该名称通知. notiName 为空, 注销 obserser 监听的所有通知.
    //! 注销函数一定要主动调用维护监听列表数据正常. 一般在析构函数中调用.
    Q_INVOKABLE void removeObserver(QObject *observer,
                        const QString &notiName = "");

    //! 发送某个特定通知.
    //! sender, info 会传递到监听函数的 YdNotification 参数中.
    //! 发送通知可以在任意线程, 监听函数会在监听对象所在线程调用.
    Q_INVOKABLE void postNotification(const QString &notiName,
                          QObject *sender = nullptr,
                          const QMap<QString, QVariant> &info = QMap<QString, QVariant>());

    QString description() const;

private:
    YdNotificationCenter();
    YdNotificationCenter(const YdNotificationCenter&) = delete;
    YdNotificationCenter(YdNotificationCenter&&) = delete;
    YdNotificationCenter& operator=(const YdNotificationCenter&) = delete;
    YdNotificationCenter& operator=(YdNotificationCenter&&) = delete;

private:
    QMap<QString, QList<YdNotiObservation>> mObservations;
    QMap<QObject*, QSet<QString>> mObserverToNameMap;
    QMutex mLock;
};

#define NotiCenter (YdNotificationCenter::instance())

#endif // YDNOFITICATIONCENTER_H

#endif
