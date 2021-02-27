#ifndef QTCORE_RESULTSTORE_H
#define QTCORE_RESULTSTORE_H

#include <QtCore/qglobal.h>

#ifndef QT_NO_QFUTURE

#include <QtCore/qmap.h>
#include <QtCore/qdebug.h>

QT_BEGIN_NAMESPACE

#ifndef Q_QDOC

namespace QtPrivate {

// 实际上, Future 里面存储的值, 仅仅是指针而已.
// 这里, 通过 0 来表示是不是 Vector, 来体现一个 bool 的目的, 其实有点不太清楚.
class ResultItem
{
public:
    ResultItem(const void *_result, int _count) : m_count(_count), result(_result) { } // contruct with vector of results
    ResultItem(const void *_result) : m_count(0), result(_result) { } // construct with result
    ResultItem() : m_count(0), result(Q_NULLPTR) { }
    bool isValid() const { return result != Q_NULLPTR; }
    bool isVector() const { return m_count != 0; }
    int count() const { return (m_count == 0) ?  1 : m_count; }

    // 真正存储的, 就是一个指针而已.
    int m_count;          // result is either a pointer to a result or to a vector of results,
    const void *result; // if count is 0 it's a result, otherwise it's a vector.
};


// 没有太明白里面的细节, 不过这个类, 就是按照 Int 值存储一个指针而已.
class Q_CORE_EXPORT ResultIteratorBase
{
public:
    ResultIteratorBase();
    ResultIteratorBase(QMap<int, ResultItem>::const_iterator _mapIterator, int _vectorIndex = 0);
    int vectorIndex() const;
    int resultIndex() const;

    ResultIteratorBase operator++();
    int batchSize() const;
    void batchedAdvance();
    bool operator==(const ResultIteratorBase &other) const;
    bool operator!=(const ResultIteratorBase &other) const;
    bool isVector() const;
    bool canIncrementVectorIndex() const;

protected:
    QMap<int, ResultItem>::const_iterator mapIterator;
    int m_vectorIndex;
public:
    template <typename T>
    const T &value() const
    {
        return *pointer<T>();
    }

    template <typename T>
    const T *pointer() const
    {
        if (mapIterator.value().isVector())
            return &(reinterpret_cast<const QVector<T> *>(mapIterator.value().result)->at(m_vectorIndex));
        else
            return reinterpret_cast<const T *>(mapIterator.value().result);
    }
};

// Future 里面, 存储数据的地方.
// 根据 Index, 存储 Item, 而 Item 里面, 存储的还是指针.
class Q_CORE_EXPORT ResultStoreBase
{
public:
    ResultStoreBase();
    void setFilterMode(bool enable);
    bool filterMode() const;
    int addResult(int index, const void *result);
    int addResults(int index, const void *results, int vectorSize, int logicalCount);
    ResultIteratorBase begin() const;
    ResultIteratorBase end() const;
    bool hasNextResult() const;
    ResultIteratorBase resultAt(int index) const;
    bool contains(int index) const;
    int count() const;
    virtual ~ResultStoreBase();

protected:
    int insertResultItem(int index, ResultItem &resultItem);
    void insertResultItemIfValid(int index, ResultItem &resultItem);
    void syncPendingResults();
    void syncResultCount();
    int updateInsertIndex(int index, int _count);

    QMap<int, ResultItem> m_results;
    int toInsertIndex;     // The index where the next results(s) will be inserted.
    int resultCount;     // The number of consecutive results stored, starting at index 0.

    bool m_filterMode;
    QMap<int, ResultItem> pendingResults;
    int filteredResults;

public:
    template <typename T>
    int addResult(int index, const T *result)
    {
        if (result == 0)
            return addResult(index, static_cast<void *>(nullptr));
        else
            // 这里, 对数据进行了一份拷贝工作. 所以, 不用担心子线程生成的 result 在子线程结束后释放.
            return addResult(index, static_cast<void *>(new T(*result)));
    }

    template <typename T>
    int addResults(int index, const QVector<T> *results)
    {
        // 这里,  QVector<T>(*results), 里面一定有着对于数据的管理. 并且, QVector 本身数据就是在堆里面.
        return addResults(index, new QVector<T>(*results), results->count(), results->count());
    }

    template <typename T>
    int addResults(int index, const QVector<T> *results, int totalCount)
    {
        if (m_filterMode == true && results->count() != totalCount && 0 == results->count())
            return addResults(index, 0, 0, totalCount);
        else
            return addResults(index, new QVector<T>(*results), results->count(), totalCount);
    }

    int addCanceledResult(int index)
    {
        return addResult(index, static_cast<void *>(nullptr));
    }

    template <typename T>
    int addCanceledResults(int index, int _count)
    {
        QVector<T> empty;
        return addResults(index, &empty, _count);
    }

    // 在这里, 有着对保存的数据的删除的工作.
    template <typename T>
    void clear()
    {
        QMap<int, ResultItem>::const_iterator mapIterator = m_results.constBegin();
        while (mapIterator != m_results.constEnd()) {
            if (mapIterator.value().isVector())
                delete reinterpret_cast<const QVector<T> *>(mapIterator.value().result);
            else
                delete reinterpret_cast<const T *>(mapIterator.value().result);
            ++mapIterator;
        }
        resultCount = 0;
        m_results.clear();
    }
};

} // namespace QtPrivate

#endif //Q_QDOC

QT_END_NAMESPACE

#endif // QT_NO_QFUTURE

#endif
