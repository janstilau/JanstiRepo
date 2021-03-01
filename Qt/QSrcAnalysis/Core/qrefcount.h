#ifndef QREFCOUNT_H
#define QREFCOUNT_H

#include <QtCore/qatomic.h>

QT_BEGIN_NAMESPACE


namespace QtPrivate
{

class RefCount
{
public:
    inline bool ref() Q_DECL_NOTHROW {
        int count = atomic.load();
        if (count == 0) // !isSharable
            return false;
        if (count != -1) // !isStatic
            atomic.ref();
        return true;
    }

    inline bool deref() Q_DECL_NOTHROW {
        int count = atomic.load();
        if (count == 0) // !isSharable
            return false;
        if (count == -1) // isStatic
            return true;
        return atomic.deref();
    }

#if !defined(QT_NO_UNSHARABLE_CONTAINERS)
    bool setSharable(bool sharable) Q_DECL_NOTHROW
    {
        Q_ASSERT(!isShared());
        if (sharable)
            return atomic.testAndSetRelaxed(0, 1);
        else
            return atomic.testAndSetRelaxed(1, 0);
    }

    bool isSharable() const Q_DECL_NOTHROW
    {
        // Sharable === Shared ownership.
        return atomic.load() != 0;
    }
#endif

    // 如果, 是静态值, 那么就是 atomic 里面存储 -1
    bool isStatic() const Q_DECL_NOTHROW
    {
        return atomic.load() == -1;
    }

    // 如果, count 不是 0, 也不是 1, 那么就是多个对象在引用着同一个 refCount .
    bool isShared() const Q_DECL_NOTHROW
    {
        int count = atomic.load();
        return (count != 1) && (count != 0);
    }

    void initializeOwned() Q_DECL_NOTHROW { atomic.store(1); }
    void initializeUnsharable() Q_DECL_NOTHROW { atomic.store(0); }

    QBasicAtomicInt atomic; // 实际, 就是一个 Int 值.
};

}

#define Q_REFCOUNT_INITIALIZE_STATIC { Q_BASIC_ATOMIC_INITIALIZER(-1) }

QT_END_NAMESPACE

#endif
