#ifndef MYPROCESSER_H
#define MYPROCESSER_H

#include <QObject>
#include <QDebug>

class MyProcesser : public QObject
{
    Q_OBJECT

    Q_CLASSINFO("author", "Sabrina Schweinsteiger")
    Q_CLASSINFO("url", "http://doc.moosesoft.co.uk/1.0/")
    Q_CLASSINFO("location", "LosAngel, Chine")

    Q_PROPERTY(Priority priority READ priority WRITE setPriority NOTIFY priorityChanged)

public:
    explicit MyProcesser(QObject *parent = nullptr);
    Q_INVOKABLE MyProcesser(int value);

public:

    enum Priority { High, Low, VeryHigh, VeryLow };
    Q_ENUM(Priority)

    void setPriority(Priority priority)
    {
        m_priority = priority;
        emit priorityChanged(priority);
    }

    Priority priority() const { return m_priority; }

    Q_INVOKABLE void description() {
        QString result("MyProcesser is a demo class while contains all meta system charicatics");
        qDebug() << result;
    }

signals:
    void valueDidChanged(int currentValue);
    void priorityChanged(Priority);

public slots:
    void onValueNeedReset(int value = 0);

private slots:
    void _reset();

private :
    int mValue;
    Priority m_priority = Priority::High;
};

#endif // MYPROCESSER_H
