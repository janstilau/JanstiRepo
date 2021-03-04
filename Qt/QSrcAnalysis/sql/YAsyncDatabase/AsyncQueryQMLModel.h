#pragma once
#include <QAbstractTableModel>
#include "AsyncQueryResult.h"

#define SUPPORTS_QSQLQUERY_TABLENAME (QT_VERSION >= QT_VERSION_CHECK(5,10,0))

namespace Database
{
class AsyncQuery;

class AsyncQueryQMLModel : public QAbstractTableModel
{
    Q_OBJECT
    Q_PROPERTY(QString query READ queryString WRITE setQueryString NOTIFY
            queryStringChanged)
    Q_PROPERTY(QStringList columnNames READ columnNames NOTIFY columnNamesChanged)

signals:
    void queryStringChanged(const QString &queryString);
    void columnNamesChanged(const QStringList &columnNames);
    void querySucceeded(const AsyncQueryResult &result);
    void queryFailed(const QString &errorMessage);

public:
#if SUPPORTS_QSQLQUERY_TABLENAME
    enum PrefixMode
    {
        PrefixTableNameAlways,
        PrefixTableNameOnDuplicate,
        PrefixTableNameNever,
    };
    Q_ENUM(PrefixMode)
#endif

    explicit AsyncQueryQMLModel(QObject *parent = nullptr);

    AsyncQuery *asyncQuery() const;
    QString queryString() const;
    QStringList columnNames() const;
    QSqlError error() const;
    AsyncQueryResult result() const;
#if SUPPORTS_QSQLQUERY_TABLENAME
    PrefixMode prefixMode() const;
#endif

    void startExec(const QString &query);
    void clear();

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    int columnCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    Q_INVOKABLE QVariant data(int row, const QString &role) const;
    QHash<int, QByteArray> roleNames() const override;

    void setQueryString(const QString &query);
#if SUPPORTS_QSQLQUERY_TABLENAME
    void setPrefixMode(PrefixMode prefixMode);
#endif

public slots:
    void bindValue(const QString &name, const QVariant &value);
    void exec();

private:
    void onExecDone(const Database::AsyncQueryResult &result);
    void updateRoles();
    void setColumnNames(const QStringList &columnNames);
#if SUPPORTS_QSQLQUERY_TABLENAME
    void updateDuplicateColumnNames(const QSqlRecord &record);
#endif
    QString columnName(const QSqlField &field);

    QHash<int, QByteArray> _roleNames;
    QHash<QString, int> _roleIDs;
    QStringList _columnNames;
    AsyncQueryResult _res;
    AsyncQuery *_aQuery;
#if SUPPORTS_QSQLQUERY_TABLENAME
    PrefixMode _prefixMode;
#endif
    QHash<QString, QString> _duplicateColumnNames;
};
};
