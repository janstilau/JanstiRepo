#ifndef QSQLDRIVER_P_H
#define QSQLDRIVER_P_H



#include <QtSql/private/qtsqlglobal_p.h>
#include "private/qobject_p.h"
#include "qsqldriver.h"
#include "qsqlerror.h"

QT_BEGIN_NAMESPACE

class QSqlDriverPrivate : public QObjectPrivate
{
    Q_DECLARE_PUBLIC(QSqlDriver)

public:
    QSqlDriverPrivate(QSqlDriver::DbmsType type = QSqlDriver::UnknownDbms)
      : QObjectPrivate(),
        dbmsType(type)
    { }

    QSqlError error;
    QSql::NumericalPrecisionPolicy precisionPolicy = QSql::LowPrecisionDouble;
    QSqlDriver::DbmsType dbmsType;
    bool isOpen = false;
    bool isOpenError = false;
};

QT_END_NAMESPACE

#endif // QSQLDRIVER_P_H
