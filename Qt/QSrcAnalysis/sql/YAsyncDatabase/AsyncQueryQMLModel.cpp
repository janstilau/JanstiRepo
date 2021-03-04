#include "AsyncQueryQMLModel.h"
#include "AsyncQuery.h"
using namespace Database;
#include <QSqlField>
#include <QStringBuilder>

static const int firstRole = Qt::UserRole + 1;


AsyncQueryQMLModel::AsyncQueryQMLModel(QObject *parent)
    : QAbstractTableModel(parent)
    , _aQuery(new AsyncQuery(this))
#if SUPPORTS_QSQLQUERY_TABLENAME
    , _prefixMode(PrefixTableNameOnDuplicate)
#endif
{
    connect(_aQuery, &AsyncQuery::execDone, this, &AsyncQueryQMLModel::onExecDone);
}

AsyncQuery *AsyncQueryQMLModel::asyncQuery() const
{
    return _aQuery;
}

QString AsyncQueryQMLModel::queryString() const
{
    return _aQuery->query();
}

QStringList AsyncQueryQMLModel::columnNames() const
{
    return _columnNames;
}

QSqlError AsyncQueryQMLModel::error() const
{
    return _res.error();
}

AsyncQueryResult AsyncQueryQMLModel::result() const
{
    return _res;
}

#if SUPPORTS_QSQLQUERY_TABLENAME
AsyncQueryQMLModel::PrefixMode AsyncQueryQMLModel::prefixMode() const
{
    return _prefixMode;
}
#endif

void AsyncQueryQMLModel::startExec(const QString &query)
{
    _aQuery->startExec(query);
}

void AsyncQueryQMLModel::clear()
{
    beginResetModel();
    _res = {};
    _roleNames.clear();
    _roleIDs.clear();
    setColumnNames({});
    endResetModel();
}

int AsyncQueryQMLModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    return _res.count();
}

int AsyncQueryQMLModel::columnCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    return _res.headRecord().count();
}

QVariant AsyncQueryQMLModel::data(const QModelIndex &index, int role) const
{
    if (role >= firstRole && role < firstRole + columnCount())
        return _res.value(index.row(), role - firstRole);

    return {};
}

QVariant AsyncQueryQMLModel::data(int row, const QString &role) const
{
    if (row >= 0 && row < rowCount() && _roleIDs.contains(role))
        return _res.value(row, _roleIDs.value(role) - firstRole);

    return {};
}

QHash<int, QByteArray> AsyncQueryQMLModel::roleNames() const
{
    return _roleNames;
}

void AsyncQueryQMLModel::setQueryString(const QString &query)
{
    if (query == asyncQuery()->query())
        return;

    clear();
    asyncQuery()->prepare(query);
    emit queryStringChanged(query);
}

#if SUPPORTS_QSQLQUERY_TABLENAME
void AsyncQueryQMLModel::setPrefixMode(PrefixMode prefixMode)
{
    if (prefixMode == _prefixMode)
        return;

    _prefixMode = prefixMode;
    updateRoles();
}
#endif

void AsyncQueryQMLModel::bindValue(const QString &name, const QVariant &value)
{
    asyncQuery()->bindValue(name, value);
}

void AsyncQueryQMLModel::exec()
{
    asyncQuery()->startExec();
}

void AsyncQueryQMLModel::onExecDone(const Database::AsyncQueryResult &result)
{
    beginResetModel();
    _res = result;
    updateRoles();
    endResetModel();

    if (result.isValid())
        emit querySucceeded(result);
    else
        emit queryFailed(result.error().text());
}

void AsyncQueryQMLModel::updateRoles()
{
    _roleNames.clear();
    _roleIDs.clear();
    auto record = _res.headRecord();
    QStringList columnNames;

#if SUPPORTS_QSQLQUERY_TABLENAME
    updateDuplicateColumnNames(record);
#endif
    for (int i = 0; i < record.count(); ++i)
    {
        auto name = columnName(record.field(i));
        auto id = firstRole + i;
        _roleNames[id] = name.toUtf8();
        _roleIDs[name] = id;
        columnNames << name;
    }

    setColumnNames(columnNames);
}

void AsyncQueryQMLModel::setColumnNames(const QStringList &columnNames)
{
    if (columnNames == _columnNames)
        return;

    _columnNames = columnNames;
    emit columnNamesChanged(_columnNames);
}

#if SUPPORTS_QSQLQUERY_TABLENAME
void AsyncQueryQMLModel::updateDuplicateColumnNames(const QSqlRecord &record)
{
    _duplicateColumnNames.clear();

    QSet<QString> columnNames;
    for (int i = 0; i < record.count(); ++i)
    {
        auto name = record.fieldName(i);
        if (columnNames.contains(name))
            _duplicateColumnNames[name] = record.field(i).tableName();

        columnNames << name;
    }
}
#endif

QString AsyncQueryQMLModel::columnName(const QSqlField &field)
{
#if SUPPORTS_QSQLQUERY_TABLENAME
    if (_prefixMode == PrefixTableNameNever)
        return field.name();
    else if (_prefixMode == PrefixTableNameAlways)
        return field.tableName() % '.' % field.name();

    if (_duplicateColumnNames.contains(field.name()))
        return field.tableName() % '.' % field.name();
#endif

    return field.name();
}
