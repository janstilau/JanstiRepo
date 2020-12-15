#ifndef QARRAYDATA_H
#define QARRAYDATA_H

#include <QtCore/qrefcount.h>
#include <string.h>

QT_BEGIN_NAMESPACE

struct Q_CORE_EXPORT QArrayData
{
    QtPrivate::RefCount ref; // 应用技术器.
    int size; // 这个代表的是, 已经占有的空间的大小.
    uint alloc : 31; // 这个代表的是, 容量的大小, 其实就是 capacity
    uint capacityReserved : 1;

    qptrdiff offset; // in bytes from beginning of header

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

    Q_REQUIRED_RESULT static QArrayData *allocate(size_t objectSize, size_t alignment,
            size_t capacity, AllocationOptions options = Default) Q_DECL_NOTHROW;
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
#ifdef QT_STRICT_ITERATORS
    class iterator {
    public:
        T *i;
        typedef std::random_access_iterator_tag  iterator_category;
        typedef int difference_type;
        typedef T value_type;
        typedef T *pointer;
        typedef T &reference;

        inline iterator() : i(nullptr) {}
        inline iterator(T *n) : i(n) {}
        inline iterator(const iterator &o): i(o.i){} // #### Qt 6: remove, the implicit version is fine
        inline T &operator*() const { return *i; }
        inline T *operator->() const { return i; }
        inline T &operator[](int j) const { return *(i + j); }
        inline bool operator==(const iterator &o) const { return i == o.i; }
        inline bool operator!=(const iterator &o) const { return i != o.i; }
        inline bool operator<(const iterator& other) const { return i < other.i; }
        inline bool operator<=(const iterator& other) const { return i <= other.i; }
        inline bool operator>(const iterator& other) const { return i > other.i; }
        inline bool operator>=(const iterator& other) const { return i >= other.i; }
        inline iterator &operator++() { ++i; return *this; }
        inline iterator operator++(int) { T *n = i; ++i; return n; }
        inline iterator &operator--() { i--; return *this; }
        inline iterator operator--(int) { T *n = i; i--; return n; }
        inline iterator &operator+=(int j) { i+=j; return *this; }
        inline iterator &operator-=(int j) { i-=j; return *this; }
        inline iterator operator+(int j) const { return iterator(i+j); }
        inline iterator operator-(int j) const { return iterator(i-j); }
        friend inline iterator operator+(int j, iterator k) { return k + j; }
        inline int operator-(iterator j) const { return i - j.i; }
        inline operator T*() const { return i; }
    };
    friend class iterator;

    class const_iterator {
    public:
        const T *i;
        typedef std::random_access_iterator_tag  iterator_category;
        typedef int difference_type;
        typedef T value_type;
        typedef const T *pointer;
        typedef const T &reference;

        inline const_iterator() : i(nullptr) {}
        inline const_iterator(const T *n) : i(n) {}
        inline const_iterator(const const_iterator &o): i(o.i) {} // #### Qt 6: remove, the default version is fine
        inline explicit const_iterator(const iterator &o): i(o.i) {}
        inline const T &operator*() const { return *i; }
        inline const T *operator->() const { return i; }
        inline const T &operator[](int j) const { return *(i + j); }
        inline bool operator==(const const_iterator &o) const { return i == o.i; }
        inline bool operator!=(const const_iterator &o) const { return i != o.i; }
        inline bool operator<(const const_iterator& other) const { return i < other.i; }
        inline bool operator<=(const const_iterator& other) const { return i <= other.i; }
        inline bool operator>(const const_iterator& other) const { return i > other.i; }
        inline bool operator>=(const const_iterator& other) const { return i >= other.i; }
        inline const_iterator &operator++() { ++i; return *this; }
        inline const_iterator operator++(int) { const T *n = i; ++i; return n; }
        inline const_iterator &operator--() { i--; return *this; }
        inline const_iterator operator--(int) { const T *n = i; i--; return n; }
        inline const_iterator &operator+=(int j) { i+=j; return *this; }
        inline const_iterator &operator-=(int j) { i-=j; return *this; }
        inline const_iterator operator+(int j) const { return const_iterator(i+j); }
        inline const_iterator operator-(int j) const { return const_iterator(i-j); }
        friend inline const_iterator operator+(int j, const_iterator k) { return k + j; }
        inline int operator-(const_iterator j) const { return i - j.i; }
        inline operator const T*() const { return i; }
    };
    friend class const_iterator;
#else
    typedef T* iterator;
    typedef const T* const_iterator;
#endif

    T *data() { return static_cast<T *>(QArrayData::data()); }
    const T *data() const { return static_cast<const T *>(QArrayData::data()); }

    iterator begin(iterator = iterator()) { return data(); }
    iterator end(iterator = iterator()) { return data() + size; }
    const_iterator begin(const_iterator = const_iterator()) const { return data(); }
    const_iterator end(const_iterator = const_iterator()) const { return data() + size; }
    const_iterator constBegin(const_iterator = const_iterator()) const { return data(); }
    const_iterator constEnd(const_iterator = const_iterator()) const { return data() + size; }

    class AlignmentDummy { QArrayData header; T data; };

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
