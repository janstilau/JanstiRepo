#ifndef QSHAREDDATA_H
#define QSHAREDDATA_H

#include <QtCore/qglobal.h>
#include <QtCore/qatomic.h>
#if QT_DEPRECATED_SINCE(5, 6)
#include <QtCore/qhash.h>
#endif
#include <QtCore/qhashfunctions.h>

QT_BEGIN_NAMESPACE


template <class T> class QSharedDataPointer;

// 这个类, 是为了给别人子类化的.
// 当一个类, 想要用引用计数被管理的时候, 需要定义一个 ref, 让别人操作.
// QShareData 定义了一个 ref. 然后, QSharedDataPointer 里面的操作, 会操作这个 ref
// QSharedDataPointer 是泛型的, 直接使用 .ref++ 进行了操作, 所以, 他应该要求的是, T 是 QSharedData 的子类. 不过 C++ 不能再泛型里面进行范围的限制.

// QSharedData is designed to be used with QSharedDataPointer or QExplicitlySharedDataPointer to implement custom implicitly shared or explicitly shared classes.
class Q_CORE_EXPORT QSharedData
{
public:
    mutable QAtomicInt ref; // Ref 是 atomic 的, 保证了线程之间的安全.

    inline QSharedData() : ref(0) { }
    inline QSharedData(const QSharedData &) : ref(0) { }

private:
    // using the assignment operator would lead to corruption in the ref-counting
    QSharedData &operator=(const QSharedData &);
};

// 里面, 默认就是使用 T.ref.load 等操作了, 就是默认, T 其实是 QSharedData
template <class T> class QSharedDataPointer
{
public:
    typedef T Type;
    typedef T *pointer;

    inline void detach() {
        if (d && d->ref.load() != 1) detach_helper();
    }
    // 修改的时候, 提前 detach. 只读的情况, 直接返回数据.
    // 编译器会判断, 到底应该调用哪个方法.
    inline T &operator*() {
        detach(); return *d;
    }
    inline const T &operator*() const {
        return *d;
    }
    inline T *operator->() { detach(); return d; }
    inline const T *operator->() const { return d; }

    inline operator T *() { detach(); return d; }
    inline operator const T *() const { return d; }

    inline T *data() { detach(); return d; }
    inline const T *data() const { return d; }
    inline const T *constData() const { return d; }

    // 相等判断, 就是指针的指向判断.
    inline bool operator==(const QSharedDataPointer<T> &other) const { return d == other.d; }
    inline bool operator!=(const QSharedDataPointer<T> &other) const { return d != other.d; }

    inline QSharedDataPointer() { d = nullptr; }
    // 析构的时候, 就是引用计数管理, 必要时候, 删除管理的对象.
    inline ~QSharedDataPointer() { if (d && !d->ref.deref()) delete d; }

    explicit QSharedDataPointer(T *data) Q_DECL_NOTHROW;
    // 拷贝构造, 就是引用计数的管理.
    inline QSharedDataPointer(const QSharedDataPointer<T> &o) : d(o.d) {
        if (d) d->ref.ref();
    }

    // 拷贝赋值, 也是引用计数的管理.
    inline QSharedDataPointer<T> & operator=(const QSharedDataPointer<T> &o) {
        if (o.d != d) {
            if (o.d)
                o.d->ref.ref();
            T *old = d;
            d = o.d;
            if (old && !old->ref.deref())
                delete old;
        }
        return *this;
    }
    inline QSharedDataPointer &operator=(T *o) {
        if (o != d) {
            if (o)
                o->ref.ref();
            T *old = d;
            d = o;
            if (old && !old->ref.deref())
                delete old;
        }
        return *this;
    }

    QSharedDataPointer(QSharedDataPointer &&o) Q_DECL_NOTHROW : d(o.d) { o.d = nullptr; }
    inline QSharedDataPointer<T> &operator=(QSharedDataPointer<T> &&other) Q_DECL_NOTHROW
    {
        QSharedDataPointer moved(std::move(other));
        swap(moved);
        return *this;
    }

    inline bool operator!() const { return !d; }

    inline void swap(QSharedDataPointer &other) Q_DECL_NOTHROW
    { qSwap(d, other.d); }

protected:
    T *clone();

private:
    void detach_helper();

    T *d;
};

template <class T> inline bool operator==(std::nullptr_t p1, const QSharedDataPointer<T> &p2)
{
    Q_UNUSED(p1);
    return !p2;
}

template <class T> inline bool operator==(const QSharedDataPointer<T> &p1, std::nullptr_t p2)
{
    Q_UNUSED(p2);
    return !p1;
}

template <class T> class QExplicitlySharedDataPointer
{
public:
    typedef T Type;
    typedef T *pointer;

    inline T &operator*() const { return *d; }
    inline T *operator->() { return d; }
    inline T *operator->() const { return d; }
    inline T *data() const { return d; }
    inline const T *constData() const { return d; }
    inline T *take() { T *x = d; d = nullptr; return x; }

    inline void detach() { if (d && d->ref.load() != 1) detach_helper(); }

    inline void reset()
    {
        if(d && !d->ref.deref())
            delete d;

        d = nullptr;
    }

    inline operator bool () const { return d != nullptr; }

    inline bool operator==(const QExplicitlySharedDataPointer<T> &other) const { return d == other.d; }
    inline bool operator!=(const QExplicitlySharedDataPointer<T> &other) const { return d != other.d; }
    inline bool operator==(const T *ptr) const { return d == ptr; }
    inline bool operator!=(const T *ptr) const { return d != ptr; }

    inline QExplicitlySharedDataPointer() { d = nullptr; }
    inline ~QExplicitlySharedDataPointer() { if (d && !d->ref.deref()) delete d; }

    explicit QExplicitlySharedDataPointer(T *data) Q_DECL_NOTHROW;
    inline QExplicitlySharedDataPointer(const QExplicitlySharedDataPointer<T> &o) : d(o.d) { if (d) d->ref.ref(); }

    template<class X>
    inline QExplicitlySharedDataPointer(const QExplicitlySharedDataPointer<X> &o)
#ifdef QT_ENABLE_QEXPLICITLYSHAREDDATAPOINTER_STATICCAST
        : d(static_cast<T *>(o.data()))
#else
        : d(o.data())
#endif
    {
        if(d)
            d->ref.ref();
    }

    inline QExplicitlySharedDataPointer<T> & operator=(const QExplicitlySharedDataPointer<T> &o) {
        if (o.d != d) {
            if (o.d)
                o.d->ref.ref();
            T *old = d;
            d = o.d;
            if (old && !old->ref.deref())
                delete old;
        }
        return *this;
    }
    inline QExplicitlySharedDataPointer &operator=(T *o) {
        if (o != d) {
            if (o)
                o->ref.ref();
            T *old = d;
            d = o;
            if (old && !old->ref.deref())
                delete old;
        }
        return *this;
    }
#ifdef Q_COMPILER_RVALUE_REFS
    inline QExplicitlySharedDataPointer(QExplicitlySharedDataPointer &&o) Q_DECL_NOTHROW : d(o.d) { o.d = nullptr; }
    inline QExplicitlySharedDataPointer<T> &operator=(QExplicitlySharedDataPointer<T> &&other) Q_DECL_NOTHROW
    {
        QExplicitlySharedDataPointer moved(std::move(other));
        swap(moved);
        return *this;
    }
#endif

    inline bool operator!() const { return !d; }

    inline void swap(QExplicitlySharedDataPointer &other) Q_DECL_NOTHROW
    { qSwap(d, other.d); }

protected:
    T *clone();

private:
    void detach_helper();

    T *d;
};

// 引用计数的管理.
template <class T>
Q_INLINE_TEMPLATE QSharedDataPointer<T>::QSharedDataPointer(T *adata) Q_DECL_NOTHROW
    : d(adata)
{ if (d) d->ref.ref(); }

template <class T>
Q_INLINE_TEMPLATE T *QSharedDataPointer<T>::clone()
{
    // 所谓的 clone, 就是使用拷贝构造, 生成一份新的数据.
    // 所以, ShareData 的子类, 其实不能是 QObject 的子类. 因为 QObject 是没有拷贝构造的.
    return new T(*d);
}

// detach, 就是使用 clone 的数据.
template <class T>
Q_OUTOFLINE_TEMPLATE void QSharedDataPointer<T>::detach_helper()
{
    T *x = clone();
    x->ref.ref();
    if (!d->ref.deref())
        delete d;
    d = x;
}

template <class T>
Q_INLINE_TEMPLATE T *QExplicitlySharedDataPointer<T>::clone()
{
    return new T(*d);
}

template <class T>
Q_OUTOFLINE_TEMPLATE void QExplicitlySharedDataPointer<T>::detach_helper()
{
    T *x = clone();
    x->ref.ref();
    if (!d->ref.deref())
        delete d;
    d = x;
}

template <class T>
Q_INLINE_TEMPLATE QExplicitlySharedDataPointer<T>::QExplicitlySharedDataPointer(T *adata) Q_DECL_NOTHROW
    : d(adata)
{ if (d) d->ref.ref(); }

template <class T> inline bool operator==(std::nullptr_t p1, const QExplicitlySharedDataPointer<T> &p2)
{
    Q_UNUSED(p1);
    return !p2;
}

template <class T> inline bool operator==(const QExplicitlySharedDataPointer<T> &p1, std::nullptr_t p2)
{
    Q_UNUSED(p2);
    return !p1;
}

template <class T>
Q_INLINE_TEMPLATE void qSwap(QSharedDataPointer<T> &p1, QSharedDataPointer<T> &p2)
{ p1.swap(p2); }

template <class T>
Q_INLINE_TEMPLATE void qSwap(QExplicitlySharedDataPointer<T> &p1, QExplicitlySharedDataPointer<T> &p2)
{ p1.swap(p2); }

QT_END_NAMESPACE
namespace std {
    template <class T>
    Q_INLINE_TEMPLATE void swap(QT_PREPEND_NAMESPACE(QSharedDataPointer)<T> &p1, QT_PREPEND_NAMESPACE(QSharedDataPointer)<T> &p2)
    { p1.swap(p2); }

    template <class T>
    Q_INLINE_TEMPLATE void swap(QT_PREPEND_NAMESPACE(QExplicitlySharedDataPointer)<T> &p1, QT_PREPEND_NAMESPACE(QExplicitlySharedDataPointer)<T> &p2)
    { p1.swap(p2); }
}
QT_BEGIN_NAMESPACE

template <class T>
Q_INLINE_TEMPLATE uint qHash(const QSharedDataPointer<T> &ptr, uint seed = 0) Q_DECL_NOTHROW
{
    return qHash(ptr.data(), seed);
}
template <class T>
Q_INLINE_TEMPLATE uint qHash(const QExplicitlySharedDataPointer<T> &ptr, uint seed = 0) Q_DECL_NOTHROW
{
    return qHash(ptr.data(), seed);
}

template<typename T> Q_DECLARE_TYPEINFO_BODY(QSharedDataPointer<T>, Q_MOVABLE_TYPE);
template<typename T> Q_DECLARE_TYPEINFO_BODY(QExplicitlySharedDataPointer<T>, Q_MOVABLE_TYPE);

QT_END_NAMESPACE

#endif // QSHAREDDATA_H
