#ifndef QTHREAD_H
#define QTHREAD_H

#include <QtCore/qobject.h>

// For QThread::create. The configure-time test just checks for the availability
// of std::future and std::async; for the C++17 codepath we perform some extra
// checks here (for std::invoke and C++14 lambdas).
#if QT_CONFIG(cxx11_future)
#  include <future> // for std::async
#  include <functional> // for std::invoke; no guard needed as it's a C++98 header

#  if defined(__cpp_lib_invoke) && __cpp_lib_invoke >= 201411 \
      && defined(__cpp_init_captures) && __cpp_init_captures >= 201304 \
      && defined(__cpp_generic_lambdas) &&  __cpp_generic_lambdas >= 201304
#    define QTHREAD_HAS_VARIADIC_CREATE
#  endif
#endif

#include <limits.h>

QT_BEGIN_NAMESPACE


class QThreadData;
class QThreadPrivate;
class QAbstractEventDispatcher;

class Q_CORE_EXPORT QThread : public QObject
{
    Q_OBJECT
public:
    enum Priority {
        IdlePriority,

        LowestPriority,
        LowPriority,
        NormalPriority,
        HighPriority,
        HighestPriority,

        TimeCriticalPriority,

        InheritPriority
    };


    static Qt::HANDLE currentThreadId() Q_DECL_NOTHROW Q_DECL_PURE_FUNCTION;
    static QThread *currentThread();
    static int idealThreadCount() Q_DECL_NOTHROW;
    static void yieldCurrentThread();

    explicit QThread(QObject *parent = nullptr);
    ~QThread();

    void setPriority(Priority priority);
    Priority priority() const;

    bool isFinished() const;
    bool isRunning() const;

    void requestInterruption();
    bool isInterruptionRequested() const;

    void setStackSize(uint stackSize);
    uint stackSize() const;

    void exit(int retcode = 0);

    QAbstractEventDispatcher *eventDispatcher() const;
    void setEventDispatcher(QAbstractEventDispatcher *eventDispatcher);

    bool event(QEvent *event) override;
    int loopLevel() const;

    template <typename Function>
    static QThread *create(Function &&f);

public Q_SLOTS:
    void start(Priority = InheritPriority);
    void terminate();
    void quit();

public:
    // default argument causes thread to block indefinetely
    bool wait(unsigned long time = ULONG_MAX);

    static void sleep(unsigned long);
    static void msleep(unsigned long);
    static void usleep(unsigned long);

Q_SIGNALS:
    void started(QPrivateSignal);
    void finished(QPrivateSignal);

protected:
    virtual void run();
    int exec();

    static void setTerminationEnabled(bool enabled = true);

protected:
    QThread(QThreadPrivate &dd, QObject *parent = nullptr);

private:
    Q_DECLARE_PRIVATE(QThread)

#if QT_CONFIG(cxx11_future)
    static QThread *createThreadImpl(std::future<void> &&future);
#endif

    friend class QCoreApplication;
    friend class QThreadData;
};

#if QT_CONFIG(cxx11_future)

// C++11: same as C++14, but with a workaround for not having generalized lambda captures
namespace QtPrivate {
template <typename Function>
struct Callable
{
    explicit Callable(Function &&f)
        : m_function(std::forward<Function>(f))
    {
    }

#if defined(Q_COMPILER_DEFAULT_MEMBERS) && defined(Q_COMPILER_DELETE_MEMBERS)
    // Apply the same semantics of a lambda closure type w.r.t. the special
    // member functions, if possible: delete the copy assignment operator,
    // bring back all the others as per the RO5 (cf. §8.1.5.1/11 [expr.prim.lambda.closure])
    ~Callable() = default;
    Callable(const Callable &) = default;
    Callable(Callable &&) = default;
    Callable &operator=(const Callable &) = delete;
    Callable &operator=(Callable &&) = default;
    void operator()()
    {
        (void)m_function();
    }

    typename std::decay<Function>::type m_function;
};
} // namespace QtPrivate

template <typename Function>
QThread *QThread::create(Function &&f)
{
    return createThreadImpl(std::async(std::launch::deferred, QtPrivate::Callable<Function>(std::forward<Function>(f))));
}
#endif // QTHREAD_HAS_VARIADIC_CREATE

#endif // QT_CONFIG(cxx11_future)

QT_END_NAMESPACE

#endif // QTHREAD_H
