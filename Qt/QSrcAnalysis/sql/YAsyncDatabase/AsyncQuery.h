#pragma once

#include "AsyncQueryResult.h"
#include "ConnectionManager.h"

#include <QLoggingCategory>
#include <QMutex>
#include <QObject>
#include <QQueue>
#include <QSqlError>
#include <QString>
#include <QWaitCondition>

namespace Database {

// class forward decl's
class SqlTaskPrivate;

/**
 * @brief Class to run a asynchron sql query.
 *
 * @details This class provides functionalities to execute sql queries in a
 * asynchrounous way. The interface is similar to the Qt's synchronous QSqlQuery
 * http://doc.qt.io/qt-5/qsqlquery.html
 *
 * Create a AsyncQuery, connect a handler to the
 * execDone(const Database::AsyncQueryResult &result) signal and start the query
 * with startExec(const QString &query). The query is started in a proper thread and
 * the connected slot is called when finished. Queries are internally maintained in
 * a QThreadPool. By using the QThreadPool the execution of queries is optimized to
 * the available cores on the cpu and threads are not blindly generated.
 *
 * QSqlDatabase's can be only be used from within the thread that created it. This
 * class provides a solution to run queries also from  different threads
 * (http://doc.qt.io/qt-5/threads-modules.html#threads-and-the-sql-module).
 *
 */
class AsyncQuery : public QObject {
    friend class SqlTaskPrivate;
    Q_OBJECT

  public:
    /**
     * @brief The Mode defines how subsequent queries, triggered with
     * startExec() or startExec(const QString &query) are handled.
     */

    enum Mode {
        /** All queries for this object are started immediately and run in parallel.
         * The order in which subsequent queries are executed and finished can not
         * be guaranteed. Each query is started as soon as possible.
         */
        Mode_Parallel,
        /** Subsquent queries for this object are started in a Fifo fashion.
         * A Subsequent query waits until the last query is finished.
         * This guarantees the order of query sequences.
         */
        Mode_Fifo,
        /** Same as Mode_Fifo, but if a previous startExec call is not executed
         * yet it is skipped and overwritten by the current query. E.g. if a
         * graphical slider is bound to a sql query heavy database access can be
         * ommited by using this mode.
         */
        Mode_SkipPrevious,
    };
    explicit AsyncQuery(ConnectionManager *conmgr, QObject *parent = nullptr);
    virtual ~AsyncQuery();

    /**
     * @brief Set the connection manager.
     */
    void setConMgr(ConnectionManager *conmgr);
    /**
     * @brief Set the mode how subsequent queries are executed.
     */
    void setMode(AsyncQuery::Mode mode);
    AsyncQuery::Mode mode();

    /**
     * @brief Are there any queries running.
     */
    bool isRunning() const;

    QString query() const;

    /**
     * @brief Retrieve the result of the last query
     */
    AsyncQueryResult result() const;

    /**
     * @brief Prepare a AsyncQuery
     */
    void prepare(const QString &query);

    /**
     * @brief BindValue for prepared query.
     *
     * @returns false if bindBatchValue() has been called, otherwise true
     */
    bool bindValue(const QString &placeholder, const QVariant &val);

    /**
     * @brief Bind list of values for prepared batch query
     *
     * The query will fail if
     * - a mix of bindValue() and bindBatchValue() is called
     * - \p values does not have the same size as \p values in other
     *   bindBatchValue() calls
     *
     * @returns false if \p values is empty, if it contains a mix of data
     * types, if its size is different from previous calls or if bindValue()
     * has been called, otherwise true
     */
    bool bindBatchValue(const QString &placeholder, const QVariantList &values);

    /**
     * @brief Start a prepared query execution set with prepare(const QString &query);
     *
     * @returns query id
     */
    qulonglong startExec();  // start

    /**
     * @brief Start the execution of the query.
     */
    qulonglong startExec(const QString &query);

    /**
     * @brief Wait for query is finished
     * @details This function blocks the calling thread until query is finsihed. Using
     * this function provides same functionallity as Qt's synchron QSqlQuery.
     */
    bool waitDone(ulong msTimout = ULONG_MAX);

    /**
     * @brief Convinience function to start a AsyncQuery once with given slot as result
     * handler.
     * @details Sample Usage:
     * \code{.cpp}
     * Database::AsyncQuery::startExecOnce(
     *        "SELECT name FROM sqlite_master WHERE type='table'",
     *        this, SLOT(myExecDoneHandler(const Database::AsyncQueryResult &)));
     * \endcode
     */
    static qulonglong startExecOnce(ConnectionManager *conmgr, const QString &query, QObject *receiver,
                                    const char *member);

    /**
     * @brief Convinience function to start a AsyncQuery once with given slot as result
     * handler.
     * @details Sample Usage:
     * \code{.cpp}
     * Database::AsyncQuery::startExecOnce(
     *        "SELECT name FROM sqlite_master WHERE type='table'",
     *        this, &MyObject::myExecDoneHandler);
     * \endcode
     */
    template <typename Object>
    static inline qulonglong startExecOnce(ConnectionManager *conmgr, const QString &query, const Object *object,
                                           void (Object::*slot)(const AsyncQueryResult &))
    {
        AsyncQuery *q = new AsyncQuery(conmgr);
        q->_deleteOnDone = true;
        connect(q, &AsyncQuery::execDone, object, slot);
        return q->startExec(query);
    }

    /**
     * @brief Convinience function to start a AsyncQuery once with given lambda function
     * as result handler.
     * @details Sample Usage:
     * \code{.cpp}
     * Database::AsyncQuery::startExecOnce(
     *        "SELECT name FROM sqlite_master WHERE type='table'",
     *        [=](const Database::AsyncQueryResult& res) {
     *            //do handling here
     * });
     * \endcode
     */
    template <typename Func>
    static inline qulonglong startExecOnce(ConnectionManager *conmgr, const QString &query, Func functor)
    {
        AsyncQuery *q = new AsyncQuery(conmgr);
        q->_deleteOnDone = true;
        connect(q, &AsyncQuery::execDone, functor);
        return q->startExec(query);
    }

    /**
     * @brief Convinience function to start a AsyncQuery once with given lambda function
     * as result handler.
     *
     * The connection is automatically destroyed if the sender or the context
     * is destroyed.
     */
    template <typename Func>
    static inline qulonglong startExecOnce(ConnectionManager *conmgr, const QString &query, const QObject *context,
                                           Func functor)
    {
        AsyncQuery *q = new AsyncQuery(conmgr);
        q->_deleteOnDone = true;
        connect(q, &AsyncQuery::execDone, context, functor);
        return q->startExec(query);
    }

    /**
     * @brief Set delay to execute query. Mainly used for testing.
     * @details The executing query thread sleeps ms before query is executed.
     */
    void setDelayMs(ulong ms);

  signals:
    /**
     * @brief Is emited when asynchronous query is done.
     */
    void execDone(const Database::AsyncQueryResult &result);
    /**
     * @brief Is emited if asynchronous query running status changes.
     */
    void busyChanged(bool busy);

  private:
    struct QueuedQuery
    {
        bool isPrepared;
        bool isBatch = false;
        qulonglong queryId;
        QString query;
        QMap<QString, QVariant> boundValues;
    };

    void startExecIntern();
    /* use only in locked area */
    void incTaskCount();
    void decTaskCount();

    // asynchronous callbacks
    // attention lives in the context of QRunable
    void taskCallback(const AsyncQueryResult &result);

    void resetQueryData();

  private:
    ConnectionManager *_conmgr;
    QLoggingCategory logger;

    QWaitCondition _waitcondition;
    mutable QMutex _mutex;
    bool _deleteOnDone;
    ulong _delayMs;
    Mode _mode;
    int _taskCnt;

    AsyncQueryResult _result;
    QQueue<QueuedQuery> _ququ;
    QueuedQuery _curQuery;
};

}  // namespace Database
