#include "qexception.h"
#include "QtCore/qshareddata.h"

#ifndef QT_NO_QFUTURE

QT_BEGIN_NAMESPACE

/*!
    \class QException
    \inmodule QtCore
    \brief The QException class provides a base class for exceptions that can transferred across threads.
    \since 5.0

    Qt Concurrent supports throwing and catching exceptions across thread
    boundaries, provided that the exception inherit from QException
    and implement two helper functions:

    \snippet code/src_corelib_thread_qexception.cpp 0

    QException subclasses must be thrown by value and
    caught by reference:

    \snippet code/src_corelib_thread_qexception.cpp 1

    If you throw an exception that is not a subclass of QException,
    the Qt functions will throw a QUnhandledException
    in the receiver thread.

    When using QFuture, transferred exceptions will be thrown when calling the following functions:
    \list
    \li QFuture::waitForFinished()
    \li QFuture::result()
    \li QFuture::resultAt()
    \li QFuture::results()
    \endlist
*/

/*!
    \fn QException::raise() const
    In your QException subclass, reimplement raise() like this:

    \snippet code/src_corelib_thread_qexception.cpp 2
*/

/*!
    \fn QException::clone() const
    In your QException subclass, reimplement clone() like this:

    \snippet code/src_corelib_thread_qexception.cpp 3
*/

/*!
    \class QUnhandledException
    \inmodule QtCore

    \brief The UnhandledException class represents an unhandled exception in a worker thread.
    \since 5.0

    If a worker thread throws an exception that is not a subclass of QException,
    the Qt functions will throw a QUnhandledException
    on the receiver thread side.

    Inheriting from this class is not supported.
*/

/*!
    \fn QUnhandledException::raise() const
    \internal
*/

/*!
    \fn QUnhandledException::clone() const
    \internal
*/

QException::~QException()
#ifdef Q_COMPILER_NOEXCEPT
    noexcept
#else
    throw()
#endif
{
    // must stay empty until ### Qt 6
}

// raise 就是 throw 自己.
void QException::raise() const
{
    QException e = *this;
    throw e;
}

QException *QException::clone() const
{
    return new QException(*this);
}

QUnhandledException::~QUnhandledException()
#ifdef Q_COMPILER_NOEXCEPT
    noexcept
#else
    throw()
#endif
{
    // must stay empty until ### Qt 6
}

void QUnhandledException::raise() const
{
    QUnhandledException e = *this;
    throw e;
}

QUnhandledException *QUnhandledException::clone() const
{
    return new QUnhandledException(*this);
}

#ifndef Q_QDOC

namespace QtPrivate {

class Base : public QSharedData
{
public:
    Base(QException *exception)
    : exception(exception), hasThrown(false) { }
    ~Base() { delete exception; }

    QException *exception;
    bool hasThrown;
};

ExceptionHolder::ExceptionHolder(QException *exception)
: base(exception ? new Base(exception) : Q_NULLPTR) {}

ExceptionHolder::ExceptionHolder(const ExceptionHolder &other)
: base(other.base)
{}

void ExceptionHolder::operator=(const ExceptionHolder &other)
{
    base = other.base;
}

ExceptionHolder::~ExceptionHolder()
{}

QException *ExceptionHolder::exception() const
{
    if (!base)
        return Q_NULLPTR;
    return base->exception;
}

void ExceptionStore::setException(const QException &e)
{
    if (hasException() == false)
        exceptionHolder = ExceptionHolder(e.clone());
}

bool ExceptionStore::hasException() const
{
    return (exceptionHolder.exception() != 0);
}

ExceptionHolder ExceptionStore::exception()
{
    return exceptionHolder;
}

void ExceptionStore::throwPossibleException()
{
    if (hasException() ) {
        exceptionHolder.base->hasThrown = true;
        exceptionHolder.exception()->raise();
    }
}

bool ExceptionStore::hasThrown() const { return exceptionHolder.base->hasThrown; }

} // namespace QtPrivate


QT_END_NAMESPACE

#endif // QT_NO_EXCEPTIONS
#endif // QT_NO_QFUTURE
