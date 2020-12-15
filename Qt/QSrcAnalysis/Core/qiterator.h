#ifndef QITERATOR_H
#define QITERATOR_H

#include <QtCore/qglobal.h>

QT_BEGIN_NAMESPACE

// Qt 对于 Java 风格的迭代器的实现, 其实也是建立在 STL 的基础上实现的.
// QListIterator<T>	QMutableListIterator<T>
// QListIterator<QString> i(list);
// while (i.hasNext()) {
//     qDebug() << i.next();
// }
// 使用 JAVA 风格的遍历器, 要使用构造函数来生成对应的对象.

#define Q_DECLARE_SEQUENTIAL_ITERATOR(C) \
\
template <class T> \
class Q##C##Iterator \
{ \
    typedef typename Q##C<T>::const_iterator const_iterator; \
    Q##C<T> c; \
    const_iterator i; \
public: \
    inline Q##C##Iterator(const Q##C<T> &container) \
        : c(container), i(c.constBegin()) {} \
    inline Q##C##Iterator &operator=(const Q##C<T> &container) \
    { c = container; i = c.constBegin(); return *this; } \
    inline void toFront() { i = c.constBegin(); } \
    inline void toBack() { i = c.constEnd(); } \
    inline bool hasNext() const { return i != c.constEnd(); } \
    inline const T &next() { return *i++; } \
    inline const T &peekNext() const { return *i; } \
    inline bool hasPrevious() const { return i != c.constBegin(); } \
    inline const T &previous() { return *--i; } \
    inline const T &peekPrevious() const { const_iterator p = i; return *--p; } \
    inline bool findNext(const T &t) \
    { while (i != c.constEnd()) if (*i++ == t) return true; return false; } \
    inline bool findPrevious(const T &t) \
    { while (i != c.constBegin()) if (*(--i) == t) return true; \
      return false;  } \
};

// 可以看到, 上面的各种操作, 不过是通过容器, 以及迭代器的包装而已.
// Java 风格的迭代器, 是一个适配器. 因为有着 hasPrevious, toFront 这些操作, 所以, 必须存储一下重启本身.
// 还有一点需要注意的是, Qt 的容器在复制的时候, 不会有大量的数据复制的过程.
// 上面的迭代器是 const 的, 所以不可以修改当前指向的内容.

#define Q_DECLARE_MUTABLE_SEQUENTIAL_ITERATOR(C) \
\
template <class T> \
class QMutable##C##Iterator \
{ \
    typedef typename Q##C<T>::iterator iterator; \
    typedef typename Q##C<T>::const_iterator const_iterator; \
    Q##C<T> *c; \
    iterator i, n; \
    inline bool item_exists() const { return const_iterator(n) != c->constEnd(); } \
public: \
    inline QMutable##C##Iterator(Q##C<T> &container) \
        : c(&container) \
    { i = c->begin(); n = c->end(); } \
    inline QMutable##C##Iterator &operator=(Q##C<T> &container) \
    { c = &container; i = c->begin(); n = c->end(); return *this; } \
    inline void toFront() { i = c->begin(); n = c->end(); } \
    inline void toBack() { i = c->end(); n = i; } \
    inline bool hasNext() const { return c->constEnd() != const_iterator(i); } \
    inline T &next() { n = i++; return *n; } \
    inline T &peekNext() const { return *i; } \
    inline bool hasPrevious() const { return c->constBegin() != const_iterator(i); } \
    inline T &previous() { n = --i; return *n; } \
    inline T &peekPrevious() const { iterator p = i; return *--p; } \
    inline void remove() \
    { if (c->constEnd() != const_iterator(n)) { i = c->erase(n); n = c->end(); } } \
    inline void setValue(const T &t) const { if (c->constEnd() != const_iterator(n)) *n = t; } \
    inline T &value() { Q_ASSERT(item_exists()); return *n; } \
    inline const T &value() const { Q_ASSERT(item_exists()); return *n; } \
    inline void insert(const T &t) { n = i = c->insert(i, t); ++i; } \
    inline bool findNext(const T &t) \
    { while (c->constEnd() != const_iterator(n = i)) if (*i++ == t) return true; return false; } \
    inline bool findPrevious(const T &t) \
    { while (c->constBegin() != const_iterator(i)) if (*(n = --i) == t) return true; \
      n = c->end(); return false;  } \
};

#define Q_DECLARE_ASSOCIATIVE_ITERATOR(C) \
\
template <class Key, class T> \
class Q##C##Iterator \
{ \
    typedef typename Q##C<Key,T>::const_iterator const_iterator; \
    typedef const_iterator Item; \
    Q##C<Key,T> c; \
    const_iterator i, n; \
    inline bool item_exists() const { return n != c.constEnd(); } \
public: \
    inline Q##C##Iterator(const Q##C<Key,T> &container) \
        : c(container), i(c.constBegin()), n(c.constEnd()) {} \
    inline Q##C##Iterator &operator=(const Q##C<Key,T> &container) \
    { c = container; i = c.constBegin(); n = c.constEnd(); return *this; } \
    inline void toFront() { i = c.constBegin(); n = c.constEnd(); } \
    inline void toBack() { i = c.constEnd(); n = c.constEnd(); } \
    inline bool hasNext() const { return i != c.constEnd(); } \
    inline Item next() { n = i++; return n; } \
    inline Item peekNext() const { return i; } \
    inline bool hasPrevious() const { return i != c.constBegin(); } \
    inline Item previous() { n = --i; return n; } \
    inline Item peekPrevious() const { const_iterator p = i; return --p; } \
    inline const T &value() const { Q_ASSERT(item_exists()); return *n; } \
    inline const Key &key() const { Q_ASSERT(item_exists()); return n.key(); } \
    inline bool findNext(const T &t) \
    { while ((n = i) != c.constEnd()) if (*i++ == t) return true; return false; } \
    inline bool findPrevious(const T &t) \
    { while (i != c.constBegin()) if (*(n = --i) == t) return true; \
      n = c.constEnd(); return false; } \
};

#define Q_DECLARE_MUTABLE_ASSOCIATIVE_ITERATOR(C) \
\
template <class Key, class T> \
class QMutable##C##Iterator \
{ \
    typedef typename Q##C<Key,T>::iterator iterator; \
    typedef typename Q##C<Key,T>::const_iterator const_iterator; \
    typedef iterator Item; \
    Q##C<Key,T> *c; \
    iterator i, n; \
    inline bool item_exists() const { return const_iterator(n) != c->constEnd(); } \
public: \
    inline QMutable##C##Iterator(Q##C<Key,T> &container) \
        : c(&container) \
    { i = c->begin(); n = c->end(); } \
    inline QMutable##C##Iterator &operator=(Q##C<Key,T> &container) \
    { c = &container; i = c->begin(); n = c->end(); return *this; } \
    inline void toFront() { i = c->begin(); n = c->end(); } \
    inline void toBack() { i = c->end(); n = c->end(); } \
    inline bool hasNext() const { return const_iterator(i) != c->constEnd(); } \
    inline Item next() { n = i++; return n; } \
    inline Item peekNext() const { return i; } \
    inline bool hasPrevious() const { return const_iterator(i) != c->constBegin(); } \
    inline Item previous() { n = --i; return n; } \
    inline Item peekPrevious() const { iterator p = i; return --p; } \
    inline void remove() \
    { if (const_iterator(n) != c->constEnd()) { i = c->erase(n); n = c->end(); } } \
    inline void setValue(const T &t) { if (const_iterator(n) != c->constEnd()) *n = t; } \
    inline T &value() { Q_ASSERT(item_exists()); return *n; } \
    inline const T &value() const { Q_ASSERT(item_exists()); return *n; } \
    inline const Key &key() const { Q_ASSERT(item_exists()); return n.key(); } \
    inline bool findNext(const T &t) \
    { while (const_iterator(n = i) != c->constEnd()) if (*i++ == t) return true; return false; } \
    inline bool findPrevious(const T &t) \
    { while (const_iterator(i) != c->constBegin()) if (*(n = --i) == t) return true; \
      n = c->end(); return false; } \
};

template<typename Key, typename T, class Iterator>
class QKeyValueIterator
{
public:
    typedef typename Iterator::iterator_category iterator_category;
    typedef typename Iterator::difference_type difference_type;
    typedef std::pair<Key, T> value_type;
    typedef const value_type *pointer;
    typedef const value_type &reference;

    QKeyValueIterator() = default;
    Q_DECL_CONSTEXPR explicit QKeyValueIterator(Iterator o) Q_DECL_NOEXCEPT_EXPR(std::is_nothrow_move_constructible<Iterator>::value)
        : i(std::move(o)) {}

    std::pair<Key, T> operator*() const {
        return std::pair<Key, T>(i.key(), i.value());
    }

    friend bool operator==(QKeyValueIterator lhs, QKeyValueIterator rhs) Q_DECL_NOEXCEPT { return lhs.i == rhs.i; }
    friend bool operator!=(QKeyValueIterator lhs, QKeyValueIterator rhs) Q_DECL_NOEXCEPT { return lhs.i != rhs.i; }

    inline QKeyValueIterator &operator++() { ++i; return *this; }
    inline QKeyValueIterator operator++(int) { return QKeyValueIterator(i++);}
    inline QKeyValueIterator &operator--() { --i; return *this; }
    inline QKeyValueIterator operator--(int) { return QKeyValueIterator(i--); }
    Iterator base() const { return i; }

private:
    Iterator i;
};

QT_END_NAMESPACE

#endif // QITERATOR_H
