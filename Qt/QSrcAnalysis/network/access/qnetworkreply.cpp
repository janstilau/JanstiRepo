#include "qnetworkreply.h"
#include "qnetworkreply_p.h"
#include <QtNetwork/qsslconfiguration.h>

QT_BEGIN_NAMESPACE

const int QNetworkReplyPrivate::progressSignalInterval = 100;

// 这个类里面, 内容很少, 大部分内容, 在 p 文件中.

QNetworkReplyPrivate::QNetworkReplyPrivate()
    : readBufferMaxSize(0),
      emitAllUploadProgressSignals(false),
      operation(QNetworkAccessManager::UnknownOperation),
      errorCode(QNetworkReply::NoError)
    , isFinished(false)
{
    // set the default attribute values
    attributes.insert(QNetworkRequest::ConnectionEncryptedAttribute, false);
}


QNetworkReply::QNetworkReply(QObject *parent)
    : QIODevice(*new QNetworkReplyPrivate, parent)
{
}

QNetworkReply::QNetworkReply(QNetworkReplyPrivate &dd, QObject *parent)
    : QIODevice(dd, parent)
{
}

QNetworkReply::~QNetworkReply()
{
}

void QNetworkReply::close()
{
    QIODevice::close();
}

bool QNetworkReply::isSequential() const
{
    return true;
}


qint64 QNetworkReply::readBufferSize() const
{
    return d_func()->readBufferMaxSize;
}

// 这里讲到了, 如果 buffer 满了,  会导致网络资源获取停滞. 所以, 获取资源是可以控制的. 比如, tcp 请求里面, 发送暂停信号.
void QNetworkReply::setReadBufferSize(qint64 size)
{
    Q_D(QNetworkReply);
    d->readBufferMaxSize = size;
}

/*!
    这里表明了, QNetworkReply 和 QNetworkAccessManager 一定是一起使用的.
*/
QNetworkAccessManager *QNetworkReply::manager() const
{
    return d_func()->manager;
}

QNetworkRequest QNetworkReply::request() const
{
    return d_func()->originalRequest;
}

QNetworkAccessManager::Operation QNetworkReply::operation() const
{
    return d_func()->operation;
}


QNetworkReply::NetworkError QNetworkReply::error() const
{
    return d_func()->errorCode;
}

bool QNetworkReply::isFinished() const
{
    return d_func()->isFinished;
}

bool QNetworkReply::isRunning() const
{
    return !isFinished();
}

QUrl QNetworkReply::url() const
{
    return d_func()->url;
}

// 感觉这样设计也有问题, 本来 HTTP 请求就是可以扩展的.
// 当然, 也提供了 rawHeader 这种, 可以任意指定的 API.
QVariant QNetworkReply::header(QNetworkRequest::KnownHeaders header) const
{
    return d_func()->cookedHeaders.value(header);
}

bool QNetworkReply::hasRawHeader(const QByteArray &headerName) const
{
    Q_D(const QNetworkReply);
    return d->findRawHeader(headerName) != d->rawHeaders.constEnd();
}

QByteArray QNetworkReply::rawHeader(const QByteArray &headerName) const
{
    Q_D(const QNetworkReply);
    QNetworkHeadersPrivate::RawHeadersList::ConstIterator it =
        d->findRawHeader(headerName);
    if (it != d->rawHeaders.constEnd())
        return it->second;
    return QByteArray();
}

// 因为返回值是 const, 所以 cpp 里面, 可以少写一些 copy.
const QList<QNetworkReply::RawHeaderPair>& QNetworkReply::rawHeaderPairs() const
{
    Q_D(const QNetworkReply);
    return d->rawHeaders;
}

QList<QByteArray> QNetworkReply::rawHeaderList() const
{
    return d_func()->rawHeadersKeys();
}

QVariant QNetworkReply::attribute(QNetworkRequest::Attribute code) const
{
    return d_func()->attributes.value(code);
}

#if QT_CONFIG(ssl)
/*!
    Returns the SSL configuration and state associated with this
    reply, if SSL was used. It will contain the remote server's
    certificate, its certificate chain leading to the Certificate
    Authority as well as the encryption ciphers in use.

    The peer's certificate and its certificate chain will be known by
    the time sslErrors() is emitted, if it's emitted.
*/
QSslConfiguration QNetworkReply::sslConfiguration() const
{
    QSslConfiguration config;
    sslConfigurationImplementation(config);
    return config;
}

/*!
    Sets the SSL configuration for the network connection associated
    with this request, if possible, to be that of \a config.
*/
void QNetworkReply::setSslConfiguration(const QSslConfiguration &config)
{
    setSslConfigurationImplementation(config);
}

/*!
    \overload
    \since 4.6

    If this function is called, the SSL errors given in \a errors
    will be ignored.

    \note Because most SSL errors are associated with a certificate, for most
    of them you must set the expected certificate this SSL error is related to.
    If, for instance, you want to issue a request to a server that uses
    a self-signed certificate, consider the following snippet:

    \snippet code/src_network_access_qnetworkreply.cpp 0

    Multiple calls to this function will replace the list of errors that
    were passed in previous calls.
    You can clear the list of errors you want to ignore by calling this
    function with an empty list.

    \note If HTTP Strict Transport Security is enabled for QNetworkAccessManager,
    this function has no effect.

    \sa sslConfiguration(), sslErrors(), QSslSocket::ignoreSslErrors(),
    QNetworkAccessManager::setStrictTransportSecurityEnabled()
*/
void QNetworkReply::ignoreSslErrors(const QList<QSslError> &errors)
{
    ignoreSslErrorsImplementation(errors);
}

/*!
  \fn void QNetworkReply::sslConfigurationImplementation(QSslConfiguration &configuration) const
  \since 5.0

  This virtual method is provided to enable overriding the behavior of
  sslConfiguration(). sslConfiguration() is a public wrapper for this method.
  The configuration will be returned in \a configuration.

  \sa sslConfiguration()
*/
void QNetworkReply::sslConfigurationImplementation(QSslConfiguration &) const
{
}

/*!
  \fn void QNetworkReply::setSslConfigurationImplementation(const QSslConfiguration &configuration)
  \since 5.0

  This virtual method is provided to enable overriding the behavior of
  setSslConfiguration(). setSslConfiguration() is a public wrapper for this method.
  If you override this method use \a configuration to set the SSL configuration.

  \sa sslConfigurationImplementation(), setSslConfiguration()
*/
void QNetworkReply::setSslConfigurationImplementation(const QSslConfiguration &)
{
}

/*!
  \fn void QNetworkReply::ignoreSslErrorsImplementation(const QList<QSslError> &errors)
  \since 5.0

  This virtual method is provided to enable overriding the behavior of
  ignoreSslErrors(). ignoreSslErrors() is a public wrapper for this method.
  \a errors contains the errors the user wishes ignored.

  \sa ignoreSslErrors()
*/
void QNetworkReply::ignoreSslErrorsImplementation(const QList<QSslError> &)
{
}

#endif // QT_CONFIG(ssl)

/*!
    If this function is called, SSL errors related to network
    connection will be ignored, including certificate validation
    errors.

    \warning Be sure to always let the user inspect the errors
    reported by the sslErrors() signal, and only call this method
    upon confirmation from the user that proceeding is ok.
    If there are unexpected errors, the reply should be aborted.
    Calling this method without inspecting the actual errors will
    most likely pose a security risk for your application. Use it
    with great care!

    This function can be called from the slot connected to the
    sslErrors() signal, which indicates which errors were
    found.

    \note If HTTP Strict Transport Security is enabled for QNetworkAccessManager,
    this function has no effect.

    \sa sslConfiguration(), sslErrors(), QSslSocket::ignoreSslErrors()
*/
void QNetworkReply::ignoreSslErrors()
{
}

qint64 QNetworkReply::writeData(const char *, qint64)
{
    return -1;                  // you can't write
}

// 这个应该是网络发送之前就指定的.
void QNetworkReply::setOperation(QNetworkAccessManager::Operation operation)
{
    Q_D(QNetworkReply);
    d->operation = operation;
}

void QNetworkReply::setRequest(const QNetworkRequest &request)
{
    Q_D(QNetworkReply);
    d->originalRequest = request;
}

void QNetworkReply::setError(NetworkError errorCode, const QString &errorString)
{
    Q_D(QNetworkReply);
    d->errorCode = errorCode;
    setErrorString(errorString); // in QIODevice
}

void QNetworkReply::setFinished(bool finished)
{
    Q_D(QNetworkReply);
    d->isFinished = finished;
}

void QNetworkReply::setUrl(const QUrl &url)
{
    Q_D(QNetworkReply);
    d->url = url;
}

void QNetworkReply::setHeader(QNetworkRequest::KnownHeaders header, const QVariant &value)
{
    Q_D(QNetworkReply);
    d->setCookedHeader(header, value);
}

void QNetworkReply::setRawHeader(const QByteArray &headerName, const QByteArray &value)
{
    Q_D(QNetworkReply);
    d->setRawHeader(headerName, value);
}


void QNetworkReply::setAttribute(QNetworkRequest::Attribute code, const QVariant &value)
{
    Q_D(QNetworkReply);
    if (value.isValid())
        d->attributes.insert(code, value);
    else
        d->attributes.remove(code);
}

QT_END_NAMESPACE
