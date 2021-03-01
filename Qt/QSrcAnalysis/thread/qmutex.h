#ifndef QMUTEX_H
#define QMUTEX_H

#include <QtCore/qglobal.h>
#include <QtCore/qatomic.h>
#include <new>

class tst_QMutex;

QT_BEGIN_NAMESPACE


class QMutexData;

class QBasicMutex
{
public:
    // BasicLockable concept
    inline void lock() {
        lockInternal();
    }

    // BasicLockable concept
    inline void unlock() Q_DECL_NOTHROW {
        Q_ASSERT(d_ptr.load()); //mutex must be locked
        if (!fastTryUnlock())
            unlockInternal();
    }

    bool tryLock() Q_DECL_NOTHROW {
        return fastTryLock();
    }

    // Lockable concept
    bool try_lock() Q_DECL_NOTHROW { return tryLock(); }

    bool isRecursive() Q_DECL_NOTHROW; //### Qt6: remove me
    bool isRecursive() const Q_DECL_NOTHROW;

private:
    inline bool fastTryLock() Q_DECL_NOTHROW {
        return d_ptr.testAndSetAcquire(Q_NULLPTR, dummyLocked());
    }
    inline bool fastTryUnlock() Q_DECL_NOTHROW {
        return d_ptr.testAndSetRelease(dummyLocked(), Q_NULLPTR);
    }
    inline bool fastTryLock(QMutexData *&current) Q_DECL_NOTHROW {
        return d_ptr.testAndSetAcquire(Q_NULLPTR, dummyLocked(), current);
    }
    inline bool fastTryUnlock(QMutexData *&current) Q_DECL_NOTHROW {
        return d_ptr.testAndSetRelease(dummyLocked(), Q_NULLPTR, current);
    }

    void lockInternal() QT_MUTEX_LOCK_NOEXCEPT;
    bool lockInternal(int timeout) QT_MUTEX_LOCK_NOEXCEPT;
    void unlockInternal() Q_DECL_NOTHROW;

    QBasicAtomicPointer<QMutexData> d_ptr;
    static inline QMutexData *dummyLocked() {
        return reinterpret_cast<QMutexData *>(quintptr(1));
    }

    friend class QMutex;
    friend class QMutexData;
};

class Q_CORE_EXPORT QMutex : public QBasicMutex
{
public:
    enum RecursionMode { NonRecursive, Recursive };
    explicit QMutex(RecursionMode mode = NonRecursive);
    ~QMutex();

    // BasicLockable concept
    void lock() QT_MUTEX_LOCK_NOEXCEPT;
    bool tryLock(int timeout = 0) QT_MUTEX_LOCK_NOEXCEPT;
    // BasicLockable concept
    void unlock() Q_DECL_NOTHROW;

    // Lockable concept
    bool try_lock() QT_MUTEX_LOCK_NOEXCEPT { return tryLock(); }

    bool isRecursive() const Q_DECL_NOTHROW
    { return QBasicMutex::isRecursive(); }

private:
    Q_DISABLE_COPY(QMutex)
    friend class QMutexLocker;
    friend class ::tst_QMutex;
};

// Qt 版本的
class Q_CORE_EXPORT QMutexLocker
{
public:
    // RAII 就是, 在构造函数里面就做事情.
    // 传递过来的指针, 经过了一次处理, 应该是利用了指针的某几位做标记. 如果已经 lock 过了, 那么就将标志位改变.
    // Mutex 是没有函数, 表明自己是否已经上过锁了, 只能是管理类自己记录.
    inline explicit QMutexLocker(QBasicMutex *m) QT_MUTEX_LOCK_NOEXCEPT
    {
        val = quintptr(m);
        if (Q_LIKELY(m)) {
            // call QMutex::lock() instead of QBasicMutex::lock()
            static_cast<QMutex *>(m)->lock();
            val |= 1;
        }
    }
    // 在析构函数里面, 做 unlock 的事情.
    inline ~QMutexLocker() { unlock(); }

    inline void unlock() Q_DECL_NOTHROW
    {
        if ((val & quintptr(1u)) == quintptr(1u)) {
            val &= ~quintptr(1u);
            mutex()->unlock();
        }
    }

    inline void relock() QT_MUTEX_LOCK_NOEXCEPT
    {
        if (val) {
            if ((val & quintptr(1u)) == quintptr(0u)) {
                mutex()->lock();
                val |= quintptr(1u);
            }
        }
    }

    inline QMutex *mutex() const
    {
        return reinterpret_cast<QMutex *>(val & ~quintptr(1u));
    }

private:
    Q_DISABLE_COPY(QMutexLocker) // 不可以拷贝.

    quintptr val; // 存储, mutex 指针.
};

#else // QT_NO_THREAD && !Q_CLANG_QDOC

#endif // QT_NO_THREAD && !Q_CLANG_QDOC

QT_END_NAMESPACE

#endif // QMUTEX_H
