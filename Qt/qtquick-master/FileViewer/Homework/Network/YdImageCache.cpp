// Created by liugquoqiang at 2020-12-8

#include "YdImageCache.h"
#include <QDir>
#include <QFile>
#include <QCryptographicHash>
#include <QDebug>
#include "Notification/YdNotificationCenter.h"
#include "Network/YdHttpManager.h"
#include "Network/YdHttpSession.h"
#include "Business/YdDefer.h"

const QString YDImageDownloadedNoti = "YDImageDownloadedNoti";
const QString YDImageDownloadedUrl = "YDImageDownloadedUrl";

YdImageCache::YdImageCache(QObject *parent) : QObject(parent)
{
}

bool YdImageCache::isDownloading(const QString &url)
{
    return mDownloadingUrls.contains(url);
}

bool YdImageCache::hasCachedImage(const QString &url) const
{
    QFile file(imageCachePath(url));
    return file.exists();
}

QString YdImageCache::imageCachePath(const QString &url) const
{
    if (url.isEmpty()) { return ""; }
    QByteArray md5Byte = QCryptographicHash::hash(url.toUtf8(), QCryptographicHash::Md5);
    QString urlPath = md5Byte.toBase64(QByteArray::Base64UrlEncoding);
    return QString("%1/%2").arg(mCacheDirPath).arg(urlPath);
}

void YdImageCache::startCache(const QString &url)
{
    if (mDownloadingUrls.contains(url)) { return; }
    YdNetwork.download(url, this,
                       SLOT(onImageDownloadProgress(YdHttpSession*,qint64,qint64)),
                       SLOT(onImageDownloadFinish(YdHttpSession*, const QString)));
}

QPixmap YdImageCache::cachedImage(const QString &url)
{
    if (!hasCachedImage(url)) { return QPixmap(); }
    return QPixmap(imageCachePath(url));
}

void YdImageCache::removeCachedImg(const QString &url)
{
    QFile removeImgFile(imageCachePath(url));
    removeImgFile.remove();
}

bool YdImageCache::setCacheDir(const QString &cacheDirPath)
{
    if (cacheDirPath.isEmpty()) { return false; }
    mCacheDirPath = cacheDirPath;
    QDir cacheDir(cacheDirPath);
    if (!cacheDir.exists()) {
        return cacheDir.mkpath(".");
    } else {
        return true;
    }
}

#pragma mark - Network

void YdImageCache::onImageDownloadProgress(YdHttpSession *session, qint64 bytesReceived, qint64 bytesTotal)
{
    qreal percent = 0.0;
    if (bytesTotal != 0) {
        percent = bytesReceived*1.0 / bytesTotal;
    }
    qDebug() << "ImageDownload:"<< session->url() << percent*100 << "%.";
}

void YdImageCache::onImageDownloadFinish(YdHttpSession *session, const QString& tempFilePath)
{
    YdDefer defer([this, session](){
        mDownloadingUrls.remove(session->url());
    });
    if (session->isCanceled()) { return; }
    QFile downloadedImgFile(tempFilePath);
    QFileInfo downloadedImgFileInfo(tempFilePath);
    if (!downloadedImgFile.exists()) {
        qDebug() << "File download failed. Empty download";
        return;
    }
    if (downloadedImgFileInfo.size() <= 10) {
        qDebug() << "File download failed. Unvalid image data:" << downloadedImgFileInfo.size() <<"Bytes";
        return;
    }

    QMap<QString, QVariant> infos;
    infos[YDImageDownloadedUrl] = session->url();
    downloadedImgFile.copy(imageCachePath(session->url()));
    NotiCenter.postNotification(YDImageDownloadedNoti,
                                this,
                                infos);
}

#pragma mark - TrashClear

void YdImageCache::clear()
{
    QDir dir(mCacheDirPath);
    dir.removeRecursively();
    setCacheDir(mCacheDirPath);
}

void YdImageCache::clearImgDaysAgo(int daysAgo)
{
    QDir dir(mCacheDirPath);
    QFileInfoList fileInfoList = dir.entryInfoList();
    QFileInfoList needDeleteFiles;
    for (const auto &fileInfo: fileInfoList) {
        int passedSeconds = QDateTime::currentDateTime().toSecsSinceEpoch() -
                fileInfo.lastRead().toSecsSinceEpoch();
        if (passedSeconds > daysAgo*24*60) {
            needDeleteFiles.append(fileInfo);
        }
    }
    for (const auto &aDeleteFile: needDeleteFiles) {
        dir.remove(aDeleteFile.fileName());
    }
}

#pragma mark - Static

#ifdef Q_OS_MACOS
static QString kGeneralCacheDir = "/Users/liugq01/Work/PenImageCache/general_img";
static QString kHomeworkCacheDir = "/Users/liugq01/Work/PenImageCache/homework_img";
#else
static QString kGeneralCacheDir = "/userdisk/cache/general_img";
static QString kHomeworkCacheDir = "/userdisk/cache/homework_img";
#endif
static QSet<YdImageCache*> sGlobalCache = QSet<YdImageCache*>();

YdImageCache* YdImageCache::generalCache()
{
    static YdImageCache* kGeneralCache = nullptr;
    if (!kGeneralCache) {
        kGeneralCache = new YdImageCache;
        kGeneralCache->setCacheDir(kGeneralCacheDir);
        sGlobalCache.insert(kGeneralCache);
    }

    return kGeneralCache;
}

YdImageCache* YdImageCache::homeworkCache()
{
    static YdImageCache* kHomeworkCache = nullptr;
    if (!kHomeworkCache) {
        kHomeworkCache = new YdImageCache;
        kHomeworkCache->setCacheDir(kHomeworkCacheDir);
        sGlobalCache.insert(kHomeworkCache);
    }
    return kHomeworkCache;
}

void YdImageCache::clearAll()
{
    for (YdImageCache *aCache: sGlobalCache) {
        aCache->clear();
    }
}

void YdImageCache::clearAllImgDaysAgo(int daysAgo)
{
    for (YdImageCache *aCache: sGlobalCache) {
        aCache->clearImgDaysAgo(daysAgo);
    }
}
