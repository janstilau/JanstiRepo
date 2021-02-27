#ifndef QTCONCURRENT_EXCEPTION_H
#define QTCONCURRENT_EXCEPTION_H

#include <QtConcurrent/qtconcurrent_global.h>
#include <QtCore/qexception.h>

QT_REQUIRE_CONFIG(concurrent);

QT_BEGIN_NAMESPACE


namespace QtConcurrent
{

#if !defined(QT_NO_EXCEPTIONS) || defined(Q_CLANG_QDOC)

typedef Q_DECL_DEPRECATED QException Exception;
typedef Q_DECL_DEPRECATED QUnhandledException UnhandledException;

#endif

} // namespace QtConcurrent

QT_END_NAMESPACE

#endif
