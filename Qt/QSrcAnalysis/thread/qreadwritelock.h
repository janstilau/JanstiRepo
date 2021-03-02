#ifndef QREADWRITELOCK_H
#define QREADWRITELOCK_H

#include <QtCore/qglobal.h>

QT_BEGIN_NAMESPACE


#ifndef QT_NO_THREAD

class QReadWriteLockPrivate;

class Q_CORE_EXPORT QReadWriteLock
{
public:
    enum RecursionMode { NonRecursive, Recursive };

    explicit QReadWriteLock(RecursionMode recursionMode = NonRecursive);
    ~QReadWriteLock();

    void lockForRead();
    bool tryLockForRead();
    bool tryLockForRead(int timeout);

    void lockForWrite();
    bool tryLockForWrite();
    bool tryLockForWrite(int timeout);

    void unlock();

private:
    Q_DISABLE_COPY(QReadWriteLock)
    QAtomicPointer<QReadWriteLockPrivate> d_ptr;

    enum StateForWaitCondition { LockedForRead, LockedForWrite, Unlocked, RecursivelyLocked };
    StateForWaitCondition stateForWaitCondition() const;
    friend class QWaitCondition;
};

class Q_CORE_EXPORT QReadLocker
{
public:
    inline QReadLocker(QReadWriteLock *readWriteLock);

    inline ~QReadLocker()
    { unlock(); }

    inline void unlock()
    {
        if (q_val) {
            if ((q_val & quintptr(1u)) == quintptr(1u)) {
                q_val &= ~quintptr(1u);
                readWriteLock()->unlock();
            }
        }
    }

    inline void relock()
    {
        if (q_val) {
            if ((q_val & quintptr(1u)) == quintptr(0u)) {
                readWriteLock()->lockForRead();
                q_val |= quintptr(1u);
            }
        }
    }

    inline QReadWriteLock *readWriteLock() const
    { return reinterpret_cast<QReadWriteLock *>(q_val & ~quintptr(1u)); }

private:
    Q_DISABLE_COPY(QReadLocker)
    quintptr q_val;
};

inline QReadLocker::QReadLocker(QReadWriteLock *areadWriteLock)
    : q_val(reinterpret_cast<quintptr>(areadWriteLock))
{
    Q_ASSERT_X((q_val & quintptr(1u)) == quintptr(0),
               "QReadLocker", "QReadWriteLock pointer is misaligned");
    relock();
}

class Q_CORE_EXPORT QWriteLocker
{
public:
    inline QWriteLocker(QReadWriteLock *readWriteLock);

    inline ~QWriteLocker()
    { unlock(); }

    inline void unlock()
    {
        if (q_val) {
            if ((q_val & quintptr(1u)) == quintptr(1u)) {
                q_val &= ~quintptr(1u);
                readWriteLock()->unlock();
            }
        }
    }

    inline void relock()
    {
        if (q_val) {
            if ((q_val & quintptr(1u)) == quintptr(0u)) {
                readWriteLock()->lockForWrite();
                q_val |= quintptr(1u);
            }
        }
    }

    inline QReadWriteLock *readWriteLock() const
    { return reinterpret_cast<QReadWriteLock *>(q_val & ~quintptr(1u)); }


private:
    Q_DISABLE_COPY(QWriteLocker)
    quintptr q_val;
};

inline QWriteLocker::QWriteLocker(QReadWriteLock *areadWriteLock)
    : q_val(reinterpret_cast<quintptr>(areadWriteLock))
{
    Q_ASSERT_X((q_val & quintptr(1u)) == quintptr(0),
               "QWriteLocker", "QReadWriteLock pointer is misaligned");
    relock();
}

#if defined(Q_CC_MSVC)
#pragma warning( pop )
#endif

#else // QT_NO_THREAD

class Q_CORE_EXPORT QReadWriteLock
{
public:
    enum RecursionMode { NonRecursive, Recursive };
    inline explicit QReadWriteLock(RecursionMode = NonRecursive) Q_DECL_NOTHROW { }
    inline ~QReadWriteLock() { }

    static inline void lockForRead() Q_DECL_NOTHROW { }
    static inline bool tryLockForRead() Q_DECL_NOTHROW { return true; }
    static inline bool tryLockForRead(int timeout) Q_DECL_NOTHROW { Q_UNUSED(timeout); return true; }

    static inline void lockForWrite() Q_DECL_NOTHROW { }
    static inline bool tryLockForWrite() Q_DECL_NOTHROW { return true; }
    static inline bool tryLockForWrite(int timeout) Q_DECL_NOTHROW { Q_UNUSED(timeout); return true; }

    static inline void unlock() Q_DECL_NOTHROW { }

private:
    Q_DISABLE_COPY(QReadWriteLock)
};

class Q_CORE_EXPORT QReadLocker
{
public:
    inline QReadLocker(QReadWriteLock *) Q_DECL_NOTHROW { }
    inline ~QReadLocker() Q_DECL_NOTHROW { }

    static inline void unlock() Q_DECL_NOTHROW { }
    static inline void relock() Q_DECL_NOTHROW { }
    static inline QReadWriteLock *readWriteLock() Q_DECL_NOTHROW { return Q_NULLPTR; }

private:
    Q_DISABLE_COPY(QReadLocker)
};

class Q_CORE_EXPORT QWriteLocker
{
public:
    inline explicit QWriteLocker(QReadWriteLock *) Q_DECL_NOTHROW { }
    inline ~QWriteLocker() Q_DECL_NOTHROW { }

    static inline void unlock() Q_DECL_NOTHROW { }
    static inline void relock() Q_DECL_NOTHROW { }
    static inline QReadWriteLock *readWriteLock() Q_DECL_NOTHROW { return Q_NULLPTR; }

private:
    Q_DISABLE_COPY(QWriteLocker)
};

#endif // QT_NO_THREAD

QT_END_NAMESPACE

#endif // QREADWRITELOCK_H
