#include "qobject.h"
#include "qobject_p.h"
#include "qmetaobject_p.h"

#include "qabstracteventdispatcher.h"
#include "qabstracteventdispatcher_p.h"
#include "qcoreapplication.h"
#include "qcoreapplication_p.h"
#include "qvariant.h"
#include "qmetaobject.h"
#include <qregexp.h>
#include <qregularexpression.h>
#include <qthread.h>
#include <qdebug.h>
#include <qpair.h>
#include <qvarlengtharray.h>
#include <qset.h>
#include <qsemaphore.h>
#include <qsharedpointer.h>

#include <private/qorderedmutexlocker_p.h>
#include <private/qhooks_p.h>

#include <new>

#include <ctype.h>
#include <limits.h>

QT_BEGIN_NAMESPACE

static int DIRECT_CONNECTION_ONLY = 0;


QDynamicMetaObjectData::~QDynamicMetaObjectData()
{
}

QAbstractDynamicMetaObject::~QAbstractDynamicMetaObject()
{
}


struct QSlotObjectBaseDeleter { // for use with QScopedPointer<QSlotObjectBase,...>
    static void cleanup(QtPrivate::QSlotObjectBase *slot) {
        if (slot) slot->destroyIfLastRef();
    }
};
static int *queuedConnectionTypes(const QList<QByteArray> &typeNames)
{
    int *types = new int [typeNames.count() + 1];
    Q_CHECK_PTR(types);
    for (int i = 0; i < typeNames.count(); ++i) {
        const QByteArray typeName = typeNames.at(i);
        if (typeName.endsWith('*'))
            types[i] = QMetaType::VoidStar;
        else
            types[i] = QMetaType::type(typeName);

        if (!types[i]) {
            qWarning("QObject::connect: Cannot queue arguments of type '%s'\n"
                     "(Make sure '%s' is registered using qRegisterMetaType().)",
                     typeName.constData(), typeName.constData());
            delete [] types;
            return 0;
        }
    }
    types[typeNames.count()] = 0;

    return types;
}

static int *queuedConnectionTypes(const QArgumentType *argumentTypes, int argc)
{
    QScopedArrayPointer<int> types(new int [argc + 1]);
    for (int i = 0; i < argc; ++i) {
        const QArgumentType &type = argumentTypes[i];
        if (type.type())
            types[i] = type.type();
        else if (type.name().endsWith('*'))
            types[i] = QMetaType::VoidStar;
        else
            types[i] = QMetaType::type(type.name());

        if (!types[i]) {
            qWarning("QObject::connect: Cannot queue arguments of type '%s'\n"
                     "(Make sure '%s' is registered using qRegisterMetaType().)",
                     type.name().constData(), type.name().constData());
            return 0;
        }
    }
    types[argc] = 0;

    return types.take();
}

static QBasicMutex _q_ObjectMutexPool[131];

/**
 * \internal
 * mutex to be locked when accessing the connectionlists or the senders list
 */
static inline QMutex *signalSlotLock(const QObject *o)
{
    return static_cast<QMutex *>(&_q_ObjectMutexPool[
        uint(quintptr(o)) % sizeof(_q_ObjectMutexPool)/sizeof(QBasicMutex)]);
}

struct QConnectionSenderSwitcher {
    QObject *receiver;
    QObjectPrivate::Sender *previousSender;
    QObjectPrivate::Sender currentSender;
    bool switched;

    inline QConnectionSenderSwitcher() : switched(false) {}

    inline QConnectionSenderSwitcher(QObject *receiver, QObject *sender, int signal_absolute_id)
    {
        switchSender(receiver, sender, signal_absolute_id);
    }

    inline void switchSender(QObject *receiver, QObject *sender, int signal_absolute_id)
    {
        this->receiver = receiver;
        currentSender.sender = sender;
        currentSender.signal = signal_absolute_id;
        currentSender.ref = 1;
        previousSender = QObjectPrivate::setCurrentSender(receiver, &currentSender);
        switched = true;
    }

    inline ~QConnectionSenderSwitcher()
    {
        if (switched)
            QObjectPrivate::resetCurrentSender(receiver, &currentSender, previousSender);
    }
private:
    Q_DISABLE_COPY(QConnectionSenderSwitcher)
};


void (*QAbstractDeclarativeData::destroyed)(QAbstractDeclarativeData *, QObject *) = 0;
void (*QAbstractDeclarativeData::destroyed_qml1)(QAbstractDeclarativeData *, QObject *) = 0;
void (*QAbstractDeclarativeData::parentChanged)(QAbstractDeclarativeData *, QObject *, QObject *) = 0;
void (*QAbstractDeclarativeData::signalEmitted)(QAbstractDeclarativeData *, QObject *, int, void **) = 0;
int  (*QAbstractDeclarativeData::receivers)(QAbstractDeclarativeData *, const QObject *, int) = 0;
bool (*QAbstractDeclarativeData::isSignalConnected)(QAbstractDeclarativeData *, const QObject *, int) = 0;
void (*QAbstractDeclarativeData::setWidgetParent)(QObject *, QObject *) = 0;

QObjectData::~QObjectData() {}

QMetaObject *QObjectData::dynamicMetaObject() const
{
    return metaObject->toDynamicMetaObject(q_ptr);
}

QObjectPrivate::QObjectPrivate(int version)
    : threadData(0), connectionLists(0), senders(0), currentSender(0), currentChildBeingDeleted(0)
{
    // QObjectData initialization
    q_ptr = 0;
    parent = 0;                                 // no parent yet. It is set by setParent()
    isWidget = false;                           // assume not a widget object
    blockSig = false;                           // not blocking signals
    wasDeleted = false;                         // double-delete catcher
    isDeletingChildren = false;                 // set by deleteChildren()
    sendChildEvents = true;                     // if we should send ChildAdded and ChildRemoved events to parent
    receiveChildEvents = true;
    postedEvents = 0;
    extraData = 0;
    connectedSignals[0] = connectedSignals[1] = 0;
    metaObject = 0;
    isWindow = false;
}

QObjectPrivate::~QObjectPrivate()
{
    if (extraData && !extraData->runningTimers.isEmpty()) {
        if (Q_LIKELY(threadData->thread == QThread::currentThread())) {
            // 对象消亡之前, 会对所有的定时器进行销毁
            // 这也就是, 为什么对象会保存所有注册定时器的句柄.
            // 感觉有些复杂, 根类做的事情太多了.
            if (threadData->eventDispatcher.load())
                threadData->eventDispatcher.load()->unregisterTimers(q_ptr);

            // release the timer ids back to the pool
            for (int i = 0; i < extraData->runningTimers.size(); ++i)
                QAbstractEventDispatcherPrivate::releaseTimerId(extraData->runningTimers.at(i));
        } else {
            qWarning("QObject::~QObject: Timers cannot be stopped from another thread");
        }
    }
    if (postedEvents)
        QCoreApplication::removePostedEvents(q_ptr, 0);

    threadData->deref();

    if (metaObject) metaObject->objectDestroyed(q_ptr);

#ifndef QT_NO_USERDATA
    if (extraData)
        qDeleteAll(extraData->userData); // 在这里, 对所有的 UserData 进行了删除. 所以, 对于一个 QObject 来说, 用 UserData 来传值, 就指的是声明周期由 QObject 来管理.
#endif
    delete extraData;
}

/*!
  \internal
  For a given metaobject, compute the signal offset, and the method offset (including signals)
*/
static void computeOffsets(const QMetaObject *metaobject, int *signalOffset, int *methodOffset)
{
    *signalOffset = *methodOffset = 0;
    const QMetaObject *m = metaobject->d.superdata;
    while (m) {
        const QMetaObjectPrivate *d = QMetaObjectPrivate::get(m);
        *methodOffset += d->methodCount;
        Q_ASSERT(d->revision >= 4);
        *signalOffset += d->signalCount;
        m = m->d.superdata;
    }
}

/*
    This vector contains the all connections from an object.

    Each object may have one vector containing the lists of
    connections for a given signal. The index in the vector correspond
    to the signal index. The signal index is the one returned by
    QObjectPrivate::signalIndex (not QMetaObject::indexOfSignal).
    Negative index means connections to all signals.

    This vector is protected by the object mutex (signalSlotMutexes())

    Each Connection is also part of a 'senders' linked list. The mutex
    of the receiver must be locked when touching the pointers of this
    linked list.
*/
class QObjectConnectionListVector : public QVector<QObjectPrivate::ConnectionList>
{
public:
    bool orphaned; //the QObject owner of this vector has been destroyed while the vector was inUse
    bool dirty; //some Connection have been disconnected (their receiver is 0) but not removed from the list yet
    int inUse; //number of functions that are currently accessing this object or its connections
    QObjectPrivate::ConnectionList allsignals;

    QObjectConnectionListVector()
        : QVector<QObjectPrivate::ConnectionList>(), orphaned(false), dirty(false), inUse(0)
    { }

    QObjectPrivate::ConnectionList &operator[](int at)
    {
        if (at < 0)
            return allsignals;
        return QVector<QObjectPrivate::ConnectionList>::operator[](at);
    }
};

// Used by QAccessibleWidget
bool QObjectPrivate::isSender(const QObject *receiver, const char *signal) const
{
    Q_Q(const QObject);
    int signal_index = signalIndex(signal);
    if (signal_index < 0)
        return false;
    QMutexLocker locker(signalSlotLock(q));
    if (connectionLists) {
        if (signal_index < connectionLists->count()) {
            const QObjectPrivate::Connection *c =
                connectionLists->at(signal_index).first;

            while (c) {
                if (c->receiver == receiver)
                    return true;
                c = c->nextConnectionList;
            }
        }
    }
    return false;
}

// Used by QAccessibleWidget
QObjectList QObjectPrivate::receiverList(const char *signal) const
{
    Q_Q(const QObject);
    QObjectList returnValue;
    int signal_index = signalIndex(signal);
    if (signal_index < 0)
        return returnValue;
    QMutexLocker locker(signalSlotLock(q));
    if (connectionLists) {
        if (signal_index < connectionLists->count()) {
            const QObjectPrivate::Connection *c = connectionLists->at(signal_index).first;

            while (c) {
                if (c->receiver)
                    returnValue << c->receiver;
                c = c->nextConnectionList;
            }
        }
    }
    return returnValue;
}

// Used by QAccessibleWidget
QObjectList QObjectPrivate::senderList() const
{
    QObjectList returnValue;
    QMutexLocker locker(signalSlotLock(q_func()));
    for (Connection *c = senders; c; c = c->next)
        returnValue << c->sender;
    return returnValue;
}

// connect 的时候, 增加 connect 的实现.
void QObjectPrivate::addConnection(int signal, Connection *c)
{
    Q_ASSERT(c->sender == q_ptr);
    if (!connectionLists)
        connectionLists = new QObjectConnectionListVector();
    if (signal >= connectionLists->count())
        connectionLists->resize(signal + 1);

    ConnectionList &connectionList = (*connectionLists)[signal];
    if (connectionList.last) {
        connectionList.last->nextConnectionList = c;
    } else {
        connectionList.first = c;
    }
    connectionList.last = c;

    cleanConnectionLists();

    c->prev = &(QObjectPrivate::get(c->receiver)->senders);
    c->next = *c->prev;
    *c->prev = c;
    if (c->next)
        c->next->prev = &c->next;

    if (signal < 0) {
        connectedSignals[0] = connectedSignals[1] = ~0;
    } else if (signal < (int)sizeof(connectedSignals) * 8) {
        connectedSignals[signal >> 5] |= (1 << (signal & 0x1f));
    }
}

void QObjectPrivate::cleanConnectionLists()
{
    if (connectionLists->dirty && !connectionLists->inUse) {
        // remove broken connections
        for (int signal = -1; signal < connectionLists->count(); ++signal) {
            QObjectPrivate::ConnectionList &connectionList =
                (*connectionLists)[signal];

            // Set to the last entry in the connection list that was *not*
            // deleted.  This is needed to update the list's last pointer
            // at the end of the cleanup.
            QObjectPrivate::Connection *last = 0;

            QObjectPrivate::Connection **prev = &connectionList.first;
            QObjectPrivate::Connection *c = *prev;
            while (c) {
                if (c->receiver) {
                    last = c;
                    prev = &c->nextConnectionList;
                    c = *prev;
                } else {
                    QObjectPrivate::Connection *next = c->nextConnectionList;
                    *prev = next;
                    c->deref();
                    c = next;
                }
            }

            // Correct the connection list's last pointer.
            // As conectionList.last could equal last, this could be a noop
            connectionList.last = last;
        }
        connectionLists->dirty = false;
    }
}

/*!

  QMetaCallEvent 是 使用队列连接调用插槽时的插槽调用的事件
 */
QMetaCallEvent::QMetaCallEvent(ushort method_offset, ushort method_relative, QObjectPrivate::StaticMetaCallFunction callFunction,
                               const QObject *sender, int signalId,
                               int nargs, int *types, void **args, QSemaphore *semaphore)
    : QEvent(MetaCall), slotObj_(0), sender_(sender), signalId_(signalId),
      nargs_(nargs), types_(types), args_(args), semaphore_(semaphore),
      callFunction_(callFunction), method_offset_(method_offset), method_relative_(method_relative)
{ }

/*!
    \internal
 */
QMetaCallEvent::QMetaCallEvent(QtPrivate::QSlotObjectBase *slotO, const QObject *sender, int signalId,
                               int nargs, int *types, void **args, QSemaphore *semaphore)
    : QEvent(MetaCall), slotObj_(slotO), sender_(sender), signalId_(signalId),
      nargs_(nargs), types_(types), args_(args), semaphore_(semaphore),
      callFunction_(0), method_offset_(0), method_relative_(ushort(-1))
{
    if (slotObj_)
        slotObj_->ref();
}

/*!
    \internal
 */
QMetaCallEvent::~QMetaCallEvent()
{
    if (types_) {
        for (int i = 0; i < nargs_; ++i) {
            if (types_[i] && args_[i])
                QMetaType::destroy(types_[i], args_[i]);
        }
        free(types_);
        free(args_);
    }
#ifndef QT_NO_THREAD
    if (semaphore_)
        semaphore_->release();
#endif
    if (slotObj_)
        slotObj_->destroyIfLastRef();
}

/*!
    \internal
 */
void QMetaCallEvent::placeMetaCall(QObject *object)
{
    if (slotObj_) {
        slotObj_->call(object, args_);
    } else if (callFunction_ && method_offset_ <= object->metaObject()->methodOffset()) {
        callFunction_(object, QMetaObject::InvokeMetaMethod, method_relative_, args_);
    } else {
        QMetaObject::metacall(object, QMetaObject::InvokeMetaMethod, method_offset_ + method_relative_, args_);
    }
}

/*****************************************************************************
  QObject member functions
 *****************************************************************************/

// 如果, parent child 不在一个线程里面, 不能成为 parent child 关系.
static bool check_parent_thread(QObject *parent,
                                QThreadData *parentThreadData,
                                QThreadData *currentThreadData)
{
    if (parent && parentThreadData != currentThreadData) {
        return false;
    }
    return true;
}

// 在 QObject 创建的时候, 就生成了 d_ptr 指针的数据, 并且是 QObjectPrivate 的数据.
// 这也就是, 为什么 Q_D(QObject); 这个宏, 能够生成 d 这个成员变量的原因.
// QObject 和线程有着强依赖关系, 这个依赖关系, 就是根据 threadData 来保持的

QObject::QObject(QObject *parent)
    : d_ptr(new QObjectPrivate)
{
    Q_D(QObject);
    d_ptr->q_ptr = this;
    d->threadData = (parent && !parent->thread()) ? parent->d_func()->threadData : QThreadData::current();
    d->threadData->ref();
    if (parent) {
        QT_TRY {
            // 如果 两个 thread 不一样, 不能成为 父子关系.
            if (!check_parent_thread(parent, parent ? parent->d_func()->threadData : 0, d->threadData))
                parent = 0;
            setParent(parent);
        } QT_CATCH(...) {
            d->threadData->deref();
            QT_RETHROW;
        }
    }
}

QObject::~QObject()
{
    Q_D(QObject);
    d->wasDeleted = true;
    d->blockSig = 0; // unblock signals so we always emit destroyed()

    QtSharedPointer::ExternalRefCountData *sharedRefcount = d->sharedRefcount.load();
    if (sharedRefcount) {
        if (sharedRefcount->strongref.load() > 0) {
            qWarning("QObject: shared QObject was deleted directly. The program is malformed and may crash.");
            // but continue deleting, it's too late to stop anyway
        }

        // indicate to all QWeakPointers that this QObject has now been deleted
        sharedRefcount->strongref.store(0);
        if (!sharedRefcount->weakref.deref())
            delete sharedRefcount;
    }

    // 主动发送信号通知外界.
    emit destroyed(this);

    if (d->declarativeData) {
        if (static_cast<QAbstractDeclarativeDataImpl*>(d->declarativeData)->ownedByQml1) {
            if (QAbstractDeclarativeData::destroyed_qml1)
                QAbstractDeclarativeData::destroyed_qml1(d->declarativeData, this);
        } else {
            if (QAbstractDeclarativeData::destroyed)
                QAbstractDeclarativeData::destroyed(d->declarativeData, this);
        }
    }

    // set ref to zero to indicate that this object has been deleted
    if (d->currentSender != 0)
        d->currentSender->ref = 0;
    d->currentSender = 0;

    // 在这里, 做了 connection 的清理工作.
    if (d->connectionLists || d->senders) {
        QMutex *signalSlotMutex = signalSlotLock(this);
        QMutexLocker locker(signalSlotMutex);

        // 将从自己发出去的所有 connection 进行清理工作.
        if (d->connectionLists) {
            ++d->connectionLists->inUse;
            int connectionListsCount = d->connectionLists->count();
            for (int signal = -1; signal < connectionListsCount; ++signal) {
                QObjectPrivate::ConnectionList &connectionList =
                    (*d->connectionLists)[signal];

                while (QObjectPrivate::Connection *c = connectionList.first) {
                    if (!c->receiver) {
                        connectionList.first = c->nextConnectionList;
                        c->deref();
                        continue;
                    }

                    QMutex *m = signalSlotLock(c->receiver);
                    bool needToUnlock = QOrderedMutexLocker::relock(signalSlotMutex, m);

                    if (c->receiver) {
                        *c->prev = c->next;
                        if (c->next) c->next->prev = c->prev;
                    }
                    c->receiver = 0;
                    if (needToUnlock)
                        m->unlock();

                    connectionList.first = c->nextConnectionList;

                    // The destroy operation must happen outside the lock
                    if (c->isSlotObject) {
                        c->isSlotObject = false;
                        locker.unlock();
                        c->slotObj->destroyIfLastRef();
                        locker.relock();
                    }
                    c->deref();
                }
            }

            if (!--d->connectionLists->inUse) {
                delete d->connectionLists;
            } else {
                d->connectionLists->orphaned = true;
            }
            d->connectionLists = 0;
        }

        // 将自己作为接受者的所有 connection 进行清理工作.
        QObjectPrivate::Connection *node = d->senders;
        while (node) {
            QObject *sender = node->sender;
            // Send disconnectNotify before removing the connection from sender's connection list.
            // This ensures any eventual destructor of sender will block on getting receiver's lock
            // and not finish until we release it.
            sender->disconnectNotify(QMetaObjectPrivate::signal(sender->metaObject(), node->signal_index));
            QMutex *m = signalSlotLock(sender);
            node->prev = &node;
            bool needToUnlock = QOrderedMutexLocker::relock(signalSlotMutex, m);
            //the node has maybe been removed while the mutex was unlocked in relock?
            if (!node || node->sender != sender) {
                // We hold the wrong mutex
                Q_ASSERT(needToUnlock);
                m->unlock();
                continue;
            }
            node->receiver = 0;
            QObjectConnectionListVector *senderLists = sender->d_func()->connectionLists;
            if (senderLists)
                senderLists->dirty = true;

            QtPrivate::QSlotObjectBase *slotObj = Q_NULLPTR;
            if (node->isSlotObject) {
                slotObj = node->slotObj;
                node->isSlotObject = false;
            }

            node = node->next;
            if (needToUnlock)
                m->unlock();

            if (slotObj) {
                if (node)
                    node->prev = &node;
                locker.unlock();
                slotObj->destroyIfLastRef();
                locker.relock();
            }
        }
    }
    // 对 ChildRen 做清理工作, 因为 QObject 的 parent 主要就是用来控制声明周期的.
    if (!d->children.isEmpty())
        d->deleteChildren();
    if (d->parent)        // remove it from parent object
        d->setParent_helper(0);
}

// 直接到数据部分进行取值设值得操作.
QString QObject::objectName() const
{
    Q_D(const QObject);
    return d->extraData ? d->extraData->objectName : QString();
}

void QObject::setObjectName(const QString &name)
{
    Q_D(QObject);
    if (!d->extraData)
        d->extraData = new QObjectPrivate::ExtraData;

    if (d->extraData->objectName != name) {
        d->extraData->objectName = name;
        emit objectNameChanged(d->extraData->objectName, QPrivateSignal());
    }
}

// 最原始的 event 函数, 就是一个分发函数, 根据 type, 调用不同的 sepecific event 处理函数. 模板方法.
bool QObject::event(QEvent *e)
{
    switch (e->type()) {
    case QEvent::Timer:
        timerEvent((QTimerEvent*)e);
        break;

    case QEvent::ChildAdded:
    case QEvent::ChildPolished:
    case QEvent::ChildRemoved:
        // 当发生了关于 child 的事件的时候.
        childEvent((QChildEvent*)e);
        break;

    case QEvent::DeferredDelete:
        qDeleteInEventHandler(this); // deleteLater, 最终会变为这样的一个事件. 在事件里面, 会存放着对应的 receiver
        break;

    case QEvent::MetaCall:
        {
            QMetaCallEvent *mce = static_cast<QMetaCallEvent*>(e);

            QConnectionSenderSwitcher sw(this, const_cast<QObject*>(mce->sender()), mce->signalId());

            mce->placeMetaCall(this);
            break;
        }

    case QEvent::ThreadChange: {
        Q_D(QObject);
        QThreadData *threadData = d->threadData;
        QAbstractEventDispatcher *eventDispatcher = threadData->eventDispatcher.load();
        if (eventDispatcher) {
            QList<QAbstractEventDispatcher::TimerInfo> timers = eventDispatcher->registeredTimers(this);
            if (!timers.isEmpty()) {
                // do not to release our timer ids back to the pool (since the timer ids are moving to a new thread).
                eventDispatcher->unregisterTimers(this);
                QMetaObject::invokeMethod(this, "_q_reregisterTimers", Qt::QueuedConnection,
                                          Q_ARG(void*, (new QList<QAbstractEventDispatcher::TimerInfo>(timers))));
            }
        }
        break;
    }

    default:
        if (e->type() >= QEvent::User) {
            customEvent(e);
            break;
        }
        return false;
    }
    return true;
}


void QObject::timerEvent(QTimerEvent *)
{
}


void QObject::childEvent(QChildEvent * /* event */)
{
}


void QObject::customEvent(QEvent * /* event */)
{
}

// 这个函数, 不会在这个类里面使用, 它是在 Application sendEvent 的时候使用.
bool QObject::eventFilter(QObject * /* watched */, QEvent * /* event */)
{
    return false;
}

bool QObject::blockSignals(bool block) Q_DECL_NOTHROW
{
    Q_D(QObject);
    bool previous = d->blockSig;
    d->blockSig = block;
    return previous;
}

/*!
    之所以, QObject 都会得知自己在哪个 QThread 里面, 就是因为, 其实在内部进行了存储.
*/
QThread *QObject::thread() const
{
    return d_func()->threadData->thread;
}

void QObject::moveToThread(QThread *targetThread)
{
    Q_D(QObject);

    if (d->threadData->thread == targetThread) {
        return;
    }

    if (d->parent != 0) {
        return;
    }
    if (d->isWidget) { // 如果是 Widget, 只能在主线程.
        return;
    }

    QThreadData *currentData = QThreadData::current();
    QThreadData *targetData = targetThread ? QThreadData::get2(targetThread) : Q_NULLPTR;
    if (d->threadData->thread == 0 && currentData == targetData) {
        // one exception to the rule: we allow moving objects with no thread affinity to the current thread
        currentData = d->threadData;
    } else if (d->threadData != currentData) {
        return;
    }

    // prepare to move
    d->moveToThread_helper();

    if (!targetData)
        targetData = new QThreadData(0);

    QOrderedMutexLocker locker(&currentData->postEventList.mutex,
                               &targetData->postEventList.mutex);

    // keep currentData alive (since we've got it locked)
    currentData->ref();

    // move the object
    d_func()->setThreadData_helper(currentData, targetData);

    locker.unlock();

    // now currentData can commit suicide if it wants to
    currentData->deref();
}

void QObjectPrivate::moveToThread_helper()
{
    Q_Q(QObject);
    QEvent e(QEvent::ThreadChange);
    QCoreApplication::sendEvent(q, &e);
    for (int i = 0; i < children.size(); ++i) {
        QObject *child = children.at(i);
        child->d_func()->moveToThread_helper();
    }
}

void QObjectPrivate::setThreadData_helper(QThreadData *currentData, QThreadData *targetData)
{
    Q_Q(QObject);

    // move posted events
    // post event 事件的转移
    int eventsMoved = 0;
    for (int i = 0; i < currentData->postEventList.size(); ++i) {
        const QPostEvent &pe = currentData->postEventList.at(i);
        if (!pe.event)
            continue;
        if (pe.receiver == q) {
            // move this post event to the targetList
            targetData->postEventList.addEvent(pe);
            const_cast<QPostEvent &>(pe).event = 0;
            ++eventsMoved;
        }
    }
    if (eventsMoved > 0 && targetData->eventDispatcher.load()) {
        targetData->canWait = false;
        targetData->eventDispatcher.load()->wakeUp();
    }

    // the current emitting thread shouldn't restore currentSender after calling moveToThread()
    if (currentSender)
        currentSender->ref = 0;
    currentSender = 0;

    // set new thread data
    // 真正数据的转移.
    targetData->ref();
    threadData->deref();
    threadData = targetData;

    // 所有的 child, 都要进行线程的转移.
    for (int i = 0; i < children.size(); ++i) {
        QObject *child = children.at(i);
        child->d_func()->setThreadData_helper(currentData, targetData);
    }
}

void QObjectPrivate::_q_reregisterTimers(void *pointer)
{
    Q_Q(QObject);
    QList<QAbstractEventDispatcher::TimerInfo> *timerList = reinterpret_cast<QList<QAbstractEventDispatcher::TimerInfo> *>(pointer);
    QAbstractEventDispatcher *eventDispatcher = threadData->eventDispatcher.load();
    for (int i = 0; i < timerList->size(); ++i) {
        const QAbstractEventDispatcher::TimerInfo &ti = timerList->at(i);
        eventDispatcher->registerTimer(ti.timerId, ti.interval, ti.timerType, q);
    }
    delete timerList;
}


int QObject::startTimer(int interval, Qt::TimerType timerType)
{
    Q_D(QObject);

    if (Q_UNLIKELY(interval < 0)) {
        return 0;
    }
    if (Q_UNLIKELY(!d->threadData->eventDispatcher.load())) {
        return 0;
    }
    if (Q_UNLIKELY(thread() != QThread::currentThread())) {
        return 0;
    }
    // 首先是防卫判断一下, 最终, 还是要到 thread 中, 进行 timer 的注册.
    // 注意, 这里 this 是函数的调用者. 也就是, 如果是 QTimer.start, 就是 QTimer.
    int timerId = d->threadData->eventDispatcher.load()->registerTimer(interval, timerType, this);
    if (!d->extraData)
        d->extraData = new QObjectPrivate::ExtraData;
    d->extraData->runningTimers.append(timerId);
    return timerId;
}

void QObject::killTimer(int id)
{
    Q_D(QObject);
    if (Q_UNLIKELY(thread() != QThread::currentThread())) {
        return;
    }
    if (id) {
        int at = d->extraData ? d->extraData->runningTimers.indexOf(id) : -1;
        if (at == -1) {

            return;
        }

        if (d->threadData->eventDispatcher.load())
            d->threadData->eventDispatcher.load()->unregisterTimer(id);

        d->extraData->runningTimers.remove(at);
        QAbstractEventDispatcherPrivate::releaseTimerId(id);
    }
}


void qt_qFindChildren_helper(const QObject *parent, const QString &name,
                             const QMetaObject &mo, QList<void*> *list, Qt::FindChildOptions options)
{
    if (!parent || !list)
        return;
    const QObjectList &children = parent->children();
    QObject *obj;
    for (int i = 0; i < children.size(); ++i) {
        obj = children.at(i);
        if (mo.cast(obj)) {
            if (name.isNull() || obj->objectName() == name)
                list->append(obj);
        }
        if (options & Qt::FindChildrenRecursively)
            qt_qFindChildren_helper(obj, name, mo, list, options);
    }
}

#ifndef QT_NO_REGEXP
/*!
    \internal
*/
void qt_qFindChildren_helper(const QObject *parent, const QRegExp &re,
                             const QMetaObject &mo, QList<void*> *list, Qt::FindChildOptions options)
{
    if (!parent || !list)
        return;
    const QObjectList &children = parent->children();
    QRegExp reCopy = re;
    QObject *obj;
    for (int i = 0; i < children.size(); ++i) {
        obj = children.at(i);
        if (mo.cast(obj) && reCopy.indexIn(obj->objectName()) != -1)
            list->append(obj);

        if (options & Qt::FindChildrenRecursively)
            qt_qFindChildren_helper(obj, re, mo, list, options);
    }
}
#endif // QT_NO_REGEXP

#ifndef QT_NO_REGULAREXPRESSION
/*!
    \internal
*/
void qt_qFindChildren_helper(const QObject *parent, const QRegularExpression &re,
                             const QMetaObject &mo, QList<void*> *list, Qt::FindChildOptions options)
{
    if (!parent || !list)
        return;
    const QObjectList &children = parent->children();
    QObject *obj;
    for (int i = 0; i < children.size(); ++i) {
        obj = children.at(i);
        if (mo.cast(obj)) {
            QRegularExpressionMatch m = re.match(obj->objectName());
            if (m.hasMatch())
                list->append(obj);
        }
        if (options & Qt::FindChildrenRecursively)
            qt_qFindChildren_helper(obj, re, mo, list, options);
    }
}
#endif // QT_NO_REGULAREXPRESSION

/*!
    \internal
 */
QObject *qt_qFindChild_helper(const QObject *parent, const QString &name, const QMetaObject &mo, Qt::FindChildOptions options)
{
    if (!parent)
        return 0;
    const QObjectList &children = parent->children();
    QObject *obj;
    int i;
    // 如果, 能够类型转化成功, 也就是类型适配上, 并且名称适配上, 就返回该值.
    for (i = 0; i < children.size(); ++i) {
        obj = children.at(i);
        if (mo.cast(obj) && (name.isNull() || obj->objectName() == name))
            return obj;
    }
    if (options & Qt::FindChildrenRecursively) {
        for (i = 0; i < children.size(); ++i) {
            obj = qt_qFindChild_helper(children.at(i), name, mo, options);
            if (obj)
                return obj;
        }
    }
    return 0;
}

void QObject::setParent(QObject *parent)
{
    Q_D(QObject);
    Q_ASSERT(!d->isWidget);
    d->setParent_helper(parent);
}

void QObjectPrivate::deleteChildren()
{
    Q_ASSERT_X(!isDeletingChildren, "QObjectPrivate::deleteChildren()", "isDeletingChildren already set, did this function recurse?");
    isDeletingChildren = true;
    // delete children objects
    // don't use qDeleteAll as the destructor of the child might
    // delete siblings
    for (int i = 0; i < children.count(); ++i) {
        currentChildBeingDeleted = children.at(i);
        children[i] = 0;
        // 在这里, 进行了 child 的 delete 操作.
        delete currentChildBeingDeleted;
    }
    children.clear();
    currentChildBeingDeleted = 0;
    isDeletingChildren = false;
}

void QObjectPrivate::setParent_helper(QObject *o)
{
    Q_Q(QObject);
    if (o == parent)
        return;
    if (parent) {
        QObjectPrivate *parentD = parent->d_func();
        if (parentD->isDeletingChildren && wasDeleted
            && parentD->currentChildBeingDeleted == q) {
            // don't do anything since QObjectPrivate::deleteChildren() already
            // cleared our entry in parentD->children.
        } else {
            const int index = parentD->children.indexOf(q);
            if (parentD->isDeletingChildren) {
                parentD->children[index] = 0;
            } else {
                parentD->children.removeAt(index);
                if (sendChildEvents && parentD->receiveChildEvents) {
                    QChildEvent e(QEvent::ChildRemoved, q);
                    QCoreApplication::sendEvent(parent, &e);
                }
            }
        }
    }
    parent = o;
    if (parent) {
        // object hierarchies are constrained to a single thread
        if (threadData != parent->d_func()->threadData) {
            qWarning("QObject::setParent: Cannot set parent, new parent is in a different thread");
            parent = 0;
            return;
        }
        parent->d_func()->children.append(q);
        if(sendChildEvents && parent->d_func()->receiveChildEvents) {
            if (!isWidget) {
                QChildEvent e(QEvent::ChildAdded, q);
                QCoreApplication::sendEvent(parent, &e);
            }
        }
    }
    if (!wasDeleted && !isDeletingChildren && declarativeData && QAbstractDeclarativeData::parentChanged)
        QAbstractDeclarativeData::parentChanged(declarativeData, q, o);
}

// 每个 Object 的 eventFilter 信息, 是存储在自己的环境里面的.
void QObject::installEventFilter(QObject *obj)
{
    Q_D(QObject);
    if (!obj)
        return;
    if (d->threadData != obj->d_func()->threadData) {
        return;
    }

    if (!d->extraData)
        d->extraData = new QObjectPrivate::ExtraData;

    // clean up unused items in the list
    d->extraData->eventFilters.removeAll((QObject*)0);
    d->extraData->eventFilters.removeAll(obj);
    d->extraData->eventFilters.prepend(obj);
}

void QObject::removeEventFilter(QObject *obj)
{
    Q_D(QObject);
    if (d->extraData) {
        for (int i = 0; i < d->extraData->eventFilters.count(); ++i) {
            if (d->extraData->eventFilters.at(i) == obj)
                d->extraData->eventFilters[i] = 0;
        }
    }
}

// deletaLater, 生成一个 QDeferredDeleteEvent 事件, 注册到 this 的数据上.
void QObject::deleteLater()
{
    QCoreApplication::postEvent(this, new QDeferredDeleteEvent());
}

/*****************************************************************************
  Signals and slots
 *****************************************************************************/


const char *qFlagLocation(const char *method)
{
    QThreadData *currentThreadData = QThreadData::current(false);
    if (currentThreadData != 0)
        currentThreadData->flaggedSignatures.store(method);
    return method;
}

static int extract_code(const char *member)
{
    // extract code, ensure QMETHOD_CODE <= code <= QSIGNAL_CODE
    return (((int)(*member) - '0') & 0x3);
}

static const char * extract_location(const char *member)
{
    if (QThreadData::current()->flaggedSignatures.contains(member)) {
        // signature includes location information after the first null-terminator
        const char *location = member + qstrlen(member) + 1;
        if (*location != '\0')
            return location;
    }
    return 0;
}

static bool check_signal_macro(const QObject *sender, const char *signal,
                                const char *func, const char *op)
{
    int sigcode = extract_code(signal);
    if (sigcode != QSIGNAL_CODE) {
        if (sigcode == QSLOT_CODE)
            qWarning("QObject::%s: Attempt to %s non-signal %s::%s",
                     func, op, sender->metaObject()->className(), signal+1);
        else
            qWarning("QObject::%s: Use the SIGNAL macro to %s %s::%s",
                     func, op, sender->metaObject()->className(), signal);
        return false;
    }
    return true;
}

static bool check_method_code(int code, const QObject *object,
                               const char *method, const char *func)
{
    if (code != QSLOT_CODE && code != QSIGNAL_CODE) {
        qWarning("QObject::%s: Use the SLOT or SIGNAL macro to "
                 "%s %s::%s", func, func, object->metaObject()->className(), method);
        return false;
    }
    return true;
}

static void err_method_notfound(const QObject *object,
                                const char *method, const char *func)
{
    const char *type = "method";
    switch (extract_code(method)) {
        case QSLOT_CODE:   type = "slot";   break;
        case QSIGNAL_CODE: type = "signal"; break;
    }
    const char *loc = extract_location(method);
    if (strchr(method,')') == 0)                // common typing mistake
        qWarning("QObject::%s: Parentheses expected, %s %s::%s%s%s",
                 func, type, object->metaObject()->className(), method+1,
                 loc ? " in ": "", loc ? loc : "");
    else
        qWarning("QObject::%s: No such %s %s::%s%s%s",
                 func, type, object->metaObject()->className(), method+1,
                 loc ? " in ": "", loc ? loc : "");

}


static void err_info_about_objects(const char * func,
                                    const QObject * sender,
                                    const QObject * receiver)
{
    QString a = sender ? sender->objectName() : QString();
    QString b = receiver ? receiver->objectName() : QString();
    if (!a.isEmpty())
        qWarning("QObject::%s:  (sender name:   '%s')", func, a.toLocal8Bit().data());
    if (!b.isEmpty())
        qWarning("QObject::%s:  (receiver name: '%s')", func, b.toLocal8Bit().data());
}


// 在 Slot 函数里面, 可以获取 sender 的信息.
QObject *QObject::sender() const
{
    Q_D(const QObject);

    QMutexLocker locker(signalSlotLock(this));
    if (!d->currentSender)
        return 0;

    // 这里, 为了保险, 还从 senders 里面进行了一次遍历操作.
    for (QObjectPrivate::Connection *c = d->senders; c; c = c->next) {
        if (c->sender == d->currentSender->sender)
            return d->currentSender->sender;
    }

    return 0;
}


int QObject::senderSignalIndex() const
{
    Q_D(const QObject);

    QMutexLocker locker(signalSlotLock(this));
    if (!d->currentSender)
        return -1;

    for (QObjectPrivate::Connection *c = d->senders; c; c = c->next) {
        if (c->sender == d->currentSender->sender) {
            // Convert from signal range to method range
            return QMetaObjectPrivate::signal(c->sender->metaObject(), d->currentSender->signal).methodIndex();
        }
    }

    return -1;
}

// 知道了所有 Connection 都存储在 QObject 的内部, 直接遍历就可以了.
int QObject::receivers(const char *signal) const
{
    Q_D(const QObject);
    int receivers = 0;
    if (signal) {
        QByteArray signal_name = QMetaObject::normalizedSignature(signal);
        signal = signal_name;
        signal++; // skip code
        int signal_index = d->signalIndex(signal);
        if (signal_index < 0) {
            return 0;
        }

        if (!d->isSignalConnected(signal_index))
            return receivers;

        if (d->declarativeData && QAbstractDeclarativeData::receivers) {
            receivers += QAbstractDeclarativeData::receivers(d->declarativeData, this,
                                                             signal_index);
        }

        QMutexLocker locker(signalSlotLock(this));
        if (d->connectionLists) {
            if (signal_index < d->connectionLists->count()) {
                const QObjectPrivate::Connection *c =
                    d->connectionLists->at(signal_index).first;
                while (c) {
                    receivers += c->receiver ? 1 : 0;
                    c = c->nextConnectionList;
                }
            }
        }
    }
    return receivers;
}

bool QObject::isSignalConnected(const QMetaMethod &signal) const
{
    Q_D(const QObject);
    if (!signal.mobj)
        return false;

    Q_ASSERT_X(signal.mobj->cast(this) && signal.methodType() == QMetaMethod::Signal,
               "QObject::isSignalConnected" , "the parameter must be a signal member of the object");
    uint signalIndex = (signal.handle - QMetaObjectPrivate::get(signal.mobj)->methodData)/5;

    if (signal.mobj->d.data[signal.handle + 4] & MethodCloned)
        signalIndex = QMetaObjectPrivate::originalClone(signal.mobj, signalIndex);

    signalIndex += QMetaObjectPrivate::signalOffset(signal.mobj);

    if (signalIndex < sizeof(d->connectedSignals) * 8)
        return d->isSignalConnected(signalIndex);

    QMutexLocker locker(signalSlotLock(this));
    if (d->connectionLists) {
        if (signalIndex < uint(d->connectionLists->count())) {
            const QObjectPrivate::Connection *c =
                d->connectionLists->at(signalIndex).first;
            while (c) {
                if (c->receiver)
                    return true;
                c = c->nextConnectionList;
            }
        }
    }
    return false;
}

void QMetaObjectPrivate::memberIndexes(const QObject *obj,
                                       const QMetaMethod &member,
                                       int *signalIndex, int *methodIndex)
{
    *signalIndex = -1;
    *methodIndex = -1;
    if (!obj || !member.mobj)
        return;
    const QMetaObject *m = obj->metaObject();
    // Check that member is member of obj class
    while (m != 0 && m != member.mobj)
        m = m->d.superdata;
    if (!m)
        return;
    *signalIndex = *methodIndex = (member.handle - get(member.mobj)->methodData)/5;

    int signalOffset;
    int methodOffset;
    computeOffsets(m, &signalOffset, &methodOffset);

    *methodIndex += methodOffset;
    if (member.methodType() == QMetaMethod::Signal) {
        *signalIndex = originalClone(m, *signalIndex);
        *signalIndex += signalOffset;
    } else {
        *signalIndex = -1;
    }
}

#ifndef QT_NO_DEBUG
static inline void check_and_warn_compat(const QMetaObject *sender, const QMetaMethod &signal,
                                         const QMetaObject *receiver, const QMetaMethod &method)
{
    if (signal.attributes() & QMetaMethod::Compatibility) {
        if (!(method.attributes() & QMetaMethod::Compatibility))
            qWarning("QObject::connect: Connecting from COMPAT signal (%s::%s)",
                     sender->className(), signal.methodSignature().constData());
    } else if ((method.attributes() & QMetaMethod::Compatibility) &&
               method.methodType() == QMetaMethod::Signal) {
        qWarning("QObject::connect: Connecting from %s::%s to COMPAT slot (%s::%s)",
                 sender->className(), signal.methodSignature().constData(),
                 receiver->className(), method.methodSignature().constData());
    }
}
#endif

/*
#  define METHOD(a)   qFlagLocation("0"#a QLOCATION)
# define SLOT(a)     qFlagLocation("1"#a QLOCATION)
# define SIGNAL(a)   qFlagLocation("2"#a QLOCATION)
这几个宏, 只不过在字符串上面, 增加了特定的标识而已. 然后, 在 connect 函数里面, 会根据这个标识进行逻辑判断.
 */

QMetaObject::Connection QObject::connect(const QObject *sender, const char *signal,
                                     const QObject *receiver, const char *method,
                                     Qt::ConnectionType type)
{
    // 首先, 是防卫判断
    if (sender == 0 || receiver == 0 || signal == 0 || method == 0) {
        qWarning("QObject::connect: Cannot connect %s::%s to %s::%s",
                 sender ? sender->metaObject()->className() : "(null)",
                 (signal && *signal) ? signal+1 : "(null)",
                 receiver ? receiver->metaObject()->className() : "(null)",
                 (method && *method) ? method+1 : "(null)");
        return QMetaObject::Connection(0);
    }

    QByteArray tmp_signal_name;
    // 如果, signal, method 不是通过 SLOT, SIGNAL 包装的,  check_macro 就会报错.
    if (!check_signal_macro(sender, signal, "connect", "bind"))
        return QMetaObject::Connection(0);

    // 拿到了 sender 的元信息.
    const QMetaObject *smeta = sender->metaObject();
    const char *signal_arg = signal;
    ++signal; //skip code
    QArgumentTypeArray signalTypes;
    QByteArray signalName = QMetaObjectPrivate::decodeMethodSignature(signal, signalTypes);
    int signal_index = QMetaObjectPrivate::indexOfSignalRelative(
            &smeta, signalName, signalTypes.size(), signalTypes.constData());
    if (signal_index < 0) {
        // check for normalized signatures
        tmp_signal_name = QMetaObject::normalizedSignature(signal - 1);
        signal = tmp_signal_name.constData() + 1;

        signalTypes.clear();
        signalName = QMetaObjectPrivate::decodeMethodSignature(signal, signalTypes);
        smeta = sender->metaObject();
        signal_index = QMetaObjectPrivate::indexOfSignalRelative(
                &smeta, signalName, signalTypes.size(), signalTypes.constData());
    }
    if (signal_index < 0) {
        err_method_notfound(sender, signal_arg, "connect");
        err_info_about_objects("connect", sender, receiver);
        return QMetaObject::Connection(0);
    }
    signal_index = QMetaObjectPrivate::originalClone(smeta, signal_index);
    signal_index += QMetaObjectPrivate::signalOffset(smeta);

    // signal_index 在这个时候, 就是在元信息里面, 信号所在的位置了.
    // 然后就是对于 slot 的处理.
    QByteArray tmp_method_name;
    int membcode = extract_code(method);

    if (!check_method_code(membcode, receiver, method, "connect"))
        return QMetaObject::Connection(0);
    const char *method_arg = method;
    ++method; // skip code

    QArgumentTypeArray methodTypes;
    QByteArray methodName = QMetaObjectPrivate::decodeMethodSignature(method, methodTypes);
    const QMetaObject *rmeta = receiver->metaObject();
    int method_index_relative = -1;
    switch (membcode) {
    case QSLOT_CODE: // 如果连接的是 SLOT
        method_index_relative = QMetaObjectPrivate::indexOfSlotRelative(
                &rmeta, methodName, methodTypes.size(), methodTypes.constData());
        break;
    case QSIGNAL_CODE: // 如果连接的是 SIGNAL
        method_index_relative = QMetaObjectPrivate::indexOfSignalRelative(
                &rmeta, methodName, methodTypes.size(), methodTypes.constData());
        break;
    }
    if (method_index_relative < 0) { // 这里, 就是说没有在元信息里面, 也就是没有用 slots: 修饰过得成员函数. 这里不太明白, 他怎么得到的最终结果.
        // check for normalized methods
        tmp_method_name = QMetaObject::normalizedSignature(method);
        method = tmp_method_name.constData();

        methodTypes.clear();
        methodName = QMetaObjectPrivate::decodeMethodSignature(method, methodTypes);
        // rmeta may have been modified above
        rmeta = receiver->metaObject();
        switch (membcode) {
        case QSLOT_CODE:
            method_index_relative = QMetaObjectPrivate::indexOfSlotRelative(
                    &rmeta, methodName, methodTypes.size(), methodTypes.constData());
            break;
        case QSIGNAL_CODE:
            method_index_relative = QMetaObjectPrivate::indexOfSignalRelative(
                    &rmeta, methodName, methodTypes.size(), methodTypes.constData());
            break;
        }
    }

    if (method_index_relative < 0) {
        err_method_notfound(receiver, method_arg, "connect");
        err_info_about_objects("connect", sender, receiver);
        return QMetaObject::Connection(0);
    }
    // 这里就是在检测, SIGNAL, SLOT 的参数个数了.
    if (!QMetaObjectPrivate::checkConnectArgs(signalTypes.size(), signalTypes.constData(),
                                              methodTypes.size(), methodTypes.constData())) {
        qWarning("QObject::connect: Incompatible sender/receiver arguments"
                 "\n        %s::%s --> %s::%s",
                 sender->metaObject()->className(), signal,
                 receiver->metaObject()->className(), method);
        return QMetaObject::Connection(0);
    }

    int *types = 0;
    if ((type == Qt::QueuedConnection)
            && !(types = queuedConnectionTypes(signalTypes.constData(), signalTypes.size()))) {
        return QMetaObject::Connection(0);
    }

#ifndef QT_NO_DEBUG
    QMetaMethod smethod = QMetaObjectPrivate::signal(smeta, signal_index);
    QMetaMethod rmethod = rmeta->method(method_index_relative + rmeta->methodOffset());
    check_and_warn_compat(smeta, smethod, rmeta, rmethod);
#endif
    // 以上, 已经拿到了所有的元信息了, 真正的关联一定在 QMetaObjectPrivate::connect 函数里.
    // QMetaObjectPrivate::connect 里面, 就是根据传入的值, 生成一个 Connection 对象, 然后把这个值, 存到了 sender
    // 的 connectionLists 里面, 所以, 信号槽这个东西, 本质上, 还是要在 sender 里面, 存储各种连接关系.
    QMetaObject::Connection handle = QMetaObject::Connection(QMetaObjectPrivate::connect(
        sender, signal_index, smeta, receiver, method_index_relative, rmeta ,type, types));
    return handle;
}

QMetaObject::Connection QObject::connect(const QObject *sender, const QMetaMethod &signal,
                                     const QObject *receiver, const QMetaMethod &method,
                                     Qt::ConnectionType type)
{
    if (sender == 0
            || receiver == 0
            || signal.methodType() != QMetaMethod::Signal
            || method.methodType() == QMetaMethod::Constructor) {
        qWarning("QObject::connect: Cannot connect %s::%s to %s::%s",
                 sender ? sender->metaObject()->className() : "(null)",
                 signal.methodSignature().constData(),
                 receiver ? receiver->metaObject()->className() : "(null)",
                 method.methodSignature().constData() );
        return QMetaObject::Connection(0);
    }

    int signal_index;
    int method_index;
    {
        int dummy;
        QMetaObjectPrivate::memberIndexes(sender, signal, &signal_index, &dummy);
        QMetaObjectPrivate::memberIndexes(receiver, method, &dummy, &method_index);
    }

    const QMetaObject *smeta = sender->metaObject();
    const QMetaObject *rmeta = receiver->metaObject();
    if (signal_index == -1) {
        qWarning("QObject::connect: Can't find signal %s on instance of class %s",
                 signal.methodSignature().constData(), smeta->className());
        return QMetaObject::Connection(0);
    }
    if (method_index == -1) {
        qWarning("QObject::connect: Can't find method %s on instance of class %s",
                 method.methodSignature().constData(), rmeta->className());
        return QMetaObject::Connection(0);
    }

    if (!QMetaObject::checkConnectArgs(signal.methodSignature().constData(), method.methodSignature().constData())) {
        qWarning("QObject::connect: Incompatible sender/receiver arguments"
                 "\n        %s::%s --> %s::%s",
                 smeta->className(), signal.methodSignature().constData(),
                 rmeta->className(), method.methodSignature().constData());
        return QMetaObject::Connection(0);
    }

    int *types = 0;
    if ((type == Qt::QueuedConnection)
            && !(types = queuedConnectionTypes(signal.parameterTypes())))
        return QMetaObject::Connection(0);

#ifndef QT_NO_DEBUG
    check_and_warn_compat(smeta, signal, rmeta, method);
#endif
    QMetaObject::Connection handle = QMetaObject::Connection(QMetaObjectPrivate::connect(
        sender, signal_index, signal.enclosingMetaObject(), receiver, method_index, 0, type, types));
    return handle;
}

// 既然, 已经知道了 connect 的实现了, 那么其实 disConnect 也就是根据参数, 去 connectionList 进行删除的操作而已.
bool QObject::disconnect(const QObject *sender, const char *signal,
                         const QObject *receiver, const char *method)
{
    if (sender == 0 || (receiver == 0 && method != 0)) {
        qWarning("QObject::disconnect: Unexpected null parameter");
        return false;
    }

    const char *signal_arg = signal;
    QByteArray signal_name;
    bool signal_found = false;
    if (signal) {
        QT_TRY {
            signal_name = QMetaObject::normalizedSignature(signal);
            signal = signal_name.constData();
        } QT_CATCH (const std::bad_alloc &) {
            // if the signal is already normalized, we can continue.
            if (sender->metaObject()->indexOfSignal(signal + 1) == -1)
                QT_RETHROW;
        }

        if (!check_signal_macro(sender, signal, "disconnect", "unbind"))
            return false;
        signal++; // skip code
    }

    QByteArray method_name;
    const char *method_arg = method;
    int membcode = -1;
    bool method_found = false;
    if (method) {
        QT_TRY {
            method_name = QMetaObject::normalizedSignature(method);
            method = method_name.constData();
        } QT_CATCH(const std::bad_alloc &) {
            // if the method is already normalized, we can continue.
            if (receiver->metaObject()->indexOfMethod(method + 1) == -1)
                QT_RETHROW;
        }

        membcode = extract_code(method);
        if (!check_method_code(membcode, receiver, method, "disconnect"))
            return false;
        method++; // skip code
    }

    /* We now iterate through all the sender's and receiver's meta
     * objects in order to also disconnect possibly shadowed signals
     * and slots with the same signature.
    */
    bool res = false;
    const QMetaObject *smeta = sender->metaObject();
    QByteArray signalName;
    QArgumentTypeArray signalTypes;
    Q_ASSERT(QMetaObjectPrivate::get(smeta)->revision >= 7);
    if (signal)
        signalName = QMetaObjectPrivate::decodeMethodSignature(signal, signalTypes);
    QByteArray methodName;
    QArgumentTypeArray methodTypes;
    Q_ASSERT(!receiver || QMetaObjectPrivate::get(receiver->metaObject())->revision >= 7);
    if (method)
        methodName = QMetaObjectPrivate::decodeMethodSignature(method, methodTypes);
    do {
        int signal_index = -1;
        if (signal) {
            signal_index = QMetaObjectPrivate::indexOfSignalRelative(
                        &smeta, signalName, signalTypes.size(), signalTypes.constData());
            if (signal_index < 0)
                break;
            signal_index = QMetaObjectPrivate::originalClone(smeta, signal_index);
            signal_index += QMetaObjectPrivate::signalOffset(smeta);
            signal_found = true;
        }

        if (!method) {
            res |= QMetaObjectPrivate::disconnect(sender, signal_index, smeta, receiver, -1, 0);
        } else {
            const QMetaObject *rmeta = receiver->metaObject();
            do {
                int method_index = QMetaObjectPrivate::indexOfMethod(
                            rmeta, methodName, methodTypes.size(), methodTypes.constData());
                if (method_index >= 0)
                    while (method_index < rmeta->methodOffset())
                            rmeta = rmeta->superClass();
                if (method_index < 0)
                    break;
                res |= QMetaObjectPrivate::disconnect(sender, signal_index, smeta, receiver, method_index, 0);
                method_found = true;
            } while ((rmeta = rmeta->superClass()));
        }
    } while (signal && (smeta = smeta->superClass()));

    if (signal && !signal_found) {
        err_method_notfound(sender, signal_arg, "disconnect");
        err_info_about_objects("disconnect", sender, receiver);
    } else if (method && !method_found) {
        err_method_notfound(receiver, method_arg, "disconnect");
        err_info_about_objects("disconnect", sender, receiver);
    }
    if (res) {
        if (!signal)
            const_cast<QObject*>(sender)->disconnectNotify(QMetaMethod());
    }
    return res;
}

bool QObject::disconnect(const QObject *sender, const QMetaMethod &signal,
                         const QObject *receiver, const QMetaMethod &method)
{
    if (sender == 0 || (receiver == 0 && method.mobj != 0)) {
        qWarning("QObject::disconnect: Unexpected null parameter");
        return false;
    }
    if (signal.mobj) {
        if(signal.methodType() != QMetaMethod::Signal) {
            qWarning("QObject::%s: Attempt to %s non-signal %s::%s",
                     "disconnect","unbind",
                     sender->metaObject()->className(), signal.methodSignature().constData());
            return false;
        }
    }
    if (method.mobj) {
        if(method.methodType() == QMetaMethod::Constructor) {
            qWarning("QObject::disconect: cannot use constructor as argument %s::%s",
                     receiver->metaObject()->className(), method.methodSignature().constData());
            return false;
        }
    }

    // Reconstructing SIGNAL() macro result for signal.methodSignature() string
    QByteArray signalSignature;
    if (signal.mobj) {
        signalSignature.reserve(signal.methodSignature().size()+1);
        signalSignature.append((char)(QSIGNAL_CODE + '0'));
        signalSignature.append(signal.methodSignature());
    }

    int signal_index;
    int method_index;
    {
        int dummy;
        QMetaObjectPrivate::memberIndexes(sender, signal, &signal_index, &dummy);
        QMetaObjectPrivate::memberIndexes(receiver, method, &dummy, &method_index);
    }
    // If we are here sender is not null. If signal is not null while signal_index
    // is -1 then this signal is not a member of sender.
    if (signal.mobj && signal_index == -1) {
        qWarning("QObject::disconect: signal %s not found on class %s",
                 signal.methodSignature().constData(), sender->metaObject()->className());
        return false;
    }
    // If this condition is true then method is not a member of receeiver.
    if (receiver && method.mobj && method_index == -1) {
        qWarning("QObject::disconect: method %s not found on class %s",
                 method.methodSignature().constData(), receiver->metaObject()->className());
        return false;
    }

    if (!QMetaObjectPrivate::disconnect(sender, signal_index, signal.mobj, receiver, method_index, 0))
        return false;

    if (!signal.isValid()) {
        // The signal is a wildcard, meaning all signals were disconnected.
        // QMetaObjectPrivate::disconnect() doesn't call disconnectNotify()
        // per connection in this case. Call it once now, with an invalid
        // QMetaMethod as argument, as documented.
        const_cast<QObject*>(sender)->disconnectNotify(signal);
    }
    return true;
}


void QObject::connectNotify(const QMetaMethod &signal)
{
    Q_UNUSED(signal);
}

void QObject::disconnectNotify(const QMetaMethod &signal)
{
    Q_UNUSED(signal);
}

/*
    \internal
    convert a signal index from the method range to the signal range
 */
static int methodIndexToSignalIndex(const QMetaObject **base, int signal_index)
{
    if (signal_index < 0)
        return signal_index;
    const QMetaObject *metaObject = *base;
    while (metaObject && metaObject->methodOffset() > signal_index)
        metaObject = metaObject->superClass();

    if (metaObject) {
        int signalOffset, methodOffset;
        computeOffsets(metaObject, &signalOffset, &methodOffset);
        if (signal_index < metaObject->methodCount())
            signal_index = QMetaObjectPrivate::originalClone(metaObject, signal_index - methodOffset) + signalOffset;
        else
            signal_index = signal_index - methodOffset + signalOffset;
        *base = metaObject;
    }
    return signal_index;
}

QMetaObject::Connection QMetaObject::connect(const QObject *sender, int signal_index,
                                          const QObject *receiver, int method_index, int type, int *types)
{
    const QMetaObject *smeta = sender->metaObject();
    signal_index = methodIndexToSignalIndex(&smeta, signal_index);
    return Connection(QMetaObjectPrivate::connect(sender, signal_index, smeta,
                                       receiver, method_index,
                                       0, //FIXME, we could speed this connection up by computing the relative index
                                       type, types));
}


QObjectPrivate::Connection *QMetaObjectPrivate::connect(const QObject *sender,
                                 int signal_index, const QMetaObject *smeta,

                                 const QObject *receiver, int method_index,
                                 const QMetaObject *rmeta,
                                                        int type, int *types)
{
    QObject *s = const_cast<QObject *>(sender);
    QObject *r = const_cast<QObject *>(receiver);

    int method_offset = rmeta ? rmeta->methodOffset() : 0;
    QObjectPrivate::StaticMetaCallFunction callFunction =
        rmeta ? rmeta->d.static_metacall : 0;

    if (type & Qt::UniqueConnection) {
        QObjectConnectionListVector *connectionLists = QObjectPrivate::get(s)->connectionLists;
        if (connectionLists && connectionLists->count() > signal_index) {
            const QObjectPrivate::Connection *c2 =
                (*connectionLists)[signal_index].first;

            int method_index_absolute = method_index + method_offset;

            while (c2) {
                if (!c2->isSlotObject && c2->receiver == receiver && c2->method() == method_index_absolute)
                    return 0;
                c2 = c2->nextConnectionList;
            }
        }
        type &= Qt::UniqueConnection - 1;
    }

    QScopedPointer<QObjectPrivate::Connection> c(new QObjectPrivate::Connection);
    c->sender = s;
    c->signal_index = signal_index;
    c->receiver = r;
    c->method_relative = method_index;
    c->method_offset = method_offset;
    c->connectionType = type;
    c->isSlotObject = false;
    c->argumentTypes.store(types);
    c->nextConnectionList = 0;
    c->callFunction = callFunction;

    QObjectPrivate::get(s)->addConnection(signal_index, c.data());

    locker.unlock();
    QMetaMethod smethod = QMetaObjectPrivate::signal(smeta, signal_index);
    if (smethod.isValid())
        s->connectNotify(smethod);

    return c.take();
}

bool QMetaObject::disconnect(const QObject *sender, int signal_index,
                             const QObject *receiver, int method_index)
{
    const QMetaObject *smeta = sender->metaObject();
    signal_index = methodIndexToSignalIndex(&smeta, signal_index);
    return QMetaObjectPrivate::disconnect(sender, signal_index, smeta,
                                          receiver, method_index, 0);
}

/*!
    \internal

Disconnect a single signal connection.  If QMetaObject::connect() has been called
multiple times for the same sender, signal_index, receiver and method_index only
one of these connections will be removed.
 */
bool QMetaObject::disconnectOne(const QObject *sender, int signal_index,
                                const QObject *receiver, int method_index)
{
    const QMetaObject *smeta = sender->metaObject();
    signal_index = methodIndexToSignalIndex(&smeta, signal_index);
    return QMetaObjectPrivate::disconnect(sender, signal_index, smeta,
                                          receiver, method_index, 0,
                                          QMetaObjectPrivate::DisconnectOne);
}

/*!
    \internal
    Helper function to remove the connection from the senders list and setting the receivers to 0
 */
bool QMetaObjectPrivate::disconnectHelper(QObjectPrivate::Connection *c,
                                          const QObject *receiver, int method_index, void **slot,
                                          QMutex *senderMutex, DisconnectType disconnectType)
{
    bool success = false;
    while (c) {
        if (c->receiver
            && (receiver == 0 || (c->receiver == receiver
                           && (method_index < 0 || (!c->isSlotObject && c->method() == method_index))
                           && (slot == 0 || (c->isSlotObject && c->slotObj->compare(slot)))))) {
            bool needToUnlock = false;
            QMutex *receiverMutex = 0;
            if (c->receiver) {
                receiverMutex = signalSlotLock(c->receiver);
                // need to relock this receiver and sender in the correct order
                needToUnlock = QOrderedMutexLocker::relock(senderMutex, receiverMutex);
            }
            if (c->receiver) {
                *c->prev = c->next;
                if (c->next)
                    c->next->prev = c->prev;
            }

            if (needToUnlock)
                receiverMutex->unlock();

            c->receiver = 0;

            if (c->isSlotObject) {
                c->isSlotObject = false;
                senderMutex->unlock();
                c->slotObj->destroyIfLastRef();
                senderMutex->lock();
            }

            success = true;

            if (disconnectType == DisconnectOne)
                return success;
        }
        c = c->nextConnectionList;
    }
    return success;
}

/*!
    \internal
    Same as the QMetaObject::disconnect, but \a signal_index must be the result of QObjectPrivate::signalIndex
 */
bool QMetaObjectPrivate::disconnect(const QObject *sender,
                                    int signal_index, const QMetaObject *smeta,
                                    const QObject *receiver, int method_index, void **slot,
                                    DisconnectType disconnectType)
{
    if (!sender)
        return false;

    QObject *s = const_cast<QObject *>(sender);

    QMutex *senderMutex = signalSlotLock(sender);
    QMutexLocker locker(senderMutex);

    QObjectConnectionListVector *connectionLists = QObjectPrivate::get(s)->connectionLists;
    if (!connectionLists)
        return false;

    // prevent incoming connections changing the connectionLists while unlocked
    ++connectionLists->inUse;

    bool success = false;
    if (signal_index < 0) {
        // remove from all connection lists
        for (int sig_index = -1; sig_index < connectionLists->count(); ++sig_index) {
            QObjectPrivate::Connection *c =
                (*connectionLists)[sig_index].first;
            if (disconnectHelper(c, receiver, method_index, slot, senderMutex, disconnectType)) {
                success = true;
                connectionLists->dirty = true;
            }
        }
    } else if (signal_index < connectionLists->count()) {
        QObjectPrivate::Connection *c =
            (*connectionLists)[signal_index].first;
        if (disconnectHelper(c, receiver, method_index, slot, senderMutex, disconnectType)) {
            success = true;
            connectionLists->dirty = true;
        }
    }

    --connectionLists->inUse;
    Q_ASSERT(connectionLists->inUse >= 0);
    if (connectionLists->orphaned && !connectionLists->inUse)
        delete connectionLists;

    locker.unlock();
    if (success) {
        QMetaMethod smethod = QMetaObjectPrivate::signal(smeta, signal_index);
        if (smethod.isValid())
            s->disconnectNotify(smethod);
    }

    return success;
}

/*!
    \fn void QMetaObject::connectSlotsByName(QObject *object)

    Searches recursively for all child objects of the given \a object, and connects
    matching signals from them to slots of \a object that follow the following form:

    \snippet code/src_corelib_kernel_qobject.cpp 33

    Let's assume our object has a child object of type \c{QPushButton} with
    the \l{QObject::objectName}{object name} \c{button1}. The slot to catch the
    button's \c{clicked()} signal would be:

    \snippet code/src_corelib_kernel_qobject.cpp 34

    If \a object itself has a properly set object name, its own signals are also
    connected to its respective slots.

    \sa QObject::setObjectName()
 */
void QMetaObject::connectSlotsByName(QObject *o)
{
    if (!o)
        return;
    const QMetaObject *mo = o->metaObject();
    Q_ASSERT(mo);
    const QObjectList list = // list of all objects to look for matching signals including...
            o->findChildren<QObject *>(QString()) // all children of 'o'...
            << o; // and the object 'o' itself

    // for each method/slot of o ...
    for (int i = 0; i < mo->methodCount(); ++i) {
        const QByteArray slotSignature = mo->method(i).methodSignature();
        const char *slot = slotSignature.constData();
        Q_ASSERT(slot);

        // ...that starts with "on_", ...
        if (slot[0] != 'o' || slot[1] != 'n' || slot[2] != '_')
            continue;

        // ...we check each object in our list, ...
        bool foundIt = false;
        for(int j = 0; j < list.count(); ++j) {
            const QObject *co = list.at(j);
            const QByteArray coName = co->objectName().toLatin1();

            // ...discarding those whose objectName is not fitting the pattern "on_<objectName>_...", ...
            if (coName.isEmpty() || qstrncmp(slot + 3, coName.constData(), coName.size()) || slot[coName.size()+3] != '_')
                continue;

            const char *signal = slot + coName.size() + 4; // the 'signal' part of the slot name

            // ...for the presence of a matching signal "on_<objectName>_<signal>".
            const QMetaObject *smeta;
            int sigIndex = co->d_func()->signalIndex(signal, &smeta);
            if (sigIndex < 0) {
                // if no exactly fitting signal (name + complete parameter type list) could be found
                // look for just any signal with the correct name and at least the slot's parameter list.
                // Note: if more than one of thoses signals exist, the one that gets connected is
                // chosen 'at random' (order of declaration in source file)
                QList<QByteArray> compatibleSignals;
                const QMetaObject *smo = co->metaObject();
                int sigLen = qstrlen(signal) - 1; // ignore the trailing ')'
                for (int k = QMetaObjectPrivate::absoluteSignalCount(smo)-1; k >= 0; --k) {
                    const QMetaMethod method = QMetaObjectPrivate::signal(smo, k);
                    if (!qstrncmp(method.methodSignature().constData(), signal, sigLen)) {
                        smeta = method.enclosingMetaObject();
                        sigIndex = k;
                        compatibleSignals.prepend(method.methodSignature());
                    }
                }
                if (compatibleSignals.size() > 1)
                    qWarning() << "QMetaObject::connectSlotsByName: Connecting slot" << slot
                               << "with the first of the following compatible signals:" << compatibleSignals;
            }

            if (sigIndex < 0)
                continue;

            // we connect it...
            if (Connection(QMetaObjectPrivate::connect(co, sigIndex, smeta, o, i))) {
                foundIt = true;
                // ...and stop looking for further objects with the same name.
                // Note: the Designer will make sure each object name is unique in the above
                // 'list' but other code may create two child objects with the same name. In
                // this case one is chosen 'at random'.
                break;
            }
        }
        if (foundIt) {
            // we found our slot, now skip all overloads
            while (mo->method(i + 1).attributes() & QMetaMethod::Cloned)
                  ++i;
        } else if (!(mo->method(i).attributes() & QMetaMethod::Cloned)) {
            // check if the slot has the following signature: "on_..._...(..."
            int iParen = slotSignature.indexOf('(');
            int iLastUnderscore = slotSignature.lastIndexOf('_', iParen-1);
            if (iLastUnderscore > 3)
                qWarning("QMetaObject::connectSlotsByName: No matching signal for %s", slot);
        }
    }
}

/*!
    \internal

    \a signal must be in the signal index range (see QObjectPrivate::signalIndex()).
*/
static void queued_activate(QObject *sender, int signal, QObjectPrivate::Connection *c, void **argv,
                            QMutexLocker &locker)
{
    const int *argumentTypes = c->argumentTypes.load();
    if (!argumentTypes) {
        QMetaMethod m = QMetaObjectPrivate::signal(sender->metaObject(), signal);
        argumentTypes = queuedConnectionTypes(m.parameterTypes());
        if (!argumentTypes) // cannot queue arguments
            argumentTypes = &DIRECT_CONNECTION_ONLY;
        if (!c->argumentTypes.testAndSetOrdered(0, argumentTypes)) {
            if (argumentTypes != &DIRECT_CONNECTION_ONLY)
                delete [] argumentTypes;
            argumentTypes = c->argumentTypes.load();
        }
    }
    if (argumentTypes == &DIRECT_CONNECTION_ONLY) // cannot activate
        return;
    int nargs = 1; // include return type
    while (argumentTypes[nargs-1])
        ++nargs;
    int *types = (int *) malloc(nargs*sizeof(int));
    Q_CHECK_PTR(types);
    void **args = (void **) malloc(nargs*sizeof(void *));
    Q_CHECK_PTR(args);
    types[0] = 0; // return type
    args[0] = 0; // return value

    if (nargs > 1) {
        for (int n = 1; n < nargs; ++n)
            types[n] = argumentTypes[n-1];

        locker.unlock();
        for (int n = 1; n < nargs; ++n)
            args[n] = QMetaType::create(types[n], argv[n]);
        locker.relock();

        if (!c->receiver) {
            locker.unlock();
            // we have been disconnected while the mutex was unlocked
            for (int n = 1; n < nargs; ++n)
                QMetaType::destroy(types[n], args[n]);
            free(types);
            free(args);
            locker.relock();
            return;
        }
    }

    QMetaCallEvent *ev = c->isSlotObject ?
        new QMetaCallEvent(c->slotObj, sender, signal, nargs, types, args) :
        new QMetaCallEvent(c->method_offset, c->method_relative, c->callFunction, sender, signal, nargs, types, args);
    // 最终, 还是用到了 postEvent 函数.
    QCoreApplication::postEvent(c->receiver, ev);
}

/*!
    emit signal 最终, 会变为 QMetaObject::activate 的调用.
 */
void QMetaObject::activate(QObject *sender, const QMetaObject *m, int local_signal_index,
                           void **argv)
{
    activate(sender, QMetaObjectPrivate::signalOffset(m), local_signal_index, argv);
}

// emit 的实现方式.
void QMetaObject::activate(QObject *sender, int signalOffset, int local_signal_index, void **argv)
{
    int signal_index = signalOffset + local_signal_index;

    // 如果, sender->blockSig 了, 那么就不会触发后面的 connection 的回调.实现的原理在这里.
    if (sender->d_func()->blockSig)
        return;

    if (sender->d_func()->isDeclarativeSignalConnected(signal_index)
            && QAbstractDeclarativeData::signalEmitted) {
        QAbstractDeclarativeData::signalEmitted(sender->d_func()->declarativeData, sender,
                                                signal_index, argv);
    }

    if (!sender->d_func()->isSignalConnected(signal_index, /*checkDeclarative =*/ false)
        && !qt_signal_spy_callback_set.signal_begin_callback
        && !qt_signal_spy_callback_set.signal_end_callback) {
        // The possible declarative connection is done, and nothing else is connected, so:
        return;
    }

    void *empty_argv[] = { 0 };
    if (qt_signal_spy_callback_set.signal_begin_callback != 0) {
        qt_signal_spy_callback_set.signal_begin_callback(sender, signal_index,
                                                         argv ? argv : empty_argv);
    }

    {
    QMutexLocker locker(signalSlotLock(sender));
    struct ConnectionListsRef {
        QObjectConnectionListVector *connectionLists;
        ConnectionListsRef(QObjectConnectionListVector *connectionLists) : connectionLists(connectionLists)
        {
            if (connectionLists)
                ++connectionLists->inUse;
        }
        ~ConnectionListsRef()
        {
            if (!connectionLists)
                return;

            --connectionLists->inUse;
            Q_ASSERT(connectionLists->inUse >= 0);
            if (connectionLists->orphaned) {
                if (!connectionLists->inUse)
                    delete connectionLists;
            }
        }

        QObjectConnectionListVector *operator->() const { return connectionLists; }
    };

    ConnectionListsRef connectionLists = sender->d_func()->connectionLists;
    if (!connectionLists.connectionLists) {
        locker.unlock();
        if (qt_signal_spy_callback_set.signal_end_callback != 0)
            qt_signal_spy_callback_set.signal_end_callback(sender, signal_index);
        return;
    }


    const QObjectPrivate::ConnectionList *list;
    if (signal_index < connectionLists->count())
        list = &connectionLists->at(signal_index);
    else
        list = &connectionLists->allsignals;

    // currentThreadId 的获取, 是通过 QThread::currentThreadId 获取的, 也就是说, 发送信号的时候, 其实并不在乎 sender 的线程 Affinity, 只是在乎触发信号的操作是在哪个线程调用的. 如果和 receiver 的线程一样, 就可以直接被调用.
    Qt::HANDLE currentThreadId = QThread::currentThreadId();

    /*
     通过 sender 的 connectionlist, 找到对应的 receiver.
     */
    do {
        QObjectPrivate::Connection *c = list->first;
        if (!c) continue;
        // We need to check against last here to ensure that signals added
        // during the signal emission are not emitted in this emission.
        QObjectPrivate::Connection *last = list->last;

        do {
            if (!c->receiver)
                continue;
            QObject * const receiver = c->receiver;
            const bool receiverInSameThread = currentThreadId == receiver->d_func()->threadData->threadId.load();

            // 特殊的 connectionType 的处理.
            // 如果, 不在一个线程里面.
            if ((c->connectionType == Qt::AutoConnection && !receiverInSameThread)
                || (c->connectionType == Qt::QueuedConnection)) {
                queued_activate(sender, signal_index, c, argv ? argv : empty_argv, locker);
                continue;
            } else if (c->connectionType == Qt::BlockingQueuedConnection) {
                // 如果, 同步调用, 如果 slot 不返回的话这里会祖册.
                if (receiverInSameThread) {
                    qWarning("Qt: Dead lock detected while activating a BlockingQueuedConnection: "
                    "Sender is %s(%p), receiver is %s(%p)",
                    sender->metaObject()->className(), sender,
                    receiver->metaObject()->className(), receiver);
                }
                QSemaphore semaphore;
                QMetaCallEvent *ev = c->isSlotObject ?
                    new QMetaCallEvent(c->slotObj, sender, signal_index, 0, 0, argv ? argv : empty_argv, &semaphore) :
                    new QMetaCallEvent(c->method_offset, c->method_relative, c->callFunction, sender, signal_index, 0, 0, argv ? argv : empty_argv, &semaphore);
                QCoreApplication::postEvent(receiver, ev);
                locker.unlock();
                semaphore.acquire();
                locker.relock();
                continue;
            }

            QConnectionSenderSwitcher sw;

            if (receiverInSameThread) {
                sw.switchSender(receiver, sender, signal_index);
            }
            if (c->isSlotObject) {
                c->slotObj->ref();
                QScopedPointer<QtPrivate::QSlotObjectBase, QSlotObjectBaseDeleter> obj(c->slotObj);
                locker.unlock();
                // 调用信号触发函数
                obj->call(receiver, argv ? argv : empty_argv);

                // Make sure the slot object gets destroyed before the mutex is locked again, as the
                // destructor of the slot object might also lock a mutex from the signalSlotLock() mutex pool,
                // and that would deadlock if the pool happens to return the same mutex.
                obj.reset();

                locker.relock();
            } else if (c->callFunction && c->method_offset <= receiver->metaObject()->methodOffset()) {
                //we compare the vtable to make sure we are not in the destructor of the object.
                const int methodIndex = c->method();
                const int method_relative = c->method_relative;
                const auto callFunction = c->callFunction;
                locker.unlock();
                if (qt_signal_spy_callback_set.slot_begin_callback != 0)
                    qt_signal_spy_callback_set.slot_begin_callback(receiver, methodIndex, argv ? argv : empty_argv);
                // 调用信号触发函数
                callFunction(receiver, QMetaObject::InvokeMetaMethod, method_relative, argv ? argv : empty_argv);

                if (qt_signal_spy_callback_set.slot_end_callback != 0)
                    qt_signal_spy_callback_set.slot_end_callback(receiver, methodIndex);
                locker.relock();
            } else {
                const int method = c->method_relative + c->method_offset;
                locker.unlock();

                if (qt_signal_spy_callback_set.slot_begin_callback != 0) {
                    qt_signal_spy_callback_set.slot_begin_callback(receiver,
                                                                method,
                                                                argv ? argv : empty_argv);
                }

                metacall(receiver, QMetaObject::InvokeMetaMethod, method, argv ? argv : empty_argv);

                if (qt_signal_spy_callback_set.slot_end_callback != 0)
                    qt_signal_spy_callback_set.slot_end_callback(receiver, method);

                locker.relock();
            }

            if (connectionLists->orphaned)
                break;
        } while (c != last && (c = c->nextConnectionList) != 0);

        if (connectionLists->orphaned)
            break;
    } while (list != &connectionLists->allsignals &&
        //start over for all signals;
        ((list = &connectionLists->allsignals), true));
    }

    if (qt_signal_spy_callback_set.signal_end_callback != 0)
        qt_signal_spy_callback_set.signal_end_callback(sender, signal_index);

}

/*!
    \internal
   signal_index comes from indexOfMethod()
*/
void QMetaObject::activate(QObject *sender, int signal_index, void **argv)
{
    const QMetaObject *mo = sender->metaObject();
    while (mo->methodOffset() > signal_index)
        mo = mo->superClass();
    activate(sender, mo, signal_index - mo->methodOffset(), argv);
}

/*!
    \internal
    Returns the signal index used in the internal connectionLists vector.

    It is different from QMetaObject::indexOfSignal():  indexOfSignal is the same as indexOfMethod
    while QObjectPrivate::signalIndex is smaller because it doesn't give index to slots.

    If \a meta is not 0, it is set to the meta-object where the signal was found.
*/
int QObjectPrivate::signalIndex(const char *signalName,
                                const QMetaObject **meta) const
{
    Q_Q(const QObject);
    const QMetaObject *base = q->metaObject();
    Q_ASSERT(QMetaObjectPrivate::get(base)->revision >= 7);
    QArgumentTypeArray types;
    QByteArray name = QMetaObjectPrivate::decodeMethodSignature(signalName, types);
    int relative_index = QMetaObjectPrivate::indexOfSignalRelative(
            &base, name, types.size(), types.constData());
    if (relative_index < 0)
        return relative_index;
    relative_index = QMetaObjectPrivate::originalClone(base, relative_index);
    if (meta)
        *meta = base;
    return relative_index + QMetaObjectPrivate::signalOffset(base);
}

/*****************************************************************************
  Properties
 *****************************************************************************/

#ifndef QT_NO_PROPERTIES

bool QObject::setProperty(const char *name, const QVariant &value)
{
    Q_D(QObject);
    const QMetaObject* meta = metaObject();
    if (!name || !meta)
        return false;

    int id = meta->indexOfProperty(name);
    if (id < 0) { // 如果是动态属性, 那么就通过 extraData 来进行处理. 这里, 为什么要用 propertyNames, propertyValues 两个容器来进行处理, 代码很差.
        if (!d->extraData)
            d->extraData = new QObjectPrivate::ExtraData;

        const int idx = d->extraData->propertyNames.indexOf(name);

        if (!value.isValid()) { // 如果 QVariant isUnValid, 那么其实就是应该进行删除操作.
            if (idx == -1)
                return false;
            d->extraData->propertyNames.removeAt(idx);
            d->extraData->propertyValues.removeAt(idx);
        } else {
            if (idx == -1) {
                d->extraData->propertyNames.append(name);
                d->extraData->propertyValues.append(value);
            } else {
                if (value == d->extraData->propertyValues.at(idx))
                    return false;
                d->extraData->propertyValues[idx] = value;
            }
        }

        // 这里, 主动的调用了 QCoreApplication::sendEvent, 进行了事件的传递处理.
        QDynamicPropertyChangeEvent ev(name);
        QCoreApplication::sendEvent(this, &ev);

        return false;
    }
    // 如果, 在元信息系统里面, 就使用 QMetaProperty 来进行处理.
    QMetaProperty p = meta->property(id);
    return p.write(this, value);
}


QVariant QObject::property(const char *name) const
{
    Q_D(const QObject);
    const QMetaObject* meta = metaObject();
    if (!name || !meta)
        return QVariant();
    // 因为返回的值, 是一个 QVariant, 所以一定要有一个值, 调用者应该检测返回值 isValid 来判断是否 property 调用合理.

    int id = meta->indexOfProperty(name);
    if (id < 0) {
        // 如果 id 是一个非法值, 就是动态属性, 直接从 QObject 的容器中获取了.
        if (!d->extraData)
            return QVariant();
        const int i = d->extraData->propertyNames.indexOf(name);
        return d->extraData->propertyValues.value(i);
    }

    // 否则, 要走 metaobject 的属性获取机制.
    QMetaProperty p = meta->property(id);
    return p.read(this);
}

QList<QByteArray> QObject::dynamicPropertyNames() const
{
    Q_D(const QObject);
    if (d->extraData)
        return d->extraData->propertyNames;
    return QList<QByteArray>();
}

#endif // QT_NO_PROPERTIES


static void dumpRecursive(int level, const QObject *object)
{
    if (object) {
        QByteArray buf;
        buf.fill(' ', level / 2 * 8);
        if (level % 2)
            buf += "    ";
        QString name = object->objectName();
        QString flags = QLatin1String("");
#if 0
#endif
        qDebug("%s%s::%s %s", (const char*)buf, object->metaObject()->className(), name.toLocal8Bit().data(),
               flags.toLatin1().data());
        QObjectList children = object->children();
        if (!children.isEmpty()) {
            for (int i = 0; i < children.size(); ++i)
                dumpRecursive(level+1, children.at(i));
        }
    }
}

void QObject::dumpObjectTree()
{
    const_cast<const QObject *>(this)->dumpObjectTree();
}

/*!
    Dumps a tree of children to the debug output.

    \note before Qt 5.9, this function was not const.

    \sa dumpObjectInfo()
*/

void QObject::dumpObjectTree() const
{
    dumpRecursive(0, this);
}


void QObject::dumpObjectInfo()
{
    const_cast<const QObject *>(this)->dumpObjectInfo();
}

void QObject::dumpObjectInfo() const
{
    qDebug("OBJECT %s::%s", metaObject()->className(),
           objectName().isEmpty() ? "unnamed" : objectName().toLocal8Bit().data());

    Q_D(const QObject);
    QMutexLocker locker(signalSlotLock(this));

    // first, look for connections where this object is the sender
    qDebug("  SIGNALS OUT");

    if (d->connectionLists) {
        for (int signal_index = 0; signal_index < d->connectionLists->count(); ++signal_index) {
            const QMetaMethod signal = QMetaObjectPrivate::signal(metaObject(), signal_index);
            qDebug("        signal: %s", signal.methodSignature().constData());

            // receivers
            const QObjectPrivate::Connection *c =
                d->connectionLists->at(signal_index).first;
            while (c) {
                if (!c->receiver) {
                    qDebug("          <Disconnected receiver>");
                    c = c->nextConnectionList;
                    continue;
                }
                if (c->isSlotObject) {
                    qDebug("          <functor or function pointer>");
                    c = c->nextConnectionList;
                    continue;
                }
                const QMetaObject *receiverMetaObject = c->receiver->metaObject();
                const QMetaMethod method = receiverMetaObject->method(c->method());
                qDebug("          --> %s::%s %s",
                       receiverMetaObject->className(),
                       c->receiver->objectName().isEmpty() ? "unnamed" : qPrintable(c->receiver->objectName()),
                       method.methodSignature().constData());
                c = c->nextConnectionList;
            }
        }
    } else {
        qDebug( "        <None>" );
    }

    // now look for connections where this object is the receiver
    qDebug("  SIGNALS IN");

    if (d->senders) {
        for (QObjectPrivate::Connection *s = d->senders; s; s = s->next) {
            QByteArray slotName = QByteArrayLiteral("<unknown>");
            if (!s->isSlotObject) {
                const QMetaMethod slot = metaObject()->method(s->method());
                slotName = slot.methodSignature();
            }
            qDebug("          <-- %s::%s %s",
                   s->sender->metaObject()->className(),
                   s->sender->objectName().isEmpty() ? "unnamed" : qPrintable(s->sender->objectName()),
                   slotName.constData());
        }
    } else {
        qDebug("        <None>");
    }
}

#ifndef QT_NO_USERDATA
/*!
    \internal
 */
uint QObject::registerUserData()
{
    static int user_data_registration = 0;
    return user_data_registration++;
}

/*!
    \internal
 */
QObjectUserData::~QObjectUserData()
{
}

/*!
    \internal
 */
void QObject::setUserData(uint id, QObjectUserData* data)
{
    Q_D(QObject);
    if (!d->extraData)
        d->extraData = new QObjectPrivate::ExtraData;

    if (d->extraData->userData.size() <= (int) id)
        d->extraData->userData.resize((int) id + 1);
    d->extraData->userData[id] = data;
}

/*!
    \internal
 */
QObjectUserData* QObject::userData(uint id) const
{
    Q_D(const QObject);
    if (!d->extraData)
        return 0;
    if ((int)id < d->extraData->userData.size())
        return d->extraData->userData.at(id);
    return 0;
}

#endif // QT_NO_USERDATA

void qDeleteInEventHandler(QObject *o)
{
    delete o;
}

// Lambda 表达式版本的 Connect 函数.
QMetaObject::Connection QObject::connectImpl(const QObject *sender, void **signal,
                                             const QObject *receiver, void **slot,
                                             QtPrivate::QSlotObjectBase *slotObj, Qt::ConnectionType type,
                                             const int *types, const QMetaObject *senderMetaObject)
{
    if (!signal) {

        return QMetaObject::Connection();
    }

    int signal_index = -1;
    void *args[] = { &signal_index, signal };
    for (; senderMetaObject && signal_index < 0; senderMetaObject = senderMetaObject->superClass()) {
        senderMetaObject->static_metacall(QMetaObject::IndexOfMethod, 0, args);
        if (signal_index >= 0 && signal_index < QMetaObjectPrivate::get(senderMetaObject)->signalCount)
            break;
    }
    if (!senderMetaObject) {
        qWarning("QObject::connect: signal not found in %s", sender->metaObject()->className());
        slotObj->destroyIfLastRef();
        return QMetaObject::Connection(0);
    }
    signal_index += QMetaObjectPrivate::signalOffset(senderMetaObject);
    return QObjectPrivate::connectImpl(sender, signal_index, receiver, slot, slotObj, type, types, senderMetaObject);
}

QMetaObject::Connection QObjectPrivate::connectImpl(const QObject *sender, int signal_index,
                                             const QObject *receiver, void **slot,
                                             QtPrivate::QSlotObjectBase *slotObj, Qt::ConnectionType type,
                                             const int *types, const QMetaObject *senderMetaObject)
{
    if (!sender || !receiver || !slotObj || !senderMetaObject) {
        qWarning("QObject::connect: invalid null parameter");
        if (slotObj)
            slotObj->destroyIfLastRef();
        return QMetaObject::Connection();
    }

    QObject *s = const_cast<QObject *>(sender);
    QObject *r = const_cast<QObject *>(receiver);

    if (type & Qt::UniqueConnection && slot) {
        QObjectConnectionListVector *connectionLists = QObjectPrivate::get(s)->connectionLists;
        if (connectionLists && connectionLists->count() > signal_index) {
            const QObjectPrivate::Connection *c2 =
                (*connectionLists)[signal_index].first;

            while (c2) {
                if (c2->receiver == receiver && c2->isSlotObject && c2->slotObj->compare(slot)) {
                    slotObj->destroyIfLastRef();
                    return QMetaObject::Connection();
                }
                c2 = c2->nextConnectionList;
            }
        }
        type = static_cast<Qt::ConnectionType>(type ^ Qt::UniqueConnection);
    }

    QScopedPointer<QObjectPrivate::Connection> c(new QObjectPrivate::Connection);
    c->sender = s;
    c->signal_index = signal_index;
    c->receiver = r;
    c->slotObj = slotObj; // 在这里, 这是一个共用体, 或者存储 Slot 的字符串, 或者存储 lambda 表达式对象.
    c->connectionType = type;
    c->isSlotObject = true;
    if (types) {
        c->argumentTypes.store(types);
        c->ownArgumentTypes = false;
    }

    QObjectPrivate::get(s)->addConnection(signal_index, c.data());
    QMetaObject::Connection ret(c.take());
    locker.unlock();

    QMetaMethod method = QMetaObjectPrivate::signal(senderMetaObject, signal_index);
    Q_ASSERT(method.isValid());
    s->connectNotify(method);

    return ret;
}

bool QObject::disconnect(const QMetaObject::Connection &connection)
{
    QObjectPrivate::Connection *c = static_cast<QObjectPrivate::Connection *>(connection.d_ptr);

    if (!c || !c->receiver)
        return false;

    QMutex *senderMutex = signalSlotLock(c->sender);
    QMutex *receiverMutex = signalSlotLock(c->receiver);

    {
        QOrderedMutexLocker locker(senderMutex, receiverMutex);

        QObjectConnectionListVector *connectionLists = QObjectPrivate::get(c->sender)->connectionLists;
        Q_ASSERT(connectionLists);
        connectionLists->dirty = true;

        *c->prev = c->next;
        if (c->next)
            c->next->prev = c->prev;
        c->receiver = 0;
    }

    // destroy the QSlotObject, if possible
    if (c->isSlotObject) {
        c->slotObj->destroyIfLastRef();
        c->isSlotObject = false;
    }

    c->sender->disconnectNotify(QMetaObjectPrivate::signal(c->sender->metaObject(),
                                                           c->signal_index));

    const_cast<QMetaObject::Connection &>(connection).d_ptr = 0;
    c->deref(); // has been removed from the QMetaObject::Connection object

    return true;
}


bool QObject::disconnectImpl(const QObject *sender, void **signal, const QObject *receiver, void **slot, const QMetaObject *senderMetaObject)
{
    if (sender == 0 || (receiver == 0 && slot != 0)) {
        qWarning("QObject::disconnect: Unexpected null parameter");
        return false;
    }

    int signal_index = -1;
    if (signal) {
        void *args[] = { &signal_index, signal };
        for (; senderMetaObject && signal_index < 0; senderMetaObject = senderMetaObject->superClass()) {
            senderMetaObject->static_metacall(QMetaObject::IndexOfMethod, 0, args);
            if (signal_index >= 0 && signal_index < QMetaObjectPrivate::get(senderMetaObject)->signalCount)
                break;
        }
        if (!senderMetaObject) {
            return QMetaObject::Connection(0);
        }
        signal_index += QMetaObjectPrivate::signalOffset(senderMetaObject);
    }

    return QMetaObjectPrivate::disconnect(sender, signal_index, senderMetaObject, receiver, -1, slot);
}

QMetaObject::Connection QObjectPrivate::connect(const QObject *sender, int signal_index, QtPrivate::QSlotObjectBase *slotObj, Qt::ConnectionType type)
{
    if (!sender) {
        qWarning("QObject::connect: invalid null parameter");
        if (slotObj)
            slotObj->destroyIfLastRef();
        return QMetaObject::Connection();
    }
    const QMetaObject *senderMetaObject = sender->metaObject();
    signal_index = methodIndexToSignalIndex(&senderMetaObject, signal_index);

    return QObjectPrivate::connectImpl(sender, signal_index, sender, /*slot*/0, slotObj, type, /*types*/0, senderMetaObject);
}

bool QObjectPrivate::disconnect(const QObject *sender, int signal_index, void **slot)
{
    const QMetaObject *senderMetaObject = sender->metaObject();
    signal_index = methodIndexToSignalIndex(&senderMetaObject, signal_index);

    return QMetaObjectPrivate::disconnect(sender, signal_index, senderMetaObject, sender, -1, slot);
}

QMetaObject::Connection::Connection(const QMetaObject::Connection &other) : d_ptr(other.d_ptr)
{
    if (d_ptr)
        static_cast<QObjectPrivate::Connection *>(d_ptr)->ref();
}

QMetaObject::Connection& QMetaObject::Connection::operator=(const QMetaObject::Connection& other)
{
    if (other.d_ptr != d_ptr) {
        if (d_ptr)
            static_cast<QObjectPrivate::Connection *>(d_ptr)->deref();
        d_ptr = other.d_ptr;
        if (other.d_ptr)
            static_cast<QObjectPrivate::Connection *>(other.d_ptr)->ref();
    }
    return *this;
}


QMetaObject::Connection::Connection() : d_ptr(0) {}

QMetaObject::Connection::~Connection()
{
    if (d_ptr)
        static_cast<QObjectPrivate::Connection *>(d_ptr)->deref();
}

bool QMetaObject::Connection::isConnected_helper() const
{
    Q_ASSERT(d_ptr);    // we're only called from operator RestrictedBool() const
    QObjectPrivate::Connection *c = static_cast<QObjectPrivate::Connection *>(d_ptr);

    return c->receiver;
}


QT_END_NAMESPACE

// 在每个 Cpp 文件最后, 增加 Moc 版本的 cpp 文件.
#include "moc_qnamespace.cpp"
#include "moc_qobject.cpp"
