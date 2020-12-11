#ifndef QPOINTER_H
#define QPOINTER_H

#include <QtCore/qsharedpointer.h>
#include <QtCore/qtypeinfo.h>

#ifndef QT_NO_QOBJECT

QT_BEGIN_NAMESPACE

class QVariant;

// 这里, QPointer 仅仅是对 QWeakPointer 的包装而已. 所以, 具体实现, 还是要去看一下 WeakPointer

//! 该类的实现原理.
//! 虽然该类内部使用了 WeakPointer, 但是不参与引用计数的过程.
//! 使用 QPointer 封装的 QObject*, 会在 OBjectPrivate 内部, 建立一个引用计数器, CountRef, 数据结构和 SharePointer, WeakPointer 中的相同, 然后将 CountRef 中强指针数设置为  -1, 弱指针数设置为 2. 当下一次再用 QPointer 封装同一对象时, 会拿到之前存储在 QObject 里面的 OBjectPrivate 进行操作.
//! QObject 的声明周期管理, 和该 CountRef 没有一点关系. 当  QObject 析构的时候, 会将 CountRef 中的强引用数设置为 0, 表明该对象已经析构. 而每一次 QPointer 的包装, 是增加的 CountRef 的弱引用数, 当 QPointer 销毁的时候, 也是修改 CountRef 的弱引用数, 当弱引用数为 0 时, CountRef 进行销毁.
//! QPointer 可以实现对象销毁时, 观察到对象被销毁, 是因为在对象内安插了 CountRef. 并且在对象析构的时候, 修改该数据. 每个 QPointer 创建析构, 都是修改 CountRef 的弱引用数据.

template <class T>
class QPointer
{
    template<typename U>
    struct TypeSelector
    {
        typedef QObject Type;
    };
    template<typename U>
    struct TypeSelector<const U>
    {
        typedef const QObject Type;
    };
    typedef typename TypeSelector<T>::Type QObjectType;

    QWeakPointer<QObjectType> wp;
public:
    inline QPointer() { }
    inline QPointer(T *p) : wp(p, true) { }
    // compiler-generated copy/move ctor/assignment operators are fine!
    // compiler-generated dtor is fine!

    inline void swap(QPointer &other) { wp.swap(other.wp); }

    inline QPointer<T> &operator=(T* p)
    { wp.assign(static_cast<QObjectType*>(p)); return *this; }

    // 这里, data() 方法的内部, 不会先进行 isNull 的判断. 所以, 一定要在使用 QPointer 之前, 先进行判断.
    inline T* data() const
    { return static_cast<T*>( wp.data()); }
    inline T* operator->() const
    { return data(); }
    inline T& operator*() const
    { return *data(); }
    inline operator T*() const
    { return data(); }

    inline bool isNull() const
    { return wp.isNull(); }

    inline void clear()
    { wp.clear(); }
};

template <class T> Q_DECLARE_TYPEINFO_BODY(QPointer<T>, Q_MOVABLE_TYPE);

// 操作符重载, C++ 有两种方式. 这里使用了函数的方式.
template <class T>
inline bool operator==(const T *o, const QPointer<T> &p)
{ return o == p.operator->(); }

template<class T>
inline bool operator==(const QPointer<T> &p, const T *o)
{ return p.operator->() == o; }

template <class T>
inline bool operator==(T *o, const QPointer<T> &p)
{ return o == p.operator->(); }

template<class T>
inline bool operator==(const QPointer<T> &p, T *o)
{ return p.operator->() == o; }

template<class T>
inline bool operator==(const QPointer<T> &p1, const QPointer<T> &p2)
{ return p1.operator->() == p2.operator->(); }

template <class T>
inline bool operator!=(const T *o, const QPointer<T> &p)
{ return o != p.operator->(); }

template<class T>
inline bool operator!= (const QPointer<T> &p, const T *o)
{ return p.operator->() != o; }

template <class T>
inline bool operator!=(T *o, const QPointer<T> &p)
{ return o != p.operator->(); }

template<class T>
inline bool operator!= (const QPointer<T> &p, T *o)
{ return p.operator->() != o; }

template<class T>
inline bool operator!= (const QPointer<T> &p1, const QPointer<T> &p2)
{ return p1.operator->() != p2.operator->() ; }

template<typename T>
QPointer<T>
qPointerFromVariant(const QVariant &variant)
{
    return QPointer<T>(qobject_cast<T*>(QtSharedPointer::weakPointerFromVariant_internal(variant).data()));
}

QT_END_NAMESPACE

#endif // QT_NO_QOBJECT

#endif // QPOINTER_H
