#ifndef QSCOPEDPOINTER_H
#define QSCOPEDPOINTER_H

#include <QtCore/qglobal.h>

#include <stdlib.h>

QT_BEGIN_NAMESPACE

template <typename T>
struct QScopedPointerDeleter
{
    static inline void cleanup(T *pointer)
    {
        // Enforce a complete type.
        // If you get a compile error here, read the section on forward declared
        // classes in the QScopedPointer documentation.
        typedef char IsIncompleteType[ sizeof(T) ? 1 : -1 ];
        (void) sizeof(IsIncompleteType);

        delete pointer;
    }
};

template <typename T>
struct QScopedPointerArrayDeleter
{
    static inline void cleanup(T *pointer)
    {
        // Enforce a complete type.
        // If you get a compile error here, read the section on forward declared
        // classes in the QScopedPointer documentation.
        typedef char IsIncompleteType[ sizeof(T) ? 1 : -1 ];
        (void) sizeof(IsIncompleteType);

        delete [] pointer;
    }
};

struct QScopedPointerPodDeleter
{
    static inline void cleanup(void *pointer) { if (pointer) free(pointer); }
};

#ifndef QT_NO_QOBJECT
template <typename T>
struct QScopedPointerObjectDeleteLater
{
    static inline void cleanup(T *pointer) { if (pointer) pointer->deleteLater(); }
};

class QObject;
typedef QScopedPointerObjectDeleteLater<QObject> QScopedPointerDeleteLater;
#endif



// 所有的上面的删除器, 都是 static inline void cleanup 这个静态方法的包装而已.

template <typename T, typename Cleanup = QScopedPointerDeleter<T> >
class QScopedPointer
{
    typedef T *QScopedPointer:: *RestrictedBool;
public:
    explicit QScopedPointer(T *p = nullptr) Q_DECL_NOTHROW : d(p)
    {
    }

    // 析构, 就是调用删除器的方法而已. 这里不需要管理删除器的内存, 因为, 这里仅仅是一个方法调用.
    inline ~QScopedPointer()
    {
        T *oldD = this->d;
        Cleanup::cleanup(oldD);
    }

    inline T &operator*() const
    {
        Q_ASSERT(d);
        return *d;
    }

    T *operator->() const Q_DECL_NOTHROW
    {
        return d;
    }

    bool operator!() const Q_DECL_NOTHROW
    {
        return !d;
    }

#if defined(Q_QDOC)
    inline operator bool() const
    {
        return isNull() ? nullptr : &QScopedPointer::d;
    }
#else
    operator RestrictedBool() const Q_DECL_NOTHROW
    {
        return isNull() ? nullptr : &QScopedPointer::d;
    }
#endif

    T *data() const Q_DECL_NOTHROW
    {
        return d;
    }

    T *get() const Q_DECL_NOTHROW
    {
        return d;
    }

    bool isNull() const Q_DECL_NOTHROW
    {
        return !d;
    }

    // 原来的, 进行删除处理. 掌管新的值的生命周期. 还是要判等
    void reset(T *other = nullptr) Q_DECL_NOEXCEPT_EXPR(noexcept(Cleanup::cleanup(std::declval<T *>())))
    {
        if (d == other)
            return;
        T *oldD = d;
        d = other;
        Cleanup::cleanup(oldD);
    }

    T *take() Q_DECL_NOTHROW
    {
        T *oldD = d;
        d = nullptr;
        return oldD;
    }

    void swap(QScopedPointer<T, Cleanup> &other) Q_DECL_NOTHROW
    {
        qSwap(d, other.d);
    }

    typedef T *pointer;

protected:
    T *d;

private:
    Q_DISABLE_COPY(QScopedPointer)
};

template <class T, class Cleanup>
inline bool operator==(const QScopedPointer<T, Cleanup> &lhs, const QScopedPointer<T, Cleanup> &rhs) Q_DECL_NOTHROW
{
    return lhs.data() == rhs.data();
}

template <class T, class Cleanup>
inline bool operator!=(const QScopedPointer<T, Cleanup> &lhs, const QScopedPointer<T, Cleanup> &rhs) Q_DECL_NOTHROW
{
    return lhs.data() != rhs.data();
}

template <class T, class Cleanup>
inline bool operator==(const QScopedPointer<T, Cleanup> &lhs, std::nullptr_t) Q_DECL_NOTHROW
{
    return lhs.isNull();
}

template <class T, class Cleanup>
inline bool operator==(std::nullptr_t, const QScopedPointer<T, Cleanup> &rhs) Q_DECL_NOTHROW
{
    return rhs.isNull();
}

template <class T, class Cleanup>
inline bool operator!=(const QScopedPointer<T, Cleanup> &lhs, std::nullptr_t) Q_DECL_NOTHROW
{
    return !lhs.isNull();
}

template <class T, class Cleanup>
inline bool operator!=(std::nullptr_t, const QScopedPointer<T, Cleanup> &rhs) Q_DECL_NOTHROW
{
    return !rhs.isNull();
}

template <class T, class Cleanup>
inline void swap(QScopedPointer<T, Cleanup> &p1, QScopedPointer<T, Cleanup> &p2) Q_DECL_NOTHROW
{ p1.swap(p2); }

// 仅仅是删除器不同, 并且提供了 [] 下标操作符的实现.
template <typename T, typename Cleanup = QScopedPointerArrayDeleter<T> >
class QScopedArrayPointer : public QScopedPointer<T, Cleanup>
{
    template <typename Ptr>
    using if_same_type = typename std::enable_if<std::is_same<typename std::remove_cv<T>::type, Ptr>::value, bool>::type;
public:
    inline QScopedArrayPointer() : QScopedPointer<T, Cleanup>(nullptr) {}

    template <typename D, if_same_type<D> = true>
    explicit QScopedArrayPointer(D *p)
        : QScopedPointer<T, Cleanup>(p)
    {
    }


    inline T &operator[](int i)
    {
        return this->d[i];
    }

    inline const T &operator[](int i) const
    {
        return this->d[i];
    }

    void swap(QScopedArrayPointer &other) Q_DECL_NOTHROW // prevent QScopedPointer <->QScopedArrayPointer swaps
    { QScopedPointer<T, Cleanup>::swap(other); }

private:
    explicit inline QScopedArrayPointer(void *) {
        // Enforce the same type.

        // If you get a compile error here, make sure you declare
        // QScopedArrayPointer with the same template type as you pass to the
        // constructor. See also the QScopedPointer documentation.

        // Storing a scalar array as a pointer to a different type is not
        // allowed and results in undefined behavior.
    }

    Q_DISABLE_COPY(QScopedArrayPointer)
};

template <typename T, typename Cleanup>
inline void swap(QScopedArrayPointer<T, Cleanup> &lhs, QScopedArrayPointer<T, Cleanup> &rhs) Q_DECL_NOTHROW
{ lhs.swap(rhs); }

QT_END_NAMESPACE

#endif // QSCOPEDPOINTER_H
