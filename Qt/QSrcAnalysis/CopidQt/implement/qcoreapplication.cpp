#include "qcoreapplication.h"
#include "qcoreapplication_p.h"

#ifndef QT_NO_QOBJECT
#include "qabstracteventdispatcher.h"
#include "qcoreevent.h"
#include "qeventloop.h"
#endif
#include "qcorecmdlineargs_p.h"
#include <qdatastream.h>
#include <qdebug.h>
#include <qdir.h>
#include <qfile.h>
#include <qfileinfo.h>
#include <qmutex.h>
#include <private/qloggingregistry_p.h>
#include <qstandardpaths.h>
#include <qtextcodec.h>
#ifndef QT_NO_QOBJECT
#include <qthread.h>
#include <qthreadpool.h>
#include <qthreadstorage.h>
#include <private/qthread_p.h>
#endif
#include <qelapsedtimer.h>
#include <qlibraryinfo.h>
#include <qvarlengtharray.h>
#include <private/qfactoryloader_p.h>
#include <private/qfunctions_p.h>
#include <private/qlocale_p.h>
#include <private/qhooks_p.h>

#include <algorithm>

QT_BEGIN_NAMESPACE

#ifndef QT_NO_QOBJECT
// 简单地资源管理类, 利用构造析构进行资源的释放.
class QMutexUnlocker
{
public:
    inline explicit QMutexUnlocker(QMutex *m)
        : mtx(m)
    { }
    inline ~QMutexUnlocker() { unlock(); }
    inline void unlock() { if (mtx) mtx->unlock(); mtx = 0; }

private:
    Q_DISABLE_COPY(QMutexUnlocker)

    QMutex *mtx;
};
#endif

#if defined(Q_OS_WIN) || defined(Q_OS_MAC)
extern QString qAppFileName();
#endif

#if QT_VERSION >= 0x060000
#endif
int QCoreApplicationPrivate::app_compile_version = 0x050000; //we don't know exactly, but it's at least 5.0.0

bool QCoreApplicationPrivate::setuidAllowed = false;

#if !defined(Q_OS_WIN)
#ifdef Q_OS_DARWIN
QString QCoreApplicationPrivate::infoDictionaryStringProperty(const QString &propertyName)
{
    QString bundleName;
    QCFString cfPropertyName = propertyName.toCFString();
    CFTypeRef string = CFBundleGetValueForInfoDictionaryKey(CFBundleGetMainBundle(),
                                                            cfPropertyName);
    if (string)
        bundleName = QString::fromCFString(static_cast<CFStringRef>(string));
    return bundleName;
}
#endif
QString QCoreApplicationPrivate::appName() const
{
    QString applicationName;
    applicationName = infoDictionaryStringProperty(QStringLiteral("CFBundleName"));
    if (applicationName.isEmpty() && argv[0]) {
        char *p = strrchr(argv[0], '/');
        applicationName = QString::fromLocal8Bit(p ? p + 1 : argv[0]);
    }

    return applicationName;
}
QString QCoreApplicationPrivate::appVersion() const
{
    QString applicationVersion;
    applicationVersion = infoDictionaryStringProperty(QStringLiteral("CFBundleVersion"));
    return applicationVersion;
}
#endif

QString *QCoreApplicationPrivate::cachedApplicationFilePath = 0;

bool QCoreApplicationPrivate::checkInstance(const char *function)
{
    // 如果, 已经有了 Application 了, 就报错.
    bool b = (QCoreApplication::self != 0);
    if (!b)
        qWarning("QApplication::%s: Please instantiate the QApplication object first", function);
    return b;
}

void QCoreApplicationPrivate::processCommandLineArguments()
{
    int j = argc ? 1 : 0;
    for (int i = 1; i < argc; ++i) {
        if (!argv[i])
            continue;
        if (*argv[i] != '-') {
            argv[j++] = argv[i];
            continue;
        }
        const char *arg = argv[i];
        if (arg[1] == '-') // startsWith("--")
            ++arg;
        if (strncmp(arg, "-qmljsdebugger=", 15) == 0) {
            qmljs_debug_arguments = QString::fromLocal8Bit(arg + 15);
        } else if (strcmp(arg, "-qmljsdebugger") == 0 && i < argc - 1) {
            ++i;
            qmljs_debug_arguments = QString::fromLocal8Bit(argv[i]);
        } else {
            argv[j++] = argv[i];
        }
    }

    if (j < argc) {
        argv[j] = 0;
        argc = j;
    }
}

// Support for introspection

#ifndef QT_NO_QOBJECT
QSignalSpyCallbackSet Q_CORE_EXPORT qt_signal_spy_callback_set = { 0, 0, 0, 0 };

void qt_register_signal_spy_callbacks(const QSignalSpyCallbackSet &callback_set)
{
    qt_signal_spy_callback_set = callback_set;
}
#endif

extern "C" void Q_CORE_EXPORT qt_startup_hook()
{
}

typedef QList<QtStartUpFunction> QStartUpFuncList;
Q_GLOBAL_STATIC(QStartUpFuncList, preRList)
typedef QList<QtCleanUpFunction> QVFuncList;
Q_GLOBAL_STATIC(QVFuncList, postRList)
#ifndef QT_NO_QOBJECT
static QBasicMutex globalPreRoutinesMutex;
#endif

/*!
    \internal

    Adds a global routine that will be called from the QCoreApplication
    constructor. The public API is Q_COREAPP_STARTUP_FUNCTION.
*/
void qAddPreRoutine(QtStartUpFunction p)
{
    QStartUpFuncList *list = preRList();
    if (!list)
        return;
    // Due to C++11 parallel dynamic initialization, this can be called
    // from multiple threads.
#ifndef QT_NO_THREAD
    QMutexLocker locker(&globalPreRoutinesMutex);
#endif
    if (QCoreApplication::instance())
        p();
    list->prepend(p); // in case QCoreApplication is re-created, see qt_call_pre_routines
}

void qAddPostRoutine(QtCleanUpFunction p)
{
    QVFuncList *list = postRList();
    if (!list)
        return;
    list->prepend(p);
}

void qRemovePostRoutine(QtCleanUpFunction p)
{
    QVFuncList *list = postRList();
    if (!list)
        return;
    list->removeAll(p);
}

static void qt_call_pre_routines()
{
    if (!preRList.exists())
        return;

#ifndef QT_NO_THREAD
    QMutexLocker locker(&globalPreRoutinesMutex);
#endif
    QVFuncList *list = &(*preRList);
    // Unlike qt_call_post_routines, we don't empty the list, because
    // Q_COREAPP_STARTUP_FUNCTION is a macro, so the user expects
    // the function to be executed every time QCoreApplication is created.
    for (int i = 0; i < list->count(); ++i)
        list->at(i)();
}

void Q_CORE_EXPORT qt_call_post_routines()
{
    if (!postRList.exists())
        return;

    QVFuncList *list = &(*postRList);
    while (!list->isEmpty())
        (list->takeFirst())();
}


// initialized in qcoreapplication and in qtextstream autotest when setlocale is called.
static bool qt_locale_initialized = false;

#ifndef QT_NO_QOBJECT

// app starting up if false
bool QCoreApplicationPrivate::is_app_running = false;
 // app closing down if true
bool QCoreApplicationPrivate::is_app_closing = false;

Q_CORE_EXPORT uint qGlobalPostedEventsCount()
{
    QThreadData *currentThreadData = QThreadData::current();
    return currentThreadData->postEventList.size() - currentThreadData->postEventList.startOffset;
}

QAbstractEventDispatcher *QCoreApplicationPrivate::eventDispatcher = 0;

#endif // QT_NO_QOBJECT

QCoreApplication *QCoreApplication::self = 0; // 一个全局值, 因为 applicaiton 就应该只有一份.
uint QCoreApplicationPrivate::attribs =
    (1 << Qt::AA_SynthesizeMouseForUnhandledTouchEvents) |
    (1 << Qt::AA_SynthesizeMouseForUnhandledTabletEvents);

struct QCoreApplicationData {
    QCoreApplicationData() Q_DECL_NOTHROW {
        applicationNameSet = false;
        applicationVersionSet = false;
    }
    ~QCoreApplicationData() {
#ifndef QT_NO_QOBJECT
        // cleanup the QAdoptedThread created for the main() thread
        if (QCoreApplicationPrivate::theMainThread) {
            QThreadData *data = QThreadData::get2(QCoreApplicationPrivate::theMainThread);
            data->deref(); // deletes the data and the adopted thread
        }
#endif
    }

    QString orgName, orgDomain;
    QString application; // application name, initially from argv[0], can then be modified.
    QString applicationVersion;
    bool applicationNameSet; // true if setApplicationName was called
    bool applicationVersionSet; // true if setApplicationVersion was called

#if QT_CONFIG(library)
    QScopedPointer<QStringList> app_libpaths;
    QScopedPointer<QStringList> manual_libpaths;
#endif

};

Q_GLOBAL_STATIC(QCoreApplicationData, coreappdata)

#ifndef QT_NO_QOBJECT
static bool quitLockRefEnabled = true;
#endif

QCoreApplicationPrivate::QCoreApplicationPrivate(int &aargc, char **aargv, uint flags)
    :
#ifndef QT_NO_QOBJECT
      QObjectPrivate(),
#endif
      argc(aargc)
    , argv(aargv)
#if defined(Q_OS_WIN) && !defined(Q_OS_WINRT)
    , origArgc(0)
    , origArgv(Q_NULLPTR)
#endif
    , application_type(QCoreApplicationPrivate::Tty)
#ifndef QT_NO_QOBJECT
    , in_exec(false)
    , aboutToQuitEmitted(false)
    , threadData_clean(false)
#else
    , q_ptr(0)
#endif
{
    app_compile_version = flags & 0xffffff;
    static const char *const empty = "";
    if (argc == 0 || argv == 0) {
        argc = 0;
        argv = const_cast<char **>(&empty);
    }

#ifndef QT_NO_QOBJECT
    QCoreApplicationPrivate::is_app_closing = false;

#  if defined(Q_OS_UNIX)
    if (Q_UNLIKELY(!setuidAllowed && (geteuid() != getuid())))
        qFatal("FATAL: The application binary appears to be running setuid, this is a security hole.");
#  endif // Q_OS_UNIX

    QThread *cur = QThread::currentThread(); // note: this may end up setting theMainThread!
    if (cur != theMainThread)
        qWarning("WARNING: QApplication was not created in the main() thread.");
#endif
}

QCoreApplicationPrivate::~QCoreApplicationPrivate()
{
#ifndef QT_NO_QOBJECT
    cleanupThreadData();
#endif
    QCoreApplicationPrivate::clearApplicationFilePath();
}

#ifndef QT_NO_QOBJECT

void QCoreApplicationPrivate::cleanupThreadData()
{
    if (threadData && !threadData_clean) {
#ifndef QT_NO_THREAD
        void *data = &threadData->tls;
        QThreadStorageData::finish((void **)data);
#endif

        // need to clear the state of the mainData, just in case a new QCoreApplication comes along.
        QMutexLocker locker(&threadData->postEventList.mutex);
        for (int i = 0; i < threadData->postEventList.size(); ++i) {
            const QPostEvent &pe = threadData->postEventList.at(i);
            if (pe.event) {
                --pe.receiver->d_func()->postedEvents;
                pe.event->posted = false;
                delete pe.event;
            }
        }
        threadData->postEventList.clear();
        threadData->postEventList.recursion = 0;
        threadData->quitNow = false;
        threadData_clean = true;
    }
}

// 根据不同的环境, 创建不同的 dispatcher
void QCoreApplicationPrivate::createEventDispatcher()
{
    Q_Q(QCoreApplication);
#if defined(Q_OS_UNIX)
#  if defined(Q_OS_DARWIN)
    bool ok = false;
    int value = qEnvironmentVariableIntValue("QT_EVENT_DISPATCHER_CORE_FOUNDATION", &ok);
    if (ok && value > 0)
        eventDispatcher = new QEventDispatcherCoreFoundation(q);
    else
        eventDispatcher = new QEventDispatcherUNIX(q);
#  elif !defined(QT_NO_GLIB)
    if (qEnvironmentVariableIsEmpty("QT_NO_GLIB") && QEventDispatcherGlib::versionSupported())
        eventDispatcher = new QEventDispatcherGlib(q);
    else
        eventDispatcher = new QEventDispatcherUNIX(q);
#  else
        eventDispatcher = new QEventDispatcherUNIX(q);
#  endif
#elif defined(Q_OS_WINRT)
    eventDispatcher = new QEventDispatcherWinRT(q);
#elif defined(Q_OS_WIN)
    eventDispatcher = new QEventDispatcherWin32(q);
#else
#  error "QEventDispatcher not yet ported to this platform"
#endif
}

void QCoreApplicationPrivate::eventDispatcherReady()
{
}

QBasicAtomicPointer<QThread> QCoreApplicationPrivate::theMainThread = Q_BASIC_ATOMIC_INITIALIZER(0);
QThread *QCoreApplicationPrivate::mainThread()
{
    Q_ASSERT(theMainThread.load() != 0);
    return theMainThread.load();
}

bool QCoreApplicationPrivate::threadRequiresCoreApplication()
{
    QThreadData *data = QThreadData::current(false);
    if (!data)
        return true;    // default setting
    return data->requiresCoreApplication;
}

void QCoreApplicationPrivate::checkReceiverThread(QObject *receiver)
{
    QThread *currentThread = QThread::currentThread();
    QThread *thr = receiver->thread();
    Q_ASSERT_X(currentThread == thr || !thr,
               "QCoreApplication::sendEvent",
               QString::asprintf("Cannot send events to objects owned by a different thread. "
                                 "Current thread 0x%p. Receiver '%ls' (of type '%s') was created in thread 0x%p",
                                 currentThread, qUtf16Printable(receiver->objectName()),
                                 receiver->metaObject()->className(), thr)
               .toLocal8Bit().data());
    Q_UNUSED(currentThread);
    Q_UNUSED(thr);
}

#endif // QT_NO_QOBJECT

void QCoreApplicationPrivate::appendApplicationPathToLibraryPaths()
{
#if QT_CONFIG(library)
    QStringList *app_libpaths = coreappdata()->app_libpaths.data();
    if (!app_libpaths)
        coreappdata()->app_libpaths.reset(app_libpaths = new QStringList);
    QString app_location = QCoreApplication::applicationFilePath();
    app_location.truncate(app_location.lastIndexOf(QLatin1Char('/')));
#ifdef Q_OS_WINRT
    if (app_location.isEmpty())
        app_location.append(QLatin1Char('/'));
#endif
    app_location = QDir(app_location).canonicalPath();
    if (QFile::exists(app_location) && !app_libpaths->contains(app_location))
        app_libpaths->append(app_location);
#endif
}

QString qAppName()
{
    if (!QCoreApplicationPrivate::checkInstance("qAppName"))
        return QString();
    return QCoreApplication::instance()->d_func()->appName();
}

void QCoreApplicationPrivate::initLocale()
{
    if (qt_locale_initialized)
        return;
    qt_locale_initialized = true;
#if defined(Q_OS_UNIX) && !defined(QT_BOOTSTRAPPED)
    setlocale(LC_ALL, "");
#endif
}


QCoreApplication::QCoreApplication(QCoreApplicationPrivate &p)
#ifdef QT_NO_QOBJECT
    : d_ptr(&p)
#else
    : QObject(p, 0)
#endif
{
    d_func()->q_ptr = this;
}

#ifndef QT_NO_QOBJECT

#if QT_DEPRECATED_SINCE(5, 9)
void QCoreApplication::flush()
{
    if (self && self->d_func()->eventDispatcher)
        self->d_func()->eventDispatcher->flush();
}
#endif
#endif

QCoreApplication::QCoreApplication(int &argc, char **argv)
    : QObject(*new QCoreApplicationPrivate(argc, argv, _internal))
{
    d_func()->q_ptr = this;
    d_func()->init();
}


void QCoreApplicationPrivate::init()
{
#if defined(Q_OS_MACOS)
    QMacAutoReleasePool pool;
#endif

    Q_Q(QCoreApplication);

    initLocale();

    QCoreApplication::self = q;

    // Store app name/version (so they're still available after QCoreApplication is destroyed)
    if (!coreappdata()->applicationNameSet)
        coreappdata()->application = appName();

    if (!coreappdata()->applicationVersionSet)
        coreappdata()->applicationVersion = appVersion();

#if QT_CONFIG(library)
    // Reset the lib paths, so that they will be recomputed, taking the availability of argv[0]
    // into account. If necessary, recompute right away and replay the manual changes on top of the
    // new lib paths.
    QStringList *appPaths = coreappdata()->app_libpaths.take();
    QStringList *manualPaths = coreappdata()->manual_libpaths.take();
    if (appPaths) {
        if (manualPaths) {
            // Replay the delta. As paths can only be prepended to the front or removed from
            // anywhere in the list, we can just linearly scan the lists and find the items that
            // have been removed. Once the original list is exhausted we know all the remaining
            // items have been added.
            QStringList newPaths(q->libraryPaths());
            for (int i = manualPaths->length(), j = appPaths->length(); i > 0 || j > 0; qt_noop()) {
                if (--j < 0) {
                    newPaths.prepend((*manualPaths)[--i]);
                } else if (--i < 0) {
                    newPaths.removeAll((*appPaths)[j]);
                } else if ((*manualPaths)[i] != (*appPaths)[j]) {
                    newPaths.removeAll((*appPaths)[j]);
                    ++i; // try again with next item.
                }
            }
            delete manualPaths;
            coreappdata()->manual_libpaths.reset(new QStringList(newPaths));
        }
        delete appPaths;
    }
#endif

#ifndef QT_NO_QOBJECT
    // use the event dispatcher created by the app programmer (if any)
    if (!eventDispatcher)
        eventDispatcher = threadData->eventDispatcher.load();
    // otherwise we create one
    if (!eventDispatcher)
        createEventDispatcher();
    Q_ASSERT(eventDispatcher);

    if (!eventDispatcher->parent()) {
        eventDispatcher->moveToThread(threadData->thread);
        eventDispatcher->setParent(q);
    }

    threadData->eventDispatcher = eventDispatcher;
    eventDispatcherReady();
#endif

#ifdef QT_EVAL
    extern void qt_core_eval_init(QCoreApplicationPrivate::Type);
    qt_core_eval_init(application_type);
#endif

    processCommandLineArguments();

    qt_call_pre_routines();
    qt_startup_hook();
#ifndef QT_BOOTSTRAPPED
    if (Q_UNLIKELY(qtHookData[QHooks::Startup]))
        reinterpret_cast<QHooks::StartupCallback>(qtHookData[QHooks::Startup])();
#endif

#ifndef QT_NO_QOBJECT
    is_app_running = true; // No longer starting up.
#endif
}

/*!
    Destroys the QCoreApplication object.
*/
QCoreApplication::~QCoreApplication()
{
    qt_call_post_routines();

    self = 0;
#ifndef QT_NO_QOBJECT
    QCoreApplicationPrivate::is_app_closing = true;
    QCoreApplicationPrivate::is_app_running = false;
#endif

#if !defined(QT_NO_THREAD)
    // Synchronize and stop the global thread pool threads.
    QThreadPool *globalThreadPool = 0;
    QT_TRY {
        globalThreadPool = QThreadPool::globalInstance();
    } QT_CATCH (...) {
        // swallow the exception, since destructors shouldn't throw
    }
    if (globalThreadPool)
        globalThreadPool->waitForDone();
#endif

#ifndef QT_NO_QOBJECT
    d_func()->threadData->eventDispatcher = 0;
    if (QCoreApplicationPrivate::eventDispatcher)
        QCoreApplicationPrivate::eventDispatcher->closingDown();
    QCoreApplicationPrivate::eventDispatcher = 0;
#endif

#if QT_CONFIG(library)
    coreappdata()->app_libpaths.reset();
    coreappdata()->manual_libpaths.reset();
#endif
}

void QCoreApplication::setSetuidAllowed(bool allow)
{
    QCoreApplicationPrivate::setuidAllowed = allow;
}


bool QCoreApplication::isSetuidAllowed()
{
    return QCoreApplicationPrivate::setuidAllowed;
}



void QCoreApplication::setAttribute(Qt::ApplicationAttribute attribute, bool on)
{
    if (on)
        QCoreApplicationPrivate::attribs |= 1 << attribute;
    else
        QCoreApplicationPrivate::attribs &= ~(1 << attribute);
}

/*!
  Returns \c true if attribute \a attribute is set;
  otherwise returns \c false.

  \sa setAttribute()
 */
bool QCoreApplication::testAttribute(Qt::ApplicationAttribute attribute)
{
    return QCoreApplicationPrivate::testAttribute(attribute);
}


#ifndef QT_NO_QOBJECT

bool QCoreApplication::isQuitLockEnabled()
{
    return quitLockRefEnabled;
}

static bool doNotify(QObject *, QEvent *);

void QCoreApplication::setQuitLockEnabled(bool enabled)
{
    quitLockRefEnabled = enabled;
}


bool QCoreApplication::notifyInternal(QObject *receiver, QEvent *event)
{
    return notifyInternal2(receiver, event);
}

bool QCoreApplication::notifyInternal2(QObject *receiver, QEvent *event)
{
    bool selfRequired = QCoreApplicationPrivate::threadRequiresCoreApplication();
    if (!self && selfRequired)
        return false;

    // Make it possible for Qt Script to hook into events even
    // though QApplication is subclassed...
    bool result = false;
    void *cbdata[] = { receiver, event, &result };
    if (QInternal::activateCallbacks(QInternal::EventNotifyCallback, cbdata)) {
        return result;
    }

    // Qt enforces the rule that events can only be sent to objects in
    // the current thread, so receiver->d_func()->threadData is
    // equivalent to QThreadData::current(), just without the function
    // call overhead.
    QObjectPrivate *d = receiver->d_func();
    QThreadData *threadData = d->threadData;
    QScopedScopeLevelCounter scopeLevelCounter(threadData);
    if (!selfRequired)
        return doNotify(receiver, event);
    return self->notify(receiver, event);
}


//  QCoreApplication-> sendEvent 会到这里来. 来整个 Qt API 里面, 整个函数是经常会被使用的.
// 在很多时机, 其实 receiver 是在相关函数中可以获取的.
bool QCoreApplication::notify(QObject *receiver, QEvent *event)
{
    if (QCoreApplicationPrivate::is_app_closing)
        return true;
    return doNotify(receiver, event);
}

static bool doNotify(QObject *receiver, QEvent *event)
{
    return receiver->isWidgetType() ? false : QCoreApplicationPrivate::notify_helper(receiver, event);
}

// 首先, 先让 Application 的 eventFilter 进行一次事件的筛选工作.
bool QCoreApplicationPrivate::sendThroughApplicationEventFilters(QObject *receiver, QEvent *event)
{
    if (extraData) {
        // application event filters are only called for objects in the GUI thread
        for (int i = 0; i < extraData->eventFilters.size(); ++i) {
            QObject *obj = extraData->eventFilters.at(i);
            if (!obj)
                continue;
            if (obj->d_func()->threadData != threadData) {
                qWarning("QCoreApplication: Application event filter cannot be in a different thread.");
                continue;
            }
            if (obj->eventFilter(receiver, event))
                return true;
        }
    }
    return false;
}

// 每个 receiver, 都可能有自己的 eventFilter, 用自己的 eventFilter 再一次进行筛选.
bool QCoreApplicationPrivate::sendThroughObjectEventFilters(QObject *receiver, QEvent *event)
{
    if (receiver != QCoreApplication::instance() && receiver->d_func()->extraData) {
        for (int i = 0; i < receiver->d_func()->extraData->eventFilters.size(); ++i) {
            QObject *obj = receiver->d_func()->extraData->eventFilters.at(i);
            if (!obj)
                continue;
            if (obj->d_func()->threadData != receiver->d_func()->threadData) {
                qWarning("QCoreApplication: Object event filter cannot be in a different thread.");
                continue;
            }
            if (obj->eventFilter(receiver, event))
                return true;
        }
    }
    return false;
}

// 显示, 用 Applicaiton 的 eventFilter 进行过滤,
// 然后用 receiver 的 eventFilter 进行过滤
// 最后是调用到 receiver 的 event 方法.
bool QCoreApplicationPrivate::notify_helper(QObject *receiver, QEvent * event)
{
    if (QCoreApplication::self
            && receiver->d_func()->threadData->thread == mainThread()
            && QCoreApplication::self->d_func()->sendThroughApplicationEventFilters(receiver, event))
        return true;
    if (sendThroughObjectEventFilters(receiver, event))
        return true;
    return receiver->event(event);
}


bool QCoreApplication::startingUp()
{
    return !QCoreApplicationPrivate::is_app_running;
}

bool QCoreApplication::closingDown()
{
    return QCoreApplicationPrivate::is_app_closing;
}

// 这个函数, 是需要主动调用的, 是为了在某个长任务里面, 调用这个方法来保持应用还能继续处理其他的事件.
void QCoreApplication::processEvents(QEventLoop::ProcessEventsFlags flags)
{
    QThreadData *data = QThreadData::current();
    if (!data->hasEventDispatcher())
        return;
    data->eventDispatcher.load()->processEvents(flags);
}

void QCoreApplication::processEvents(QEventLoop::ProcessEventsFlags flags, int maxtime)
{
    QThreadData *data = QThreadData::current();
    if (!data->hasEventDispatcher())
        return;
    QElapsedTimer start;
    start.start();
    while (data->eventDispatcher.load()->processEvents(flags & ~QEventLoop::WaitForMoreEvents)) {
        if (start.elapsed() > maxtime)
            break;
    }
}

/*****************************************************************************
  Main event loop wrappers
 *****************************************************************************/

int QCoreApplication::exec()
{
    if (!QCoreApplicationPrivate::checkInstance("exec"))
        return -1;

    QThreadData *threadData = self->d_func()->threadData;
    if (threadData != QThreadData::current()) {
        qWarning("%s::exec: Must be called from the main thread", self->metaObject()->className());
        return -1;
    }
    if (!threadData->eventLoops.isEmpty()) {
        qWarning("QCoreApplication::exec: The event loop is already running");
        return -1;
    }

    threadData->quitNow = false;

    // 开启了一个事件循环.
    QEventLoop eventLoop;
    self->d_func()->in_exec = true;
    self->d_func()->aboutToQuitEmitted = false;
    // 这是一个死循环. 但是这个死循环每次进行检查.
    // exit, quit 这些函数就是去更改检查的值.
    // 自己设计一个系统的时候, 也可以这样做, 比如, 一个照片处理系统, 在合适的时候去检查一下某个值, 例如可以提前退出的功能.
    // 这样, 在设计的时候, 提供外界可以控制的 option.
    int returnCode = eventLoop.exec();
    threadData->quitNow = false;

    // 在主事件循环结束之后, 进行清理工作.
    if (self)
        self->d_func()->execCleanup();

    return returnCode;
}

void QCoreApplicationPrivate::execCleanup()
{
    threadData->quitNow = false;
    in_exec = false;
    if (!aboutToQuitEmitted)
        emit q_func()->aboutToQuit(QCoreApplication::QPrivateSignal());
    aboutToQuitEmitted = true;
    QCoreApplication::sendPostedEvents(0, QEvent::DeferredDelete);
}

void QCoreApplication::exit(int returnCode)
{
    if (!self) return;
    QThreadData *data = self->d_func()->threadData;
    data->quitNow = true;
    for (int i = 0; i < data->eventLoops.size(); ++i) {
        QEventLoop *eventLoop = data->eventLoops.at(i);
        eventLoop->exit(returnCode);
    }
}
// Adds the event event, with the object receiver as the receiver of the event, to an event queue and returns immediately.
// 所谓的 postEvent, 其实就是将这些 event, 添加到 receiver 所在的线程的 postEventList 里面.
// 这样, 当 receiver 的 thread 开始下一个运行循环的时候, 就可以处理这些 event 了.
void QCoreApplication::postEvent(QObject *receiver, QEvent *event, int priority)
{
    if (receiver == 0) {
        delete event;
        return;
    }

    // 获取目标对象的的线程环境.
    QThreadData * volatile * pdata = &receiver->d_func()->threadData;
    QThreadData *data = *pdata;
    if (!data) {
        delete event;
        return;
    }

    data->postEventList.mutex.lock();

    // if object has moved to another thread, follow it
    // 系统的类库, 考虑的比较充分. post 的过程中, 如果 recevier 发生了线程变化, 也考虑在内了.
    while (data != *pdata) {
        data->postEventList.mutex.unlock();

        data = *pdata;
        if (!data) {
            // posting during destruction? just delete the event to prevent a leak
            delete event;
            return;
        }
        data->postEventList.mutex.lock();
    }

    QMutexUnlocker locker(&data->postEventList.mutex);

    // if this is one of the compressible events, do compression
    if (receiver->d_func()->postedEvents &&
            self && // 对于 postEvent, 会有 compress 之说.
            self->compressEvent(event, receiver, &data->postEventList)) {
        return;
    }

    // 这里没太明白.
    if (event->type() == QEvent::DeferredDelete && data == QThreadData::current()) {
        int loopLevel = data->loopLevel;
        int scopeLevel = data->scopeLevel;
        if (scopeLevel == 0 && loopLevel != 0)
            scopeLevel = 1;
        static_cast<QDeferredDeleteEvent *>(event)->level = loopLevel + scopeLevel;
    }

    // delete the event on exceptions to protect against memory leaks till the event is
    // properly owned in the postEventList
    QScopedPointer<QEvent> eventDeleter(event);
    // 然后, 就是把这个事件, 放到线程的队列里面了.
    data->postEventList.addEvent(QPostEvent(receiver, event, priority));
    eventDeleter.take();
    event->posted = true;
    ++receiver->d_func()->postedEvents;
    data->canWait = false;
    locker.unlock();

    QAbstractEventDispatcher* dispatcher = data->eventDispatcher.loadAcquire();
    if (dispatcher) { dispatcher->wakeUp(); }

}


bool QCoreApplication::compressEvent(QEvent *event, QObject *receiver, QPostEventList *postedEvents)
{
        if ((event->type() == QEvent::DeferredDelete
             || event->type() == QEvent::Quit)
            && receiver->d_func()->postedEvents > 0) {
            for (int i = 0; i < postedEvents->size(); ++i) {
                const QPostEvent &cur = postedEvents->at(i);
                if (cur.receiver != receiver
                    || cur.event == 0
                    || cur.event->type() != event->type())
                    continue;
                // found an event for this receiver
                delete event;
                return true;
            }
        }
    return false;
}

void QCoreApplication::sendPostedEvents(QObject *receiver, int event_type)
{
    QThreadData *data = QThreadData::current();

    QCoreApplicationPrivate::sendPostedEvents(receiver, event_type, data);
}

// 这里, 才是最终的大部分的事件的处理函数.
// 对标着 Runloop, 就是处理 source0, source1, 各种提交的 block, 通知 runloop 的 observer 等逻辑.
// 最终, 还是到 QCoreApplication::sendEvent(r, e); 中去, sendEvent 最终, 是到达 QOBject::event 中去.
void QCoreApplicationPrivate::sendPostedEvents(QObject *receiver, int event_type,
                                               QThreadData *data)
{
    if (event_type == -1) {
        event_type = 0;
    }

    if (receiver && receiver->d_func()->threadData != data) {
        return;
    }

    ++data->postEventList.recursion;

    // 在处理数据的时候, 加锁.
    QMutexLocker locker(&data->postEventList.mutex);

    // by default, we assume that the event dispatcher can go to sleep after
    // processing all events. if any new events are posted while we send
    // events, canWait will be set to false.
    data->canWait = (data->postEventList.size() == 0);

    if (data->postEventList.size() == 0 || (receiver && !receiver->d_func()->postedEvents)) {
        --data->postEventList.recursion;
        return;
    }

    data->canWait = true;

    // okay. here is the tricky loop. be careful about optimizing
    // this, it looks the way it does for good reasons.
    int startOffset = data->postEventList.startOffset;
    int &i = (!event_type && !receiver) ? data->postEventList.startOffset : startOffset;
    data->postEventList.insertionOffset = data->postEventList.size();

    // Exception-safe cleaning up without the need for a try/catch block
    struct CleanUp {
        QObject *receiver;
        int event_type;
        QThreadData *data;
        bool exceptionCaught;

        inline CleanUp(QObject *receiver, int event_type, QThreadData *data) :
            receiver(receiver), event_type(event_type), data(data), exceptionCaught(true)
        {}
        inline ~CleanUp()
        {
            if (exceptionCaught) {
                // since we were interrupted, we need another pass to make sure we clean everything up
                data->canWait = false;
            }

            --data->postEventList.recursion;
            if (!data->postEventList.recursion && !data->canWait && data->hasEventDispatcher())
                data->eventDispatcher.load()->wakeUp();

            // clear the global list, i.e. remove everything that was
            // delivered.
            if (!event_type && !receiver && data->postEventList.startOffset >= 0) {
                const QPostEventList::iterator it = data->postEventList.begin();
                data->postEventList.erase(it, it + data->postEventList.startOffset);
                data->postEventList.insertionOffset -= data->postEventList.startOffset;
                Q_ASSERT(data->postEventList.insertionOffset >= 0);
                data->postEventList.startOffset = 0;
            }
        }
    };
    // 这种, 使用 RAII 对象进行数据管理, 主要是防止 exception 等情况.
    CleanUp cleanup(receiver, event_type, data);

    // 所以, 是线程不断的收集着 event 数据, 然后在这里进行处理. 而在事件循环里面, 会不断的到这里进行处理.
    // 可以看到, 这里处理的都是 QPostEvent, 而 QPostEvent 是存储了 receiver 的.
    while (i < data->postEventList.size()) {
        // avoid live-lock
        if (i >= data->postEventList.insertionOffset)
            break;

        const QPostEvent &pe = data->postEventList.at(i);
        ++i;

        if (!pe.event)
            continue;
        if ((receiver && receiver != pe.receiver) || (event_type && event_type != pe.event->type())) {
            data->canWait = false;
            continue;
        }

        // 如果是 deleteLater 时间.
        if (pe.event->type() == QEvent::DeferredDelete) {
            // DeferredDelete events are sent either
            // 1) when the event loop that posted the event has returned; or
            // 2) if explicitly requested (with QEvent::DeferredDelete) for
            //    events posted by the current event loop; or
            // 3) if the event was posted before the outermost event loop.

            int eventLevel = static_cast<QDeferredDeleteEvent *>(pe.event)->loopLevel();
            int loopLevel = data->loopLevel + data->scopeLevel;
            const bool allowDeferredDelete =
                (eventLevel > loopLevel
                 || (!eventLevel && loopLevel > 0)
                 || (event_type == QEvent::DeferredDelete
                     && eventLevel == loopLevel));
            if (!allowDeferredDelete) {
                // cannot send deferred delete
                if (!event_type && !receiver) {
                    // we must copy it first; we want to re-post the event
                    // with the event pointer intact, but we can't delay
                    // nulling the event ptr until after re-posting, as
                    // addEvent may invalidate pe.
                    QPostEvent pe_copy = pe;

                    // null out the event so if sendPostedEvents recurses, it
                    // will ignore this one, as it's been re-posted.
                    const_cast<QPostEvent &>(pe).event = 0;

                    // re-post the copied event so it isn't lost
                    data->postEventList.addEvent(pe_copy);
                }
                continue;
            }
        }

        // first, we diddle the event so that we can deliver
        // it, and that no one will try to touch it later.
        pe.event->posted = false;
        QEvent *e = pe.event;
        QObject *r = pe.receiver; // 因为, 这里处理的都是 postEvent, 而对于 postEvent 来说, 是会记录 receiver 的.

        --r->d_func()->postedEvents;

        // next, update the data structure so that we're ready
        // for the next event.
        const_cast<QPostEvent &>(pe).event = 0;

        struct MutexUnlocker
        {
            QMutexLocker &m;
            MutexUnlocker(QMutexLocker &m) : m(m) { m.unlock(); }
            ~MutexUnlocker() { m.relock(); }
        };
        MutexUnlocker unlocker(locker);

        QScopedPointer<QEvent> event_deleter(e); // will delete the event (with the mutex unlocked)

        // 前面大部分的工作, 还是内部数据的控制. 这里才是最直接的事件处理过程. 可以看到, 还是 sendEvent.
        // 直接, 把 event 发送到 receiver 里面.
        QCoreApplication::sendEvent(r, e);

        // careful when adding anything below this point - the
        // sendEvent() call might invalidate any invariants this
        // function depends on.
    }

    cleanup.exceptionCaught = false;
}

void QCoreApplication::removePostedEvents(QObject *receiver, int eventType)
{
    QThreadData *data = receiver ? receiver->d_func()->threadData : QThreadData::current();
    QMutexLocker locker(&data->postEventList.mutex);

    // the QObject destructor calls this function directly.  this can
    // happen while the event loop is in the middle of posting events,
    // and when we get here, we may not have any more posted events
    // for this object.
    if (receiver && !receiver->d_func()->postedEvents)
        return;

    //we will collect all the posted events for the QObject
    //and we'll delete after the mutex was unlocked
    QVarLengthArray<QEvent*> events;
    int n = data->postEventList.size();
    int j = 0;

    for (int i = 0; i < n; ++i) {
        const QPostEvent &pe = data->postEventList.at(i);

        if ((!receiver || pe.receiver == receiver)
            && (pe.event && (eventType == 0 || pe.event->type() == eventType))) {
            --pe.receiver->d_func()->postedEvents;
            pe.event->posted = false;
            events.append(pe.event);
            const_cast<QPostEvent &>(pe).event = 0;
        } else if (!data->postEventList.recursion) {
            if (i != j)
                qSwap(data->postEventList[i], data->postEventList[j]);
            ++j;
        }
    }

#ifdef QT_DEBUG
    if (receiver && eventType == 0) {
        Q_ASSERT(!receiver->d_func()->postedEvents);
    }
#endif

    if (!data->postEventList.recursion) {
        // truncate list
        data->postEventList.erase(data->postEventList.begin() + j, data->postEventList.end());
    }

    locker.unlock();
    for (int i = 0; i < events.count(); ++i) {
        delete events[i];
    }
}


void QCoreApplicationPrivate::removePostedEvent(QEvent * event)
{
    if (!event || !event->posted)
        return;

    QThreadData *data = QThreadData::current();

    QMutexLocker locker(&data->postEventList.mutex);

    if (data->postEventList.size() == 0) {
#if defined(QT_DEBUG)
        qDebug("QCoreApplication::removePostedEvent: Internal error: %p %d is posted",
                (void*)event, event->type());
        return;
#endif
    }

    for (int i = 0; i < data->postEventList.size(); ++i) {
        const QPostEvent & pe = data->postEventList.at(i);
        if (pe.event == event) {
#ifndef QT_NO_DEBUG
            qWarning("QCoreApplication::removePostedEvent: Event of type %d deleted while posted to %s %s",
                     event->type(),
                     pe.receiver->metaObject()->className(),
                     pe.receiver->objectName().toLocal8Bit().data());
#endif
            --pe.receiver->d_func()->postedEvents;
            pe.event->posted = false;
            delete pe.event;
            const_cast<QPostEvent &>(pe).event = 0;
            return;
        }
    }
}

/*
Applicaiton 的 event 方法里面, 并没有很多的对于事件的处理. 这里并不是事件处理的起点.
*/
bool QCoreApplication::event(QEvent *e)
{
    if (e->type() == QEvent::Quit) {
        quit();
        return true;
    }
    return QObject::event(e);
}

void QCoreApplicationPrivate::ref()
{
    quitLockRef.ref();
}

void QCoreApplicationPrivate::deref()
{
    if (!quitLockRef.deref())
        maybeQuit();
}

void QCoreApplicationPrivate::maybeQuit()
{
    if (quitLockRef.load() == 0 && in_exec && quitLockRefEnabled && shouldQuit())
        QCoreApplication::postEvent(QCoreApplication::instance(), new QEvent(QEvent::Quit));
}

void QCoreApplication::quit()
{
    exit(0);
}

#endif // QT_NO_QOBJECT

#ifndef QT_NO_TRANSLATION
bool QCoreApplication::installTranslator(QTranslator *translationFile)
{
    if (!translationFile)
        return false;

    if (!QCoreApplicationPrivate::checkInstance("installTranslator"))
        return false;
    QCoreApplicationPrivate *d = self->d_func();
    d->translators.prepend(translationFile);

#ifndef QT_NO_TRANSLATION_BUILDER
    if (translationFile->isEmpty())
        return false;
#endif

#ifndef QT_NO_QOBJECT
    QEvent ev(QEvent::LanguageChange);
    QCoreApplication::sendEvent(self, &ev);
#endif

    return true;
}


bool QCoreApplication::removeTranslator(QTranslator *translationFile)
{
    if (!translationFile)
        return false;
    if (!QCoreApplicationPrivate::checkInstance("removeTranslator"))
        return false;
    QCoreApplicationPrivate *d = self->d_func();
    if (d->translators.removeAll(translationFile)) {
#ifndef QT_NO_QOBJECT
        if (!self->closingDown()) {
            QEvent ev(QEvent::LanguageChange);
            QCoreApplication::sendEvent(self, &ev);
        }
#endif
        return true;
    }
    return false;
}

static void replacePercentN(QString *result, int n)
{
    if (n >= 0) {
        int percentPos = 0;
        int len = 0;
        while ((percentPos = result->indexOf(QLatin1Char('%'), percentPos + len)) != -1) {
            len = 1;
            QString fmt;
            if (result->at(percentPos + len) == QLatin1Char('L')) {
                ++len;
                fmt = QLatin1String("%L1");
            } else {
                fmt = QLatin1String("%1");
            }
            if (result->at(percentPos + len) == QLatin1Char('n')) {
                fmt = fmt.arg(n);
                ++len;
                result->replace(percentPos, len, fmt);
                len = fmt.length();
            }
        }
    }
}

QString QCoreApplication::translate(const char *context, const char *sourceText,
                                    const char *disambiguation, int n)
{
    QString result;

    if (!sourceText)
        return result;

    if (self && !self->d_func()->translators.isEmpty()) {
        QList<QTranslator*>::ConstIterator it;
        QTranslator *translationFile;
        for (it = self->d_func()->translators.constBegin(); it != self->d_func()->translators.constEnd(); ++it) {
            translationFile = *it;
            result = translationFile->translate(context, sourceText, disambiguation, n);
            if (!result.isNull())
                break;
        }
    }

    if (result.isNull())
        result = QString::fromUtf8(sourceText);

    replacePercentN(&result, n);
    return result;
}

/*! \fn static QString QCoreApplication::translate(const char *context, const char *key, const char *disambiguation, Encoding encoding, int n = -1)

  \obsolete
*/

// Declared in qglobal.h
QString qtTrId(const char *id, int n)
{
    return QCoreApplication::translate(0, id, 0, n);
}

bool QCoreApplicationPrivate::isTranslatorInstalled(QTranslator *translator)
{
    return QCoreApplication::self
           && QCoreApplication::self->d_func()->translators.contains(translator);
}

#else

QString QCoreApplication::translate(const char *context, const char *sourceText,
                                    const char *disambiguation, int n)
{
    Q_UNUSED(context)
    Q_UNUSED(disambiguation)
    QString ret = QString::fromUtf8(sourceText);
    if (n >= 0)
        ret.replace(QLatin1String("%n"), QString::number(n));
    return ret;
}

#endif //QT_NO_TRANSLATION

// Makes it possible to point QCoreApplication to a custom location to ensure
// the directory is added to the patch, and qt.conf and deployed plugins are
// found from there. This is for use cases in which QGuiApplication is
// instantiated by a library and not by an application executable, for example,
// Active X servers.

void QCoreApplicationPrivate::setApplicationFilePath(const QString &path)
{
    if (QCoreApplicationPrivate::cachedApplicationFilePath)
        *QCoreApplicationPrivate::cachedApplicationFilePath = path;
    else
        QCoreApplicationPrivate::cachedApplicationFilePath = new QString(path);
}

/*!
    Returns the directory that contains the application executable.

    For example, if you have installed Qt in the \c{C:\Qt}
    directory, and you run the \c{regexp} example, this function will
    return "C:/Qt/examples/tools/regexp".

    On \macos and iOS this will point to the directory actually containing
    the executable, which may be inside an application bundle (if the
    application is bundled).

    \warning On Linux, this function will try to get the path from the
    \c {/proc} file system. If that fails, it assumes that \c
    {argv[0]} contains the absolute file name of the executable. The
    function also assumes that the current directory has not been
    changed by the application.

    \sa applicationFilePath()
*/
QString QCoreApplication::applicationDirPath()
{
    if (!self) {
        qWarning("QCoreApplication::applicationDirPath: Please instantiate the QApplication object first");
        return QString();
    }

    QCoreApplicationPrivate *d = self->d_func();
    if (d->cachedApplicationDirPath.isNull())
        d->cachedApplicationDirPath = QFileInfo(applicationFilePath()).path();
    return d->cachedApplicationDirPath;
}

/*!
    Returns the file path of the application executable.

    For example, if you have installed Qt in the \c{/usr/local/qt}
    directory, and you run the \c{regexp} example, this function will
    return "/usr/local/qt/examples/tools/regexp/regexp".

    \warning On Linux, this function will try to get the path from the
    \c {/proc} file system. If that fails, it assumes that \c
    {argv[0]} contains the absolute file name of the executable. The
    function also assumes that the current directory has not been
    changed by the application.

    \sa applicationDirPath()
*/
QString QCoreApplication::applicationFilePath()
{
    if (!self) {
        qWarning("QCoreApplication::applicationFilePath: Please instantiate the QApplication object first");
        return QString();
    }

    QCoreApplicationPrivate *d = self->d_func();

    if (d->argc) {
        static QByteArray procName = QByteArray(d->argv[0]);
        if (procName != d->argv[0]) {
            // clear the cache if the procname changes, so we reprocess it.
            QCoreApplicationPrivate::clearApplicationFilePath();
            procName = QByteArray(d->argv[0]);
        }
    }

    if (QCoreApplicationPrivate::cachedApplicationFilePath)
        return *QCoreApplicationPrivate::cachedApplicationFilePath;

#if defined(Q_OS_WIN)
    QCoreApplicationPrivate::setApplicationFilePath(QFileInfo(qAppFileName()).filePath());
    return *QCoreApplicationPrivate::cachedApplicationFilePath;
#elif defined(Q_OS_MAC)
    QString qAppFileName_str = qAppFileName();
    if(!qAppFileName_str.isEmpty()) {
        QFileInfo fi(qAppFileName_str);
        if (fi.exists()) {
            QCoreApplicationPrivate::setApplicationFilePath(fi.canonicalFilePath());
            return *QCoreApplicationPrivate::cachedApplicationFilePath;
        }
    }
#endif
#if defined( Q_OS_UNIX )
#  if defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
    // Try looking for a /proc/<pid>/exe symlink first which points to
    // the absolute path of the executable
    QFileInfo pfi(QString::fromLatin1("/proc/%1/exe").arg(getpid()));
    if (pfi.exists() && pfi.isSymLink()) {
        QCoreApplicationPrivate::setApplicationFilePath(pfi.canonicalFilePath());
        return *QCoreApplicationPrivate::cachedApplicationFilePath;
    }
#  endif
    if (!arguments().isEmpty()) {
        QString argv0 = QFile::decodeName(arguments().at(0).toLocal8Bit());
        QString absPath;

        if (!argv0.isEmpty() && argv0.at(0) == QLatin1Char('/')) {
            /*
              If argv0 starts with a slash, it is already an absolute
              file path.
            */
            absPath = argv0;
        } else if (argv0.contains(QLatin1Char('/'))) {
            /*
              If argv0 contains one or more slashes, it is a file path
              relative to the current directory.
            */
            absPath = QDir::current().absoluteFilePath(argv0);
        } else {
            /*
              Otherwise, the file path has to be determined using the
              PATH environment variable.
            */
            absPath = QStandardPaths::findExecutable(argv0);
        }

        absPath = QDir::cleanPath(absPath);

        QFileInfo fi(absPath);
        if (fi.exists()) {
            QCoreApplicationPrivate::setApplicationFilePath(fi.canonicalFilePath());
            return *QCoreApplicationPrivate::cachedApplicationFilePath;
        }
    }

#endif
    return QString();
}

/*!
    \since 4.4

    Returns the current process ID for the application.
*/
qint64 QCoreApplication::applicationPid()
{
#if defined(Q_OS_WIN)
    return GetCurrentProcessId();
#elif defined(Q_OS_VXWORKS)
    return (pid_t) taskIdCurrent;
#else
    return getpid();
#endif
}

/*!
    \since 4.1

    Returns the list of command-line arguments.

    Usually arguments().at(0) is the program name, arguments().at(1)
    is the first argument, and arguments().last() is the last
    argument. See the note below about Windows.

    Calling this function is slow - you should store the result in a variable
    when parsing the command line.

    \warning On Unix, this list is built from the argc and argv parameters passed
    to the constructor in the main() function. The string-data in argv is
    interpreted using QString::fromLocal8Bit(); hence it is not possible to
    pass, for example, Japanese command line arguments on a system that runs in a
    Latin1 locale. Most modern Unix systems do not have this limitation, as they are
    Unicode-based.

    On Windows, the list is built from the argc and argv parameters only if
    modified argv/argc parameters are passed to the constructor. In that case,
    encoding problems might occur.

    Otherwise, the arguments() are constructed from the return value of
    \l{http://msdn2.microsoft.com/en-us/library/ms683156(VS.85).aspx}{GetCommandLine()}.
    As a result of this, the string given by arguments().at(0) might not be
    the program name on Windows, depending on how the application was started.

    \sa applicationFilePath(), QCommandLineParser
*/

QStringList QCoreApplication::arguments()
{
    QStringList list;

    if (!self) {
        qWarning("QCoreApplication::arguments: Please instantiate the QApplication object first");
        return list;
    }
    const int ac = self->d_func()->argc;
    char ** const av = self->d_func()->argv;
    list.reserve(ac);

#if defined(Q_OS_WIN) && !defined(Q_OS_WINRT)
    // On Windows, it is possible to pass Unicode arguments on
    // the command line. To restore those, we split the command line
    // and filter out arguments that were deleted by derived application
    // classes by index.
    QString cmdline = QString::fromWCharArray(GetCommandLine());

    const QCoreApplicationPrivate *d = self->d_func();
    if (d->origArgv) {
        const QStringList allArguments = qWinCmdArgs(cmdline);
        Q_ASSERT(allArguments.size() == d->origArgc);
        for (int i = 0; i < d->origArgc; ++i) {
            if (contains(ac, av, d->origArgv[i]))
                list.append(allArguments.at(i));
        }
        return list;
    } // Fall back to rebuilding from argv/argc when a modified argv was passed.
#endif // defined(Q_OS_WIN) && !defined(Q_OS_WINRT)

    for (int a = 0; a < ac; ++a) {
        list << QString::fromLocal8Bit(av[a]);
    }

    return list;
}

void QCoreApplication::setOrganizationName(const QString &orgName)
{
    if (coreappdata()->orgName == orgName)
        return;
    coreappdata()->orgName = orgName;
#ifndef QT_NO_QOBJECT
    if (QCoreApplication::self)
        emit QCoreApplication::self->organizationNameChanged();
#endif
}

QString QCoreApplication::organizationName()
{
    return coreappdata()->orgName;
}

void QCoreApplication::setOrganizationDomain(const QString &orgDomain)
{
    if (coreappdata()->orgDomain == orgDomain)
        return;
    coreappdata()->orgDomain = orgDomain;
#ifndef QT_NO_QOBJECT
    if (QCoreApplication::self)
        emit QCoreApplication::self->organizationDomainChanged();
#endif
}

QString QCoreApplication::organizationDomain()
{
    return coreappdata()->orgDomain;
}

void QCoreApplication::setApplicationName(const QString &application)
{
    coreappdata()->applicationNameSet = !application.isEmpty();
    QString newAppName = application;
    if (newAppName.isEmpty() && QCoreApplication::self)
        newAppName = QCoreApplication::self->d_func()->appName();
    if (coreappdata()->application == newAppName)
        return;
    coreappdata()->application = newAppName;
}

QString QCoreApplication::applicationName()
{
    return coreappdata() ? coreappdata()->application : QString();
}

void QCoreApplication::setApplicationVersion(const QString &version)
{
    coreappdata()->applicationVersionSet = !version.isEmpty();
    QString newVersion = version;
    if (newVersion.isEmpty() && QCoreApplication::self)
        newVersion = QCoreApplication::self->d_func()->appVersion();
    if (coreappdata()->applicationVersion == newVersion)
        return;
    coreappdata()->applicationVersion = newVersion;
#ifndef QT_NO_QOBJECT
    if (QCoreApplication::self)
        emit QCoreApplication::self->applicationVersionChanged();
#endif
}

QString QCoreApplication::applicationVersion()
{
    return coreappdata() ? coreappdata()->applicationVersion : QString();
}

#if QT_CONFIG(library)

Q_GLOBAL_STATIC_WITH_ARGS(QMutex, libraryPathMutex, (QMutex::Recursive))

/*!
    Returns a list of paths that the application will search when
    dynamically loading libraries.

    The return value of this function may change when a QCoreApplication
    is created. It is not recommended to call it before creating a
    QCoreApplication. The directory of the application executable (\b not
    the working directory) is part of the list if it is known. In order
    to make it known a QCoreApplication has to be constructed as it will
    use \c {argv[0]} to find it.

    Qt provides default library paths, but they can also be set using
    a \l{Using qt.conf}{qt.conf} file. Paths specified in this file
    will override default values. Note that if the qt.conf file is in
    the directory of the application executable, it may not be found
    until a QCoreApplication is created. If it is not found when calling
    this function, the default library paths will be used.

    The list will include the installation directory for plugins if
    it exists (the default installation directory for plugins is \c
    INSTALL/plugins, where \c INSTALL is the directory where Qt was
    installed). The colon separated entries of the \c QT_PLUGIN_PATH
    environment variable are always added. The plugin installation
    directory (and its existence) may change when the directory of
    the application executable becomes known.

    If you want to iterate over the list, you can use the \l foreach
    pseudo-keyword:

    \snippet code/src_corelib_kernel_qcoreapplication.cpp 2

    \sa setLibraryPaths(), addLibraryPath(), removeLibraryPath(), QLibrary,
        {How to Create Qt Plugins}
*/
QStringList QCoreApplication::libraryPaths()
{
    QMutexLocker locker(libraryPathMutex());

    if (coreappdata()->manual_libpaths)
        return *(coreappdata()->manual_libpaths);

    if (!coreappdata()->app_libpaths) {
        QStringList *app_libpaths = new QStringList;
        coreappdata()->app_libpaths.reset(app_libpaths);

        const QByteArray libPathEnv = qgetenv("QT_PLUGIN_PATH");
        if (!libPathEnv.isEmpty()) {
            QStringList paths = QFile::decodeName(libPathEnv).split(QDir::listSeparator(), QString::SkipEmptyParts);
            for (QStringList::const_iterator it = paths.constBegin(); it != paths.constEnd(); ++it) {
                QString canonicalPath = QDir(*it).canonicalPath();
                if (!canonicalPath.isEmpty()
                    && !app_libpaths->contains(canonicalPath)) {
                    app_libpaths->append(canonicalPath);
                }
            }
        }

#ifdef Q_OS_DARWIN
        // Check the main bundle's PlugIns directory as this is a standard location for Apple OSes.
        // Note that the QLibraryInfo::PluginsPath below will coincidentally be the same as this value
        // but with a different casing, so it can't be relied upon when the underlying filesystem
        // is case sensitive (and this is always the case on newer OSes like iOS).
        if (CFBundleRef bundleRef = CFBundleGetMainBundle()) {
            if (QCFType<CFURLRef> urlRef = CFBundleCopyBuiltInPlugInsURL(bundleRef)) {
                if (QCFType<CFURLRef> absoluteUrlRef = CFURLCopyAbsoluteURL(urlRef)) {
                    if (QCFString path = CFURLCopyFileSystemPath(absoluteUrlRef, kCFURLPOSIXPathStyle)) {
                        if (QFile::exists(path)) {
                            path = QDir(path).canonicalPath();
                            if (!app_libpaths->contains(path))
                                app_libpaths->append(path);
                        }
                    }
                }
            }
        }
#endif // Q_OS_DARWIN

        QString installPathPlugins =  QLibraryInfo::location(QLibraryInfo::PluginsPath);
        if (QFile::exists(installPathPlugins)) {
            // Make sure we convert from backslashes to slashes.
            installPathPlugins = QDir(installPathPlugins).canonicalPath();
            if (!app_libpaths->contains(installPathPlugins))
                app_libpaths->append(installPathPlugins);
        }

        // If QCoreApplication is not yet instantiated,
        // make sure we add the application path when we construct the QCoreApplication
        if (self) self->d_func()->appendApplicationPathToLibraryPaths();
    }
    return *(coreappdata()->app_libpaths);
}



/*!

    Sets the list of directories to search when loading libraries to
    \a paths. All existing paths will be deleted and the path list
    will consist of the paths given in \a paths.

    The library paths are reset to the default when an instance of
    QCoreApplication is destructed.

    \sa libraryPaths(), addLibraryPath(), removeLibraryPath(), QLibrary
 */
void QCoreApplication::setLibraryPaths(const QStringList &paths)
{
    QMutexLocker locker(libraryPathMutex());

    // setLibraryPaths() is considered a "remove everything and then add some new ones" operation.
    // When the application is constructed it should still amend the paths. So we keep the originals
    // around, and even create them if they don't exist, yet.
    if (!coreappdata()->app_libpaths)
        libraryPaths();

    if (coreappdata()->manual_libpaths)
        *(coreappdata()->manual_libpaths) = paths;
    else
        coreappdata()->manual_libpaths.reset(new QStringList(paths));

    locker.unlock();
    QFactoryLoader::refreshAll();
}

/*!
  Prepends \a path to the beginning of the library path list, ensuring that
  it is searched for libraries first. If \a path is empty or already in the
  path list, the path list is not changed.

  The default path list consists of a single entry, the installation
  directory for plugins.  The default installation directory for plugins
  is \c INSTALL/plugins, where \c INSTALL is the directory where Qt was
  installed.

  The library paths are reset to the default when an instance of
  QCoreApplication is destructed.

  \sa removeLibraryPath(), libraryPaths(), setLibraryPaths()
 */
void QCoreApplication::addLibraryPath(const QString &path)
{
    if (path.isEmpty())
        return;

    QString canonicalPath = QDir(path).canonicalPath();
    if (canonicalPath.isEmpty())
        return;

    QMutexLocker locker(libraryPathMutex());

    QStringList *libpaths = coreappdata()->manual_libpaths.data();
    if (libpaths) {
        if (libpaths->contains(canonicalPath))
            return;
    } else {
        // make sure that library paths are initialized
        libraryPaths();
        QStringList *app_libpaths = coreappdata()->app_libpaths.data();
        if (app_libpaths->contains(canonicalPath))
            return;

        coreappdata()->manual_libpaths.reset(libpaths = new QStringList(*app_libpaths));
    }

    libpaths->prepend(canonicalPath);
    locker.unlock();
    QFactoryLoader::refreshAll();
}

/*!
    Removes \a path from the library path list. If \a path is empty or not
    in the path list, the list is not changed.

    The library paths are reset to the default when an instance of
    QCoreApplication is destructed.

    \sa addLibraryPath(), libraryPaths(), setLibraryPaths()
*/
void QCoreApplication::removeLibraryPath(const QString &path)
{
    if (path.isEmpty())
        return;

    QString canonicalPath = QDir(path).canonicalPath();
    if (canonicalPath.isEmpty())
        return;

    QMutexLocker locker(libraryPathMutex());

    QStringList *libpaths = coreappdata()->manual_libpaths.data();
    if (libpaths) {
        if (libpaths->removeAll(canonicalPath) == 0)
            return;
    } else {
        // make sure that library paths is initialized
        libraryPaths();
        QStringList *app_libpaths = coreappdata()->app_libpaths.data();
        if (!app_libpaths->contains(canonicalPath))
            return;

        coreappdata()->manual_libpaths.reset(libpaths = new QStringList(*app_libpaths));
        libpaths->removeAll(canonicalPath);
    }

    locker.unlock();
    QFactoryLoader::refreshAll();
}

#endif // QT_CONFIG(library)

#ifndef QT_NO_QOBJECT
void QCoreApplication::installNativeEventFilter(QAbstractNativeEventFilter *filterObj)
{
    if (QCoreApplication::testAttribute(Qt::AA_PluginApplication)) {
        qWarning("Native event filters are not applied when the Qt::AA_PluginApplication attribute is set");
        return;
    }

    QAbstractEventDispatcher *eventDispatcher = QAbstractEventDispatcher::instance(QCoreApplicationPrivate::theMainThread);
    if (!filterObj || !eventDispatcher)
        return;
    eventDispatcher->installNativeEventFilter(filterObj);
}

void QCoreApplication::removeNativeEventFilter(QAbstractNativeEventFilter *filterObject)
{
    QAbstractEventDispatcher *eventDispatcher = QAbstractEventDispatcher::instance();
    if (!filterObject || !eventDispatcher)
        return;
    eventDispatcher->removeNativeEventFilter(filterObject);
}


/*!
    Returns a pointer to the event dispatcher object for the main thread. If no
    event dispatcher exists for the thread, this function returns 0.
*/
QAbstractEventDispatcher *QCoreApplication::eventDispatcher()
{
    if (QCoreApplicationPrivate::theMainThread)
        return QCoreApplicationPrivate::theMainThread.load()->eventDispatcher();
    return 0;
}

/*!
    Sets the event dispatcher for the main thread to \a eventDispatcher. This
    is only possible as long as there is no event dispatcher installed yet. That
    is, before QCoreApplication has been instantiated. This method takes
    ownership of the object.
*/
void QCoreApplication::setEventDispatcher(QAbstractEventDispatcher *eventDispatcher)
{
    QThread *mainThread = QCoreApplicationPrivate::theMainThread;
    if (!mainThread)
        mainThread = QThread::currentThread(); // will also setup theMainThread
    mainThread->setEventDispatcher(eventDispatcher);
}

#endif // QT_NO_QOBJECT

/*!
    \macro Q_COREAPP_STARTUP_FUNCTION(QtStartUpFunction ptr)
    \since 5.1
    \relates QCoreApplication
    \reentrant

    Adds a global function that will be called from the QCoreApplication
    constructor. This macro is normally used to initialize libraries
    for program-wide functionality, without requiring the application to
    call into the library for initialization.

    The function specified by \a ptr should take no arguments and should
    return nothing. For example:

    \snippet code/src_corelib_kernel_qcoreapplication.cpp 3

    Note that the startup function will run at the end of the QCoreApplication constructor,
    before any GUI initialization. If GUI code is required in the function,
    use a timer (or a queued invocation) to perform the initialization later on,
    from the event loop.

    If QCoreApplication is deleted and another QCoreApplication is created,
    the startup function will be invoked again.
*/

/*!
    \fn void qAddPostRoutine(QtCleanUpFunction ptr)
    \relates QCoreApplication

    Adds a global routine that will be called from the QCoreApplication
    destructor. This function is normally used to add cleanup routines
    for program-wide functionality.

    The cleanup routines are called in the reverse order of their addition.

    The function specified by \a ptr should take no arguments and should
    return nothing. For example:

    \snippet code/src_corelib_kernel_qcoreapplication.cpp 4

    Note that for an application- or module-wide cleanup, qaddPostRoutine()
    is often not suitable. For example, if the program is split into dynamically
    loaded modules, the relevant module may be unloaded long before the
    QCoreApplication destructor is called. In such cases, if using qaddPostRoutine()
    is still desirable, qRemovePostRoutine() can be used to prevent a routine
    from being called by the QCoreApplication destructor. For example, if that
    routine was called before the module was unloaded.

    For modules and libraries, using a reference-counted
    initialization manager or Qt's parent-child deletion mechanism may
    be better. Here is an example of a private class that uses the
    parent-child mechanism to call a cleanup function at the right
    time:

    \snippet code/src_corelib_kernel_qcoreapplication.cpp 5

    By selecting the right parent object, this can often be made to
    clean up the module's data at the right moment.

    \sa qRemovePostRoutine()
*/

/*!
    \fn void qRemovePostRoutine(QtCleanUpFunction ptr)
    \relates QCoreApplication
    \since 5.3

    Removes the cleanup routine specified by \a ptr from the list of
    routines called by the QCoreApplication destructor. The routine
    must have been previously added to the list by a call to
    qAddPostRoutine(), otherwise this function has no effect.

    \sa qAddPostRoutine()
*/

/*!
    \macro Q_DECLARE_TR_FUNCTIONS(context)
    \relates QCoreApplication

    The Q_DECLARE_TR_FUNCTIONS() macro declares and implements two
    translation functions, \c tr() and \c trUtf8(), with these
    signatures:

    \snippet code/src_corelib_kernel_qcoreapplication.cpp 6

    This macro is useful if you want to use QObject::tr() or
    QObject::trUtf8() in classes that don't inherit from QObject.

    Q_DECLARE_TR_FUNCTIONS() must appear at the very top of the
    class definition (before the first \c{public:} or \c{protected:}).
    For example:

    \snippet code/src_corelib_kernel_qcoreapplication.cpp 7

    The \a context parameter is normally the class name, but it can
    be any text.

    \sa Q_OBJECT, QObject::tr(), QObject::trUtf8()
*/

QT_END_NAMESPACE

#ifndef QT_NO_QOBJECT
#include "moc_qcoreapplication.cpp"
#endif
