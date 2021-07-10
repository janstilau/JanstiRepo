// Created by liugquoqiang at 2020-12-8

#ifndef YDIMAGECACHE_H
#define YDIMAGECACHE_H

#include <QObject>
#include <QPixmap>
#include <QSet>

class YdHttpSession;

extern const QString YDImageDownloadedNoti;
extern const QString YDImageDownloadedUrl;

class YdImageCache : public QObject
{
    Q_OBJECT
public:
    explicit YdImageCache(QObject *parent = nullptr);

public:
    static YdImageCache *generalCache();
    static YdImageCache *homeworkCache();
    static void clearAll();
    static void clearAllImgDaysAgo(int daysAgo = 3);

public:
    bool hasCachedImage(const QString &url) const;
    QString imageCachePath(const QString &url) const;
    QPixmap cachedImage(const QString &url);
    void removeCachedImg(const QString &url);

    void startCache(const QString &url);
    bool isDownloading(const QString &url);
    bool setCacheDir(const QString &cacheDir);

    void clear();
    void clearImgDaysAgo(int daysAgo = 3);

private slots:
    void onImageDownloadProgress(YdHttpSession *session, qint64 bytesReceived, qint64 bytesTotal);
    void onImageDownloadFinish(YdHttpSession *session, const QString& tempFilePath);

private:
    QString mCacheDirPath;
    QSet<QString> mDownloadingUrls;
};

#endif // YDIMAGECACHE_H
