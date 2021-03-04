#ifndef QSQLRESULT_P_H
#define QSQLRESULT_P_H

#include <QtSql/private/qtsqlglobal_p.h>
#include <QtCore/qpointer.h>
#include "qsqlerror.h"
#include "qsqlresult.h"
#include "qsqldriver.h"

QT_BEGIN_NAMESPACE

// convenience method Q*ResultPrivate::drv_d_func() returns pointer to private driver. Compare to Q_DECLARE_PRIVATE in qglobal.h.
#define Q_DECLARE_SQLDRIVER_PRIVATE(Class) \
    inline const Class##Private* drv_d_func() const { return !sqldriver ? nullptr : reinterpret_cast<const Class *>(static_cast<const QSqlDriver*>(sqldriver))->d_func(); } \
    inline Class##Private* drv_d_func()  { return !sqldriver ? nullptr : reinterpret_cast<Class *>(static_cast<QSqlDriver*>(sqldriver))->d_func(); }

struct QHolder {
    QHolder(const QString &hldr = QString(), int index = -1): holderName(hldr), holderPos(index) { }
    bool operator==(const QHolder &h) const { return h.holderPos == holderPos && h.holderName == holderName; }
    bool operator!=(const QHolder &h) const { return h.holderPos != holderPos || h.holderName != holderName; }
    QString holderName;
    int holderPos;
};

class Q_SQL_EXPORT QSqlResultPrivate
{
    Q_DECLARE_PUBLIC(QSqlResult)

public:
    QSqlResultPrivate(QSqlResult *q, const QSqlDriver *drv)
      : q_ptr(q),
        sqldriver(const_cast<QSqlDriver*>(drv))
    { }
    virtual ~QSqlResultPrivate() { }

    void clearValues()
    {
        values.clear();
        bindCount = 0;
    }

    void resetBindCount()
    {
        bindCount = 0;
    }

    void clearIndex()
    {
        indexes.clear();
        holders.clear();
        types.clear();
    }

    void clear()
    {
        clearValues();
        clearIndex();;
    }

    virtual QString fieldSerial(int) const;
    QString positionalToNamedBinding(const QString &query) const;
    QString namedToPositionalBinding(const QString &query);
    QString holderAt(int index) const;

    QSqlResult *q_ptr = nullptr;
    // 所以, 实际上, result 里面, 是存储了 sqldriver 的. 所以, result 能够直接进行数据库的查询
    // 而 query 里面, 存储了 QSqlResult 的指针.
    QPointer<QSqlDriver> sqldriver;
    QString sql; // 原本的 sql 语句.
    QSqlError error;
    QSql::NumericalPrecisionPolicy precisionPolicy = QSql::LowPrecisionDouble;
    QSqlResult::BindingSyntax binds = QSqlResult::PositionalBinding;

    // 整个值, 控制的当前取值到了第几行.
    int idx = QSql::BeforeFirstRow;
    int bindCount = 0;
    bool active = false;
    bool isSel = false;
    bool forwardOnly = false;

    QString executedQuery;
    QHash<int, QSql::ParamType> types;
    QVector<QVariant> values;

    typedef QHash<QString, QVector<int> > IndexMap;
    IndexMap indexes;

    typedef QVector<QHolder> QHolderVector;
    QHolderVector holders;
};

QT_END_NAMESPACE

#endif // QSQLRESULT_P_H
