// Created by liugquoqiang at 2020-11-16

#ifdef YD_HOMEWORK

#ifndef YDHTTPDOWNLOADER_H
#define YDHTTPDOWNLOADER_H

#include <QObject>
#include <QFile>
#include <QMap>

class YdHttpDownloader : public QObject
{
    Q_OBJECT
public:
    explicit YdHttpDownloader(QObject *parent = nullptr);

public:
    QString downloadFilePath(const QString &url) const;
    void startDownload(const QString& url);
    void finishDownload(const QString& url);
    void appendData(const QString&url, QByteArray data);
    void removeDownload(const QString& url);

private:
    QMap<QString, QFile*> mActiveUrls;

};

#endif // YDHTTPDOWNLOADER_H

#endif
