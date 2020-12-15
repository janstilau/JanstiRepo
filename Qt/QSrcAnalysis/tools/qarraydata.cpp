
#include <QtCore/qarraydata.h>
#include <QtCore/private/qnumeric_p.h>
#include <QtCore/private/qtools_p.h>

#include <stdlib.h>

QT_BEGIN_NAMESPACE

const QArrayData QArrayData::shared_null[2] = {
    { Q_REFCOUNT_INITIALIZE_STATIC, 0, 0, 0, sizeof(QArrayData) }, // shared null
    { { Q_BASIC_ATOMIC_INITIALIZER(0) }, 0, 0, 0, 0 } /* zero initialized terminator */
};

static const QArrayData qt_array[3] = {
    { Q_REFCOUNT_INITIALIZE_STATIC, 0, 0, 0, sizeof(QArrayData) }, // shared empty
    { { Q_BASIC_ATOMIC_INITIALIZER(0) }, 0, 0, 0, sizeof(QArrayData) }, // unsharable empty
    { { Q_BASIC_ATOMIC_INITIALIZER(0) }, 0, 0, 0, 0 } /* zero initialized terminator */
};

static const QArrayData &qt_array_empty = qt_array[0];
static const QArrayData &qt_array_unsharable_empty = qt_array[1];

static inline size_t calculateBlockSize(size_t &capacity, size_t objectSize, size_t headerSize,
                                        uint options)
{
    // Calculate the byte size
    // allocSize = objectSize * capacity + headerSize, but checked for overflow
    // plus padded to grow in size
    if (options & QArrayData::Grow) {
        auto r = qCalculateGrowingBlockSize(capacity, objectSize, headerSize);
        capacity = r.elementCount;
        return r.size;
    } else {
        return qCalculateBlockSize(capacity, objectSize, headerSize);
    }
}

static QArrayData *reallocateData(QArrayData *header, size_t allocSize, uint options)
{
    header = static_cast<QArrayData *>(::realloc(header, allocSize));
    if (header)
        header->capacityReserved = bool(options & QArrayData::CapacityReserved);
    return header;
}

QArrayData *QArrayData::allocate(size_t objectSize, size_t alignment,
        size_t capacity, AllocationOptions options) Q_DECL_NOTHROW
{
    // Alignment is a power of two
    Q_ASSERT(alignment >= Q_ALIGNOF(QArrayData)
            && !(alignment & (alignment - 1)));

    // Don't allocate empty headers
    if (!(options & RawData) && !capacity) {
#if !defined(QT_NO_UNSHARABLE_CONTAINERS)
        if (options & Unsharable)
            return const_cast<QArrayData *>(&qt_array_unsharable_empty);
#endif
        return const_cast<QArrayData *>(&qt_array_empty);
    }

    size_t headerSize = sizeof(QArrayData);

    // Allocate extra (alignment - Q_ALIGNOF(QArrayData)) padding bytes so we
    // can properly align the data array. This assumes malloc is able to
    // provide appropriate alignment for the header -- as it should!
    // Padding is skipped when allocating a header for RawData.
    if (!(options & RawData))
        headerSize += (alignment - Q_ALIGNOF(QArrayData));

    if (headerSize > size_t(MaxAllocSize))
        return 0;

    // 最终, 还是调用了 malloc
    size_t allocSize = calculateBlockSize(capacity, objectSize, headerSize, options);
    QArrayData *header = static_cast<QArrayData *>(::malloc(allocSize));
    if (header) {
        quintptr data = (quintptr(header) + sizeof(QArrayData) + alignment - 1)
                & ~(alignment - 1);

#if !defined(QT_NO_UNSHARABLE_CONTAINERS)
        header->ref.atomic.store(bool(!(options & Unsharable)));
#else
        header->ref.atomic.store(1);
#endif
        header->size = 0;
        header->alloc = capacity;
        header->capacityReserved = bool(options & CapacityReserved);
        header->offset = data - quintptr(header);
    }

    return header;
}

QArrayData *QArrayData::reallocateUnaligned(QArrayData *data, size_t objectSize, size_t capacity,
                                            AllocationOptions options) Q_DECL_NOTHROW
{
    Q_ASSERT(data);
    Q_ASSERT(data->isMutable());
    Q_ASSERT(!data->ref.isShared());

    size_t headerSize = sizeof(QArrayData);
    size_t allocSize = calculateBlockSize(capacity, objectSize, headerSize, options);
    QArrayData *header = static_cast<QArrayData *>(reallocateData(data, allocSize, options));
    if (header)
        header->alloc = capacity;
    return header;
}

void QArrayData::deallocate(QArrayData *data, size_t objectSize,
        size_t alignment) Q_DECL_NOTHROW
{
    // Alignment is a power of two
    Q_ASSERT(alignment >= Q_ALIGNOF(QArrayData)
            && !(alignment & (alignment - 1)));
    Q_UNUSED(objectSize) Q_UNUSED(alignment)

#if !defined(QT_NO_UNSHARABLE_CONTAINERS)
    if (data == &qt_array_unsharable_empty)
        return;
#endif

    Q_ASSERT_X(data == 0 || !data->ref.isStatic(), "QArrayData::deallocate",
               "Static data can not be deleted");
    ::free(data);
}

namespace QtPrivate {
/*!
  \internal
*/
QContainerImplHelper::CutResult QContainerImplHelper::mid(int originalLength, int *_position, int *_length)
{
    int &position = *_position;
    int &length = *_length;
    if (position > originalLength)
        return Null;

    if (position < 0) {
        if (length < 0 || length + position >= originalLength)
            return Full;
        if (length + position <= 0)
            return Null;
        length += position;
        position = 0;
    } else if (uint(length) > uint(originalLength - position)) {
        length = originalLength - position;
    }

    if (position == 0 && length == originalLength)
        return Full;

    return length > 0 ? Subset : Empty;
}
}

QT_END_NAMESPACE
