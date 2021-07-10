// Created by liugquoqiang at 2020-11-16

#ifdef YD_HOMEWORK

#include "YdHttpSession.h"
#include <QDebug>

YdHttpSession::YdHttpSession(QNetworkReply *parent) : QObject(parent)
{
    mReply = parent;
}

YdHttpSession::~YdHttpSession()
{
}


void YdHttpSession::emitFinished()
{
    QString response = mReply->readAll();
    mResponse = response;
    emit finished(this, response);
}

void YdHttpSession::emitDownloadFinished(QString tempFilePath)
{
    emit donwloadFinished(this, tempFilePath);
}

void YdHttpSession::emitProgress(qint64 bytesReceived, qint64 bytesTotal)
{
    emit downloadProgress(this, bytesReceived, bytesTotal);
}

#pragma mark - PropertyGet

static QString methodName(YDHttpMethod method)
{
    QMap<YDHttpMethod, QString> names = {
        {YDHttpMethod::Get, "Get"},
        {YDHttpMethod::Post, "Post"},
        {YDHttpMethod::Upload, "Upload"},
        {YDHttpMethod::Download, "Download"},
    };
    return names[method];
}

QString YdHttpSession::description() const
{
    QString result;
    result.reserve(100);
    result.append(methodName(mMethod)).append(": ").append(mUrl).append('\n');
    QString params;
    for (auto it = mParams.begin(); it != mParams.end(); ++it) {
        params.append(it.key()).append(":").append(it.value()).append('\n');
    }
    result.append("parameters:\n").append(params);
    result.append("sessionID:").append(QString("%1").arg(mSessionId)).append('\n');
    int costTime = QDateTime::currentDateTime().toMSecsSinceEpoch() - mStartTime.toMSecsSinceEpoch();
    double timeSecond = costTime / 1000.0;
    result.append("总耗时:").append(QString("%1 秒").arg(timeSecond));
    if (mIsCanceled) {
        result.append("  被取消").append('\n');
    } else if (mIsTimeouted) {
        result.append("  超时").append('\n');
    } else {
        result.append('\n');
    }
    result.append("Response:\n").append(mResponse).append('\n');
    return result;
}

HttpSessionId YdHttpSession::sessionId() const
{
    return mSessionId;
}

YDHttpMethod YdHttpSession::method() const
{
    return mMethod;
}

QDateTime YdHttpSession::startTime() const
{
    return mStartTime;
}

int YdHttpSession::timeOut() const
{
    return mTimeOut;
}

QNetworkRequest YdHttpSession::request() const
{
    return mRequest;
}

QString YdHttpSession::url() const
{
    return mUrl;
}

QMap<QString, QString> YdHttpSession::params() const
{
    return mParams;
}

QObject* YdHttpSession::recevier() const
{
    if (mReceiver.isNull()) {
        return nullptr;
    } else {
        return mReceiver.data();
    }

}

QString YdHttpSession::completionHandler() const
{
    return mCompletionHandler;
}

QString YdHttpSession::progressHandler() const
{
    return mProgressHandler;
}

QNetworkReply* YdHttpSession::reply() const
{
    if (mReply.isNull()) {
        return nullptr;
    } else {
        return mReply.data();
    }
}

bool YdHttpSession::isCanceled() const
{
    return mIsCanceled;
}

bool YdHttpSession::isTimeouted() const
{
    return mIsTimeouted;
}

#pragma mark - PropertySet

void YdHttpSession::setSessionId(HttpSessionId id)
{
    mSessionId = id;
}
void YdHttpSession::setMethod(YDHttpMethod method)
{
    mMethod = method;
}

void YdHttpSession::setStartTime(const QDateTime& startTime)
{
    mStartTime = startTime;
}

void YdHttpSession::setTimeOut(int timeOut)
{
    mTimeOut = timeOut;
}

void YdHttpSession::setRequest(const QNetworkRequest& request)
{
    mRequest = request;
}

void YdHttpSession::setUrl(const QString& url)
{
    mUrl = url;
}

void YdHttpSession::setParams(const QMap<QString, QString>& params)
{
    mParams = params;
}

void YdHttpSession::setReceiver(const QObject *recevier)
{
    QObject *receiverObj = const_cast<QObject *>(recevier);
    mReceiver = receiverObj;
}

void YdHttpSession::setCompletionHandler(const QString& completionHandler)
{
    mCompletionHandler = completionHandler;
}

void YdHttpSession::setProgressHandler(const QString& progressHandler)
{
    mProgressHandler = progressHandler;
}

void YdHttpSession::setReply(const QNetworkReply* reply) {
    QNetworkReply *receiverObj = const_cast<QNetworkReply *>(reply);
    mReply = receiverObj;
}

void YdHttpSession::setCanceled()
{
    mIsCanceled = true;
}

void YdHttpSession::setTimeouted()
{
    mIsTimeouted = true;
}

#endif
