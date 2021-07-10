// Created by liugquoqiang at 2020-11-16

#ifdef YD_HOMEWORK

#ifndef YDHTTPMANAGER_H
#define YDHTTPMANAGER_H

#include <QObject>
#include "YdHttpSession.h"

/*
 * void onNetworkFinish(YdHttpSession *session, QString response);
 * void onDownloadFinish(YdHttpSession *session, const QString& tempFilePath);
 * void onDownloadProgress(YdHttpSession *session, qint64 bytesReceived, qint64 bytesTotal);
 */

class QNetworkAccessManager;
class QNetworkReply;
class YdHttpDownloader;

class YdHttpManager : public QObject
{
    Q_OBJECT
public:
    static YdHttpManager& instance();
    ~YdHttpManager();

public:
    HttpSessionId get(const QString& url,
                      const QMap<QString, QString>& params,
                      const QObject *receiver =  nullptr,
                      const char *completion = nullptr,
                      int timeout = 10);
    HttpSessionId post(const QString& url,
                       const QMap<QString, QString>& params,
                       const QObject *receiver =  nullptr,
                       const char *completion = nullptr,
                       int timeout = 10);
    //! 参数中 value 为 json 对象, 转化为字符串可能会引起服务器端解析错误, 可以在业务层组织数据发送 json 字符串.
    HttpSessionId post(const QString& url,
                       const QString& paramsTxt,
                       const QObject *receiver =  nullptr,
                       const char *completion = nullptr,
                       int timeout = 10);
    HttpSessionId upload(const QString& url,
                         const QMap<QString, QString>& params,
                         const QString& filePath,
                         const QObject *receiver =  nullptr,
                         const char *completion = nullptr,
                         int timeout = 10,
                         std::function<void(QString&,QString&)> fileTypeNameConfig = nullptr);
    HttpSessionId download(const QString& url,
                           const QObject *receiver =  nullptr,
                           const char *progress = nullptr,
                           const char *completion = nullptr,
                           int timeout = 0);
    bool cancel(HttpSessionId sessionId);

private slots:
    void onFinished();

    void onReadyRead();
    void onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal);

    void filterTimeoutSession();

private:
    YdHttpSession *createSession(QNetworkReply *reply,
                                 const QNetworkRequest& request,
                                 const QString& url,
                                 const QMap<QString, QString>& params,
                                 const QObject *receiver =  nullptr,
                                 const char *completion = nullptr,
                                 int timeout = 0);

private:
    YdHttpManager(QObject* parent = nullptr);
    YdHttpManager(const YdHttpManager&) = delete;
    YdHttpManager(YdHttpManager&&) = delete;
    YdHttpManager& operator=(const YdHttpManager&) = delete;
    YdHttpManager& operator=(YdHttpManager&&) = delete;

private:
    QNetworkAccessManager *mNetwork = nullptr;
    YdHttpDownloader *mDownloader = nullptr;
    QMap<QNetworkReply*, YdHttpSession*> mActiveSessions;
};

#define YdNetwork (YdHttpManager::instance())

#endif // YDHTTPMANAGER_H

#endif
