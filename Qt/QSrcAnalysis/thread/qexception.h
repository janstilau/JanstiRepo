#ifndef QTCORE_QEXCEPTION_H
#define QTCORE_QEXCEPTION_H

#include <QtCore/qglobal.h>

#ifndef QT_NO_QFUTURE

#include <QtCore/qatomic.h>
#include <QtCore/qshareddata.h>


QT_BEGIN_NAMESPACE
/*
std::exception 是 C++ 里面, 异常的公共父类, 其实他只有一个 what 方法可以作为抽象的一环.
C++ Throw 的不一定是 std::exception, 也可以是一个 int, 或者 String. 这其实是不太好的部分.
*/

class Q_CORE_EXPORT QException : public std::exception
{
public:
    ~QException()

    throw();
    virtual void raise() const;
    // 在 C++ 里面, 复制一份资源, 使用 Clone 是一个通用的命名方式.
    virtual QException *clone() const;
};

class Q_CORE_EXPORT QUnhandledException : public QException
{
public:
    ~QUnhandledException()
#ifdef Q_COMPILER_NOEXCEPT
    noexcept
#else
    throw()
#endif
    ;
    void raise() const Q_DECL_OVERRIDE;
    QUnhandledException *clone() const Q_DECL_OVERRIDE;
};

namespace QtPrivate {

class Base;
class Q_CORE_EXPORT ExceptionHolder
{
public:
    ExceptionHolder(QException *exception = Q_NULLPTR);
    ExceptionHolder(const ExceptionHolder &other);
    void operator=(const ExceptionHolder &other); // ### Qt6: copy-assign operator shouldn't return void. Remove this method and the copy-ctor, they are unneeded.
    ~ExceptionHolder();
    QException *exception() const;
    QExplicitlySharedDataPointer<Base> base;
};

class Q_CORE_EXPORT ExceptionStore
{
public:
    void setException(const QException &e);
    bool hasException() const;
    ExceptionHolder exception();
    void throwPossibleException();
    bool hasThrown() const;
    ExceptionHolder exceptionHolder;
};

} // namespace QtPrivate


QT_END_NAMESPACE

#endif // QT_NO_QFUTURE

#endif
