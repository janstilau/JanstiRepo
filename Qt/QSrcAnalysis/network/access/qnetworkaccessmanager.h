#ifndef QNETWORKACCESSMANAGER_H
#define QNETWORKACCESSMANAGER_H

#include <QtNetwork/qtnetworkglobal.h>
#include <QtNetwork/qnetworkrequest.h>
#include <QtCore/QString>
#include <QtCore/QVector>
#include <QtCore/QObject>
#ifndef QT_NO_SSL
#include <QtNetwork/QSslConfiguration>
#include <QtNetwork/QSslPreSharedKeyAuthenticator>
#endif

QT_BEGIN_NAMESPACE

class QIODevice;
class QAbstractNetworkCache;
class QAuthenticator;
class QByteArray;
template<typename T> class QList;
class QNetworkCookie;
class QNetworkCookieJar;
class QNetworkReply;
class QNetworkProxy;
class QNetworkProxyFactory;
class QSslError;
class QHstsPolicy;
#ifndef QT_NO_BEARERMANAGEMENT
class QNetworkConfiguration;
#endif
class QHttpMultiPart;

class QNetworkReplyImplPrivate;
class QNetworkAccessManagerPrivate;
class Q_NETWORK_EXPORT QNetworkAccessManager: public QObject
{
    Q_OBJECT

#ifndef QT_NO_BEARERMANAGEMENT
    Q_PROPERTY(NetworkAccessibility networkAccessible READ networkAccessible WRITE setNetworkAccessible NOTIFY networkAccessibleChanged)
#endif

public:
    enum Operation {
        HeadOperation = 1,
        GetOperation,
        PutOperation,
        PostOperation,
        DeleteOperation,
        CustomOperation,

        UnknownOperation = 0
    };

#ifndef QT_NO_BEARERMANAGEMENT
    enum NetworkAccessibility {
        UnknownAccessibility = -1,
        NotAccessible = 0,
        Accessible = 1
    };
    Q_ENUM(NetworkAccessibility)
#endif

    explicit QNetworkAccessManager(QObject *parent = nullptr);
    ~QNetworkAccessManager();

    // ### Qt 6: turn into virtual
    QStringList supportedSchemes() const;

    void clearAccessCache();

    void clearConnectionCache();

#ifndef QT_NO_NETWORKPROXY
    QNetworkProxy proxy() const;
    void setProxy(const QNetworkProxy &proxy);
    QNetworkProxyFactory *proxyFactory() const;
    void setProxyFactory(QNetworkProxyFactory *factory);
#endif

    QAbstractNetworkCache *cache() const;
    void setCache(QAbstractNetworkCache *cache);

    QNetworkCookieJar *cookieJar() const;
    void setCookieJar(QNetworkCookieJar *cookieJar);

    void setStrictTransportSecurityEnabled(bool enabled);
    bool isStrictTransportSecurityEnabled() const;
    void enableStrictTransportSecurityStore(bool enabled, const QString &storeDir = QString());
    bool isStrictTransportSecurityStoreEnabled() const;
    void addStrictTransportSecurityHosts(const QVector<QHstsPolicy> &knownHosts);
    QVector<QHstsPolicy> strictTransportSecurityHosts() const;

    QNetworkReply *head(const QNetworkRequest &request);
    QNetworkReply *get(const QNetworkRequest &request);
    QNetworkReply *post(const QNetworkRequest &request, QIODevice *data);
    QNetworkReply *post(const QNetworkRequest &request, const QByteArray &data);
    QNetworkReply *put(const QNetworkRequest &request, QIODevice *data);
    QNetworkReply *put(const QNetworkRequest &request, const QByteArray &data);
    QNetworkReply *deleteResource(const QNetworkRequest &request);
    QNetworkReply *sendCustomRequest(const QNetworkRequest &request, const QByteArray &verb, QIODevice *data = nullptr);
    QNetworkReply *sendCustomRequest(const QNetworkRequest &request, const QByteArray &verb, const QByteArray &data);

#ifndef QT_NO_BEARERMANAGEMENT
    void setConfiguration(const QNetworkConfiguration &config);
    QNetworkConfiguration configuration() const;
    QNetworkConfiguration activeConfiguration() const;

    void setNetworkAccessible(NetworkAccessibility accessible);
    NetworkAccessibility networkAccessible() const;
#endif

#ifndef QT_NO_SSL
    void connectToHostEncrypted(const QString &hostName, quint16 port = 443,
                                const QSslConfiguration &sslConfiguration = QSslConfiguration::defaultConfiguration());
#endif
    void connectToHost(const QString &hostName, quint16 port = 80);

    void setRedirectPolicy(QNetworkRequest::RedirectPolicy policy);
    QNetworkRequest::RedirectPolicy redirectPolicy() const;

Q_SIGNALS:
#ifndef QT_NO_NETWORKPROXY
    void proxyAuthenticationRequired(const QNetworkProxy &proxy, QAuthenticator *authenticator);
#endif
    void authenticationRequired(QNetworkReply *reply, QAuthenticator *authenticator);
    void finished(QNetworkReply *reply);
#ifndef QT_NO_SSL
    void encrypted(QNetworkReply *reply);
    void sslErrors(QNetworkReply *reply, const QList<QSslError> &errors);
    void preSharedKeyAuthenticationRequired(QNetworkReply *reply, QSslPreSharedKeyAuthenticator *authenticator);
#endif

#ifndef QT_NO_BEARERMANAGEMENT
    void networkSessionConnected();

    void networkAccessibleChanged(QNetworkAccessManager::NetworkAccessibility accessible);
#endif

protected:
    virtual QNetworkReply *createRequest(Operation op, const QNetworkRequest &request,
                                         QIODevice *outgoingData = nullptr);

protected Q_SLOTS:
    QStringList supportedSchemesImplementation() const;

private:
    friend class QNetworkReplyImplPrivate;
    friend class QNetworkReplyHttpImpl;
    friend class QNetworkReplyHttpImplPrivate;
    friend class QNetworkReplyFileImpl;

#ifdef Q_OS_WASM
    friend class QNetworkReplyWasmImpl;
#endif
    Q_DECLARE_PRIVATE(QNetworkAccessManager)
    Q_PRIVATE_SLOT(d_func(), void _q_replyFinished())
    Q_PRIVATE_SLOT(d_func(), void _q_replyEncrypted())
    Q_PRIVATE_SLOT(d_func(), void _q_replySslErrors(QList<QSslError>))
    Q_PRIVATE_SLOT(d_func(), void _q_replyPreSharedKeyAuthenticationRequired(QSslPreSharedKeyAuthenticator*))
#ifndef QT_NO_BEARERMANAGEMENT
    Q_PRIVATE_SLOT(d_func(), void _q_networkSessionClosed())
    Q_PRIVATE_SLOT(d_func(), void _q_networkSessionStateChanged(QNetworkSession::State))
    Q_PRIVATE_SLOT(d_func(), void _q_onlineStateChanged(bool))
    Q_PRIVATE_SLOT(d_func(), void _q_configurationChanged(const QNetworkConfiguration &))
    Q_PRIVATE_SLOT(d_func(), void _q_networkSessionFailed(QNetworkSession::SessionError))
#endif
};

QT_END_NAMESPACE

#endif
