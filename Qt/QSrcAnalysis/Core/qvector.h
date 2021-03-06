#ifndef QVECTOR_H
#define QVECTOR_H

#include <QtCore/qalgorithms.h>
#include <QtCore/qiterator.h>
#include <QtCore/qlist.h>
#include <QtCore/qrefcount.h>
#include <QtCore/qarraydata.h>
#include <QtCore/qhashfunctions.h>
#include <iterator>
#include <vector>
#include <stdlib.h>
#include <string.h>
#include <initializer_list>
#endif

#include <algorithm>

// 全局泛型算法使用大大减少了, 各种 traits 的判断, copy, fill 等算法, 都在 QVector 的内部, 有自己的实现了.
// 增加了写实拷贝的功能, 复制数组, 不再是深拷贝了, 而是共享内存, 但是在所有的改变内容的地方, 增加了对于引用计数的判断.

QT_BEGIN_NAMESPACE

template <typename T>
class QVector
{
    // QTypedArrayData 里面记录了, 引用计数, 容量, 实际占用 size.
    typedef QTypedArrayData<T> Data;
    Data *backingStore;

public:
    // Data::sharedNull, 默认, 使用一个特殊值, 代表着空数据.
    inline QVector() : backingStore(Data::sharedNull()) { }
    explicit QVector(int size);
    QVector(int size, const T &t);
    inline QVector(const QVector<T> &v);
    inline ~QVector() {
        // 引用计数的管理, 如果为 0, 就进行资源的释放.
        if (!backingStore->ref.deref()) freeData(backingStore);
    }
    QVector<T> &operator=(const QVector<T> &v);
    // move cpor, 就是, 1. 数据转移. 2. clean 原有
    QVector(QVector<T> &&other) Q_DECL_NOTHROW : backingStore(other.backingStore) { other.backingStore = Data::sharedNull(); }
    // move assign, 生临时对象, swap, 为什么不直接操作 backingStore, 不更加好一些.
    QVector<T> &operator=(QVector<T> &&other) Q_DECL_NOTHROW
    { QVector moved(std::move(other)); swap(moved); return *this; }
    void swap(QVector<T> &other) Q_DECL_NOTHROW {
        // 这里, 其实就是两个指针的交换.
        qSwap(backingStore, other.backingStore);
    }
    inline QVector(std::initializer_list<T> args);
    bool operator==(const QVector<T> &v) const;
    // 使用 primitive 来组件复杂的操作.
    inline bool operator!=(const QVector<T> &v) const { return !(*this == v); }

    inline int size() const { return backingStore->size; }
    inline bool isEmpty() const { return backingStore->size == 0; }
    inline int capacity() const { return int(backingStore->alloc); }
    void reserve(int size);
    void resize(int size);

    // 压缩, 就是把底层存储的空间, 压缩到现有的空间.
    // reallocData 是一个通用的数据操作的方法.
    inline void squeeze()
    {
        reallocData(backingStore->size, backingStore->size);
        if (backingStore->capacityReserved) {
            // capacity reserved in a read only memory would be useless
            // this checks avoid writing to such memory.
            backingStore->capacityReserved = 0;
        }
    }

    inline void detach();
    inline bool isDetached() const {
        // isShared 有着自己的考虑意图, 但是实际上, 就是引用计数的判断.
        return !backingStore->ref.isShared();
    }
    inline bool isSharedWith(const QVector<T> &other) const { return backingStore == other.backingStore; }

    // 如果是可变 vector 调用, 到这里, 触发深拷贝.
    // 这里就是为什么, vectorValue[1] 会有性能损失的原因所在.
    inline T *data() { detach(); return backingStore->begin(); }
    // 如果是不可变调用, 直接读取 backingStore 里面的数据.
    inline const T *data() const { return backingStore->begin(); }
    inline const T *constData() const { return backingStore->begin(); }
    void clear();

    const T &at(int i) const;
    T &operator[](int i);
    const T &operator[](int i) const;
    void append(const T &t);
#if defined(Q_COMPILER_RVALUE_REFS) || defined(Q_CLANG_QDOC)
    void append(T &&t);
#endif
    inline void append(const QVector<T> &l) { *this += l; }
    void prepend(T &&t);
    void prepend(const T &t);
    void insert(int i, T &&t);
    void insert(int i, const T &t);
    void insert(int i, int n, const T &t);
    void replace(int i, const T &t);
    void remove(int i);
    void remove(int i, int n);
    inline void removeFirst() { Q_ASSERT(!isEmpty()); erase(backingStore->begin()); }
    inline void removeLast();

    // 这里, 之所以可以使用 move ctor, 是因为后面马上就是 remove 这个数据了.
    T takeFirst() { Q_ASSERT(!isEmpty()); T r = std::move(first()); removeFirst(); return r; }
    T takeLast()  { Q_ASSERT(!isEmpty()); T r = std::move(last()); removeLast(); return r; }

    QVector<T> &fill(const T &t, int size = -1);

    int indexOf(const T &t, int from = 0) const;
    int lastIndexOf(const T &t, int from = -1) const;
    bool contains(const T &t) const;
    int count(const T &t) const;

    // QList compatibility
    void removeAt(int i) { remove(i); }
    int removeAll(const T &t)
    {
        const const_iterator ce = this->cend(), cit = std::find(this->cbegin(), ce, t);
        if (cit == ce)
            return 0;
        // next operation detaches, so ce, cit, t may become invalidated:
        const T tCopy = t;
        const int firstFoundIdx = std::distance(this->cbegin(), cit);
        const iterator e = end(), it = std::remove(begin() + firstFoundIdx, e, tCopy);
        const int result = std::distance(it, e);
        erase(it, e);
        return result;
    }
    bool removeOne(const T &t)
    {
        const int i = indexOf(t);
        if (i < 0)
            return false;
        remove(i);
        return true;
    }
    int length() const { return size(); }
    T takeAt(int i) { T t = std::move((*this)[i]); remove(i); return t; }
    void move(int from, int to)
    {
        Q_ASSERT_X(from >= 0 && from < size(), "QVector::move(int,int)", "'from' is out-of-range");
        Q_ASSERT_X(to >= 0 && to < size(), "QVector::move(int,int)", "'to' is out-of-range");
        if (from == to) // don't detach when no-op
            return;
        detach();
        T * const b = backingStore->begin();
        if (from < to)
            std::rotate(b + from, b + from + 1, b + to + 1);
        else
            std::rotate(b + to, b + from, b + from + 1);
    }

    // STL-style
    typedef typename Data::iterator iterator;
    typedef typename Data::const_iterator const_iterator;
    typedef std::reverse_iterator<iterator> reverse_iterator;
    typedef std::reverse_iterator<const_iterator> const_reverse_iterator;
    inline iterator begin() { detach(); return backingStore->begin(); }
    inline const_iterator begin() const Q_DECL_NOTHROW { return backingStore->constBegin(); }
    inline const_iterator cbegin() const Q_DECL_NOTHROW { return backingStore->constBegin(); }
    inline const_iterator constBegin() const Q_DECL_NOTHROW { return backingStore->constBegin(); }
    inline iterator end() { detach(); return backingStore->end(); }
    inline const_iterator end() const Q_DECL_NOTHROW { return backingStore->constEnd(); }
    inline const_iterator cend() const Q_DECL_NOTHROW { return backingStore->constEnd(); }
    inline const_iterator constEnd() const Q_DECL_NOTHROW { return backingStore->constEnd(); }
    reverse_iterator rbegin() { return reverse_iterator(end()); }
    reverse_iterator rend() { return reverse_iterator(begin()); }
    const_reverse_iterator rbegin() const Q_DECL_NOTHROW { return const_reverse_iterator(end()); }
    const_reverse_iterator rend() const Q_DECL_NOTHROW { return const_reverse_iterator(begin()); }
    const_reverse_iterator crbegin() const Q_DECL_NOTHROW { return const_reverse_iterator(end()); }
    const_reverse_iterator crend() const Q_DECL_NOTHROW { return const_reverse_iterator(begin()); }
    iterator insert(iterator before, int n, const T &x);
    inline iterator insert(iterator before, const T &x) { return insert(before, 1, x); }
    inline iterator insert(iterator before, T &&x);
    iterator erase(iterator begin, iterator end);
    inline iterator erase(iterator pos) { return erase(pos, pos+1); }

    // more Qt
    inline int count() const { return backingStore->size; }
    inline T& first() { Q_ASSERT(!isEmpty()); return *begin(); }
    inline const T &first() const { Q_ASSERT(!isEmpty()); return *begin(); }
    inline const T &constFirst() const { Q_ASSERT(!isEmpty()); return *begin(); }
    inline T& last() { Q_ASSERT(!isEmpty()); return *(end()-1); }
    inline const T &last() const { Q_ASSERT(!isEmpty()); return *(end()-1); }
    inline const T &constLast() const { Q_ASSERT(!isEmpty()); return *(end()-1); }
    inline bool startsWith(const T &t) const { return !isEmpty() && first() == t; }
    inline bool endsWith(const T &t) const { return !isEmpty() && last() == t; }
    QVector<T> mid(int pos, int len = -1) const;

    T value(int i) const;
    T value(int i, const T &defaultValue) const;

    // STL compatibility
    typedef T value_type;
    typedef value_type* pointer;
    typedef const value_type* const_pointer;
    typedef value_type& reference;
    typedef const value_type& const_reference;
    typedef qptrdiff difference_type;
    typedef iterator Iterator;
    typedef const_iterator ConstIterator;
    typedef int size_type;
    inline void push_back(const T &t) { append(t); }
    inline void push_front(const T &t) { prepend(t); }
    void pop_back() { removeLast(); }
    void pop_front() { removeFirst(); }
    inline bool empty() const
    { return backingStore->size == 0; }
    inline T& front() { return first(); }
    inline const_reference front() const { return first(); }
    inline reference back() { return last(); }
    inline const_reference back() const { return last(); }
    void shrink_to_fit() { squeeze(); }

    // comfort
    QVector<T> &operator+=(const QVector<T> &l);
    inline QVector<T> operator+(const QVector<T> &l) const
    { QVector n = *this; n += l; return n; }
    inline QVector<T> &operator+=(const T &t)
    { append(t); return *this; }
    inline QVector<T> &operator<< (const T &t)
    { append(t); return *this; }
    inline QVector<T> &operator<<(const QVector<T> &l)
    { *this += l; return *this; }
    inline QVector<T> &operator+=(T &&t)
    { append(std::move(t)); return *this; }
    inline QVector<T> &operator<<(T &&t)
    { append(std::move(t)); return *this; }

    QList<T> toList() const;

    static QVector<T> fromList(const QList<T> &list);

    static inline QVector<T> fromStdVector(const std::vector<T> &vector)
    { QVector<T> tmp; tmp.reserve(int(vector.size())); std::copy(vector.begin(), vector.end(), std::back_inserter(tmp)); return tmp; }
    inline std::vector<T> toStdVector() const
    { return std::vector<T>(backingStore->begin(), backingStore->end()); }
private:
    // ### Qt6: remove const from int parameters
    void reallocData(const int size, const int alloc, QArrayData::AllocationOptions options = QArrayData::Default);
    void reallocData(const int sz) { reallocData(sz, backingStore->alloc); }
    void freeData(Data *d);
    void defaultConstruct(T *from, T *to);
    void copyConstruct(const T *srcFrom, const T *srcTo, T *dstFrom);
    void destruct(T *from, T *to);
    bool isValidIterator(const iterator &i) const
    {
        const std::less<const T*> less = {};
        return !less(backingStore->end(), i) && !less(i, backingStore->begin());
    }
    class AlignmentDummy { Data header; T array[1]; };
};

template <typename T>
void QVector<T>::defaultConstruct(T *from, T *to)
{
    // 还是还有 type traits
    if (QTypeInfo<T>::isComplex) {
        // 如果是对象类型, 直接调用默认构造函数
        // 默认构造函数的重要性就在这里, 很多时候, 它是被系统 API 自动调用的. 如果不设计出来, 会有问题.
        while (from != to) {
            new (from++) T();
        }
    } else {
        // 基本数据类型, 进行 memset 0 的处理.
        ::memset(static_cast<void *>(from), 0, (to - from) * sizeof(T));
    }
}

// Vector 的拷贝构造函数.
// Qt 对于这些, 没有使用通用算法, 而是使用了自己的实现.
// 调用这个方法, 需要有着来源数据的情况下.
// 对于 Qt 版本的 QVector 来说, 扩容这件事, 没有调用 copyConstruct
template <typename T>
void QVector<T>::copyConstruct(const T *srcFrom, const T *srcTo, T *dstFrom)
{
    if (QTypeInfo<T>::isComplex) {
        while (srcFrom != srcTo) {
            new (dstFrom++) T(*srcFrom++); // placeholder new, 使用目标位置的数据, 进行构造.
        }
    } else {
        // 在这种地方, 使用 static_cast 是很好的. 是可控的转化.
        ::memcpy(static_cast<void *>(dstFrom), static_cast<const void *>(srcFrom), (srcTo - srcFrom) * sizeof(T));
    }
}

// QVector 的 destruct 方法, 就是一个个的进行对应数据的析构函数.
// 这本应该是 alloctor 的责任, 但是 QVector 并没有 alloctor, 而是使用的 ByteArray, 这个类就是原始数据的封装而已, 所以在 QVector 里面, 主动承担了对应的数据的析构的调用.
template <typename T>
void QVector<T>::destruct(T *from, T *to)
{
    if (QTypeInfo<T>::isComplex) {
        while (from != to) {
            from++->~T();
        }
    }
}

// QVector 的拷贝复制函数.
template <typename T>
inline QVector<T>::QVector(const QVector<T> &v)
{
    if (v.backingStore->ref.ref()) {
        // 增加了引用计数, 仅仅拷贝底层指针.
        // 使用共享内存, 那么相应的 copy, assign, 是对共享内存的引用计数的修改.
        backingStore = v.backingStore;
    } else {
        // 这里, 就代表数据是 static 的. 总之就是不可共享. 就要深拷贝
        // 先进行空间的申请.
        if (v.backingStore->capacityReserved) {
            backingStore = Data::allocate(v.backingStore->alloc);
            Q_CHECK_PTR(backingStore);
            backingStore->capacityReserved = true;
        } else {
            backingStore = Data::allocate(v.backingStore->size);
            Q_CHECK_PTR(backingStore);
        }
        // 然后每一项, 都调用 cpor
        if (backingStore->alloc) {
            copyConstruct(v.backingStore->begin(), v.backingStore->end(), backingStore->begin());
            backingStore->size = v.backingStore->size;
        }
    }
}


// 如果, 还没有分离过, 就进行分离.
// 将分离操作, 集中到一点. 使用前调用, 如果已经分离了, 也没什么影响. 好的设计.
template <typename T>
void QVector<T>::detach()
{
    if (!isDetached()) {
        if (!backingStore->alloc)
            backingStore = Data::unsharableEmpty();
        else
            reallocData(backingStore->size, int(backingStore->alloc));
    }
}

template <typename T>
void QVector<T>::reserve(int asize)
{
    if (asize > int(backingStore->alloc)){
        reallocData(backingStore->size, asize);
    }
    if (isDetached()) {
        backingStore->capacityReserved = 1;
    }
}

template <typename T>
void QVector<T>::resize(int asize)
{
    int newAlloc;
    const int oldAlloc = int(backingStore->alloc);
    QArrayData::AllocationOptions opt;

    if (asize > oldAlloc) { // there is not enough space
        newAlloc = asize;
        opt = QArrayData::Grow;
    } else {
        newAlloc = oldAlloc;
    }
    reallocData(asize, newAlloc, opt);
}

template <typename T>
inline void QVector<T>::clear()
{ resize(0); }

// 不会改变内部存储, 直接返回 backingStore 里面的数据,
template <typename T>
inline const T &QVector<T>::at(int i) const
{
    return backingStore->begin()[i];
}

// const Vector 会调用到这个版本, 不会改变存储, 直接返回 backingStore 里面的数据.
template <typename T>
inline const T &QVector<T>::operator[](int i) const
{ Q_ASSERT_X(i >= 0 && i < backingStore->size, "QVector<T>::operator[]", "index out of range");
  return backingStore->begin()[i]; }

// 会更改数据, data() 的内部会先 detach, 然后返回重新拷贝后的指针.
template <typename T>
inline T &QVector<T>::operator[](int i)
{ Q_ASSERT_X(i >= 0 && i < backingStore->size, "QVector<T>::operator[]", "index out of range");
  return data()[i]; }

template <typename T>
inline void QVector<T>::insert(int i, const T &t)
{ Q_ASSERT_X(i >= 0 && i <= backingStore->size, "QVector<T>::insert", "index out of range");
  insert(begin() + i, 1, t); }
template <typename T>
inline void QVector<T>::insert(int i, int n, const T &t)
{ Q_ASSERT_X(i >= 0 && i <= backingStore->size, "QVector<T>::insert", "index out of range");
  insert(begin() + i, n, t); }
// move 语义的插入.
template <typename T>
inline void QVector<T>::insert(int i, T &&t)
{ Q_ASSERT_X(i >= 0 && i <= backingStore->size, "QVector<T>::insert", "index out of range");
  insert(begin() + i, std::move(t)); }
template <typename T>
inline void QVector<T>::remove(int i, int n)
{ Q_ASSERT_X(i >= 0 && n >= 0 && i + n <= backingStore->size, "QVector<T>::remove", "index out of range");
  erase(backingStore->begin() + i, backingStore->begin() + i + n); }
template <typename T>
inline void QVector<T>::remove(int i)
{ Q_ASSERT_X(i >= 0 && i < backingStore->size, "QVector<T>::remove", "index out of range");
  erase(backingStore->begin() + i, backingStore->begin() + i + 1); }
template <typename T>
inline void QVector<T>::prepend(const T &t)
{ insert(begin(), 1, t); }
template <typename T>
inline void QVector<T>::prepend(T &&t)
{ insert(begin(), std::move(t)); }

template <typename T>
inline void QVector<T>::replace(int i, const T &t)
{
    // 使用目标值, 进行拷贝构造, 然后调用已经写好的 [] 操作符.
    const T copy(t);
    data()[i] = copy;
}

// 这里利用了 assign swap 的技术.
// 如果参数不是自己, 就进行 swap.
// 这里, 因为传递的值是 const, 所以是生成了一个临时对象进行 swap, 又因为, Qt 里面是引用计数在管理真正的资源, 代价不大
// 最后 tmp 析构的时候, 会进行原有 this 的引用计数 -- .
template <typename T>
QVector<T> &QVector<T>::operator=(const QVector<T> &v)
{
    if (v.backingStore != backingStore) {
        QVector<T> tmp(v);
        tmp.swap(*this);
    }
    return *this;
}

template <typename T>
QVector<T>::QVector(int asize)
{
    // 直接, Q_ASSERT_X 进行非法数据的拦截.
    Q_ASSERT_X(asize >= 0, "QVector::QVector", "Size must be greater than or equal to 0.");
    if (Q_LIKELY(asize > 0)) {
        // 存储空间的分配
        backingStore = Data::allocate(asize);
        backingStore->size = asize;
        // 调用默认的构造函数.
        defaultConstruct(backingStore->begin(), backingStore->end());
    } else {
        backingStore = Data::sharedNull();
    }
}

template <typename T>
QVector<T>::QVector(int asize, const T &t)
{
    if (asize > 0) {
        // 先使用 asize, 分配对应的空间出来.
        backingStore = Data::allocate(asize);
        backingStore->size = asize;
        T* i = backingStore->end();
        // 然后, 进行 placeHolder 的拷贝构造的调用.
        while (i != backingStore->begin())
            new (--i) T(t);
    } else {
        backingStore = Data::sharedNull();
    }
}

// 各个容器类, 都增加了对于 std::initializer_list 的适配.
// std::initializer_list 本质上, 就是一个临时数组.
// 所以, 通过 std::initializer_list 初始化的逻辑, 和 通过 QVector 初始化没有太大的区别.
template <typename T>
QVector<T>::QVector(std::initializer_list<T> args)
{
    if (args.size() > 0) {
        backingStore = Data::allocate(args.size());
        copyConstruct(args.begin(), args.end(), backingStore->begin());
        backingStore->size = int(args.size());
    } else {
        backingStore = Data::sharedNull();
    }
}

// 先调用析构函数, 然后进行内存空间的释放.
template <typename T>
void QVector<T>::freeData(Data *x)
{
    destruct(x->begin(), x->end()); // 需要调用析构函数进行资源释放.
    Data::deallocate(x);
}

// 非常重要的方法.
// 重新分配内存并且复制当前的数据.
template <typename T>
void QVector<T>::reallocData(const int nowSize, /*现有容量*/
                             const int targetSize/*目标容量*/,
                             QArrayData::AllocationOptions options)
{
    Data *createdStore = backingStore;

    const bool isShared = backingStore->ref.isShared();

    if (targetSize != 0) {
        // 如果, 目标容量和自己的capacity不相符, 或者正在共享.
        if (targetSize != int(backingStore->alloc) || isShared) {
            // 这里, 是扩容处理.
            QT_TRY {
                // allocate memory
                createdStore = Data::allocate(targetSize, options);
                createdStore->size = nowSize; //新创建的 size, 和当前的一样.

                T *srcBegin = backingStore->begin();
                T *srcEnd = nowSize > backingStore->size ? backingStore->end() : backingStore->begin() + nowSize;
                T *dst = createdStore->begin();

                // 所以, 无论是 Qt, 还是 STL 在扩容的时候, 都是要调用构造函数进行新空间的初始化的.
                // 这里对应的, 也就是 uninitialized_copy 里面的操作.
                if (!QTypeInfoQuery<T>::isRelocatable || (isShared && QTypeInfo<T>::isComplex)) {
                    QT_TRY {
                        // 到这里, 就是调用拷贝构造, 或者 move 构造进行新值的初始化了.
                        // 直接使用了 std::is_nothrow_move_constructible 来进行 type_traits.
                        // std 要求, move 必须是 nothrow 的, 所以这里判断一下.
                        // 如果, 当前的 data 没有被共享, 也就是只有自己操作这个数据, 那么就可以 move.
                        if (isShared || !std::is_nothrow_move_constructible<T>::value) {
                            // we can not move the data, we need to copy construct it
                            while (srcBegin != srcEnd)
                                new (dst++) T(*srcBegin++);
                        } else {
                            while (srcBegin != srcEnd)
                                new (dst++) T(std::move(*srcBegin++));
                        }
                    } QT_CATCH (...) {
                        // destruct already copied objects
                        // 发生了异常, 那么就把 createdStore 的资源释放, 这样 vector 的数据, 保持原样.
                        // 这是 std 的要求, 发生异常, 原有数据不受影响. 这也是, move 不能 throw 的原因.
                        destruct(createdStore->begin(), dst);
                        QT_RETHROW;
                    }
                } else {
                    // 直接 memory copy 就可以了.
                    ::memcpy(static_cast<void *>(dst), static_cast<void *>(srcBegin), (srcEnd - srcBegin) * sizeof(T));
                    dst += srcEnd - srcBegin;

                    // destruct unused / not moved data
                    if (nowSize < backingStore->size)
                        destruct(backingStore->begin() + nowSize, backingStore->end());
                }

                if (nowSize > backingStore->size) {
                    // construct all new objects when growing
                    if (!QTypeInfo<T>::isComplex) {
                        ::memset(static_cast<void *>(dst), 0, (static_cast<T *>(createdStore->end()) - dst) * sizeof(T));
                    } else {
                        QT_TRY {
                            while (dst != createdStore->end())
                                new (dst++) T();
                        } QT_CATCH (...) {
                            // destruct already copied objects
                            destruct(createdStore->begin(), dst);
                            QT_RETHROW;
                        }
                    }
                }
            } QT_CATCH (...) {
                Data::deallocate(createdStore);
                QT_RETHROW;
            }
            createdStore->capacityReserved = backingStore->capacityReserved;
        } else {
            if (nowSize <= backingStore->size) {
                destruct(createdStore->begin() + nowSize, createdStore->end()); // from future end to current end
            } else {
                defaultConstruct(createdStore->end(), createdStore->begin() + nowSize); // from current end to future end
            }
            createdStore->size = nowSize;
        }
    } else {
        createdStore = Data::sharedNull();
    }


    // 开辟了新的空间, 复制完了, 就应该交换指针了.
    if (backingStore != createdStore) {
        // 首先, 要做的是原有资源的管理
        if (!backingStore->ref.deref()) { // backingStore 没有引用计数了, 应该释放.
            if (!QTypeInfoQuery<T>::isRelocatable || !targetSize || (isShared && QTypeInfo<T>::isComplex)) {
                // data was copy constructed, we need to call destructors
                // or if !alloc we did nothing to the old 'd'.
                freeData(backingStore);
            } else {
                Data::deallocate(backingStore);
            }
        }
        backingStore = createdStore;
    }
}

// 直接使用迭代器的 [] 做实现.
// 想想一下最最原始的数组 [] 不就是 *(address+n) 这样实现的吗
template<typename T>
Q_OUTOFLINE_TEMPLATE T QVector<T>::value(int i) const
{
    if (uint(i) >= uint(backingStore->size)) {
        return T();
    }
    return backingStore->begin()[i];
}

// 如果超过了数组长度, 可以返回一个默认值. 这种函数真的应该使用吗.
template<typename T>
Q_OUTOFLINE_TEMPLATE T QVector<T>::value(int i, const T &defaultValue) const
{
    return uint(i) >= uint(backingStore->size) ? defaultValue : backingStore->begin()[i];
}

template <typename T>
void QVector<T>::append(const T &t)
{
    // tooSmall 代表的是, 容量不够, 需要扩容
    const bool isTooSmall = uint(backingStore->size + 1) > backingStore->alloc;
    if (!isDetached() || isTooSmall) {
        T copy(t);// 这里拷贝了, 后面就能用 Move 语义了.
        QArrayData::AllocationOptions opt(isTooSmall ? QArrayData::Grow : QArrayData::Default);
        reallocData(backingStore->size, isTooSmall ? backingStore->size + 1 : backingStore->alloc, opt);

        if (QTypeInfo<T>::isComplex)
            new (backingStore->end()) T(qMove(copy));
        else
            *backingStore->end() = qMove(copy);

    } else { // 如果, 单独 own 这块空间, 直接在尾部添加数据
        if (QTypeInfo<T>::isComplex)
            new (backingStore->end()) T(t);
        else
            *backingStore->end() = t;
    }
    ++backingStore->size; // 增加容量.
}

// 当参数是一个 move 语义的引用的时候, 怎么办, 参数应该释放自己的资源, 但是资源是参数内部的, 没有公开的办法去修改.
// 其实, 就应该利用 move 构造函数.
// move 就是要对方接管这部分数据, 所以一定要新建一个对象接管, 而这个新建的过程, 就要调用 move 构造函数.
template <typename T>
void QVector<T>::append(T &&t)
{
    const bool isTooSmall = uint(backingStore->size + 1) > backingStore->alloc;
    if (!isDetached() || isTooSmall) {
        QArrayData::AllocationOptions opt(isTooSmall ? QArrayData::Grow : QArrayData::Default);
        reallocData(backingStore->size, isTooSmall ? backingStore->size + 1 : backingStore->alloc, opt);
    }
    new (backingStore->end()) T(std::move(t));
    ++backingStore->size;
}

template <typename T>
void QVector<T>::removeLast()
{
    if (!backingStore->ref.isShared()) {
        --backingStore->size; // 直接更改 backingStore 的结尾 idx 值
        if (QTypeInfo<T>::isComplex) {
            // 对刚刚删除的值, 进行析构调用.
            (backingStore->data() + backingStore->size)->~T();
        }
    } else {
        reallocData(backingStore->size - 1);
    }
}

// 不是 move 语义的插入操作.
// 带有 move 语义的, 在搬移的时候, 是 move ctor 的调用.
// 不带 move 语义的, 在搬移的时候, 是 assign operator 的调用
template <typename T>
typename QVector<T>::iterator QVector<T>::insert(iterator before, size_type n, const T &t)
{
    const auto offset = std::distance(backingStore->begin(), before);
    if (n != 0) {
        const T copy(t);
        if (!isDetached() || backingStore->size + n > int(backingStore->alloc))
        {
            reallocData(backingStore->size, backingStore->size + n, QArrayData::Grow);
        }

        if (!QTypeInfoQuery<T>::isRelocatable) {
            T *b = backingStore->end();
            T *i = backingStore->end() + n;
            while (i != b)
                new (--i) T;
            i = backingStore->end();
            T *j = i + n;
            b = backingStore->begin() + offset;
            while (i != b)
                *--j = *--i;
            i = b+n;
            while (i != b)
                *--i = copy;
        } else {
            T *b = backingStore->begin() + offset;
            T *i = b + n;
            memmove(static_cast<void *>(i),
                    static_cast<const void *>(b),
                    (backingStore->size - offset) * sizeof(T));
            while (i != b){
                new (--i) T(copy);
            }
        }
        backingStore->size += n;
    }

    return backingStore->begin() + offset;
}

template <typename T>
typename QVector<T>::iterator QVector<T>::insert(iterator before, T &&t)
{
    const auto offset = std::distance(backingStore->begin(), before);
    // 首先, 没有分离, 或者空间不足, 会重新进行内存空间的分配. 里面会有大量的 cpctor 的调用.
    if (!isDetached() || backingStore->size + 1 > int(backingStore->alloc)) {
        reallocData(backingStore->size, backingStore->size + 1, QArrayData::Grow);
    }
    // 因为, 这里是 move insert, 所以下面的操作, 都增加了 move 操作符.
    if (!QTypeInfoQuery<T>::isRelocatable) {
        T *i = backingStore->end();
        T *j = i + 1;
        T *b = backingStore->begin() + offset;
        // The new end-element needs to be constructed, the rest must be move assigned
        if (i != b) {
            // 这里, 还是会有 assign 操作符的调用.
            // 也就是说, 在 insert 操作里面, 如果重新分配了空间, 会有大量的复制操作.
            // 如果需要搬移, 会有大量的 assign 的搬移工作.
            // 实在是效率低下.
            // 设计良好的 move, 可以达到 memmove 的操作, 到底 move ctor, move assign 会做出什么样的效果, 完全看类的设计者.
            new (--j) T(std::move(*--i));
            while (i != b)
                *--j = std::move(*--i);
            *b = std::move(t);
        } else {
            new (b) T(std::move(t));
        }
    } else {
        T *b = backingStore->begin() + offset;
        memmove(static_cast<void *>(b + 1), static_cast<const void *>(b), (backingStore->size - offset) * sizeof(T));
        new (b) T(std::move(t));
    }
    backingStore->size += 1;
    return backingStore->begin() + offset;
}

template <typename T>
typename QVector<T>::iterator QVector<T>::erase(iterator abegin, iterator aend)
{
    Q_ASSERT_X(isValidIterator(abegin), "QVector::erase", "The specified iterator argument 'abegin' is invalid");
    Q_ASSERT_X(isValidIterator(aend), "QVector::erase", "The specified iterator argument 'aend' is invalid");

    const auto itemsToErase = aend - abegin;

    if (!itemsToErase)
        return abegin;

    Q_ASSERT(abegin >= backingStore->begin());
    Q_ASSERT(aend <= backingStore->end());
    Q_ASSERT(abegin <= aend);

    const auto itemsUntouched = abegin - backingStore->begin();

    // FIXME we could do a proper realloc, which copy constructs only needed data.
    // FIXME we are about to delete data - maybe it is good time to shrink?
    // FIXME the shrink is also an issue in removeLast, that is just a copy + reduce of this.
    if (backingStore->alloc) {
        detach();
        abegin = backingStore->begin() + itemsUntouched;
        aend = abegin + itemsToErase;
        if (!QTypeInfoQuery<T>::isRelocatable) {
            iterator moveBegin = abegin + itemsToErase;
            iterator moveEnd = backingStore->end();
            while (moveBegin != moveEnd) {
                if (QTypeInfo<T>::isComplex)
                    static_cast<T *>(abegin)->~T();
                new (abegin++) T(*moveBegin++);
            }
            if (abegin < backingStore->end()) {
                // destroy rest of instances
                destruct(abegin, backingStore->end());
            }
        } else {
            destruct(abegin, aend);
            // QTBUG-53605: static_cast<void *> masks clang errors of the form
            // error: destination for this 'memmove' call is a pointer to class containing a dynamic class
            // FIXME maybe use std::is_polymorphic (as soon as allowed) to avoid the memmove
            memmove(static_cast<void *>(abegin), static_cast<void *>(aend),
                    (backingStore->size - itemsToErase - itemsUntouched) * sizeof(T));
        }
        backingStore->size -= int(itemsToErase);
    }
    return backingStore->begin() + itemsUntouched;
}

template <typename T>
bool QVector<T>::operator==(const QVector<T> &v) const
{
    if (backingStore == v.backingStore) // 底层存储一样
        return true;
    if (backingStore->size != v.backingStore->size) // 底层存储的数量不一样
        return false;

    const T *vb = v.backingStore->begin();
    const T *b  = backingStore->begin();
    const T *e  = backingStore->end();
    // 最终, 还是一个个的取判断, 每一个 Item 是否 equal.
    return std::equal(b, e, QT_MAKE_CHECKED_ARRAY_ITERATOR(vb, v.backingStore->size));
}

template <typename T>
QVector<T> &QVector<T>::fill(const T &from, int asize)
{
    const T copy(from);
    resize(asize < 0 ? backingStore->size : asize);
    if (backingStore->size) {
        T *i = backingStore->end();
        T *b = backingStore->begin();
        while (i != b) {
            *--i = copy; // 一定要警醒, 这里会不会有 assign 操作符的调用
        }
    }
    return *this;
}

template <typename T>
QVector<T> &QVector<T>::operator+=(const QVector &l)
{
    if (backingStore == Data::sharedNull()) {
        *this = l;
    } else {
        uint newSize = backingStore->size + l.backingStore->size;
        const bool isTooSmall = newSize > backingStore->alloc;
        if (!isDetached() || isTooSmall) {
            QArrayData::AllocationOptions opt(isTooSmall ? QArrayData::Grow : QArrayData::Default);
            reallocData(backingStore->size, isTooSmall ? newSize : backingStore->alloc, opt);
        }

        if (backingStore->alloc) {
            T *w = backingStore->begin() + newSize;
            T *i = l.backingStore->end();
            T *b = l.backingStore->begin();
            while (i != b) {
                if (QTypeInfo<T>::isComplex)
                    new (--w) T(*--i);
                else
                    *--w = *--i;
            }
            backingStore->size = newSize;
        }
    }
    return *this;
}

// index 就是线性查找.
template <typename T>
int QVector<T>::indexOf(const T &t, int from) const
{
    if (from < 0)
        from = qMax(from + backingStore->size, 0);
    if (from < backingStore->size) {
        T* n = backingStore->begin() + from - 1;
        T* e = backingStore->end();
        while (++n != e)
            if (*n == t) // 这里, 使用了等号操作符这一统一的抽象, 进行相等性判断.
                return n - backingStore->begin();
    }
    return -1;
}

template <typename T>
int QVector<T>::lastIndexOf(const T &t, int from) const
{
    if (from < 0)
        from += backingStore->size;
    else if (from >= backingStore->size)
        from = backingStore->size-1;
    if (from >= 0) {
        T* b = backingStore->begin();
        T* n = backingStore->begin() + from + 1;
        while (n != b) {
            if (*--n == t)
                return n - b;
        }
    }
    return -1;
}

// 其实就是线性查找.
template <typename T>
bool QVector<T>::contains(const T &t) const
{
    const T *b = backingStore->begin();
    const T *e = backingStore->end();
    return std::find(b, e, t) != e;
}

// 其实就是线性查找.
template <typename T>
int QVector<T>::count(const T &t) const
{
    const T *b = backingStore->begin();
    const T *e = backingStore->end();
    return int(std::count(b, e, t));
}

template <typename T>
Q_OUTOFLINE_TEMPLATE QVector<T> QVector<T>::mid(int pos, int len) const
{
    using namespace QtPrivate;
    switch (QContainerImplHelper::mid(backingStore->size, &pos, &len)) {
    case QContainerImplHelper::Null:
    case QContainerImplHelper::Empty:
        return QVector<T>();
    case QContainerImplHelper::Full:
        return *this;
    case QContainerImplHelper::Subset:
        break;
    }

    QVector<T> midResult;
    midResult.reallocData(0, len);
    T *srcFrom = backingStore->begin() + pos;
    T *srcTo = backingStore->begin() + pos + len;
    midResult.copyConstruct(srcFrom, srcTo, midResult.data());
    midResult.backingStore->size = len;
    return midResult;
}

template <typename T>
Q_OUTOFLINE_TEMPLATE QList<T> QVector<T>::toList() const
{
    QList<T> result;
    result.reserve(size());
    for (int i = 0; i < size(); ++i)
        result.append(at(i));
    return result;
}

template <typename T>
Q_OUTOFLINE_TEMPLATE QVector<T> QList<T>::toVector() const
{
    QVector<T> result(size());
    for (int i = 0; i < size(); ++i)
        result[i] = at(i);
    return result;
}

template <typename T>
QVector<T> QVector<T>::fromList(const QList<T> &list)
{
    return list.toVector();
}

template <typename T>
QList<T> QList<T>::fromVector(const QVector<T> &vector)
{
    return vector.toList();
}

Q_DECLARE_SEQUENTIAL_ITERATOR(Vector)
Q_DECLARE_MUTABLE_SEQUENTIAL_ITERATOR(Vector)

template <typename T>
uint qHash(const QVector<T> &key, uint seed = 0)
    Q_DECL_NOEXCEPT_EXPR(noexcept(qHashRange(key.cbegin(), key.cend(), seed)))
{
    return qHashRange(key.cbegin(), key.cend(), seed);
}

template <typename T>
bool operator<(const QVector<T> &lhs, const QVector<T> &rhs)
    Q_DECL_NOEXCEPT_EXPR(noexcept(std::lexicographical_compare(lhs.begin(), lhs.end(),
                                                               rhs.begin(), rhs.end())))
{
    return std::lexicographical_compare(lhs.begin(), lhs.end(),
                                        rhs.begin(), rhs.end());
}

template <typename T>
inline bool operator>(const QVector<T> &lhs, const QVector<T> &rhs)
    Q_DECL_NOEXCEPT_EXPR(noexcept(lhs < rhs))
{
    return rhs < lhs;
}

template <typename T>
inline bool operator<=(const QVector<T> &lhs, const QVector<T> &rhs)
    Q_DECL_NOEXCEPT_EXPR(noexcept(lhs < rhs))
{
    return !(lhs > rhs);
}

template <typename T>
inline bool operator>=(const QVector<T> &lhs, const QVector<T> &rhs)
    Q_DECL_NOEXCEPT_EXPR(noexcept(lhs < rhs))
{
    return !(lhs < rhs);
}

/*
   ### Qt 5:
   ### This needs to be removed for next releases of Qt. It is a workaround for vc++ because
   ### Qt exports QPolygon and QPolygonF that inherit QVector<QPoint> and
   ### QVector<QPointF> respectively.
*/

QVector<uint> QStringView::toUcs4() const { return QtPrivate::convertToUcs4(*this); }

QT_END_NAMESPACE

#endif // QVECTOR_H
