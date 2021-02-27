#ifndef QSCOPEDPOINTER_H
#define QSCOPEDPOINTER_H

#include <QtCore/qglobal.h>

#include <stdlib.h>

QT_BEGIN_NAMESPACE

//! C++ 的模板技术, 传递一个类名过去, 其实并不知道这个类会被怎么使用.
//! 有可能, 会生成这个类的对象, 然后使用这个类的对象在模板算法里面参与逻辑
//! 也有可能, 会使用这个模板的静态方法, 直接参与逻辑.
//! 不管怎么说, 模板技术, 都有着类似于多态的效果.
//! 以下的几个 Deleter, 都是仅仅有一个要求, 那就是, cleanup 静态方法. 如果想要实现自己的删除器, 那这个删除器实现该方法也就可以了.

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

template <typename T>
struct QScopedPointerObjectDeleteLater
{
    // 这里, 怎么保证, 是 QObject 的子类啊.
    static inline void cleanup(T *pointer) { if (pointer) pointer->deleteLater(); }
};

class QObject;
typedef QScopedPointerObjectDeleteLater<QObject> QScopedPointerDeleteLater;



// 默认, 使用 QScopedPointerDeleter 作为删除器. 模板的类参数, 也可以指定默认参数.
// 该类对标 std::unique_ptr, 但是 std::unique_ptr 的源代码太过于难以理解.
template <typename T, typename Cleanup = QScopedPointerDeleter<T> >
class QScopedPointer
{
    typedef T *QScopedPointer:: *RestrictedBool;
public:
    explicit QScopedPointer(T *p = nullptr) : d(p)
    {
    }

    // ScaopedPointer, 就是自己的生命周期内, 管理着传入指针, 自己生命周期结束, 就应该调用对象的清理方法, 清理资源
    inline ~QScopedPointer()
    {
        T *oldD = this->d;
        Cleanup::cleanup(oldD);
    }

    inline T &operator*() const
    {
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

    inline operator bool() const
    {
        return isNull() ? nullptr : &QScopedPointer::d;
    }

    operator RestrictedBool() const Q_DECL_NOTHROW
    {
        return isNull() ? nullptr : &QScopedPointer::d;
    }

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

    void reset(T *other = nullptr) Q_DECL_NOEXCEPT_EXPR(noexcept(Cleanup::cleanup(std::declval<T *>())))
    {
        // 如果 d == other, 那么不直接 return, 后续的 cleanup, 会让资源的状态危险.
        if (d == other)
            return;
        T *oldD = d;
        d = other;
        // 这里, 主动地调用了 oldPointer 的 cleanup.
        Cleanup::cleanup(oldD);
    }

    // task, 取出并且 reset, 这是一个通用的名称.
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
    T *d; // 真正的业务对象指针.

private:
    Q_DISABLE_COPY(QScopedPointer) // 一个简单地宏, 其实就是 copy ctor, assign ctor == delete
};

// 所有的模板函数, 都要写清楚类型参数.
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

// 同 null 的判断, 也要明确的写出来才可以.
// typedef decltype(nullptr) nullptr_t; C++ 是通过类型进行函数重载的, 所以 nullptr, 其实是有着自己专门的类型的.
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

// QScopedArrayPointer 仅仅是增加了一些数组相关的方法.
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
