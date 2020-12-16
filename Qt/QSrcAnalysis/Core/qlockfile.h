#ifndef QLOCKFILE_H
#define QLOCKFILE_H

#include <QtCore/qstring.h>
#include <QtCore/qscopedpointer.h>

QT_BEGIN_NAMESPACE

class QLockFilePrivate;

// The QLockFile class provides locking between processes using a file.

class Q_CORE_EXPORT QLockFile
{
public:
    QLockFile(const QString &fileName);
    ~QLockFile();

    bool lock();
    bool tryLock(int timeout = 0);
    void unlock();

    void setStaleLockTime(int);
    int staleLockTime() const;

    bool isLocked() const;
    bool getLockInfo(qint64 *pid, QString *hostname, QString *appname) const;
    bool removeStaleLockFile();

    enum LockError {
        NoError = 0,
        LockFailedError = 1,
        PermissionError = 2,
        UnknownError = 3
    };
    LockError error() const;

protected:
    QScopedPointer<QLockFilePrivate> d_ptr;

private:
    Q_DECLARE_PRIVATE(QLockFile)
    Q_DISABLE_COPY(QLockFile)
};

QT_END_NAMESPACE

#endif // QLOCKFILE_H
