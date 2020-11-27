#ifndef QMUTEX_H
#define QMUTEX_H

#include <QtCore/qglobal.h>
#include <QtCore/qatomic.h>
#include <new>

#if QT_HAS_INCLUDE(<chrono>)
#endif

class tst_QMutex;

QT_BEGIN_NAMESPACE


#if !defined(QT_NO_THREAD) || defined(Q_CLANG_QDOC)

#ifdef Q_OS_LINUX
# define QT_MUTEX_LOCK_NOEXCEPT Q_DECL_NOTHROW
#else
# define QT_MUTEX_LOCK_NOEXCEPT
#endif

class QMutexData;

class Q_CORE_EXPORT QBasicMutex
{
public:
    // BasicLockable concept
    inline void lock() QT_MUTEX_LOCK_NOEXCEPT {
        if (!fastTryLock())
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

class Q_CORE_EXPORT QMutexLocker
{
public:
    inline explicit QMutexLocker(QBasicMutex *m) QT_MUTEX_LOCK_NOEXCEPT
    {
        Q_ASSERT_X((reinterpret_cast<quintptr>(m) & quintptr(1u)) == quintptr(0),
                   "QMutexLocker", "QMutex pointer is misaligned");
        val = quintptr(m);
        if (Q_LIKELY(m)) {
            // call QMutex::lock() instead of QBasicMutex::lock()
            static_cast<QMutex *>(m)->lock();
            val |= 1;
        }
    }
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
    Q_DISABLE_COPY(QMutexLocker)

    quintptr val;
};

#else // QT_NO_THREAD && !Q_CLANG_QDOC

#endif // QT_NO_THREAD && !Q_CLANG_QDOC

QT_END_NAMESPACE

#endif // QMUTEX_H
