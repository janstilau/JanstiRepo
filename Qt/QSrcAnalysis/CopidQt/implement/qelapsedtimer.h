#ifndef QELAPSEDTIMER_H
#define QELAPSEDTIMER_H

#include <QtCore/qglobal.h>

QT_BEGIN_NAMESPACE


// 这个类, 主要用来做耗时的统计. Qt 居然还专门写了这种小的工具类出来了.
// The QElapsedTimer class is usually used to quickly calculate how much time has elapsed between two events.
// 使用 timer.start(); timer.elapsed() 就能达到目的.
class Q_CORE_EXPORT QElapsedTimer
{
public:
    enum ClockType {
        SystemTime,
        MonotonicClock,
        TickCounter,
        MachAbsoluteTime,
        PerformanceCounter
    };

    Q_DECL_CONSTEXPR QElapsedTimer()
        : t1(Q_INT64_C(0x8000000000000000)),
          t2(Q_INT64_C(0x8000000000000000))
    {
    }

    static ClockType clockType() Q_DECL_NOTHROW;
    static bool isMonotonic() Q_DECL_NOTHROW;

    void start() Q_DECL_NOTHROW;
    qint64 restart() Q_DECL_NOTHROW;
    void invalidate() Q_DECL_NOTHROW;
    bool isValid() const Q_DECL_NOTHROW;

    qint64 nsecsElapsed() const Q_DECL_NOTHROW;
    qint64 elapsed() const Q_DECL_NOTHROW;
    bool hasExpired(qint64 timeout) const Q_DECL_NOTHROW;

    qint64 msecsSinceReference() const Q_DECL_NOTHROW;
    qint64 msecsTo(const QElapsedTimer &other) const Q_DECL_NOTHROW;
    qint64 secsTo(const QElapsedTimer &other) const Q_DECL_NOTHROW;

    bool operator==(const QElapsedTimer &other) const Q_DECL_NOTHROW
    { return t1 == other.t1 && t2 == other.t2; }
    bool operator!=(const QElapsedTimer &other) const Q_DECL_NOTHROW
    { return !(*this == other); }

    friend bool Q_CORE_EXPORT operator<(const QElapsedTimer &v1, const QElapsedTimer &v2) Q_DECL_NOTHROW;

private:
    qint64 t1;
    qint64 t2;
};

QT_END_NAMESPACE

#endif // QELAPSEDTIMER_H
