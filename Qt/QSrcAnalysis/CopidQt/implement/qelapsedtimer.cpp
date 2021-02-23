#include "qelapsedtimer.h"

QT_BEGIN_NAMESPACE

// 在类的内部, 定义一个特殊值.
// 在类的内部, 根据成员和这个特殊值的比较, 确定 valid 的状态.
// 在类的外部, 直接使用接口, 隐藏实现的细节.
static const qint64 invalidData = Q_INT64_C(0x8000000000000000);

void QElapsedTimer::invalidate() Q_DECL_NOTHROW
{
     t1 = t2 = invalidData;
}

bool QElapsedTimer::isValid() const Q_DECL_NOTHROW
{
    return t1 != invalidData && t2 != invalidData;
}

// 获取已经经过的时间, 和参数进行比较.
// 逻辑很简单, 但是封装使得这个类更加的好用.
bool QElapsedTimer::hasExpired(qint64 timeout) const Q_DECL_NOTHROW
{
    return quint64(elapsed()) > quint64(timeout);
}

QT_END_NAMESPACE
