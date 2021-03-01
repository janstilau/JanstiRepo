
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
    // 所以, 实际上, 就是使用了 std 的 realloc 的功能, realloc 里面, 本身就有 copy 的功能.
    // 作为一个 C 的 API, 一定是最简单的 bit copy.
    header = static_cast<QArrayData *>(::realloc(header, allocSize));
    if (header)
        header->capacityReserved = bool(options & QArrayData::CapacityReserved);
    return header;
}

QArrayData *QArrayData::allocate(size_t objectSize, // 对象的大小.
                                 size_t alignment, // 对齐大小
                                 size_t capacity, // 对象的多少.
                                 AllocationOptions options) Q_DECL_NOTHROW
                         {
    // Don't allocate empty headers
    if (!(options & RawData) && !capacity) {
        // 如果, capacity 是 0, 那么返回一个公用的值代表没有数据.
        // 这种设计手法可以借鉴. 使用一个公用值代表非法值, 特殊值.
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

    // 根据上面的这些配置, 计算出最终需要多少的空间, 然后, 最终还是调用了 malloc 来分配空间.
    // 在分配成功之后, 进行对应的值的赋值.
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

    if (data == &qt_array_unsharable_empty)
        return;

    // 通过 Assert 来防止某些非法的传入
    Q_ASSERT_X(data == 0 || !data->ref.isStatic(), "QArrayData::deallocate",
               "Static data can not be deleted");
    // 最终, dealloc 还是使用了 free 来释放内存资源.
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
