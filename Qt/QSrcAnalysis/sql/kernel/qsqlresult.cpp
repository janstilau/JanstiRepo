#include "qsqlresult.h"

#include "qvariant.h"
#include "qhash.h"
#include "qsqlerror.h"
#include "qsqlfield.h"
#include "qsqlrecord.h"
#include "qvector.h"
#include "qsqldriver.h"
#include "qpointer.h"
#include "qsqlresult_p.h"
#include "private/qsqldriver_p.h"
#include <QDebug>

QT_BEGIN_NAMESPACE

QString QSqlResultPrivate::holderAt(int index) const
{
    return holders.size() > index ? holders.at(index).holderName : fieldSerial(index);
}

// return a unique id for bound names
QString QSqlResultPrivate::fieldSerial(int i) const
{
    ushort arr[] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    ushort *end = &arr[(sizeof(arr)/sizeof(*arr))];
    ushort *ptr = end;

    while (i > 0) {
        *(--ptr) = 'a' + i % 16;
        i >>= 4;
    }

    const int nb = end - ptr;
    *(--ptr) = 'a' + nb;
    *(--ptr) = ':';

    return QString::fromUtf16(ptr, int(end - ptr));
}

static bool qIsAlnum(QChar ch)
{
    uint u = uint(ch.unicode());
    // matches [a-zA-Z0-9_]
    return u - 'a' < 26 || u - 'A' < 26 || u - '0' < 10 || u == '_';
}

QString QSqlResultPrivate::positionalToNamedBinding(const QString &query) const
{
    int n = query.size();

    QString result;
    result.reserve(n * 5 / 4);
    QChar closingQuote;
    int count = 0;
    bool ignoreBraces = (sqldriver->dbmsType() == QSqlDriver::PostgreSQL);

    for (int i = 0; i < n; ++i) {
        QChar ch = query.at(i);
        if (!closingQuote.isNull()) {
            if (ch == closingQuote) {
                if (closingQuote == QLatin1Char(']')
                    && i + 1 < n && query.at(i + 1) == closingQuote) {
                    // consume the extra character. don't close.
                    ++i;
                    result += ch;
                } else {
                    closingQuote = QChar();
                }
            }
            result += ch;
        } else {
            if (ch == QLatin1Char('?')) {
                result += fieldSerial(count++);
            } else {
                if (ch == QLatin1Char('\'') || ch == QLatin1Char('"') || ch == QLatin1Char('`'))
                    closingQuote = ch;
                else if (!ignoreBraces && ch == QLatin1Char('['))
                    closingQuote = QLatin1Char(']');
                result += ch;
            }
        }
    }
    result.squeeze();
    return result;
}

QString QSqlResultPrivate::namedToPositionalBinding(const QString &query)
{
    int n = query.size();

    QString result;
    result.reserve(n);
    QChar closingQuote;
    int count = 0;
    int i = 0;
    bool ignoreBraces = (sqldriver->dbmsType() == QSqlDriver::PostgreSQL);

    while (i < n) {
        QChar ch = query.at(i);
        if (!closingQuote.isNull()) {
            if (ch == closingQuote) {
                if (closingQuote == QLatin1Char(']')
                        && i + 1 < n && query.at(i + 1) == closingQuote) {
                    // consume the extra character. don't close.
                    ++i;
                    result += ch;
                } else {
                    closingQuote = QChar();
                }
            }
            result += ch;
            ++i;
        } else {
            if (ch == QLatin1Char(':')
                    && (i == 0 || query.at(i - 1) != QLatin1Char(':'))
                    && (i + 1 < n && qIsAlnum(query.at(i + 1)))) {
                int pos = i + 2;
                while (pos < n && qIsAlnum(query.at(pos)))
                    ++pos;
                QString holder(query.mid(i, pos - i));
                indexes[holder].append(count++);
                holders.append(QHolder(holder, i));
                result += QLatin1Char('?');
                i = pos;
            } else {
                if (ch == QLatin1Char('\'') || ch == QLatin1Char('"') || ch == QLatin1Char('`'))
                    closingQuote = ch;
                else if (!ignoreBraces && ch == QLatin1Char('['))
                    closingQuote = QLatin1Char(']');
                result += ch;
                ++i;
            }
        }
    }
    result.squeeze();
    values.resize(holders.size());
    return result;
}

/*!
    \class QSqlResult
    \brief The QSqlResult class provides an abstract interface for
    accessing data from specific SQL databases.

    \ingroup database
    \inmodule QtSql

    Normally, you would use QSqlQuery instead of QSqlResult, since
    QSqlQuery provides a generic wrapper for database-specific
    implementations of QSqlResult.

    If you are implementing your own SQL driver (by subclassing
    QSqlDriver), you will need to provide your own QSqlResult
    subclass that implements all the pure virtual functions and other
    virtual functions that you need.

    \sa QSqlDriver
*/

/*!
    \enum QSqlResult::BindingSyntax

    This enum type specifies the different syntaxes for specifying
    placeholders in prepared queries.

    \value PositionalBinding Use the ODBC-style positional syntax, with "?" as placeholders.
    \value NamedBinding Use the Oracle-style syntax with named placeholders (e.g., ":id")

    \sa bindingSyntax()
*/

/*!
    \enum QSqlResult::VirtualHookOperation
    \internal
*/

/*!
    Creates a QSqlResult using database driver \a db. The object is
    initialized to an inactive state.

    \sa isActive(), driver()
*/

QSqlResult::QSqlResult(const QSqlDriver *db)
{
    d_ptr = new QSqlResultPrivate(this, db);
    Q_D(QSqlResult);
    if (d->sqldriver)
        setNumericalPrecisionPolicy(d->sqldriver->numericalPrecisionPolicy());
}

/*!  \internal
*/
QSqlResult::QSqlResult(QSqlResultPrivate &dd)
    : d_ptr(&dd)
{
    Q_D(QSqlResult);
    if (d->sqldriver)
        setNumericalPrecisionPolicy(d->sqldriver->numericalPrecisionPolicy());
}

/*!
    Destroys the object and frees any allocated resources.
*/

QSqlResult::~QSqlResult()
{
    Q_D(QSqlResult);
    delete d;
}

void QSqlResult::setQuery(const QString& query)
{
    Q_D(QSqlResult);
    d->sql = query;
}

// 就是返回存储的 sql 语句
QString QSqlResult::lastQuery() const
{
    Q_D(const QSqlResult);
    return d->sql;
}

int QSqlResult::at() const
{
    Q_D(const QSqlResult);
    return d->idx;
}


bool QSqlResult::isValid() const
{
    Q_D(const QSqlResult);
    return d->idx != QSql::BeforeFirstRow && d->idx != QSql::AfterLastRow;
}

bool QSqlResult::isActive() const
{
    Q_D(const QSqlResult);
    return d->active;
}

void QSqlResult::setAt(int index)
{
    Q_D(QSqlResult);
    d->idx = index;
}

void QSqlResult::setSelect(bool select)
{
    Q_D(QSqlResult);
    d->isSel = select;
}

bool QSqlResult::isSelect() const
{
    Q_D(const QSqlResult);
    return d->isSel;
}

const QSqlDriver *QSqlResult::driver() const
{
    Q_D(const QSqlResult);
    return d->sqldriver;
}

void QSqlResult::setActive(bool active)
{
    Q_D(QSqlResult);
    if (active)
        d->executedQuery = d->sql;

    d->active = active;
}

/*!
    This function is provided for derived classes to set the last
    error to \a error.

    \sa lastError()
*/

void QSqlResult::setLastError(const QSqlError &error)
{
    Q_D(QSqlResult);
    d->error = error;
}


/*!
    Returns the last error associated with the result.
*/

QSqlError QSqlResult::lastError() const
{
    Q_D(const QSqlResult);
    return d->error;
}

/*!
    \fn int QSqlResult::size()

    Returns the size of the \c SELECT result, or -1 if it cannot be
    determined or if the query is not a \c SELECT statement.

    \sa numRowsAffected()
*/

/*!
    \fn int QSqlResult::numRowsAffected()

    Returns the number of rows affected by the last query executed, or
    -1 if it cannot be determined or if the query is a \c SELECT
    statement.

    \sa size()
*/

/*!
    \fn QVariant QSqlResult::data(int index)

    Returns the data for field \a index in the current row as
    a QVariant. This function is only called if the result is in
    an active state and is positioned on a valid record and \a index is
    non-negative. Derived classes must reimplement this function and
    return the value of field \a index, or QVariant() if it cannot be
    determined.
*/

/*!
    \fn  bool QSqlResult::reset(const QString &query)

    Sets the result to use the SQL statement \a query for subsequent
    data retrieval.

    Derived classes must reimplement this function and apply the \a
    query to the database. This function is only called after the
    result is set to an inactive state and is positioned before the
    first record of the new result. Derived classes should return
    true if the query was successful and ready to be used, or false
    otherwise.

    \sa setQuery()
*/

/*!
    \fn bool QSqlResult::fetch(int index)

    Positions the result to an arbitrary (zero-based) row \a index.

    This function is only called if the result is in an active state.
    Derived classes must reimplement this function and position the
    result to the row \a index, and call setAt() with an appropriate
    value. Return true to indicate success, or false to signify
    failure.

    \sa isActive(), fetchFirst(), fetchLast(), fetchNext(), fetchPrevious()
*/

/*!
    \fn bool QSqlResult::fetchFirst()

    Positions the result to the first record (row 0) in the result.

    This function is only called if the result is in an active state.
    Derived classes must reimplement this function and position the
    result to the first record, and call setAt() with an appropriate
    value. Return true to indicate success, or false to signify
    failure.

    \sa fetch(), fetchLast()
*/

/*!
    \fn bool QSqlResult::fetchLast()

    Positions the result to the last record (last row) in the result.

    This function is only called if the result is in an active state.
    Derived classes must reimplement this function and position the
    result to the last record, and call setAt() with an appropriate
    value. Return true to indicate success, or false to signify
    failure.

    \sa fetch(), fetchFirst()
*/

/*!
    Positions the result to the next available record (row) in the
    result.

    This function is only called if the result is in an active
    state. The default implementation calls fetch() with the next
    index. Derived classes can reimplement this function and position
    the result to the next record in some other way, and call setAt()
    with an appropriate value. Return true to indicate success, or
    false to signify failure.

    \sa fetch(), fetchPrevious()
*/

bool QSqlResult::fetchNext()
{
    return fetch(at() + 1);
}

/*!
    Positions the result to the previous record (row) in the result.

    This function is only called if the result is in an active state.
    The default implementation calls fetch() with the previous index.
    Derived classes can reimplement this function and position the
    result to the next record in some other way, and call setAt()
    with an appropriate value. Return true to indicate success, or
    false to signify failure.
*/

bool QSqlResult::fetchPrevious()
{
    return fetch(at() - 1);
}

/*!
    Returns \c true if you can only scroll forward through the result
    set; otherwise returns \c false.

    \sa setForwardOnly()
*/
bool QSqlResult::isForwardOnly() const
{
    Q_D(const QSqlResult);
    return d->forwardOnly;
}

/*!
    Sets forward only mode to \a forward. If \a forward is true, only
    fetchNext() is allowed for navigating the results. Forward only
    mode needs much less memory since results do not have to be
    cached. By default, this feature is disabled.

    Setting forward only to false is a suggestion to the database engine,
    which has the final say on whether a result set is forward only or
    scrollable. isForwardOnly() will always return the correct status of
    the result set.

    \note Calling setForwardOnly after execution of the query will result
    in unexpected results at best, and crashes at worst.

    \note To make sure the forward-only query completed successfully,
    the application should check lastError() for an error not only after
    executing the query, but also after navigating the query results.

    \warning PostgreSQL: While navigating the query results in forward-only
    mode, do not execute any other SQL command on the same database
    connection. This will cause the query results to be lost.

    \sa isForwardOnly(), fetchNext(), QSqlQuery::setForwardOnly()
*/
void QSqlResult::setForwardOnly(bool forward)
{
    Q_D(QSqlResult);
    d->forwardOnly = forward;
}

/*!
    Prepares the given \a query, using the underlying database
    functionality where possible. Returns \c true if the query is
    prepared successfully; otherwise returns \c false.

    Note: This method should have been called "safePrepare()".

    \sa prepare()
*/
bool QSqlResult::savePrepare(const QString& query)
{
    Q_D(QSqlResult);
    if (!driver())
        return false;
    d->clear();
    d->sql = query;
    if (!driver()->hasFeature(QSqlDriver::PreparedQueries))
        return prepare(query);

    // parse the query to memorize parameter location
    d->executedQuery = d->namedToPositionalBinding(query);

    if (driver()->hasFeature(QSqlDriver::NamedPlaceholders))
        d->executedQuery = d->positionalToNamedBinding(query);

    return prepare(d->executedQuery);
}

/*!
    Prepares the given \a query for execution; the query will normally
    use placeholders so that it can be executed repeatedly. Returns
    true if the query is prepared successfully; otherwise returns \c false.

    \sa exec()
*/
bool QSqlResult::prepare(const QString& query)
{
    Q_D(QSqlResult);
    d->sql = query;
    if (d->holders.isEmpty()) {
        // parse the query to memorize parameter location
        d->namedToPositionalBinding(query);
    }
    return true; // fake prepares should always succeed
}

//
bool QSqlResult::exec()
{
    Q_D(QSqlResult);
    bool ret;
    // fake preparation - just replace the placeholders..
    // 所以, 其实就是字符串的替换工作.
    // 在 exec 之前, 把 bind 的过程中存储的各个值, 替换到最终执行的字符串中.
    // driver()->formatValue(f) 会根据对应字段的类型, 进行格式化输出.
    QString query = lastQuery();
    if (d->binds == NamedBinding) {
        int i;
        QVariant val;
        QString holder;
        for (i = d->holders.count() - 1; i >= 0; --i) {
            holder = d->holders.at(i).holderName;
            val = d->values.value(d->indexes.value(holder).value(0,-1));
            QSqlField f(QLatin1String(""), QVariant::Type(val.userType()));
            f.setValue(val);
            query = query.replace(d->holders.at(i).holderPos,
                                   holder.length(),
                                  driver()->formatValue(f));
        }
    } else {
        QString val;
        int i = 0;
        int idx = 0;
        for (idx = 0; idx < d->values.count(); ++idx) {
            i = query.indexOf(QLatin1Char('?'), i);
            if (i == -1)
                continue;
            QVariant var = d->values.value(idx);
            QSqlField f(QLatin1String(""), QVariant::Type(var.userType()));
            if (var.isNull())
                f.clear();
            else
                f.setValue(var);
            val = driver()->formatValue(f);
            query = query.replace(i, 1, driver()->formatValue(f));
            i += val.length();
        }
    }

    // have to retain the original query with placeholders
    QString orig = lastQuery();
    // 在这里, 是真正的使用 query 进行数据库的查询工作.
    ret = reset(query);
    // 所以, 实际上有两个值, 一个真正执行 sql, 一个是没有绑定值的 sql.
    d->executedQuery = query;
    setQuery(orig);
    d->resetBindCount();
    return ret;
}

/*!
    Binds the value \a val of parameter type \a paramType to position \a index
    in the current record (row).

    \sa addBindValue()
*/
void QSqlResult::bindValue(int index, const QVariant& val, QSql::ParamType paramType)
{
    Q_D(QSqlResult);
    d->binds = PositionalBinding;
    QVector<int> &indexes = d->indexes[d->fieldSerial(index)];
    if (!indexes.contains(index))
        indexes.append(index);
    if (d->values.count() <= index)
        d->values.resize(index + 1);
    d->values[index] = val;
    if (paramType != QSql::In || !d->types.isEmpty())
        d->types[index] = paramType;
}

// 所以, 其实各种 bind, 只是 C++ 类的 bind, 还没有直接 bind 到 sql 上.
void QSqlResult::bindValue(const QString& placeholder,
                           const QVariant& val,
                           QSql::ParamType paramType)
{
    Q_D(QSqlResult);
    d->binds = NamedBinding;
    const QVector<int> indexes = d->indexes.value(placeholder);
    for (int idx : indexes) {
        if (d->values.count() <= idx)
            d->values.resize(idx + 1);
        d->values[idx] = val;
        if (paramType != QSql::In || !d->types.isEmpty())
            d->types[idx] = paramType;
    }
}

void QSqlResult::addBindValue(const QVariant& val, QSql::ParamType paramType)
{
    Q_D(QSqlResult);
    d->binds = PositionalBinding;
    bindValue(d->bindCount, val, paramType);
    ++d->bindCount;
}

/*!
    Returns the value bound at position \a index in the current record
    (row).

    \sa bindValue(), boundValues()
*/
QVariant QSqlResult::boundValue(int index) const
{
    Q_D(const QSqlResult);
    return d->values.value(index);
}

/*!
    \overload

    Returns the value bound by the given \a placeholder name in the
    current record (row).

    \sa bindValueType()
*/
QVariant QSqlResult::boundValue(const QString& placeholder) const
{
    Q_D(const QSqlResult);
    const QVector<int> indexes = d->indexes.value(placeholder);
    return d->values.value(indexes.value(0,-1));
}

/*!
    Returns the parameter type for the value bound at position \a index.

    \sa boundValue()
*/
QSql::ParamType QSqlResult::bindValueType(int index) const
{
    Q_D(const QSqlResult);
    return d->types.value(index, QSql::In);
}

/*!
    \overload

    Returns the parameter type for the value bound with the given \a
    placeholder name.
*/
QSql::ParamType QSqlResult::bindValueType(const QString& placeholder) const
{
    Q_D(const QSqlResult);
    return d->types.value(d->indexes.value(placeholder).value(0,-1), QSql::In);
}

/*!
    Returns the number of bound values in the result.

    \sa boundValues()
*/
int QSqlResult::boundValueCount() const
{
    Q_D(const QSqlResult);
    return d->values.count();
}

/*!
    Returns a vector of the result's bound values for the current
    record (row).

    \sa boundValueCount()
*/
QVector<QVariant>& QSqlResult::boundValues() const
{
    Q_D(const QSqlResult);
    return const_cast<QSqlResultPrivate *>(d)->values;
}

/*!
    Returns the binding syntax used by prepared queries.
*/
QSqlResult::BindingSyntax QSqlResult::bindingSyntax() const
{
    Q_D(const QSqlResult);
    return d->binds;
}

/*!
    Clears the entire result set and releases any associated
    resources.
*/
void QSqlResult::clear()
{
    Q_D(QSqlResult);
    d->clear();
}

/*!
    Returns the query that was actually executed. This may differ from
    the query that was passed, for example if bound values were used
    with a prepared query and the underlying database doesn't support
    prepared queries.

    \sa exec(), setQuery()
*/
QString QSqlResult::executedQuery() const
{
    Q_D(const QSqlResult);
    return d->executedQuery;
}

/*!
    Resets the number of bind parameters.
*/
void QSqlResult::resetBindCount()
{
    Q_D(QSqlResult);
    d->resetBindCount();
}

/*!
    Returns the name of the bound value at position \a index in the
    current record (row).

    \sa boundValue()
*/
QString QSqlResult::boundValueName(int index) const
{
    Q_D(const QSqlResult);
    return d->holderAt(index);
}

/*!
    Returns \c true if at least one of the query's bound values is a \c
    QSql::Out or a QSql::InOut; otherwise returns \c false.

    \sa bindValueType()
*/
bool QSqlResult::hasOutValues() const
{
    Q_D(const QSqlResult);
    if (d->types.isEmpty())
        return false;
    QHash<int, QSql::ParamType>::ConstIterator it;
    for (it = d->types.constBegin(); it != d->types.constEnd(); ++it) {
        if (it.value() != QSql::In)
            return true;
    }
    return false;
}


QSqlRecord QSqlResult::record() const
{
    return QSqlRecord();
}

/*!
    Returns the object ID of the most recent inserted row if the
    database supports it.
    An invalid QVariant will be returned if the query did not
    insert any value or if the database does not report the id back.
    If more than one row was touched by the insert, the behavior is
    undefined.

    Note that for Oracle databases the row's ROWID will be returned,
    while for MySQL databases the row's auto-increment field will
    be returned.

    \sa QSqlDriver::hasFeature()
*/
QVariant QSqlResult::lastInsertId() const
{
    return QVariant();
}

/*! \internal
*/
void QSqlResult::virtual_hook(int, void *)
{
}

/*! \internal
    \since 4.2

    Executes a prepared query in batch mode if the driver supports it,
    otherwise emulates a batch execution using bindValue() and exec().
    QSqlDriver::hasFeature() can be used to find out whether a driver
    supports batch execution.

    Batch execution can be faster for large amounts of data since it
    reduces network roundtrips.

    For batch executions, bound values have to be provided as lists
    of variants (QVariantList).

    Each list must contain values of the same type. All lists must
    contain equal amount of values (rows).

    NULL values are passed in as typed QVariants, for example
    \c {QVariant(QVariant::Int)} for an integer NULL value.

    Example:

    \snippet code/src_sql_kernel_qsqlresult.cpp 0

    Here, we insert two rows into a SQL table, with each row containing three values.

    \sa exec(), QSqlDriver::hasFeature()
*/
bool QSqlResult::execBatch(bool arrayBind)
{
    Q_UNUSED(arrayBind);
    Q_D(QSqlResult);

    QVector<QVariant> values = d->values;
    if (values.count() == 0)
        return false;
    for (int i = 0; i < values.at(0).toList().count(); ++i) {
        for (int j = 0; j < values.count(); ++j)
            bindValue(j, values.at(j).toList().at(i), QSql::In);
        if (!exec())
            return false;
    }
    return true;
}

/*! \internal
 */
void QSqlResult::detachFromResultSet()
{
}

/*! \internal
 */
void QSqlResult::setNumericalPrecisionPolicy(QSql::NumericalPrecisionPolicy policy)
{
    Q_D(QSqlResult);
    d->precisionPolicy = policy;
}

/*! \internal
 */
QSql::NumericalPrecisionPolicy QSqlResult::numericalPrecisionPolicy() const
{
    Q_D(const QSqlResult);
    return d->precisionPolicy;
}

/*! \internal
*/
bool QSqlResult::nextResult()
{
    return false;
}

QVariant QSqlResult::handle() const
{
    return QVariant();
}

QT_END_NAMESPACE
