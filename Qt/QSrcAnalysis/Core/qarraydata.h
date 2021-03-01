#ifndef QARRAYDATA_H
#define QARRAYDATA_H

#include <QtCore/qrefcount.h>
#include <string.h>

QT_BEGIN_NAMESPACE

// 这个类是 QVector 里面的底层存储.
// 在 QVector 里面, 使用的是 QArrayData*, 也就是引用值.
// 这个类设计出来, 就应该使用 引用的语义.
// Qt 的容器里面, 没有使用 alloctor 的设计, 这个类作为容器的底层存储, 没有相关的内存的管理工作.
struct Q_CORE_EXPORT QArrayData
{
    QtPrivate::RefCount ref; //
    int size; // 这个代表的是, 已经占有的空间的大小.
    uint alloc : 31; // 这个代表的是, 容量的大小, 其实就是 capacity
    uint capacityReserved : 1;

    // offset 这个值, 只会在 QArrayData::allocate 中赋值.
    // 他代表着, 从 offset 位置开始, 就是真正的数据部分了.
    // 而之前的, 是上面的元数据部分. 这里, RefCount 和实际的数据部分放到了同样的一个对象里面.
    // RefCount 这个其实要比 share_ptr 里面的 refCount 使用的广, 因为大部分情况下, 没有弱引用的使用机会.
    qptrdiff offset;

    // 简单的转义, reinterpret_cast 使用在这种, 带有明显设计意图的方法里面, 是非常安全的.
    // 元信息加数据的这种设计, 是 QArrayData 的设计, 应该在返回 data 的时候, 将 offset 记录的, header 的部分跨过去.
    void *data()
    {
        return reinterpret_cast<char *>(this) + offset;
    }
    const void *data() const
    {
        return reinterpret_cast<const char *>(this) + offset;
    }

    // This refers to array data mutability, not "header data" represented by
    // data members in QArrayData. Shared data (array and header) must still
    // follow COW principles.
    bool isMutable() const
    {
        return alloc != 0;
    }

    enum AllocationOption {
        CapacityReserved    = 0x1,
#if !defined(QT_NO_UNSHARABLE_CONTAINERS)
        Unsharable          = 0x2,
#endif
        RawData             = 0x4,
        Grow                = 0x8,

        Default = 0
    };

    Q_DECLARE_FLAGS(AllocationOptions, AllocationOption)

    size_t detachCapacity(size_t newSize) const
    {
        if (capacityReserved && newSize < alloc)
            return alloc;
        return newSize;
    }

    // detachFlags, cloneFlags 完全一样, 为什么没有复用.
    AllocationOptions detachFlags() const
    {
        AllocationOptions result;
        if (capacityReserved)
            result |= CapacityReserved;
        return result;
    }

    AllocationOptions cloneFlags() const
    {
        AllocationOptions result;
        if (capacityReserved)
            result |= CapacityReserved;
        return result;
    }

    // #  define Q_REQUIRED_RESULT __attribute__ ((__warn_unused_result__))
    // 如果使用放, 没有接收这个值, 那么会有警告.
    Q_REQUIRED_RESULT static QArrayData *allocate(size_t objectSize, size_t alignment,
            size_t capacity, AllocationOptions options = Default) Q_DECL_NOTHROW;

    /*
     *  std::realloc
     *  Reallocates the given area of memory. It must be previously allocated by std::malloc(), std::calloc() or std::realloc() and not yet freed with std::free(), otherwise, the results are undefined.
     * 所以, 实际上最原始的 realloc 的作用, 就是开辟新的空间, 并且复制原来的数据, 到新的空间上.
     *
     * std::calloc
     * Allocates memory for an array of num objects of size size and initializes it to all bits zero.
     * 这个相比 malloc, 增加了一个 memset 0 的操作.
     *
     * reallocateUnaligned 的内部, 是使用了 std::realloc 作为底层的实现.
     */
    Q_REQUIRED_RESULT static QArrayData *reallocateUnaligned(QArrayData *data, size_t objectSize,
            size_t newCapacity, AllocationOptions newOptions = Default) Q_DECL_NOTHROW;

    static void deallocate(QArrayData *data, size_t objectSize,
            size_t alignment) Q_DECL_NOTHROW;

    static const QArrayData shared_null[2];
    static QArrayData *sharedNull() Q_DECL_NOTHROW { return const_cast<QArrayData*>(shared_null); }
};

Q_DECLARE_OPERATORS_FOR_FLAGS(QArrayData::AllocationOptions)

// QTypedArrayData 就是在 arrayData 的基础上, 增加了 type 的限制. 这样, ++, -- 都会跨越 sizeof(T)大小的字节数.
template <class T>
struct QTypedArrayData
    : QArrayData
{
    typedef T* iterator; // iterator 就是简答的 T 的指针而已.
    typedef const T* const_iterator;

    // 实际上, Typed 并没有做
    T *data() { return static_cast<T *>(QArrayData::data()); }
    const T *data() const { return static_cast<const T *>(QArrayData::data()); }

    iterator begin(iterator = iterator()) { return data(); }
    iterator end(iterator = iterator()) { return data() + size; }
    const_iterator begin(const_iterator = const_iterator()) const { return data(); }
    const_iterator end(const_iterator = const_iterator()) const { return data() + size; }
    const_iterator constBegin(const_iterator = const_iterator()) const { return data(); }
    const_iterator constEnd(const_iterator = const_iterator()) const { return data() + size; }

    class AlignmentDummy {
        QArrayData header;
        T data;
    };

    // Typed, 就代表和相关类型的数据, 可以通过 sizeof 这些操作符使用.
    // 这里再次表明了, 泛型, 不一定是使用类型创建对象, 也可能是使用类型的信息, 无论是静态函数, 还是类型的元信息.
    Q_REQUIRED_RESULT static QTypedArrayData *allocate(size_t capacity,
            AllocationOptions options = Default)
    {
        Q_STATIC_ASSERT(sizeof(QTypedArrayData) == sizeof(QArrayData));
        return static_cast<QTypedArrayData *>(QArrayData::allocate(sizeof(T),
                    Q_ALIGNOF(AlignmentDummy), capacity, options));
    }

    static QTypedArrayData *reallocateUnaligned(QTypedArrayData *data, size_t capacity,
            AllocationOptions options = Default)
    {
        Q_STATIC_ASSERT(sizeof(QTypedArrayData) == sizeof(QArrayData));
        return static_cast<QTypedArrayData *>(QArrayData::reallocateUnaligned(data, sizeof(T),
                    capacity, options));
    }

    static void deallocate(QArrayData *data)
    {
        Q_STATIC_ASSERT(sizeof(QTypedArrayData) == sizeof(QArrayData));
        QArrayData::deallocate(data, sizeof(T), Q_ALIGNOF(AlignmentDummy));
    }

    static QTypedArrayData *fromRawData(const T *data, size_t n,
            AllocationOptions options = Default)
    {
        Q_STATIC_ASSERT(sizeof(QTypedArrayData) == sizeof(QArrayData));
        QTypedArrayData *result = allocate(0, options | RawData);
        if (result) {
            Q_ASSERT(!result->ref.isShared()); // No shared empty, please!

            result->offset = reinterpret_cast<const char *>(data)
                - reinterpret_cast<const char *>(result);
            result->size = int(n);
        }
        return result;
    }

    static QTypedArrayData *sharedNull() Q_DECL_NOTHROW
    {
        Q_STATIC_ASSERT(sizeof(QTypedArrayData) == sizeof(QArrayData));
        return static_cast<QTypedArrayData *>(QArrayData::sharedNull());
    }

    static QTypedArrayData *sharedEmpty()
    {
        Q_STATIC_ASSERT(sizeof(QTypedArrayData) == sizeof(QArrayData));
        return allocate(/* capacity */ 0);
    }

#if !defined(QT_NO_UNSHARABLE_CONTAINERS)
    static QTypedArrayData *unsharableEmpty()
    {
        Q_STATIC_ASSERT(sizeof(QTypedArrayData) == sizeof(QArrayData));
        return allocate(/* capacity */ 0, Unsharable);
    }
#endif
};

template <class T, size_t N>
struct QStaticArrayData
{
    QArrayData header;
    T data[N];
};

// Support for returning QArrayDataPointer<T> from functions
template <class T>
struct QArrayDataPointerRef
{
    QTypedArrayData<T> *ptr;
};

#define Q_STATIC_ARRAY_DATA_HEADER_INITIALIZER_WITH_OFFSET(size, offset) \
    { Q_REFCOUNT_INITIALIZE_STATIC, size, 0, 0, offset } \
    /**/

#define Q_STATIC_ARRAY_DATA_HEADER_INITIALIZER(type, size) \
    Q_STATIC_ARRAY_DATA_HEADER_INITIALIZER_WITH_OFFSET(size,\
        ((sizeof(QArrayData) + (Q_ALIGNOF(type) - 1)) & ~(Q_ALIGNOF(type) - 1) )) \
    /**/

////////////////////////////////////////////////////////////////////////////////
//  Q_ARRAY_LITERAL

// The idea here is to place a (read-only) copy of header and array data in an
// mmappable portion of the executable (typically, .rodata section). This is
// accomplished by hiding a static const instance of QStaticArrayData, which is
// POD.

#if defined(Q_COMPILER_VARIADIC_MACROS)
#if defined(Q_COMPILER_LAMBDA)
// Hide array inside a lambda
#define Q_ARRAY_LITERAL(Type, ...)                                              \
    ([]() -> QArrayDataPointerRef<Type> {                                       \
            /* MSVC 2010 Doesn't support static variables in a lambda, but */   \
            /* happily accepts them in a static function of a lambda-local */   \
            /* struct :-) */                                                    \
            struct StaticWrapper {                                              \
                static QArrayDataPointerRef<Type> get()                         \
                {                                                               \
                    Q_ARRAY_LITERAL_IMPL(Type, __VA_ARGS__)                     \
                    return ref;                                                 \
                }                                                               \
            };                                                                  \
            return StaticWrapper::get();                                        \
        }())                                                                    \
    /**/
#endif
#endif // defined(Q_COMPILER_VARIADIC_MACROS)

#if defined(Q_ARRAY_LITERAL)
#define Q_ARRAY_LITERAL_IMPL(Type, ...)                                         \
    union { Type type_must_be_POD; } dummy; Q_UNUSED(dummy)                     \
                                                                                \
    /* Portable compile-time array size computation */                          \
    Type data[] = { __VA_ARGS__ }; Q_UNUSED(data)                               \
    enum { Size = sizeof(data) / sizeof(data[0]) };                             \
                                                                                \
    static const QStaticArrayData<Type, Size> literal = {                       \
        Q_STATIC_ARRAY_DATA_HEADER_INITIALIZER(Type, Size), { __VA_ARGS__ } };  \
                                                                                \
    QArrayDataPointerRef<Type> ref =                                            \
        { static_cast<QTypedArrayData<Type> *>(                                 \
            const_cast<QArrayData *>(&literal.header)) };                       \
    /**/
#else
// As a fallback, memory is allocated and data copied to the heap.

// The fallback macro does NOT use variadic macros and does NOT support
// variable number of arguments. It is suitable for char arrays.

namespace QtPrivate {
    template <class T, size_t N>
    inline QArrayDataPointerRef<T> qMakeArrayLiteral(const T (&array)[N])
    {
        union { T type_must_be_POD; } dummy; Q_UNUSED(dummy)

        QArrayDataPointerRef<T> result = { QTypedArrayData<T>::allocate(N) };
        Q_CHECK_PTR(result.ptr);

        ::memcpy(result.ptr->data(), array, N * sizeof(T));
        result.ptr->size = N;

        return result;
    }
}

#define Q_ARRAY_LITERAL(Type, Array) \
    QT_PREPEND_NAMESPACE(QtPrivate::qMakeArrayLiteral)<Type>( Array )
#endif // !defined(Q_ARRAY_LITERAL)

namespace QtPrivate {
struct Q_CORE_EXPORT QContainerImplHelper
{
    enum CutResult { Null, Empty, Full, Subset };
    static CutResult mid(int originalLength, int *position, int *length);
};
}

QT_END_NAMESPACE

#endif // include guard
