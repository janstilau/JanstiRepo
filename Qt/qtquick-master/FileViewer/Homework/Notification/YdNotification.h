// Created by liugquoqiang at 2020-11-28

#ifdef YD_HOMEWORK

#ifndef YDNOTIFICATION_H
#define YDNOTIFICATION_H

#include <QObject>
#include <QPointer>
#include <QMap>
#include <QVariant>
#include <QThread>

class YdNotification
{
public:
    YdNotification();

    QString name() const;
    //! 通知发送者
    QObject *sender() const;
    //! 通知发送时所在线程, 如果监听对象不在该线程, 监听函数会异步调用. 这种情况, 线程可能已经销毁, 返回 nullptr.
    QThread* postTimeThread() const;
    //! 数据容器. 如何传递, 解析由业务使用者决定. 由于 QVariant 没有提供指针包裹, 可使用 qlonglong 和 void* 之间的转化.
    //! 如果触发异步监听, 确保指针数据在监听函数调用时有效.
    const QMap<QString, QVariant>& notiInfo() const;

    void setSender(QObject *sender);
    void setName(QString name);
    void setInfo(const QMap<QString, QVariant> info);

private:
    QPointer<QObject> mSender;
    QString mName;
    QMap<QString, QVariant> mInfo;
    QPointer<QThread> mThread;
};

Q_DECLARE_METATYPE(YdNotification);

#endif // YDNOTIFICATION_H

#endif
