#ifndef QSQLQUERY_H
#define QSQLQUERY_H

#include <QtSql/qtsqlglobal.h>
#include <QtSql/qsqldatabase.h>
#include <QtCore/qstring.h>

QT_BEGIN_NAMESPACE


class QVariant;
class QSqlDriver;
class QSqlError;
class QSqlResult;
class QSqlRecord;
template <class Key, class T> class QMap;
class QSqlQueryPrivate;

// 这个类, 更多的还是对外的接口, 主要的实现逻辑和数据部分, 是在 SQLResult 之中.
class Q_SQL_EXPORT QSqlQuery
{
public:
    explicit QSqlQuery(QSqlResult *r);
    explicit QSqlQuery(const QString& query = QString(), QSqlDatabase db = QSqlDatabase());
    explicit QSqlQuery(QSqlDatabase db);
    QSqlQuery(const QSqlQuery& other);
    QSqlQuery& operator=(const QSqlQuery& other);
    ~QSqlQuery();

    bool isValid() const;
    bool isActive() const;
    bool isNull(int field) const;
    bool isNull(const QString &name) const;
    int at() const;
    QString lastQuery() const;
    int numRowsAffected() const;
    QSqlError lastError() const;
    bool isSelect() const;
    int size() const;
    const QSqlDriver* driver() const;
    const QSqlResult* result() const;
    bool isForwardOnly() const;
    QSqlRecord record() const;

    void setForwardOnly(bool forward);
    bool exec(const QString& query);
    QVariant value(int i) const;
    QVariant value(const QString& name) const;

    void setNumericalPrecisionPolicy(QSql::NumericalPrecisionPolicy precisionPolicy);
    QSql::NumericalPrecisionPolicy numericalPrecisionPolicy() const;

    bool seek(int i, bool relative = false);
    bool next();
    bool previous();
    bool first();
    bool last();

    void clear();

    // prepared query support
    bool exec();
    enum BatchExecutionMode { ValuesAsRows, ValuesAsColumns };
    bool execBatch(BatchExecutionMode mode = ValuesAsRows);
    bool prepare(const QString& query);
    void bindValue(const QString& placeholder,
                   const QVariant& val,
                   QSql::ParamType type = QSql::In);
    void bindValue(int pos, const QVariant& val, QSql::ParamType type = QSql::In);
    void addBindValue(const QVariant& val, QSql::ParamType type = QSql::In);
    QVariant boundValue(const QString& placeholder) const;
    QVariant boundValue(int pos) const;
    QMap<QString, QVariant> boundValues() const;
    QString executedQuery() const;
    QVariant lastInsertId() const;
    void finish();
    bool nextResult();

private:
    QSqlQueryPrivate* d;
};

QT_END_NAMESPACE

#endif // QSQLQUERY_H
