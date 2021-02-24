#ifndef QTCONCURRENT_GLOBAL_H
#define QTCONCURRENT_GLOBAL_H

#include <QtCore/qglobal.h>

QT_BEGIN_NAMESPACE

#ifndef QT_STATIC
#  if defined(QT_BUILD_CONCURRENT_LIB)
#    define Q_CONCURRENT_EXPORT Q_DECL_EXPORT
#  else
#    define Q_CONCURRENT_EXPORT Q_DECL_IMPORT
#  endif
#else
#  define Q_CONCURRENT_EXPORT
#endif

QT_END_NAMESPACE

#endif // include guard
