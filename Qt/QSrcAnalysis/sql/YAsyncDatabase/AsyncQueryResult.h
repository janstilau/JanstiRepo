#pragma once

#include <QMetaType>
#include <QSqlRecord>
#include <QVector>
#include <QVariant>
#include <QSqlError>


namespace Database {

// class forward decls's
class SqlTaskPrivate;

/**
* @brief Represent a AsyncQuery result.
* @details The query result is retreived via the getter functions. If an sql error
* occured AsyncQueryResult is not isValid() and the error can retrieved with
* error().
*
*/
class AsyncQueryResult
{
friend class SqlTaskPrivate;

public:
    AsyncQueryResult();
    virtual ~AsyncQueryResult() = default;

    /**
     * @brief Returns \c true if no error occured in the query.
     */
    bool isValid() const;

    /**
     * @brief Retrieve the sql error of the query.
     */
    QSqlError error() const;

    /**
     * @brief Returns the head record to retrieve column names of the table.
     */
    QSqlRecord headRecord() const;

    /**
     * @brief Returns the number of rows in the result.
     */
    int  count() const;

    /**
     * @brief Returns the QSqlRecord of given row.
     */
    QSqlRecord record(int row) const;

    /**
     * @brief Returns the value of given row and columns.
     * @details If row or col is invalid a empty QVariatn is returned.
     */
    QVariant value(int row, int col) const;

    /**
     * @brief Returns the value of given row and column name.
     * @details If row or col is invalid a empty QVariant is returned.
     */
    QVariant value(int row, const QString &col) const;

    /**
     * @brief Returns internal raw data structure of result.
     */
    QVector<QVector<QVariant>> data() const { return _data; }

    /**
     * @brief Returns the object ID of the most recent inserted row
     *
     * @see QSqlQuery::lastInsertId()
     */
    QVariant lastInsertId() const { return _lastInsertId; }
    /**
     * @brief Returns the query string
     * @note A prepared query may not always have its value placeholder
     * replaced if the query fails.
     */
    QString queryString() const { return _queryString; }
    /**
     * @brief Returns the number of rows affected by the SQL statement
     *
     * @see QSqlQuery::numRowsAffected()
     */
    int numRowsAffected() const { return _numRowsAffected; }
    /**
     * @brief Returns the unique query id
     *
     */
    qulonglong queryId() const { return _queryId; }

private:
    QVector<QVector<QVariant>> _data;
    QSqlRecord _record;
    QSqlError _error;
    QVariant _lastInsertId;
    QString _queryString;
    int _numRowsAffected = -1;
    qulonglong _queryId = 0;
};

}    //    namespace

Q_DECLARE_METATYPE(Database::AsyncQueryResult)
