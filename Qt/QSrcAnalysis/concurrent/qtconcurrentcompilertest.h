#ifndef QTCONCURRENT_COMPILERTEST_H
#define QTCONCURRENT_COMPILERTEST_H

#include <QtConcurrent/qtconcurrent_global.h>

#ifndef QT_NO_CONCURRENT

QT_BEGIN_NAMESPACE

namespace QtPrivate {

template<class T>
class HasResultType {
    typedef char Yes;
    typedef void *No;

    template<typename U> static Yes test(int, const typename U::result_type * = nullptr);
    template<typename U> static No test(double);

public:
    enum { Value = (sizeof(test<T>(0)) == sizeof(Yes)) };
};

}

QT_END_NAMESPACE

#endif // QT_NO_CONCURRENT

#endif
