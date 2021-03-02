#ifndef QCACHE_H
#define QCACHE_H

#include <QtCore/qhash.h>

QT_BEGIN_NAMESPACE

// 这个类, 再次证明了, 链表 + Hash 的强大的作用
// 链表, 进行顺序的管理, Hash 提供强大的快速的查询服务.
template <class Key, class T>
class QCache
{
    // 这里, keyPtr 没有作用.
    // 感觉还是应该存一下 KeyPtr, 就像 iOS 里面的 copy 一样.
    struct Node {
        inline Node() : keyPtr(0) {}
        inline Node(T *data, int cost)
            : keyPtr(0), valuePtr(data), cost(cost), previous(0), next(0) {}
        const Key *keyPtr;
        T *valuePtr;
        int cost;
        Node *previous,*next; // previous, next 的指针, 所以其实还是链表存储.
    };

    Node *first, *last; // first, last
    QHash<Key, Node> hash;

    int maxCost, total;

    inline void unlink(Node &n) {
        if (n.previous) n.previous->next = n.next;
        if (n.next) n.next->previous = n.previous;
        if (last == &n) last = n.previous;
        if (first == &n) first = n.next;
        total -= n.cost;
        T *obj = n.valuePtr;
        hash.remove(*n.keyPtr);
        // 这里, 提交给 Cache 类的数据, 在从 Cache 类的时候, 被 delete 掉了.
        // 感觉应该是外界主动进行 delete.
        // 这也就是 C++ 内存管理的难点. 如何设计都是合理的. Cache 也可以作为, 数据的最终管理者.
        delete obj;
    }

    // 将数据, 从当前的位置, 转移到开始的位置.
    // 所以 Cache 这个类, 是按照 FIFO 的管理策略, 管理的内存.
    inline T *relink(const Key &key) {
        typename QHash<Key, Node>::iterator i = hash.find(key);
        if (typename QHash<Key, Node>::const_iterator(i) == hash.constEnd())
            return 0;

        Node &n = *i;
        if (first != &n) {
            if (n.previous) n.previous->next = n.next;
            if (n.next) n.next->previous = n.previous;
            if (last == &n) last = n.previous;
            n.previous = 0;
            n.next = first;
            first->previous = &n;
            first = &n;
        }
        return n.valuePtr;
    }

    Q_DISABLE_COPY(QCache)

public:
    inline explicit QCache(int maxCost = 100) Q_DECL_NOTHROW;
    inline ~QCache() { clear(); }

    inline int maxCost() const { return maxCost; }
    void setMaxCost(int m);
    inline int totalCost() const { return total; }

    inline int size() const { return hash.size(); }
    inline int count() const { return hash.size(); }
    inline bool isEmpty() const { return hash.isEmpty(); }
    inline QList<Key> keys() const { return hash.keys(); }

    void clear();

    // 默认是 1, 也就是当 Object 没有提供 cost 的考虑的时候, 可以用数量这件事来考虑.
    bool insert(const Key &key, T *object, int cost = 1);
    T *object(const Key &key) const;
    inline bool contains(const Key &key) const { return hash.contains(key); }
    T *operator[](const Key &key) const;

    bool remove(const Key &key);
    T *take(const Key &key);

private:
    void trim(int m);
};

template <class Key, class T>
inline QCache<Key, T>::QCache(int amaxCost) Q_DECL_NOTHROW
    : first(0), last(0), maxCost(amaxCost), total(0) {}

template <class Key, class T>
inline void QCache<Key,T>::clear()
{ while (first) { delete first->valuePtr; first = first->next; }
 hash.clear(); last = 0; total = 0; }

template <class Key, class T>
inline void QCache<Key,T>::setMaxCost(int m)
{ maxCost = m; trim(maxCost); }

template <class Key, class T>
inline T *QCache<Key,T>::object(const Key &key) const
{ return const_cast<QCache<Key,T>*>(this)->relink(key); }

// operator[] 调用 object(const Key &key), 同样的返回值类型, 所有的逻辑, 集中到了 object(const Key &key) 的内部
// 之所以, 有 operator[]  的存在, 是因为这是一个统一的, 标准的外界的使用方式.
template <class Key, class T>
inline T *QCache<Key,T>::operator[](const Key &key) const
{ return object(key); }

template <class Key, class T>
inline bool QCache<Key,T>::remove(const Key &key)
{
    // 首先, Hash 查找, 然后链表中删除, hash 表中删除, delete value.
    typename QHash<Key, Node>::iterator i = hash.find(key);
    if (typename QHash<Key, Node>::const_iterator(i) == hash.constEnd()) {
        return false;
    } else {
        unlink(*i);
        return true;
    }
}

// take, 就是释放 Cache 类对于对应数据的管理, 所以在 Unlick 之前, 进行 valuePtr 的清空.
// 从这个方法来看, Cache 这个类, 是有着管理资源生命周期的责任的.
template <class Key, class T>
inline T *QCache<Key,T>::take(const Key &key)
{
    typename QHash<Key, Node>::iterator i = hash.find(key);
    if (i == hash.end())
        return 0;

    Node &n = *i;
    T *t = n.valuePtr;
    n.valuePtr = 0;
    unlink(n);
    return t;
}

template <class Key, class T>
bool QCache<Key,T>::insert(const Key &akey, T *aobject, int acost)
{
    // 先删除原来的.
    remove(akey);
    if (acost > maxCost) {
        delete aobject;
        return false;
    }
    trim(maxCost - acost);
    Node insertedNode(aobject, acost);
    // 这里, 并没有使用 move, 因为实际上, 对于不用指针代表资源的类来说, 没有意义使用 move.
    typename QHash<Key, Node>::iterator i = hash.insert(akey, insertedNode);
    total += acost;
    Node *n = &i.value();
    n->keyPtr = &i.key();
    // 从这里来看, 是按照时间顺序, 进行的链表的管理.
    if (first) first->previous = n;
    n->next = first;
    first = n;
    if (!last) last = first;
    return true;
}

template <class Key, class T>
void QCache<Key,T>::trim(int m)
{
    // 按照时间顺序, 从后向前, 清理数据.
    Node *n = last;
    while (n && total > m) {
        Node *u = n;
        n = n->previous;
        unlink(*u);
    }
}

QT_END_NAMESPACE

#endif // QCACHE_H
