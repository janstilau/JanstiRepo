#include "ConnectionManager.h"
#include <QSqlError>
#include <QFileInfo>
#include <QDir>
#include <QUuid>

namespace Database {
QMutex ConnectionManager::_instanceMutex;

ConnectionManager::ConnectionManager(QObject* parent /*= nullptr */)
    : QObject(parent), logger("Database.ConnectionManager")
{
    _port = -1;
    _precisionPolicy = QSql::LowPrecisionDouble;
    _type = "QMYSQL";
}

ConnectionManager::~ConnectionManager()
{
    closeAll();
}

ConnectionManager *ConnectionManager::createInstance()
{
    return instance();
}

ConnectionManager *ConnectionManager::instance()
{
    QMutexLocker locker(&_instanceMutex);
    return new ConnectionManager();
}

void ConnectionManager::destroyInstance(ConnectionManager *instance)
{
    QMutexLocker locker(&_instanceMutex);
    if (instance != nullptr) {
        delete instance; instance = nullptr;
    }
}

void ConnectionManager::setType(QString type)
{
    QMutexLocker locker(&_mutex);
    _type = type;
}

QString ConnectionManager::type()
{
    QMutexLocker locker(&_mutex);
    return _type;
}

void ConnectionManager::setHostName(const QString & host)
{
    QMutexLocker locker(&_mutex);
    _hostName = host;
}

QString    ConnectionManager::hostName() const
{
    QMutexLocker locker(&_mutex);
    return _hostName;
}

void ConnectionManager::setPort(int port)
{
    QMutexLocker locker(&_mutex);
    _port = port;
}

int    ConnectionManager::port() const
{
    QMutexLocker locker(&_mutex);
    return _port;
}

void ConnectionManager::setDatabaseName(const QString& name)
{
    QMutexLocker locker(&_mutex);
    _databaseName = name;
}

QString ConnectionManager::databaseName() const
{
    QMutexLocker locker(&_mutex);
    return _databaseName;
}


void ConnectionManager::setUserName(const QString & name)
{
    QMutexLocker locker(&_mutex);
    _userName = name;
}

QString    ConnectionManager::userName() const
{
    QMutexLocker locker(&_mutex);
    return _userName;
}

void ConnectionManager::setNumericalPrecisionPolicy(
    QSql::NumericalPrecisionPolicy precisionPolicy)
{
    QMutexLocker locker(&_mutex);
    _precisionPolicy = precisionPolicy;
}

QSql::NumericalPrecisionPolicy
    ConnectionManager::numericalPrecisionPolicy() const
{
    QMutexLocker locker(&_mutex);
    return _precisionPolicy;
}

void ConnectionManager::setPassword(const QString & password)
{
    QMutexLocker locker(&_mutex);
    _password = password;
}

QString    ConnectionManager::password() const
{
    QMutexLocker locker(&_mutex);
    return _password;
}

int ConnectionManager::connectionCount() const
{
    QMutexLocker locker(&_mutex);
    return _conns.count();
}

bool ConnectionManager::connectionExists() const
{
    QMutexLocker locker(&_mutex);
    QString name;
    if(storage.hasLocalData())
        name = storage.localData();
    return _conns.contains(name);
}

bool ConnectionManager::open(QSqlError *error)
{
    QMutexLocker locker(&_mutex);

    QString curThreadName;

    if(storage.hasLocalData())
        curThreadName = storage.localData();

    if (_conns.contains(curThreadName)) {
        qCWarning(logger) << "ConnectionManager::open: "
            "there is a open connection";
        return true;
    }

    QFileInfo file = QFileInfo(_databaseName);
    if (!file.dir().path().isEmpty() && !file.dir().exists()) {
        if (!file.dir().mkpath(file.dir().path())) {
            qCCritical(logger) << "failed to create path << " << file.dir().path() << ", error: " << strerror(errno);
            return false;
        }
    }

    curThreadName = QUuid::createUuid().toString();
    storage.setLocalData(curThreadName);
    QString conname = QString("CNM0x%1").arg(curThreadName);
    QSqlDatabase dbconn = QSqlDatabase::contains(conname) ?
        QSqlDatabase::database(conname, false) : QSqlDatabase::addDatabase(_type, conname);
    if (!dbconn.isValid()) {
        if (error)
            *error = dbconn.lastError();

        dbconn = {};
        QSqlDatabase::removeDatabase(conname);
        _conns.remove(curThreadName);
        return false;
    }


    dbconn.setHostName(_hostName);
    dbconn.setDatabaseName(_databaseName);
    dbconn.setUserName(_userName);
    dbconn.setPassword(_password);
    dbconn.setPort(_port);
    dbconn.setNumericalPrecisionPolicy(_precisionPolicy);

    bool ok = dbconn.open();

    if (ok != true) {
        qCCritical(logger) << "ConnectionManager::open: con= " << conname
            << ": Connection error=" << dbconn.lastError().text();
        if (error)
            *error = dbconn.lastError();

        dbconn = {};
        QSqlDatabase::removeDatabase(conname);
        _conns.remove(curThreadName);
        return false;
    }

    _conns.insert(curThreadName, dbconn);

    return true;
}

QSqlDatabase ConnectionManager::threadConnection() const
{
    QMutexLocker locker(&_mutex);
    QString curThreadName;
    if(storage.hasLocalData())
        curThreadName = storage.localData();
    QSqlDatabase ret = _conns.value(curThreadName, QSqlDatabase());
    return ret;
}

void ConnectionManager::dump()
{
    qCInfo(logger) << "Database connections:" << _conns;
}

void ConnectionManager::closeAll()
{
    QMutexLocker locker(&_mutex);
    /// @attention es koennte sein, dass das nicht geht, weil falscher thread

    while (_conns.count()) {
        QString curThreadName = _conns.firstKey();
        QSqlDatabase db = _conns.take(curThreadName);
        db.close();
    }
}

void ConnectionManager::closeOne(QString curThreadName)
{
    QMutexLocker locker(&_mutex);
    /// @attention es koennte sein, dass das nicht geht, wenn falscher thread

    if (!_conns.contains(curThreadName)) {
        qCWarning(logger) << "closeOne no Connection open for thread " << curThreadName;
        return;
    }

    QSqlDatabase db = _conns.take(curThreadName);
    db.close();
}

}    //    namespace
