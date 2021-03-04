#include "qsqldatabase.h"
#include "qsqlquery.h"
#include "qdebug.h"
#include "qcoreapplication.h"
#include "qreadwritelock.h"
#include "qsqlresult.h"
#include "qsqldriver.h"
#include "qsqldriverplugin.h"
#include "qsqlindex.h"
#include "private/qfactoryloader_p.h"
#include "private/qsqlnulldriver_p.h"
#include "qmutex.h"
#include "qhash.h"
#include "qthread.h"
#include <stdlib.h>

QT_BEGIN_NAMESPACE

// const char 是新标准的要求.
const char *QSqlDatabase::defaultConnection = const_cast<char *>("qt_sql_default_connection");

typedef QHash<QString, QSqlDriverCreatorBase*> DriverDict;

// QConnectionDict 这个类, 就是为 DataBase 存在的.
// 它的主要的目的, 就是增加了锁机制.
// 在对这个全局 Dict 进行查改的时候, 应该加锁.
// 这也是为什么, lock 作为数据部分却是 public 的原因.
class QConnectionDict: public QHash<QString, QSqlDatabase>
{
public:
    inline bool contains_ts(const QString &key)
    {
        QReadLocker locker(&lock);
        return contains(key);
    }
    inline QStringList keys_ts() const
    {
        QReadLocker locker(&lock);
        return keys();
    }

    mutable QReadWriteLock lock;
};

// 是一个通用宏, 目的就是, 通过后面的函数, 返回一个前面的对象. 这个对象, 可以确保是全局唯一的.
Q_GLOBAL_STATIC(QConnectionDict, globalDbDict)

// 真正的数据部分.
class QSqlDatabasePrivate
{
public:
    QSqlDatabasePrivate(QSqlDatabase *d, QSqlDriver *dr = nullptr):
        ref(1),
        dbInterface(d),
        driver(dr),
        port(-1)
    {
        precisionPolicy = QSql::LowPrecisionDouble;
    }
    QSqlDatabasePrivate(const QSqlDatabasePrivate &other);
    ~QSqlDatabasePrivate();
    void init(const QString& type);
    void copy(const QSqlDatabasePrivate *other);
    void disable();

    // 对于, 一个需要引用计数管理的类来说, 没有必要使用 WeakRef count, 在自己内部, 增加一个 int 值就可以了.
    QAtomicInt ref;
    QSqlDatabase *dbInterface;
    QSqlDriver* driver; // 真正和底层数据库交互的封装.
    QString dbname; // 数据库名
    QString uname; // 用户名
    QString pword; // 密码
    QString hname; // host 名.
    QString drvName; // drive 名
    int port; // port
    QString connOptions;
    QString connName;
    QSql::NumericalPrecisionPolicy precisionPolicy;

    static QSqlDatabasePrivate *shared_null();
    static QSqlDatabase database(const QString& name, bool open);
    static void addDatabase(const QSqlDatabase &db, const QString & name);
    static void removeDatabase(const QString& name);
    static void invalidateDb(const QSqlDatabase &db, const QString &name, bool doWarn = true);
    static DriverDict &driverDict();
    static void cleanConnections();
};

QSqlDatabasePrivate::QSqlDatabasePrivate(const QSqlDatabasePrivate &other) : ref(1)
{
    dbInterface = other.dbInterface;
    dbname = other.dbname;
    uname = other.uname;
    pword = other.pword;
    hname = other.hname;
    drvName = other.drvName;
    port = other.port;
    connOptions = other.connOptions;
    driver = other.driver;
    precisionPolicy = other.precisionPolicy;
    if (driver)
        driver->setNumericalPrecisionPolicy(other.driver->numericalPrecisionPolicy());
}

QSqlDatabasePrivate::~QSqlDatabasePrivate()
{
    if (driver != shared_null()->driver)
        delete driver;
}

void QSqlDatabasePrivate::cleanConnections()
{
    QConnectionDict *dict = globalDbDict();
    Q_ASSERT(dict);
    QWriteLocker locker(&dict->lock);

    QConnectionDict::iterator it = dict->begin();
    while (it != dict->end()) {
        invalidateDb(it.value(), it.key(), false);
        ++it;
    }
    dict->clear();
}

// 用一个标记量, 来表示资源的有效性.
// 也可以这个资源内部, 自己可以标志自己的有效性.
static bool qDriverDictInit = false;
static void cleanDriverDict()
{
    //  qDeleteAll 一个全局的算法, 就是 iterator begin 到 end 进行 delete 操作.
    qDeleteAll(QSqlDatabasePrivate::driverDict());
    QSqlDatabasePrivate::driverDict().clear();
    QSqlDatabasePrivate::cleanConnections();
    qDriverDictInit = false;
}

DriverDict &QSqlDatabasePrivate::driverDict()
{
    static DriverDict dict;
    if (!qDriverDictInit) {
        qDriverDictInit = true;
        qAddPostRoutine(cleanDriverDict);
    }
    return dict;
}

// 就是返回一个全局的资源的指针.
// 一个全局的量, 作为非法值的标志, 在代码里面, 当 database 是非法状态的时候, 要主动替换 driver 为这个值.
// 这是 database 设计者的设计意图.
QSqlDatabasePrivate *QSqlDatabasePrivate::shared_null()
{
    static QSqlNullDriver dr;
    static QSqlDatabasePrivate n(nullptr, &dr);
    return &n;
}

// invalidate 开头, 作为资源的取消方式, 是一个很通用的命名方式.
void QSqlDatabasePrivate::invalidateDb(const QSqlDatabase &db, const QString &name, bool doWarn)
{
    if (db.d->ref.loadRelaxed() != 1 && doWarn) {
        qWarning("QSqlDatabasePrivate::removeDatabase: connection '%s' is still in use, "
                 "all queries will cease to work.", name.toLocal8Bit().constData());
        // 关键在于这里, disable(), 真正的进行 driver 的修改.
        // database 所有的值, 都是标记值, 存储使用的.
        // 只有 driver 才是真正有效的逻辑类, 所以 db 也以 driver 作为 valid 的标志.
        db.d->disable();
        db.d->connName.clear();
    }
}

void QSqlDatabasePrivate::removeDatabase(const QString &name)
{
    QConnectionDict *dict = globalDbDict();
    Q_ASSERT(dict);
    QWriteLocker locker(&dict->lock);
    if (!dict->contains(name))
        return;
    invalidateDb(dict->take(name), name);
}

void QSqlDatabasePrivate::addDatabase(const QSqlDatabase &db, const QString &name)
{
    QConnectionDict *dict = globalDbDict();

    QWriteLocker locker(&dict->lock);
    if (dict->contains(name)) {
        // take, 就是从 dict 取出, 并且从 dict 里面删除.
        invalidateDb(dict->take(name), name);
        // 这里就是为什么, 词典笔里面, 没有指定名称一致会有 log 的原因所在.
        qWarning("QSqlDatabasePrivate::addDatabase: duplicate connection name '%s', old "
                 "connection removed.", name.toLocal8Bit().data());
    }
    dict->insert(name, db);
    db.d->connName = name;
}

// 就是去全局表里面, 查找 name 对应的 QSqlDatabase 对象, 会有一些安全的 log.
QSqlDatabase QSqlDatabasePrivate::database(const QString& name, bool open)
{
    const QConnectionDict *dict = globalDbDict();
    Q_ASSERT(dict);

    dict->lock.lockForRead();
    QSqlDatabase db = dict->value(name);
    dict->lock.unlock();
    if (!db.isValid()) { return db; }

    if (db.driver()->thread() != QThread::currentThread()) {
        qWarning("QSqlDatabasePrivate::database: requested database does not belong to the calling thread.");
        return QSqlDatabase();
    }

    if (open && !db.isOpen()) {
        if (!db.open())
            qWarning() << "QSqlDatabasePrivate::database: unable to open database:"
                         << db.lastError().text();
    }
    return db;
}

// 因为这些值都是值语义的, 所以这里就是简单的拷贝工作.
void QSqlDatabasePrivate::copy(const QSqlDatabasePrivate *other)
{
    dbInterface = other->dbInterface;
    dbname = other->dbname;
    uname = other->uname;
    pword = other->pword;
    hname = other->hname;
    drvName = other->drvName;
    port = other->port;
    connOptions = other->connOptions;
    precisionPolicy = other->precisionPolicy;
    if (driver)
        driver->setNumericalPrecisionPolicy(other->driver->numericalPrecisionPolicy());
}

void QSqlDatabasePrivate::disable()
{
    if (driver != shared_null()->driver) {
        // 原来的真正和底层数据库交互的 driver 进行 delete. 然后替换为一个非法值.
        delete driver;
        driver = shared_null()->driver;
    }
}

// 一般情况下, 我们就是使用这个方法, 去创建数据库.
// 这个方法, 更多的是做 database 的管理工作.
QSqlDatabase QSqlDatabase::addDatabase(const QString &type, const QString &connectionName)
{
    QSqlDatabase db(type);
    QSqlDatabasePrivate::addDatabase(db, connectionName);
    return db;
}

QSqlDatabase QSqlDatabase::database(const QString& connectionName, bool open)
{
    return QSqlDatabasePrivate::database(connectionName, open);
}

void QSqlDatabase::removeDatabase(const QString& connectionName)
{
    QSqlDatabasePrivate::removeDatabase(connectionName);
}

QStringList QSqlDatabase::drivers()
{
    QStringList list;

    DriverDict dict = QSqlDatabasePrivate::driverDict();
    for (DriverDict::const_iterator i = dict.constBegin(); i != dict.constEnd(); ++i) {
        if (!list.contains(i.key()))
            list << i.key();
    }

    return list;
}

// 注册一个工厂类到系统中, 这样, 就可以动态配置, 生成的 DataBase 使用哪个 driver 作为自己的实际数据库查询引擎了.
void QSqlDatabase::registerSqlDriver(const QString& name, QSqlDriverCreatorBase *creator)
{
    // delete and take.
    // 良好的 API 的设计, 可以大大的减少代码量.
    delete QSqlDatabasePrivate::driverDict().take(name);
    if (creator)
        QSqlDatabasePrivate::driverDict().insert(name, creator);
}

bool QSqlDatabase::contains(const QString& connectionName)
{
    return globalDbDict()->contains_ts(connectionName);
}

QStringList QSqlDatabase::connectionNames()
{
    return globalDbDict()->keys_ts();
}

QSqlDatabase::QSqlDatabase(const QString &type)
{
    d = new QSqlDatabasePrivate(this);
    d->init(type);
}

// 这个其实不太好. 既然, 所有的方法, 都封装到了内部, 就不应将 driver 暴露出去了.
QSqlDatabase::QSqlDatabase(QSqlDriver *driver)
{
    d = new QSqlDatabasePrivate(this, driver);
}


QSqlDatabase::QSqlDatabase()
{
    // 默认构造函数, 也会将 d 进行赋值.
    // 只不过是一个非法值.
    // 这种设计方式, 在 DataBase 内部使用指针的时候, 就不需要判断 d 的 nullptr 了
    d = QSqlDatabasePrivate::shared_null();
    d->ref.ref();
}

// 引用计数的改变.
QSqlDatabase::QSqlDatabase(const QSqlDatabase &other)
{
    d = other.d;
    d->ref.ref();
}

// 引用计数的改变.
QSqlDatabase &QSqlDatabase::operator=(const QSqlDatabase &other)
{
    qAtomicAssign(d, other.d);
    return *this;
}

// 这里, 是 database 最最重要的 driver 的构造部分.
void QSqlDatabasePrivate::init(const QString &type)
{
    drvName = type;
    // 所以, 实际上, 就是工厂方法创建对象的方式.
    if (!driver) {
        DriverDict dict = QSqlDatabasePrivate::driverDict();
        for (DriverDict::const_iterator it = dict.constBegin();
             it != dict.constEnd() && !driver;
             ++it) {
            if (type == it.key()) {
                driver = ((QSqlDriverCreatorBase*)(*it))->createObject();
            }
        }
    }

    // 如果, 没有匹配的类型, drvier 使用默认的非法值.
    if (!driver) {
        driver = shared_null()->driver;
    }
}

QSqlDatabase::~QSqlDatabase()
{
    if (!d->ref.deref()) {
        close();
        delete d;
    }
}


// 使用 db 执行一个语句.
// 实际上, 可以看到最终还是 query.exec 调用了.
// QSqlQuery 其实, 并不是和 QSqlDatabase 挂钩, 而是和 QResult 挂钩, 和背后的 Driver 挂钩.
// QSqlDatabase 只是用户使用的壳子而已.
QSqlQuery QSqlDatabase::exec(const QString & query) const
{
    QSqlQuery queryObj(d->driver->createResult());
    if (!query.isEmpty()) {
        queryObj.exec(query);
        d->driver->setLastError(queryObj.lastError());
    }
    return queryObj;
}

// open, 其实是 Driver open. 各个参数, 其实是数据库的通用设计.
bool QSqlDatabase::open()
{
    return d->driver->open(d->dbname,
                           d->uname,
                           d->pword,
                           d->hname,
                            d->port,
                           d->connOptions);
}

bool QSqlDatabase::open(const QString& user, const QString& password)
{
    setUserName(user);
    return d->driver->open(d->dbname, user, password, d->hname,
                            d->port, d->connOptions);
}

// 实际上, 就是 driver 的 close. 一个虚方法, 各个实际的 driver 来实现.
void QSqlDatabase::close()
{
    d->driver->close();
}


bool QSqlDatabase::isOpen() const
{
    return d->driver->isOpen();
}

bool QSqlDatabase::isOpenError() const
{
    return d->driver->isOpenError();
}

// 调用 driver 的 beginTransaction
bool QSqlDatabase::transaction()
{
    if (!d->driver->hasFeature(QSqlDriver::Transactions))
        return false;
    return d->driver->beginTransaction();
}

bool QSqlDatabase::commit()
{
    if (!d->driver->hasFeature(QSqlDriver::Transactions))
        return false;
    return d->driver->commitTransaction();
}


bool QSqlDatabase::rollback()
{
    if (!d->driver->hasFeature(QSqlDriver::Transactions))
        return false;
    return d->driver->rollbackTransaction();
}

/*!
    Sets the connection's database name to \a name. To have effect,
    the database name must be set \e{before} the connection is
    \l{open()} {opened}.  Alternatively, you can close() the
    connection, set the database name, and call open() again.  \note
    The \e{database name} is not the \e{connection name}. The
    connection name must be passed to addDatabase() at connection
    object create time.

    For the QSQLITE driver, if the database name specified does not
    exist, then it will create the file for you unless the
    QSQLITE_OPEN_READONLY option is set.

    Additionally, \a name can be set to \c ":memory:" which will
    create a temporary database which is only available for the
    lifetime of the application.

    For the QOCI (Oracle) driver, the database name is the TNS
    Service Name.

    For the QODBC driver, the \a name can either be a DSN, a DSN
    filename (in which case the file must have a \c .dsn extension),
    or a connection string.

    For example, Microsoft Access users can use the following
    connection string to open an \c .mdb file directly, instead of
    having to create a DSN entry in the ODBC manager:

    \snippet code/src_sql_kernel_qsqldatabase.cpp 3

    There is no default value.

    \sa databaseName(), setUserName(), setPassword(), setHostName(),
        setPort(), setConnectOptions(), open()
*/

void QSqlDatabase::setDatabaseName(const QString& name)
{
    if (isValid())
        d->dbname = name;
}


void QSqlDatabase::setUserName(const QString& name)
{
    if (isValid())
        d->uname = name;
}

void QSqlDatabase::setPassword(const QString& password)
{
    if (isValid())
        d->pword = password;
}

void QSqlDatabase::setHostName(const QString& host)
{
    if (isValid())
        d->hname = host;
}

void QSqlDatabase::setPort(int port)
{
    if (isValid())
        d->port = port;
}

QString QSqlDatabase::databaseName() const
{
    return d->dbname;
}

QString QSqlDatabase::userName() const
{
    return d->uname;
}

QString QSqlDatabase::password() const
{
    return d->pword;
}

QString QSqlDatabase::hostName() const
{
    return d->hname;
}

QString QSqlDatabase::driverName() const
{
    return d->drvName;
}

int QSqlDatabase::port() const
{
    return d->port;
}

QSqlDriver* QSqlDatabase::driver() const
{
    return d->driver;
}

QSqlError QSqlDatabase::lastError() const
{
    return d->driver->lastError();
}

// 返回表名
QStringList QSqlDatabase::tables(QSql::TableType type) const
{
    return d->driver->tables(type);
}

/*!
    Returns the primary index for table \a tablename. If no primary
    index exists, an empty QSqlIndex is returned.

    \note Some drivers, such as the \l {QPSQL Case Sensitivity}{QPSQL}
    driver, may may require you to pass \a tablename in lower case if
    the table was not quoted when created. See the
    \l{sql-driver.html}{Qt SQL driver} documentation for more information.

    \sa tables(), record()
*/

QSqlIndex QSqlDatabase::primaryIndex(const QString& tablename) const
{
    return d->driver->primaryIndex(tablename);
}


/*!
    Returns a QSqlRecord populated with the names of all the fields in
    the table (or view) called \a tablename. The order in which the
    fields appear in the record is undefined. If no such table (or
    view) exists, an empty record is returned.

    \note Some drivers, such as the \l {QPSQL Case Sensitivity}{QPSQL}
    driver, may may require you to pass \a tablename in lower case if
    the table was not quoted when created. See the
    \l{sql-driver.html}{Qt SQL driver} documentation for more information.
*/

QSqlRecord QSqlDatabase::record(const QString& tablename) const
{
    return d->driver->record(tablename);
}


/*!
    Sets database-specific \a options. This must be done before the
    connection is opened, otherwise it has no effect. Another possibility
    is to close the connection, call QSqlDatabase::setConnectOptions(),
    and open() the connection again.

    The format of the \a options string is a semicolon separated list
    of option names or option=value pairs. The options depend on the
    database client used:

    \table
    \header \li ODBC \li MySQL \li PostgreSQL
    \row

    \li
    \list
    \li SQL_ATTR_ACCESS_MODE
    \li SQL_ATTR_LOGIN_TIMEOUT
    \li SQL_ATTR_CONNECTION_TIMEOUT
    \li SQL_ATTR_CURRENT_CATALOG
    \li SQL_ATTR_METADATA_ID
    \li SQL_ATTR_PACKET_SIZE
    \li SQL_ATTR_TRACEFILE
    \li SQL_ATTR_TRACE
    \li SQL_ATTR_CONNECTION_POOLING
    \li SQL_ATTR_ODBC_VERSION
    \endlist

    \li
    \list
    \li CLIENT_COMPRESS
    \li CLIENT_FOUND_ROWS
    \li CLIENT_IGNORE_SPACE
    \li CLIENT_ODBC
    \li CLIENT_NO_SCHEMA
    \li CLIENT_INTERACTIVE
    \li UNIX_SOCKET
    \li MYSQL_OPT_RECONNECT
    \li MYSQL_OPT_CONNECT_TIMEOUT
    \li MYSQL_OPT_READ_TIMEOUT
    \li MYSQL_OPT_WRITE_TIMEOUT
    \li SSL_KEY
    \li SSL_CERT
    \li SSL_CA
    \li SSL_CAPATH
    \li SSL_CIPHER
    \endlist

    \li
    \list
    \li connect_timeout
    \li options
    \li tty
    \li requiressl
    \li service
    \endlist

    \header \li DB2 \li OCI \li TDS
    \row

    \li
    \list
    \li SQL_ATTR_ACCESS_MODE
    \li SQL_ATTR_LOGIN_TIMEOUT
    \endlist

    \li
    \list
    \li OCI_ATTR_PREFETCH_ROWS
    \li OCI_ATTR_PREFETCH_MEMORY
    \endlist

    \li
    \e none

    \header \li SQLite \li Interbase
    \row

    \li
    \list
    \li QSQLITE_BUSY_TIMEOUT
    \li QSQLITE_OPEN_READONLY
    \li QSQLITE_OPEN_URI
    \li QSQLITE_ENABLE_SHARED_CACHE
    \li QSQLITE_ENABLE_REGEXP
    \endlist

    \li
    \list
    \li ISC_DPB_LC_CTYPE
    \li ISC_DPB_SQL_ROLE_NAME
    \endlist

    \endtable

    Examples:
    \snippet code/src_sql_kernel_qsqldatabase.cpp 4

    Refer to the client library documentation for more information
    about the different options.

    \sa connectOptions()
*/

void QSqlDatabase::setConnectOptions(const QString &options)
{
    if (isValid())
        d->connOptions = options;
}

/*!
    Returns the connection options string used for this connection.
    The string may be empty.

    \sa setConnectOptions()
 */
QString QSqlDatabase::connectOptions() const
{
    return d->connOptions;
}

/*!
    Returns \c true if a driver called \a name is available; otherwise
    returns \c false.

    \sa drivers()
*/

bool QSqlDatabase::isDriverAvailable(const QString& name)
{
    return drivers().contains(name);
}

QSqlDatabase QSqlDatabase::addDatabase(QSqlDriver* driver, const QString& connectionName)
{
    QSqlDatabase db(driver);
    QSqlDatabasePrivate::addDatabase(db, connectionName);
    return db;
}

// 数据库有效的标志, 是有 driver, 并且不是无效值.
bool QSqlDatabase::isValid() const
{
    return d->driver && d->driver != d->shared_null()->driver;
}

// 新建一个 db, 然后一顿复制操作.
// 最后, 还是加到了全局表里面.
QSqlDatabase QSqlDatabase::cloneDatabase(const QSqlDatabase &other, const QString &connectionName)
{
    if (!other.isValid())
        return QSqlDatabase();

    QSqlDatabase db(other.driverName());
    db.d->copy(other.d);
    QSqlDatabasePrivate::addDatabase(db, connectionName);
    return db;
}


// 先去全局表里面进行查询, 如果不存在, 就返回一个新的默认的.
// 这里, 在类的创建的时候, 应该有类似于 isvalid 这样的设计.
// 因为, 在 QHash 里面, 调用 get value, 经常是查询不到就返回默认构造的数据的.
// 然后就是简单的 clone 操作了
QSqlDatabase QSqlDatabase::cloneDatabase(const QString &other, const QString &connectionName)
{
    const QConnectionDict *dict = globalDbDict();
    Q_ASSERT(dict);

    dict->lock.lockForRead();
    QSqlDatabase otherDb = dict->value(other);
    dict->lock.unlock();
    if (!otherDb.isValid())
        return QSqlDatabase();

    QSqlDatabase db(otherDb.driverName());
    db.d->copy(otherDb.d);
    QSqlDatabasePrivate::addDatabase(db, connectionName);
    return db;
}

/*!
    \since 4.4

    Returns the connection name, which may be empty.  \note The
    connection name is not the \l{databaseName()} {database name}.

    \sa addDatabase()
*/
QString QSqlDatabase::connectionName() const
{
    return d->connName;
}

/*!
    \since 4.6

    Sets the default numerical precision policy used by queries created
    on this database connection to \a precisionPolicy.

    Note: Drivers that don't support fetching numerical values with low
    precision will ignore the precision policy. You can use
    QSqlDriver::hasFeature() to find out whether a driver supports this
    feature.

    Note: Setting the default precision policy to \a precisionPolicy
    doesn't affect any currently active queries.

    \sa QSql::NumericalPrecisionPolicy, numericalPrecisionPolicy(),
        QSqlQuery::setNumericalPrecisionPolicy(), QSqlQuery::numericalPrecisionPolicy()
*/
void QSqlDatabase::setNumericalPrecisionPolicy(QSql::NumericalPrecisionPolicy precisionPolicy)
{
    if(driver())
        driver()->setNumericalPrecisionPolicy(precisionPolicy);
    d->precisionPolicy = precisionPolicy;
}

/*!
    \since 4.6

    Returns the current default precision policy for the database connection.

    \sa QSql::NumericalPrecisionPolicy, setNumericalPrecisionPolicy(),
        QSqlQuery::numericalPrecisionPolicy(), QSqlQuery::setNumericalPrecisionPolicy()
*/
QSql::NumericalPrecisionPolicy QSqlDatabase::numericalPrecisionPolicy() const
{
    if(driver())
        return driver()->numericalPrecisionPolicy();
    else
        return d->precisionPolicy;
}


#ifndef QT_NO_DEBUG_STREAM
QDebug operator<<(QDebug dbg, const QSqlDatabase &d)
{
    QDebugStateSaver saver(dbg);
    dbg.nospace();
    dbg.noquote();
    if (!d.isValid()) {
        dbg << "QSqlDatabase(invalid)";
        return dbg;
    }

    dbg << "QSqlDatabase(driver=\"" << d.driverName() << "\", database=\""
        << d.databaseName() << "\", host=\"" << d.hostName() << "\", port=" << d.port()
        << ", user=\"" << d.userName() << "\", open=" << d.isOpen() << ')';
    return dbg;
}
#endif

QT_END_NAMESPACE
