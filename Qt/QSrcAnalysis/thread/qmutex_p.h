#ifndef QMUTEX_P_H
#define QMUTEX_P_H


#include <QtCore/private/qglobal_p.h>
#include <QtCore/qnamespace.h>
#include <QtCore/qmutex.h>
#include <QtCore/qatomic.h>


struct timespec;

QT_BEGIN_NAMESPACE

class QMutexData
{
public:
    bool recursive;
    QMutexData(QMutex::RecursionMode mode = QMutex::NonRecursive)
        : recursive(mode == QMutex::Recursive) {}
};

#if !defined(QT_LINUX_FUTEX)
class QMutexPrivate : public QMutexData
{
public:
    ~QMutexPrivate();
    QMutexPrivate();

    bool wait(int timeout = -1);
    void wakeUp() Q_DECL_NOTHROW;

    // Control the lifetime of the privates
    QAtomicInt refCount;
    int id;

    bool ref() {
        int c;
        do {
            c = refCount.load();
            if (c == 0)
                return false;
        } while (!refCount.testAndSetRelaxed(c, c + 1));
        return true;
    }
    void deref() {
        if (!refCount.deref())
            release();
    }
    void release();
    static QMutexPrivate *allocate();

    QAtomicInt waiters; // Number of threads waiting on this mutex. (may be offset by -BigNumber)
    QAtomicInt possiblyUnlocked; /* Boolean indicating that a timed wait timed out.
                                    When it is true, a reference is held.
                                    It is there to avoid a race that happens if unlock happens right
                                    when the mutex is unlocked.
                                  */
    enum { BigNumber = 0x100000 }; //Must be bigger than the possible number of waiters (number of threads)
    void derefWaiters(int value) Q_DECL_NOTHROW;

    bool wakeup;
    pthread_mutex_t mutex;
    pthread_cond_t cond;
};
#endif //QT_LINUX_FUTEX


#ifdef Q_OS_UNIX
// helper functions for qmutex_unix.cpp and qwaitcondition_unix.cpp
// they are in qwaitcondition_unix.cpp actually
void qt_initialize_pthread_cond(pthread_cond_t *cond, const char *where);
void qt_abstime_for_timeout(struct timespec *ts, int timeout);
#endif

QT_END_NAMESPACE

#endif // QMUTEX_P_H
