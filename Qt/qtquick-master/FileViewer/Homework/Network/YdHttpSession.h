// Created by liugquoqiang at 2020-11-16

#ifdef YD_HOMEWORK

#ifndef YDHTTPSESSION_H
#define YDHTTPSESSION_H

#include <QObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QPointer>

enum YDHttpMethod{
    Get,
    Post,
    Upload,
    Download
};

typedef int HttpSessionId;
const int kHttpSessionUnvliad = -1;

class YdHttpSession : public QObject
{
    Q_OBJECT
public:
    explicit YdHttpSession(QNetworkReply *parent = nullptr);
    ~YdHttpSession();

    void emitFinished();
    void emitDownloadFinished(QString tempFilePath);
    void emitProgress(qint64 bytesReceived, qint64 bytesTotal);

signals:
    void finished(YdHttpSession *session, const QString& response);
    void donwloadFinished(YdHttpSession *session, const QString& tempFilePath);
    void downloadProgress(YdHttpSession *session, qint64 bytesReceived, qint64 bytesTotal);

public:
    QString description() const;

    HttpSessionId sessionId() const;
    YDHttpMethod method() const;
    QDateTime startTime() const;
    int timeOut() const;
    QNetworkRequest request() const;
    QString url() const;
    QMap<QString, QString> params() const;
    QObject *recevier() const;
    QString completionHandler() const;
    QString progressHandler() const;
    QNetworkReply *reply() const;
    bool isCanceled() const;
    bool isTimeouted() const;

    void setSessionId(HttpSessionId id);
    void setMethod(YDHttpMethod method);
    void setStartTime(const QDateTime& startTime);
    void setTimeOut(int timeOut);
    void setRequest(const QNetworkRequest& request);
    void setUrl(const QString& url);
    void setParams(const QMap<QString, QString>& params);
    void setReceiver(const QObject *recevier);
    void setCompletionHandler(const QString& completionHandler);
    void setProgressHandler(const QString& progressHandler);
    void setReply(const QNetworkReply* reply);
    void setCanceled();
    void setTimeouted();

private:
    HttpSessionId mSessionId = kHttpSessionUnvliad;
    YDHttpMethod mMethod = YDHttpMethod::Get;
    QDateTime mStartTime;
    int mTimeOut = 0;

    QNetworkRequest mRequest;
    QString mUrl;
    QMap<QString, QString> mParams;
    QString mResponse;

    QPointer<QObject> mReceiver;
    QString mCompletionHandler;
    QString mProgressHandler;

    QPointer<QNetworkReply> mReply;
    bool mIsCanceled = false;
    bool mIsTimeouted = false;
};

#endif // YDHTTPSESSION_H

#endif
