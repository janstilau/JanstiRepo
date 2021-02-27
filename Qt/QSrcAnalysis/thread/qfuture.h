#ifndef QFUTURE_H
#define QFUTURE_H

#include <QtCore/qglobal.h>

#ifndef QT_NO_QFUTURE

#include <QtCore/qfutureinterface.h>
#include <QtCore/qstring.h>

QT_BEGIN_NAMESPACE


template <typename T>
class QFutureWatcher;
template <>
class QFutureWatcher<void>;

template <typename T>
class QFuture
{
public:
    QFuture()
        : d(QFutureInterface<T>::canceledResult())
    { }
    explicit QFuture(QFutureInterface<T> *p) // internal
        : d(*p)
    { }

    // Future 仅仅是一个 wrapper 类, 各种操作, 都是被包装的数据的处理.
    bool operator==(const QFuture &other) const { return (d == other.d); }
    bool operator!=(const QFuture &other) const { return (d != other.d); }

    void cancel() { d.cancel(); }
    bool isCanceled() const { return d.isCanceled(); }

    void setPaused(bool paused) { d.setPaused(paused); }
    bool isPaused() const { return d.isPaused(); }
    void pause() { setPaused(true); }
    void resume() { setPaused(false); }
    void togglePaused() { d.togglePaused(); }

    bool isStarted() const { return d.isStarted(); }
    bool isFinished() const { return d.isFinished(); }
    bool isRunning() const { return d.isRunning(); }

    int resultCount() const { return d.resultCount(); }
    int progressValue() const { return d.progressValue(); }
    int progressMinimum() const { return d.progressMinimum(); }
    int progressMaximum() const { return d.progressMaximum(); }
    QString progressText() const { return d.progressText(); }
    void waitForFinished() { d.waitForFinished(); }

    inline T result() const;
    inline T resultAt(int index) const;
    bool isResultReadyAt(int resultIndex) const { return d.isResultReadyAt(resultIndex); }

    operator T() const { return result(); }
    QList<T> results() const { return d.results(); }

    // Future 的各个函数, 都是对于 包装的数据的封装而已.

    // Qt 版本里面, Future 不仅仅是存值那么简单, 可以存一系列的值, 所有需要有迭代器.
    class const_iterator
    {
    public:
        // 对于 iterator 的适配, 双向的 iter.
        typedef std::bidirectional_iterator_tag iterator_category;
        typedef qptrdiff difference_type;
        typedef T value_type;
        typedef const T *pointer;
        typedef const T &reference;

        inline const_iterator() {}
        inline const_iterator(QFuture const * const _future, int _index) : future(_future), index(_index) {}
        inline const_iterator(const const_iterator &o) : future(o.future), index(o.index)  {}
        inline const_iterator &operator=(const const_iterator &o)
        { future = o.future; index = o.index; return *this; }

        // 实际取值, 就是取结果.
        inline const T &operator*() const { return future->d.resultReference(index); }
        inline const T *operator->() const { return future->d.resultPointer(index); }

        inline bool operator!=(const const_iterator &other) const
        {
            if (index == -1 && other.index == -1) // comparing end != end?
                return false;
            if (other.index == -1)
                return (future->isRunning() || (index < future->resultCount()));
            return (index != other.index);
        }

        inline bool operator==(const const_iterator &o) const { return !operator!=(o); }
        inline const_iterator &operator++() { ++index; return *this; }
        inline const_iterator operator++(int) { const_iterator r = *this; ++index; return r; }
        inline const_iterator &operator--() { --index; return *this; }
        inline const_iterator operator--(int) { const_iterator r = *this; --index; return r; }
        inline const_iterator operator+(int j) const { return const_iterator(future, index + j); }
        inline const_iterator operator-(int j) const { return const_iterator(future, index - j); }
        inline const_iterator &operator+=(int j) { index += j; return *this; }
        inline const_iterator &operator-=(int j) { index -= j; return *this; }
    private:
        QFuture const * future;
        int index;
    };

    friend class const_iterator;
    typedef const_iterator ConstIterator;

    const_iterator begin() const { return  const_iterator(this, 0); }
    const_iterator constBegin() const { return  const_iterator(this, 0); }
    const_iterator end() const { return const_iterator(this, -1); }
    const_iterator constEnd() const { return const_iterator(this, -1); }

private:
    friend class QFutureWatcher<T>;

public:
    // 真正的数据部分.
    mutable QFutureInterface<T> d;
};

template <typename T>
inline T QFuture<T>::result() const
{
    // Future 里面, 会有着线程同步的处理. 这就是为什么使用这个类, 可以获取到子线程执行结果的原因.
    // 本质上, 内部其实还是使用了 wait, wakeup 那一套逻辑.
    d.waitForResult(0);
    return d.resultReference(0);
}

template <typename T>
inline T QFuture<T>::resultAt(int index) const
{
    d.waitForResult(index);
    return d.resultReference(index);
}

// QFutureInterface 返回一个 future 对象.
// 真正的数据实现, 返回一个包装类.
// Future 是给外界用的. 所以多生成几份, 是没有关系的.
// 真正的数据部分, 只有一份.
template <typename T>
inline QFuture<T> QFutureInterface<T>::future()
{
    return QFuture<T>(this);
}

Q_DECLARE_SEQUENTIAL_ITERATOR(Future)

template <>
class QFuture<void>
{
public:
    QFuture()
        : d(QFutureInterface<void>::canceledResult())
    { }
    explicit QFuture(QFutureInterfaceBase *p) // internal
        : d(*p)
    { }

    bool operator==(const QFuture &other) const { return (d == other.d); }
    bool operator!=(const QFuture &other) const { return (d != other.d); }

#if !defined(Q_CC_XLC)
    template <typename T>
    QFuture(const QFuture<T> &other)
        : d(other.d)
    { }

    template <typename T>
    QFuture<void> &operator=(const QFuture<T> &other)
    {
        d = other.d;
        return *this;
    }
#endif

    void cancel() { d.cancel(); }
    bool isCanceled() const { return d.isCanceled(); }

    void setPaused(bool paused) { d.setPaused(paused); }
    bool isPaused() const { return d.isPaused(); }
    void pause() { setPaused(true); }
    void resume() { setPaused(false); }
    void togglePaused() { d.togglePaused(); }

    bool isStarted() const { return d.isStarted(); }
    bool isFinished() const { return d.isFinished(); }
    bool isRunning() const { return d.isRunning(); }

    int resultCount() const { return d.resultCount(); }
    int progressValue() const { return d.progressValue(); }
    int progressMinimum() const { return d.progressMinimum(); }
    int progressMaximum() const { return d.progressMaximum(); }
    QString progressText() const { return d.progressText(); }
    void waitForFinished() { d.waitForFinished(); }

private:
    friend class QFutureWatcher<void>;

#ifdef QFUTURE_TEST
public:
#endif
    mutable QFutureInterfaceBase d;
};

inline QFuture<void> QFutureInterface<void>::future()
{
    return QFuture<void>(this);
}

template <typename T>
QFuture<void> qToVoidFuture(const QFuture<T> &future)
{
    return QFuture<void>(future.d);
}

QT_END_NAMESPACE

#endif // QT_NO_QFUTURE

#endif // QFUTURE_H
