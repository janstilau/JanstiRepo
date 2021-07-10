// Created by liugquoqiang at 2020-11-16

#ifdef YD_HOMEWORK

#include "YdHttpManager.h"
#include "YdHttpDownloader.h"
#include <QNetworkAccessManager>
#include <QTimer>
#include <QHttpMultiPart>
#include <QJsonDocument>
#include <QJsonObject>

#pragma mark - Init

YdHttpManager& YdHttpManager::instance()
{
    static YdHttpManager mInstance;
    return mInstance;
}

YdHttpManager::YdHttpManager(QObject* parent):
    QObject(parent),
    mNetwork(new QNetworkAccessManager()),
    mDownloader(new YdHttpDownloader())
{
}

YdHttpManager::~YdHttpManager()
{
    if (mNetwork) {
        delete mNetwork;
        mNetwork = nullptr;
    }

    if (mDownloader) {
        delete mDownloader;
        mDownloader = nullptr;
    }
}

#pragma mark - Network

static HttpSessionId sHttpSessionId = 0;

HttpSessionId YdHttpManager::get(const QString& url,
                                 const QMap<QString, QString>& params,
                                 const QObject *receiver,
                                 const char *completion,
                                 int timeout)
{
    if (url.isEmpty()) { return kHttpSessionUnvliad; }

    QString urlM = url;
    if (!urlM.contains("?")) {
        urlM.append("?");
    }
    bool shouldAddAmpersand = true;
    if (urlM.endsWith("?")) {
        shouldAddAmpersand = false;
    }
    for (auto it = params.begin(); it != params.end(); ++it) {
        QString aParamItem = QString("%1=%2").arg(it.key()).arg(it.value());
        if (shouldAddAmpersand) {
            urlM.append("&");
        }
        urlM.append(aParamItem);
        shouldAddAmpersand = true;
    }
    urlM = QUrl::toPercentEncoding(urlM);
    QNetworkRequest request = QNetworkRequest(QUrl(urlM));
    QNetworkReply *reply = mNetwork->get(request);
    if (!reply) { return kHttpSessionUnvliad; }

    if (timeout > 0) {
        QTimer::singleShot(timeout*1000, this, SLOT(filterTimeoutSession()));
    }
    connect(reply, SIGNAL(finished()), this, SLOT(onFinished()));
    YdHttpSession *session = createSession(reply, request, url, params, receiver, completion, timeout);
    {
        session->setMethod(YDHttpMethod::Get);
        if (receiver != nullptr && completion != nullptr) {
            connect(session, SIGNAL(finished(YdHttpSession*,QString)), receiver, completion);
        }
    }
    mActiveSessions.insert(reply, session);
    return sHttpSessionId++;
}

HttpSessionId YdHttpManager::post(const QString& url,
                                  const QMap<QString, QString>& params,
                                  const QObject *receiver,
                                  const char *completion,
                                  int timeout)
{
    if (url.isEmpty()) { return kHttpSessionUnvliad; }

    QJsonObject paramsJson;
    for (auto it = params.begin(); it != params.end(); ++it) {
        if (it.key().isEmpty() || it.value().isEmpty()) { continue; }
        paramsJson[it.key()] = it.value();
    }
    QJsonDocument jsonDoc;
    jsonDoc.setObject(paramsJson);
    QNetworkRequest request = QNetworkRequest(QUrl(url));
    request.setRawHeader("Content-type", "application/json");
    QString paramsTxt(jsonDoc.toBinaryData());
    QNetworkReply *reply = mNetwork->post(request, paramsTxt.toUtf8());
    if (!reply) { return kHttpSessionUnvliad; }

    if (timeout > 0) {
        QTimer::singleShot(timeout*1000, this, SLOT(filterTimeoutSession()));
    }
    connect(reply, SIGNAL(finished()), this, SLOT(onFinished()));
    YdHttpSession *session = createSession(reply, request, url, params, receiver, completion, timeout);
    {
        session->setMethod(YDHttpMethod::Post);
        if (receiver != nullptr && completion != nullptr) {
            connect(session, SIGNAL(finished(YdHttpSession*,QString)), receiver, completion);
        }
    }
    mActiveSessions.insert(reply, session);
    return sHttpSessionId++;
}

HttpSessionId YdHttpManager::post(const QString& url,
                   const QString& paramsTxt,
                   const QObject *receiver,
                   const char *completion,
                   int timeout)
{
    if (url.isEmpty()) { return kHttpSessionUnvliad; }

    QNetworkRequest request = QNetworkRequest(QUrl(url));
    request.setRawHeader("Content-type", "application/json");
    QNetworkReply *reply = mNetwork->post(request, paramsTxt.toUtf8());
    if (!reply) { return kHttpSessionUnvliad; }

    if (timeout > 0) {
        QTimer::singleShot(timeout*1000, this, SLOT(filterTimeoutSession()));
    }
    connect(reply, SIGNAL(finished()), this, SLOT(onFinished()));
    QMap<QString, QString> param;
    param["data"] = paramsTxt;
    YdHttpSession *session = createSession(reply, request, url, param, receiver, completion, timeout);
    {
        session->setMethod(YDHttpMethod::Post);
        if (receiver != nullptr && completion != nullptr) {
            connect(session, SIGNAL(finished(YdHttpSession*,QString)), receiver, completion);
        }
    }
    mActiveSessions.insert(reply, session);
    return sHttpSessionId++;
}

HttpSessionId YdHttpManager::upload(const QString& url,
                                    const QMap<QString, QString>& params,
                                    const QString& filePath,
                                    const QObject *receiver,
                                    const char *completion,
                                    int timeout,
                                    std::function<void(QString&,QString&)> fileTypeNameConfig)
{
    if (url.isEmpty()) { return kHttpSessionUnvliad; }

    QHttpMultiPart *multiPart = new QHttpMultiPart(QHttpMultiPart::FormDataType);

    for (auto it = params.begin(); it != params.end(); ++it) {
        QHttpPart textPart;
        QString textHeader = QString("form-data; name=\"%1\"").arg(it.key());
        textPart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant(textHeader));
        textPart.setBody(it.value().toUtf8());
        multiPart->append(textPart);
    }

    QFile *file = new QFile(filePath);
    if (file->exists()) {
        QString fileType = "image/png";
        QString fileName = "file";
        if (fileTypeNameConfig) {
            fileTypeNameConfig(fileType, fileName);
        }
        QHttpPart filePart;
        filePart.setHeader(QNetworkRequest::ContentTypeHeader, QVariant(fileType));
        QString fileHeader = QString("form-data; name=\"%1\"; filename=\"%2\"").arg(fileName).arg(file->fileName());
        filePart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant(fileHeader));
        file->open(QIODevice::ReadOnly);
        filePart.setBodyDevice(file);
        multiPart->append(filePart);
        file->setParent(multiPart);
    } else {
        delete  file;
    }
    QNetworkRequest request = QNetworkRequest(QUrl(url));
    QNetworkReply *reply = mNetwork->post(request, multiPart);
    if (!reply) {
        delete  multiPart;
        return kHttpSessionUnvliad;
    }

    multiPart->setParent(reply);
    if (timeout > 0) {
        QTimer::singleShot(timeout*1000, this, SLOT(filterTimeoutSession()));
    }
    connect(reply, SIGNAL(finished()), this, SLOT(onFinished()));
    YdHttpSession *session = createSession(reply, request, url, params, receiver, completion, timeout);
    {
        session->setMethod(YDHttpMethod::Upload);
        if (receiver != nullptr && completion != nullptr) {
            connect(session, SIGNAL(finished(YdHttpSession*,QString)), receiver, completion);
        }
    }
    mActiveSessions.insert(reply, session);
    return sHttpSessionId++;
}

HttpSessionId YdHttpManager::download(const QString& url,
                                      const QObject *receiver,
                                      const char *progress,
                                      const char *completion,
                                      int timeout)
{
    if (url.isEmpty()) { return kHttpSessionUnvliad; }

    QNetworkRequest request = QNetworkRequest(QUrl(url));
    QNetworkReply *reply = mNetwork->get(request);
    if (!reply) { return kHttpSessionUnvliad; }

    if (timeout > 0) {
        QTimer::singleShot(timeout*1000, this, SLOT(filterTimeoutSession()));
    }
    connect(reply, SIGNAL(finished()), this, SLOT(onFinished()));
    connect(reply, SIGNAL(downloadProgress(qint64,qint64)), this, SLOT(onDownloadProgress(qint64,qint64)));
//    readyRead 中逐步写入文件的方式, 会发生下载图片只有一半的情况. 在目前只有图片这种小资源文件的情况下, 先使用 finish 一次写入的办法
//    connect(reply, SIGNAL(readyRead()), this, SLOT(onReadyRead()));

    QMap<QString, QString> params;
    YdHttpSession *session = createSession(reply, request, url, params, receiver, completion, timeout);
    {
        session->setProgressHandler(progress);
        session->setMethod(YDHttpMethod::Download);
        if (receiver != nullptr && completion != nullptr) {
            connect(session, SIGNAL(donwloadFinished(YdHttpSession*,const QString&)), receiver, completion);
        }
        if (receiver != nullptr && progress != nullptr) {
            connect(session, SIGNAL(downloadProgress(YdHttpSession*,qint64,qint64)), receiver, progress);
        }
        mDownloader->startDownload(session->url());
    }
    mActiveSessions.insert(reply, session);
    return sHttpSessionId++;
}

YdHttpSession* YdHttpManager::createSession(QNetworkReply *reply,
                                            const QNetworkRequest& request,
                                            const QString& url,
                                            const QMap<QString, QString>& params,
                                            const QObject *receiver,
                                            const char *completion,
                                            int timeout)
{
    YdHttpSession *session = new YdHttpSession(reply);
    session->setRequest(request);
    session->setSessionId(sHttpSessionId);
    session->setStartTime(QDateTime::currentDateTime());
    session->setTimeOut(timeout);

    session->setUrl(url);
    session->setParams(params);

    session->setReceiver(receiver);
    session->setCompletionHandler(completion);

    return session;
}

/*!
 * \brief YdHttpManager::filterTimeoutSession
 * Qt 5.15 才提供了 timeOut 的设置功能, 在此之前, 需要手动启动定时器判断超时.
 */

void YdHttpManager::filterTimeoutSession()
{
    QVector<YdHttpSession*> timeOutSessions;
    for (auto it = mActiveSessions.begin(); it != mActiveSessions.end(); ++it) {
        YdHttpSession *session = it.value();
        if (session->timeOut() <= 0) { continue; }
        int passedSeconds = QDateTime::currentDateTime().toSecsSinceEpoch() -
                session->startTime().toSecsSinceEpoch();
        if (passedSeconds >= session->timeOut()) {
            timeOutSessions.append(it.value());
        }
    }
    for (auto it = timeOutSessions.begin(); it != timeOutSessions.end(); ++it) {
        YdHttpSession* session = *it;
        session->setTimeouted();
        session->reply()->abort();
    }
}

bool YdHttpManager::cancel(HttpSessionId sessionId)
{
    if (sessionId == kHttpSessionUnvliad) {
        return false;
    }
    bool hasFound = false;
    QVector<YdHttpSession*> needCancelSessions;
    for (auto it = mActiveSessions.begin(); it != mActiveSessions.end(); ++it) {
        YdHttpSession *session = it.value();
        if (session->sessionId() != sessionId) { continue; }
        needCancelSessions.append(it.value());
    }
    for (auto it = needCancelSessions.begin(); it != needCancelSessions.end(); ++it) {
        YdHttpSession* session = *it;
        session->setCanceled();
        session->reply()->abort();
        hasFound = true;
    }
    return hasFound;
}

#pragma mark - ReplyHandler

void YdHttpManager::onFinished()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) { return; }
    auto it = mActiveSessions.find(reply);
    if (it == mActiveSessions.end()) { return; }
    YdHttpSession *session = it.value();
    if (session->method() == YDHttpMethod::Download) {
        mDownloader->appendData(session->url(), reply->readAll());
        mDownloader->finishDownload(session->url());
        session->emitDownloadFinished(mDownloader->downloadFilePath(session->url()));
        mDownloader->removeDownload(session->url());
    } else {
        session->emitFinished();
    }
    if (!session->url().contains("https://oapi.dingtalk.com/robot/send")) {
       qDebug().noquote() << session->description();
    }
    mActiveSessions.remove(reply);
    session->deleteLater();
    reply->deleteLater();
}

void YdHttpManager::onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal)
{
    QNetworkReply *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) { return; }
    auto it = mActiveSessions.find(reply);
    if (it == mActiveSessions.end()) { return; }
    YdHttpSession *session = it.value();
    session->emitProgress(bytesReceived, bytesTotal);
}

void YdHttpManager::onReadyRead()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) { return; }
    auto it = mActiveSessions.find(reply);
    if (it == mActiveSessions.end()) { return; }
    YdHttpSession *session = it.value();
    mDownloader->appendData(session->url(), reply->readAll());
}

#endif
