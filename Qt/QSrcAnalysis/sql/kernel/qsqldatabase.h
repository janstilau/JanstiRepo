#ifndef QSQLDATABASE_H
#define QSQLDATABASE_H

#include <QtSql/qtsqlglobal.h>
#include <QtCore/qstring.h>

QT_BEGIN_NAMESPACE


class QSqlError;
class QSqlDriver;
class QSqlIndex;
class QSqlRecord;
class QSqlQuery;
class QSqlDatabasePrivate;

// 这个工厂类, 很简单, 就是创建对应的 Driver.
class Q_SQL_EXPORT QSqlDriverCreatorBase
{
public:
    virtual ~QSqlDriverCreatorBase() {}
    virtual QSqlDriver *createObject() const = 0;
};

// 模板工厂类.
// 因为实际上, 创建工作就是 new OBJ 而已.
// 这里其实解释了, Qt 里面为什么这么多 base 的原因.
// base 里面, 不带泛型. 子类化的时候, 带泛型.
// 调用的时候, 使用泛型的版本, 可以指定类型.
// 算法里面, 使用 base 版本, 直接使用抽象.
template <class T>
class QSqlDriverCreator : public QSqlDriverCreatorBase
{
public:
    QSqlDriver *createObject() const override { return new T; }
};

/*
    其实, 可以从这个类, 去思考一下 C++ Interface, Private 的设计意图.
    首先, 自然是实现的隐藏了. Private 是一个指针, 里面到底有多少类进行配合, 不用暴露出去.
    那么从这个角度来看, Private 仅仅是数据部分, 理解为写在 实现方法里面的数据.
    这种指针, 还有用一个好处, copy, assign, move 方法设计起来很简单. 仅仅是指针操作就可以了.
    如果想要值语义, 那么就 new copy, 如果想要引用语义, 那么就引用计数的 +- 就可以了

    从实现我们知道, 真正的各种数据库的操作, 还是依赖于 driver.
    但是各个接口, 应该是 QSqlDatabase 提供. 所以, QSqlDatabase 提供了很多的代理工作.
 */
class Q_SQL_EXPORT QSqlDatabase
{
public:
    // 首先, 铁定是 Big 5 的代码区域
    QSqlDatabase();
    QSqlDatabase(const QSqlDatabase &other);
    ~QSqlDatabase();

    QSqlDatabase &operator=(const QSqlDatabase &other);

    // 然后是 action 区域.
    bool open();
    bool open(const QString& user, const QString& password);
    void close();
    bool isOpen() const;
    bool isOpenError() const;
    QStringList tables(QSql::TableType type = QSql::Tables) const;
    QSqlIndex primaryIndex(const QString& tablename) const;
    QSqlRecord record(const QString& tablename) const;
    QSqlQuery exec(const QString& query = QString()) const;
    QSqlError lastError() const;
    bool isValid() const;

    bool transaction();
    bool commit();
    bool rollback();

    // 然后是 set 方法区域
    void setDatabaseName(const QString& name);
    void setUserName(const QString& name);
    void setPassword(const QString& password);
    void setHostName(const QString& host);
    void setPort(int p);
    void setConnectOptions(const QString& options = QString());

    // 最后, get 方法区域.
    QString databaseName() const;
    QString userName() const;
    QString password() const;
    QString hostName() const;
    QString driverName() const;
    int port() const;
    QString connectOptions() const;
    QString connectionName() const;
    void setNumericalPrecisionPolicy(QSql::NumericalPrecisionPolicy precisionPolicy);
    QSql::NumericalPrecisionPolicy numericalPrecisionPolicy() const;

    QSqlDriver* driver() const;


    // 在源码里面, 是把 static 放到了 public 的最后部分.
    static const char *defaultConnection;

    static QSqlDatabase addDatabase(const QString& type,
                                 const QString& connectionName = QLatin1String(defaultConnection));
    static QSqlDatabase addDatabase(QSqlDriver* driver,
                                 const QString& connectionName = QLatin1String(defaultConnection));

    static QSqlDatabase cloneDatabase(const QSqlDatabase &other, const QString& connectionName);
    static QSqlDatabase cloneDatabase(const QString &other, const QString& connectionName);
    static QSqlDatabase database(const QString& connectionName = QLatin1String(defaultConnection),
                                 bool open = true);
    static void removeDatabase(const QString& connectionName);
    static bool contains(const QString& connectionName = QLatin1String(defaultConnection));
    static QStringList drivers();
    static QStringList connectionNames();
    static void registerSqlDriver(const QString &name, QSqlDriverCreatorBase *creator);
    static bool isDriverAvailable(const QString &name);

protected:
    explicit QSqlDatabase(const QString& type);
    explicit QSqlDatabase(QSqlDriver* driver);

private:
    friend class QSqlDatabasePrivate;
    // dataBase 的数据部分, 一个指针, 也使得 copy, move 非常简单.
    QSqlDatabasePrivate *d;
};

#ifndef QT_NO_DEBUG_STREAM
Q_SQL_EXPORT QDebug operator<<(QDebug, const QSqlDatabase &);
#endif

QT_END_NAMESPACE

#endif // QSQLDATABASE_H
