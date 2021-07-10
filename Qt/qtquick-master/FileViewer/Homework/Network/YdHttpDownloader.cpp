// Created by liugquoqiang at 2020-11-16

#ifdef YD_HOMEWORK

#include "YdHttpDownloader.h"
#include <QDir>
#include <QCryptographicHash>
#include <QDebug>

#ifdef Q_OS_MACOS
static QString kRootDownloadDir = "/Users/liugq01/Work/PenDownload";
#else
static QString kRootDownloadDir = "/userdisk/cache/download_tmp";
#endif

YdHttpDownloader::YdHttpDownloader(QObject *parent) : QObject(parent)
{
    QDir downloadRoot(kRootDownloadDir);
    if (!downloadRoot.exists()) {
        //! mkpath
        //! The function will create all parent directories necessary to create the directory.
        downloadRoot.mkpath(".");
    }
    // 每次启动, 清空未完成任务.
    QStringList files = downloadRoot.entryList();
    for (auto const &fileName: files) {
        downloadRoot.remove(fileName);
    }
}

QString YdHttpDownloader::downloadFilePath(const QString &url) const
{
    if (url.isEmpty()) { return ""; }
    QByteArray md5Byte = QCryptographicHash::hash(url.toUtf8(), QCryptographicHash::Md5);
    QString urlPath = md5Byte.toBase64(QByteArray::Base64UrlEncoding);
    return QString("%1/%2").arg(kRootDownloadDir).arg(urlPath);
}

void YdHttpDownloader::startDownload(const QString &url)
{
    if (mActiveUrls.find(url) != mActiveUrls.end()) { return; }
    const QString urlPath = downloadFilePath(url);
    if (urlPath.isEmpty()) { return; }

    if (QFile::exists(urlPath)) {
        QFile::remove(urlPath);
    }
    QFile *writeFile = new QFile(urlPath);
    writeFile->open(QIODevice::WriteOnly);
    mActiveUrls[url] = writeFile;
}

void YdHttpDownloader::appendData(const QString &url, QByteArray data)
{
    auto it = mActiveUrls.find(url);
    if (it == mActiveUrls.end()) { return; }
    QFile *writeFile = it.value();
    writeFile->write(data);
}

void YdHttpDownloader::finishDownload(const QString &url)
{
    auto it = mActiveUrls.find(url);
    if (it == mActiveUrls.end()) { return; }
    QFile *writeFile = it.value();
    writeFile->close();
    delete writeFile;
    mActiveUrls.erase(it);
}

void YdHttpDownloader::removeDownload(const QString &url)
{
    auto it = mActiveUrls.find(url);
    if (it == mActiveUrls.end()) {
        QFile::remove(downloadFilePath(url));
        return;
    }
    QFile *writeFile = it.value();
    writeFile->close();
    writeFile->remove();
    delete writeFile;
    mActiveUrls.erase(it);
}


#endif
