#ifndef Q_QDOC

#include <new>
#include <QtCore/qatomic.h>
#include <QtCore/qobject.h>    // for qobject_cast
#if QT_DEPRECATED_SINCE(5, 6)
#include <QtCore/qhash.h>
#endif
#include <QtCore/qhashfunctions.h>

QT_BEGIN_NAMESPACE

/*

  Qt 版本的实现非常复杂, 简单地用 std 的来进行理解


最后说一下**计数器增减**的规则：

初始化及增加的情形：

- 当创建一个新的shared_ptr时，内部对象计数器和自身的计数器均置1.

- 当将另外一个shared_ptr赋值给新的shared_ptr时，内部对象计数器+1,自身计数器不变。

- 当将另外一个shared_ptr赋值给新的weak_ptr时,内部对象计数器不变,自身计数器+1。

- 当从weak_ptr获取一个shared_ptr时，内部对象计数器+1,自身计数器不变。

减少的情形：

- 当一个shared_ptr析构时，内部对象计数器-1。当内部对象计数器减为0时，则释放内部对象，并将自身计数器-1。

- 当一个weak_ptr析构时，自身计数器-1。当自身计数器减为0时，则释放自身_Ref_count*对象。

*/
template <class T> class QWeakPointer;
template <class T> class QSharedPointer;
template <class T> class QEnableSharedFromThis;

class QVariant;

template <class X, class T>
QSharedPointer<X> qSharedPointerCast(const QSharedPointer<T> &ptr);
template <class X, class T>
QSharedPointer<X> qSharedPointerDynamicCast(const QSharedPointer<T> &ptr);
template <class X, class T>
QSharedPointer<X> qSharedPointerConstCast(const QSharedPointer<T> &ptr);

#ifndef QT_NO_QOBJECT
template <class X, class T>
QSharedPointer<X> qSharedPointerObjectCast(const QSharedPointer<T> &ptr);
#endif

// 这是 namespace, 并不是 class 定义
namespace QtSharedPointer {
    template <class T> class ExternalRefCount;
    template <class X, class Y> QSharedPointer<X> copyAndSetPointer(X * ptr, const QSharedPointer<Y> &src);

    // used in debug mode to verify the reuse of pointers
    Q_CORE_EXPORT void internalSafetyCheckAdd(const void *, const volatile void *);
    Q_CORE_EXPORT void internalSafetyCheckRemove(const void *);

    template <class T, typename Klass, typename RetVal>
    inline void executeDeleter(T *t, RetVal (Klass:: *memberDeleter)())
    { (t->*memberDeleter)(); }
    template <class T, typename Deleter>
    inline void executeDeleter(T *t, Deleter d)
    { d(t); }
    struct NormalDeleter {};

    // this uses partial template specialization
    template <class T> struct RemovePointer;
    template <class T> struct RemovePointer<T *> { typedef T Type; };
    template <class T> struct RemovePointer<QSharedPointer<T> > { typedef T Type; };
    template <class T> struct RemovePointer<QWeakPointer<T> > { typedef T Type; };

    struct ExternalRefCountData
    {
        typedef void (*DestroyerFn)(ExternalRefCountData *);

        QBasicAtomicInt weakref; // 弱引用计数量
        QBasicAtomicInt strongref; // 强引用计数量
        DestroyerFn destroyer; // 资源管理函数, 进行资源的管理.

        inline ExternalRefCountData(DestroyerFn d)
            : destroyer(d)
        {
            // 默认, 都是 1.
            strongref.store(1);
            weakref.store(1);
        }

        inline ExternalRefCountData(Qt::Initialization) { }
        ~ExternalRefCountData() { Q_ASSERT(!weakref.load()); Q_ASSERT(strongref.load() <= 0); }

        void destroy() { destroyer(this); }

#ifndef QT_NO_QOBJECT
        Q_CORE_EXPORT static ExternalRefCountData *getAndRef(const QObject *);
        Q_CORE_EXPORT void setQObjectShared(const QObject *, bool enable);
        Q_CORE_EXPORT void checkQObjectShared(const QObject *);
#endif
        inline void checkQObjectShared(...) { }
        inline void setQObjectShared(...) { }

        inline void operator delete(void *ptr) { ::operator delete(ptr); }
        inline void operator delete(void *, void *) { }
    };

    template <class T, typename Deleter>
    struct CustomDeleter
    {
        Deleter deleter;
        T *ptr;

        CustomDeleter(T *p, Deleter d) : deleter(d), ptr(p) {}
        void execute() { executeDeleter(ptr, deleter); }
    };
    // sizeof(CustomDeleter) = sizeof(Deleter) + sizeof(void*) + padding
    // for Deleter = stateless functor: 8 (32-bit) / 16 (64-bit) due to padding
    // for Deleter = function pointer:  8 (32-bit) / 16 (64-bit)
    // for Deleter = PMF: 12 (32-bit) / 24 (64-bit)  (GCC)

    // This specialization of CustomDeleter for a deleter of type NormalDeleter
    // is an optimization: instead of storing a pointer to a function that does
    // the deleting, we simply delete the pointer ourselves.
    template <class T>
    struct CustomDeleter<T, NormalDeleter>
    {
        T *ptr;

        CustomDeleter(T *p, NormalDeleter) : ptr(p) {}
        void execute() { delete ptr; }
    };
    // sizeof(CustomDeleter specialization) = sizeof(void*)

    // This class extends ExternalRefCountData and implements
    // the static function that deletes the object. The pointer and the
    // custom deleter are kept in the "extra" member so we can construct
    // and destruct it independently of the full structure.
    template <class T, typename Deleter>
    struct ExternalRefCountWithCustomDeleter: public ExternalRefCountData
    {
        typedef ExternalRefCountWithCustomDeleter Self;
        typedef ExternalRefCountData BaseClass;
        CustomDeleter<T, Deleter> extra;

        static inline void deleter(ExternalRefCountData *self)
        {
            Self *realself = static_cast<Self *>(self);
            realself->extra.execute();

            // delete the deleter too
            realself->extra.~CustomDeleter<T, Deleter>();
        }
        static void safetyCheckDeleter(ExternalRefCountData *self)
        {
            internalSafetyCheckRemove(self);
            deleter(self);
        }

        static inline Self *create(T *ptr, Deleter userDeleter, DestroyerFn actualDeleter)
        {
            Self *d = static_cast<Self *>(::operator new(sizeof(Self)));

            // initialize the two sub-objects
            new (&d->extra) CustomDeleter<T, Deleter>(ptr, userDeleter);
            new (d) BaseClass(actualDeleter); // can't throw

            return d;
        }
    private:
        // prevent construction
        ExternalRefCountWithCustomDeleter() Q_DECL_EQ_DELETE;
        ~ExternalRefCountWithCustomDeleter() Q_DECL_EQ_DELETE;
        Q_DISABLE_COPY(ExternalRefCountWithCustomDeleter)
    };

    // This class extends ExternalRefCountData and adds a "T"
    // member. That way, when the create() function is called, we allocate
    // memory for both QSharedPointer's d-pointer and the actual object being
    // tracked.
    template <class T>
    struct ExternalRefCountWithContiguousData: public ExternalRefCountData
    {
        typedef ExternalRefCountData Parent;
        typedef typename std::remove_cv<T>::type NoCVType;
        NoCVType data;

        static void deleter(ExternalRefCountData *self)
        {
            ExternalRefCountWithContiguousData *that =
                    static_cast<ExternalRefCountWithContiguousData *>(self);
            that->data.~T();
            Q_UNUSED(that); // MSVC warns if T has a trivial destructor
        }
        static void safetyCheckDeleter(ExternalRefCountData *self)
        {
            internalSafetyCheckRemove(self);
            deleter(self);
        }
        static void noDeleter(ExternalRefCountData *) { }

        static inline ExternalRefCountData *create(NoCVType **ptr, DestroyerFn destroy)
        {
            ExternalRefCountWithContiguousData *d =
                static_cast<ExternalRefCountWithContiguousData *>(::operator new(sizeof(ExternalRefCountWithContiguousData)));

            // initialize the d-pointer sub-object
            // leave d->data uninitialized
            new (d) Parent(destroy); // can't throw

            *ptr = &d->data;
            return d;
        }

    private:
        // prevent construction
        ExternalRefCountWithContiguousData() Q_DECL_EQ_DELETE;
        ~ExternalRefCountWithContiguousData() Q_DECL_EQ_DELETE;
        Q_DISABLE_COPY(ExternalRefCountWithContiguousData)
    };

#ifndef QT_NO_QOBJECT
    Q_CORE_EXPORT QWeakPointer<QObject> weakPointerFromVariant_internal(const QVariant &variant);
    Q_CORE_EXPORT QSharedPointer<QObject> sharedPointerFromVariant_internal(const QVariant &variant);
#endif
} // namespace QtSharedPointer




// 实际的 sharedpointer 的定义.
template <class T> class QSharedPointer
{
    typedef T *QSharedPointer:: *RestrictedBool;
    typedef QtSharedPointer::ExternalRefCountData Data;

// 实际管理的资源
    Data *counter;
    T *value;

public:
    typedef T Type;
    typedef T element_type;
    typedef T value_type;

    typedef value_type *pointer;
    typedef const value_type *const_pointer;
    typedef value_type &reference;
    typedef const value_type &const_reference;
    typedef qptrdiff difference_type;

    // 获取原始值.
    T *data() const  { return value; }
    T *get() const { return value; }

    bool isNull() const  { return !data(); }
    operator RestrictedBool() const  { return isNull() ? nullptr : &QSharedPointer::value; }
    bool operator !() const  { return isNull(); }

    T &operator*() const { return *data(); } // 返回记录的指针
    T *operator->() const { return data(); } // 返回记录的指针

    ~QSharedPointer() { deref(); }

    template <class X>
    inline explicit QSharedPointer(X *ptr) : value(ptr) // noexcept
    { internalConstruct(ptr, QtSharedPointer::NormalDeleter()); }

    template <class X, typename Deleter>
    inline QSharedPointer(X *ptr, Deleter deleter) : value(ptr) // throws
    { internalConstruct(ptr, deleter); }

    template <typename Deleter>
    QSharedPointer(std::nullptr_t, Deleter) : value(nullptr), counter(nullptr) { }

    QSharedPointer(const QSharedPointer &other) Q_DECL_NOTHROW : value(other.value), counter(other.counter)
    { if (counter) ref(); }
    QSharedPointer &operator=(const QSharedPointer &other) Q_DECL_NOTHROW
    {
        QSharedPointer copy(other);
        swap(copy);
        return *this;
    }
#ifdef Q_COMPILER_RVALUE_REFS
    QSharedPointer(QSharedPointer &&other) Q_DECL_NOTHROW
        : value(other.value), d(other.d)
    {
        other.d = nullptr;
        other.value = nullptr;
    }
    QSharedPointer &operator=(QSharedPointer &&other) Q_DECL_NOTHROW
    {
        QSharedPointer moved(std::move(other));
        swap(moved);
        return *this;
    }

    template <class X>
    QSharedPointer(QSharedPointer<X> &&other) Q_DECL_NOTHROW
        : value(other.value), d(other.d)
    {
        other.d = nullptr;
        other.value = nullptr;
    }

    template <class X>
    QSharedPointer &operator=(QSharedPointer<X> &&other) Q_DECL_NOTHROW
    {
        QSharedPointer moved(std::move(other));
        swap(moved);
        return *this;
    }

#endif

    template <class X>
    QSharedPointer(const QSharedPointer<X> &other) Q_DECL_NOTHROW : value(other.value), counter(other.counter)
    { if (counter) ref(); }

    template <class X>
    inline QSharedPointer &operator=(const QSharedPointer<X> &other)
    {
        QSharedPointer copy(other);
        swap(copy);
        return *this;
    }

    template <class X>
    inline QSharedPointer(const QWeakPointer<X> &other) : value(nullptr), counter(nullptr)
    { *this = other; }

    template <class X>
    inline QSharedPointer<T> &operator=(const QWeakPointer<X> &other)
    { internalSet(other.counter, other.value); return *this; }

    inline void swap(QSharedPointer &other)
    { this->internalSwap(other); }

    inline void reset() { clear(); }
    inline void reset(T *t)
    { QSharedPointer copy(t); swap(copy); }
    template <typename Deleter>
    inline void reset(T *t, Deleter deleter)
    { QSharedPointer copy(t, deleter); swap(copy); }

    template <class X>
    QSharedPointer<X> staticCast() const
    {
        return qSharedPointerCast<X, T>(*this);
    }

    template <class X>
    QSharedPointer<X> dynamicCast() const
    {
        return qSharedPointerDynamicCast<X, T>(*this);
    }

    template <class X>
    QSharedPointer<X> constCast() const
    {
        return qSharedPointerConstCast<X, T>(*this);
    }

#ifndef QT_NO_QOBJECT
    template <class X>
    QSharedPointer<X> objectCast() const
    {
        return qSharedPointerObjectCast<X, T>(*this);
    }
#endif

    inline void clear() { QSharedPointer copy; swap(copy); }

    QWeakPointer<T> toWeakRef() const;

    template <typename... Args>
    static QSharedPointer create(Args && ...arguments)
    {
        typedef QtSharedPointer::ExternalRefCountWithContiguousData<T> Private;
        typename Private::DestroyerFn destroy = &Private::deleter;
        typename Private::DestroyerFn noDestroy = &Private::noDeleter;
        QSharedPointer result(Qt::Uninitialized);
        typename std::remove_cv<T>::type *ptr;
        result.counter = Private::create(&ptr, noDestroy);

        // now initialize the data
        new (ptr) T(std::forward<Args>(arguments)...);
        result.value = ptr;
        result.counter->destroyer = destroy;
        result.counter->setQObjectShared(result.value, true);
# ifdef QT_SHAREDPOINTER_TRACK_POINTERS
        internalSafetyCheckAdd(result.d, result.value);
# endif
        result.enableSharedFromThis(result.data());
        return result;
    }

private:
    explicit QSharedPointer(Qt::Initialization) {}

    void deref() Q_DECL_NOTHROW
    { deref(counter); }

    // 强指针下的 deref 处理逻辑.
    static void deref(Data *dd)
    {
        if (!dd) return;
        if (!dd->strongref.deref()) { // 如果, 强引用计数为 0 了, 应该摧毁计数器管理的资源
            dd->destroy();
        }
        if (!dd->weakref.deref()) // 如果, 弱引用计数为 0 了, 应该摧毁计数器. 这里和 Std 的有点差别, 为什么还要进行弱引用计数的管理.
            delete dd;
    }

    template <class X>
    inline void enableSharedFromThis(const QEnableSharedFromThis<X> *ptr)
    {
        ptr->initializeFromSharedPointer(constCast<typename std::remove_cv<T>::type>());
    }

    inline void enableSharedFromThis(...) {}

    // 强指针的创建操作.
    template <typename X, typename Deleter>
    inline void internalConstruct(X *ptr, Deleter deleter)
    {
        if (!ptr) {
            counter = nullptr;
            return;
        }

        typedef QtSharedPointer::ExternalRefCountWithCustomDeleter<X, Deleter> Private;
        typename Private::DestroyerFn actualDeleter = &Private::deleter;
        counter = Private::create(ptr, deleter, actualDeleter);
        counter->setQObjectShared(ptr, true);
        enableSharedFromThis(ptr);
    }

    void internalSwap(QSharedPointer &other) Q_DECL_NOTHROW
    {
        qSwap(counter, other.counter);
        qSwap(this->value, other.value);
    }

#if defined(Q_NO_TEMPLATE_FRIENDS)
public:
#else
    template <class X> friend class QSharedPointer;
    template <class X> friend class QWeakPointer;
    template <class X, class Y> friend QSharedPointer<X> QtSharedPointer::copyAndSetPointer(X * ptr, const QSharedPointer<Y> &src);
#endif
    void ref() const Q_DECL_NOTHROW { counter->weakref.ref(); counter->strongref.ref(); }

    inline void internalSet(Data *o, T *actual)
    {
        if (o) {
            // increase the strongref, but never up from zero
            // or less (-1 is used by QWeakPointer on untracked QObject)
            int tmp = o->strongref.load();
            while (tmp > 0) {
                // try to increment from "tmp" to "tmp + 1"
                if (o->strongref.testAndSetRelaxed(tmp, tmp + 1))
                    break;   // succeeded
                tmp = o->strongref.load();  // failed, try again
            }

            if (tmp > 0) {
                o->weakref.ref();
            } else {
                o->checkQObjectShared(actual);
                o = nullptr;
            }
        }

        qSwap(counter, o);
        qSwap(this->value, actual);
        if (!counter || counter->strongref.load() == 0)
            this->value = nullptr;

        // dereference saved data
        deref(o);
    }

    Type *value; // 真正的数据
    Data *counter; // 除了数据部分, 还要有一个用于计数的部分.
};

template <class T>
class QWeakPointer
{
    typedef T *QWeakPointer:: *RestrictedBool;
    typedef QtSharedPointer::ExternalRefCountData Data;

public:
    typedef T element_type;
    typedef T value_type;
    typedef value_type *pointer;
    typedef const value_type *const_pointer;
    typedef value_type &reference;
    typedef const value_type &const_reference;
    typedef qptrdiff difference_type;

    // 如果, 强引用计数为 0 了, 代表为空了.
    bool isNull() const Q_DECL_NOTHROW { return counter == nullptr || counter->strongref.load() == 0 || value == nullptr; }
    operator RestrictedBool() const Q_DECL_NOTHROW { return isNull() ? nullptr : &QWeakPointer::value; }
    bool operator !() const Q_DECL_NOTHROW { return isNull(); }
    T *data() const Q_DECL_NOTHROW { return counter == nullptr || counter->strongref.load() == 0 ? nullptr : value; }

    inline QWeakPointer() Q_DECL_NOTHROW : counter(nullptr), value(nullptr) { }
    inline ~QWeakPointer() { if (counter && !counter->weakref.deref()) delete counter; } // 如果, 弱引用计数为 0 了, 摧毁计数器.

    QWeakPointer(const QWeakPointer &other) Q_DECL_NOTHROW : counter(other.counter), value(other.value)
    { if (counter) counter->weakref.ref(); }

    QWeakPointer(QWeakPointer &&other) Q_DECL_NOTHROW
        : counter(other.counter), value(other.value)
    {
        other.counter = nullptr;
        other.value = nullptr;
    }
    QWeakPointer &operator=(QWeakPointer &&other) Q_DECL_NOTHROW
    { QWeakPointer moved(std::move(other)); swap(moved); return *this; }
#endif
    QWeakPointer &operator=(const QWeakPointer &other) Q_DECL_NOTHROW
    {
        QWeakPointer copy(other);
        swap(copy);
        return *this;
    }

    void swap(QWeakPointer &other) Q_DECL_NOTHROW
    {
        qSwap(this->counter, other.counter);
        qSwap(this->value, other.value);
    }

    inline QWeakPointer(const QSharedPointer<T> &o) : counter(o.counter), value(o.data())
    { if (counter) counter->weakref.ref();}

    inline QWeakPointer &operator=(const QSharedPointer<T> &o)
    {
        internalSet(o.counter, o.value);
        return *this;
    }

    template <class X>
    inline QWeakPointer(const QWeakPointer<X> &o) : counter(nullptr), value(nullptr)
    { *this = o; }

    template <class X>
    inline QWeakPointer &operator=(const QWeakPointer<X> &o)
    {
        // conversion between X and T could require access to the virtual table
        // so force the operation to go through QSharedPointer
        *this = o.toStrongRef();
        return *this;
    }

    template <class X>
    bool operator==(const QWeakPointer<X> &o) const Q_DECL_NOTHROW
    { return counter == o.counter && value == static_cast<const T *>(o.value); }

    template <class X>
    bool operator!=(const QWeakPointer<X> &o) const Q_DECL_NOTHROW
    { return !(*this == o); }

    template <class X>
    inline QWeakPointer(const QSharedPointer<X> &o) : counter(nullptr), value(nullptr)
    { *this = o; }

    template <class X>
    inline QWeakPointer &operator=(const QSharedPointer<X> &o)
    {
        QSHAREDPOINTER_VERIFY_AUTO_CAST(T, X); // if you get an error in this line, the cast is invalid
        internalSet(o.counter, o.data());
        return *this;
    }

    template <class X>
    bool operator==(const QSharedPointer<X> &o) const Q_DECL_NOTHROW
    { return counter == o.counter; }

    template <class X>
    bool operator!=(const QSharedPointer<X> &o) const Q_DECL_NOTHROW
    { return !(*this == o); }

    inline void clear() { *this = QWeakPointer(); }

    inline QSharedPointer<T> toStrongRef() const { return QSharedPointer<T>(*this); }
    // std::weak_ptr compatibility:
    inline QSharedPointer<T> lock() const { return toStrongRef(); }

#if defined(QWEAKPOINTER_ENABLE_ARROW)
    inline T *operator->() const { return data(); }
#endif

private:

#if defined(Q_NO_TEMPLATE_FRIENDS)
public:
#else
    template <class X> friend class QSharedPointer;
    template <class X> friend class QPointer;
#endif

    template <class X>
    inline QWeakPointer &assign(X *ptr)
    { return *this = QWeakPointer<X>(ptr, true); }

    // 这个函数, 是不会暴露给外界使用的.
    template <class X>
    inline QWeakPointer(X *ptr, bool) : counter(ptr ? Data::getAndRef(ptr) : nullptr), value(ptr)
    { }

    inline void internalSet(Data *o, T *actual)
    {
        if (counter == o) return;
        if (o)
            o->weakref.ref();
        if (counter && !counter->weakref.deref())
            delete counter;
        counter = o;
        value = actual;
    }
};

template <class T>
class QEnableSharedFromThis
{
protected:
#ifdef Q_COMPILER_DEFAULT_MEMBERS
    QEnableSharedFromThis() = default;
#else
    Q_DECL_CONSTEXPR QEnableSharedFromThis() {}
#endif
    QEnableSharedFromThis(const QEnableSharedFromThis &) {}
    QEnableSharedFromThis &operator=(const QEnableSharedFromThis &) { return *this; }

public:
    inline QSharedPointer<T> sharedFromThis() { return QSharedPointer<T>(weakPointer); }
    inline QSharedPointer<const T> sharedFromThis() const { return QSharedPointer<const T>(weakPointer); }

#ifndef Q_NO_TEMPLATE_FRIENDS
private:
    template <class X> friend class QSharedPointer;
#else
public:
#endif
    template <class X>
    inline void initializeFromSharedPointer(const QSharedPointer<X> &ptr) const
    {
        weakPointer = ptr;
    }

    mutable QWeakPointer<T> weakPointer;
};

//
// operator== and operator!=
//
template <class T, class X>
bool operator==(const QSharedPointer<T> &ptr1, const QSharedPointer<X> &ptr2) Q_DECL_NOTHROW
{
    return ptr1.data() == ptr2.data();
}
template <class T, class X>
bool operator!=(const QSharedPointer<T> &ptr1, const QSharedPointer<X> &ptr2) Q_DECL_NOTHROW
{
    return ptr1.data() != ptr2.data();
}

template <class T, class X>
bool operator==(const QSharedPointer<T> &ptr1, const X *ptr2) Q_DECL_NOTHROW
{
    return ptr1.data() == ptr2;
}
template <class T, class X>
bool operator==(const T *ptr1, const QSharedPointer<X> &ptr2) Q_DECL_NOTHROW
{
    return ptr1 == ptr2.data();
}
template <class T, class X>
bool operator!=(const QSharedPointer<T> &ptr1, const X *ptr2) Q_DECL_NOTHROW
{
    return !(ptr1 == ptr2);
}
template <class T, class X>
bool operator!=(const T *ptr1, const QSharedPointer<X> &ptr2) Q_DECL_NOTHROW
{
    return !(ptr2 == ptr1);
}

template <class T, class X>
bool operator==(const QSharedPointer<T> &ptr1, const QWeakPointer<X> &ptr2) Q_DECL_NOTHROW
{
    return ptr2 == ptr1;
}
template <class T, class X>
bool operator!=(const QSharedPointer<T> &ptr1, const QWeakPointer<X> &ptr2) Q_DECL_NOTHROW
{
    return ptr2 != ptr1;
}

template<class T>
inline bool operator==(const QSharedPointer<T> &lhs, std::nullptr_t) Q_DECL_NOTHROW
{
    return lhs.isNull();
}

template<class T>
inline bool operator!=(const QSharedPointer<T> &lhs, std::nullptr_t) Q_DECL_NOTHROW
{
    return !lhs.isNull();
}

template<class T>
inline bool operator==(std::nullptr_t, const QSharedPointer<T> &rhs) Q_DECL_NOTHROW
{
    return rhs.isNull();
}

template<class T>
inline bool operator!=(std::nullptr_t, const QSharedPointer<T> &rhs) Q_DECL_NOTHROW
{
    return !rhs.isNull();
}

template<class T>
inline bool operator==(const QWeakPointer<T> &lhs, std::nullptr_t) Q_DECL_NOTHROW
{
    return lhs.isNull();
}

template<class T>
inline bool operator!=(const QWeakPointer<T> &lhs, std::nullptr_t) Q_DECL_NOTHROW
{
    return !lhs.isNull();
}

template<class T>
inline bool operator==(std::nullptr_t, const QWeakPointer<T> &rhs) Q_DECL_NOTHROW
{
    return rhs.isNull();
}

template<class T>
inline bool operator!=(std::nullptr_t, const QWeakPointer<T> &rhs) Q_DECL_NOTHROW
{
    return !rhs.isNull();
}

//
// operator-
//
template <class T, class X>
Q_INLINE_TEMPLATE typename QSharedPointer<T>::difference_type operator-(const QSharedPointer<T> &ptr1, const QSharedPointer<X> &ptr2)
{
    return ptr1.data() - ptr2.data();
}
template <class T, class X>
Q_INLINE_TEMPLATE typename QSharedPointer<T>::difference_type operator-(const QSharedPointer<T> &ptr1, X *ptr2)
{
    return ptr1.data() - ptr2;
}
template <class T, class X>
Q_INLINE_TEMPLATE typename QSharedPointer<X>::difference_type operator-(T *ptr1, const QSharedPointer<X> &ptr2)
{
    return ptr1 - ptr2.data();
}

//
// operator<
//
template <class T, class X>
Q_INLINE_TEMPLATE bool operator<(const QSharedPointer<T> &ptr1, const QSharedPointer<X> &ptr2)
{
    using CT = typename std::common_type<T *, X *>::type;
    return std::less<CT>()(ptr1.data(), ptr2.data());
}
template <class T, class X>
Q_INLINE_TEMPLATE bool operator<(const QSharedPointer<T> &ptr1, X *ptr2)
{
    using CT = typename std::common_type<T *, X *>::type;
    return std::less<CT>()(ptr1.data(), ptr2);
}
template <class T, class X>
Q_INLINE_TEMPLATE bool operator<(T *ptr1, const QSharedPointer<X> &ptr2)
{
    using CT = typename std::common_type<T *, X *>::type;
    return std::less<CT>()(ptr1, ptr2.data());
}

//
// qHash
//
template <class T>
Q_INLINE_TEMPLATE uint qHash(const QSharedPointer<T> &ptr, uint seed = 0)
{
    return QT_PREPEND_NAMESPACE(qHash)(ptr.data(), seed);
}


template <class T>
Q_INLINE_TEMPLATE QWeakPointer<T> QSharedPointer<T>::toWeakRef() const
{
    return QWeakPointer<T>(*this);
}

template <class T>
inline void qSwap(QSharedPointer<T> &p1, QSharedPointer<T> &p2)
{
    p1.swap(p2);
}

QT_END_NAMESPACE
namespace std {
    template <class T>
    inline void swap(QT_PREPEND_NAMESPACE(QSharedPointer)<T> &p1, QT_PREPEND_NAMESPACE(QSharedPointer)<T> &p2)
    { p1.swap(p2); }
}
QT_BEGIN_NAMESPACE

namespace QtSharedPointer {
// helper functions:
    template <class X, class T>
    Q_INLINE_TEMPLATE QSharedPointer<X> copyAndSetPointer(X *ptr, const QSharedPointer<T> &src)
    {
        QSharedPointer<X> result;
        result.internalSet(src.counter, ptr);
        return result;
    }
}

// cast operators
template <class X, class T>
Q_INLINE_TEMPLATE QSharedPointer<X> qSharedPointerCast(const QSharedPointer<T> &src)
{
    X *ptr = static_cast<X *>(src.data()); // if you get an error in this line, the cast is invalid
    return QtSharedPointer::copyAndSetPointer(ptr, src);
}
template <class X, class T>
Q_INLINE_TEMPLATE QSharedPointer<X> qSharedPointerCast(const QWeakPointer<T> &src)
{
    return qSharedPointerCast<X, T>(src.toStrongRef());
}

template <class X, class T>
Q_INLINE_TEMPLATE QSharedPointer<X> qSharedPointerDynamicCast(const QSharedPointer<T> &src)
{
    X *ptr = dynamic_cast<X *>(src.data()); // if you get an error in this line, the cast is invalid
    if (!ptr)
        return QSharedPointer<X>();
    return QtSharedPointer::copyAndSetPointer(ptr, src);
}
template <class X, class T>
Q_INLINE_TEMPLATE QSharedPointer<X> qSharedPointerDynamicCast(const QWeakPointer<T> &src)
{
    return qSharedPointerDynamicCast<X, T>(src.toStrongRef());
}

template <class X, class T>
Q_INLINE_TEMPLATE QSharedPointer<X> qSharedPointerConstCast(const QSharedPointer<T> &src)
{
    X *ptr = const_cast<X *>(src.data()); // if you get an error in this line, the cast is invalid
    return QtSharedPointer::copyAndSetPointer(ptr, src);
}
template <class X, class T>
Q_INLINE_TEMPLATE QSharedPointer<X> qSharedPointerConstCast(const QWeakPointer<T> &src)
{
    return qSharedPointerConstCast<X, T>(src.toStrongRef());
}

template <class X, class T>
Q_INLINE_TEMPLATE
QWeakPointer<X> qWeakPointerCast(const QSharedPointer<T> &src)
{
    return qSharedPointerCast<X, T>(src).toWeakRef();
}

#ifndef QT_NO_QOBJECT
template <class X, class T>
Q_INLINE_TEMPLATE QSharedPointer<X> qSharedPointerObjectCast(const QSharedPointer<T> &src)
{
    X *ptr = qobject_cast<X *>(src.data());
    return QtSharedPointer::copyAndSetPointer(ptr, src);
}
template <class X, class T>
Q_INLINE_TEMPLATE QSharedPointer<X> qSharedPointerObjectCast(const QWeakPointer<T> &src)
{
    return qSharedPointerObjectCast<X>(src.toStrongRef());
}

template <class X, class T>
inline QSharedPointer<typename QtSharedPointer::RemovePointer<X>::Type>
qobject_cast(const QSharedPointer<T> &src)
{
    return qSharedPointerObjectCast<typename QtSharedPointer::RemovePointer<X>::Type, T>(src);
}
template <class X, class T>
inline QSharedPointer<typename QtSharedPointer::RemovePointer<X>::Type>
qobject_cast(const QWeakPointer<T> &src)
{
    return qSharedPointerObjectCast<typename QtSharedPointer::RemovePointer<X>::Type, T>(src);
}

template<typename T>
QWeakPointer<typename std::enable_if<QtPrivate::IsPointerToTypeDerivedFromQObject<T*>::Value, T>::type>
qWeakPointerFromVariant(const QVariant &variant)
{
    return QWeakPointer<T>(qobject_cast<T*>(QtSharedPointer::weakPointerFromVariant_internal(variant).data()));
}
template<typename T>
QSharedPointer<typename std::enable_if<QtPrivate::IsPointerToTypeDerivedFromQObject<T*>::Value, T>::type>
qSharedPointerFromVariant(const QVariant &variant)
{
    return qSharedPointerObjectCast<T>(QtSharedPointer::sharedPointerFromVariant_internal(variant));
}

#endif

template<typename T> Q_DECLARE_TYPEINFO_BODY(QWeakPointer<T>, Q_MOVABLE_TYPE);
template<typename T> Q_DECLARE_TYPEINFO_BODY(QSharedPointer<T>, Q_MOVABLE_TYPE);


QT_END_NAMESPACE

#endif
