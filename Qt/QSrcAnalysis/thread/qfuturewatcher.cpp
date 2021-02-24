#include "qfuturewatcher.h"

#ifndef QT_NO_QFUTURE

#include "qfuturewatcher_p.h"

#include <QtCore/qcoreevent.h>
#include <QtCore/qcoreapplication.h>
#include <QtCore/qmetaobject.h>
#include <QtCore/qthread.h>

QT_BEGIN_NAMESPACE

QFutureWatcherBase::QFutureWatcherBase(QObject *parent)
    :QObject(*new QFutureWatcherBasePrivate, parent)
{ }

void QFutureWatcherBase::cancel()
{
    futureInterface().cancel();
}

void QFutureWatcherBase::setPaused(bool paused)
{
    futureInterface().setPaused(paused);
}


void QFutureWatcherBase::pause()
{
    futureInterface().setPaused(true);
}

void QFutureWatcherBase::resume()
{
    futureInterface().setPaused(false);
}

void QFutureWatcherBase::togglePaused()
{
    futureInterface().togglePaused();
}

int QFutureWatcherBase::progressValue() const
{
    return futureInterface().progressValue();
}

int QFutureWatcherBase::progressMinimum() const
{
    return futureInterface().progressMinimum();
}

int QFutureWatcherBase::progressMaximum() const
{
    return futureInterface().progressMaximum();
}

QString QFutureWatcherBase::progressText() const
{
    return futureInterface().progressText();
}

bool QFutureWatcherBase::isStarted() const
{
    return futureInterface().queryState(QFutureInterfaceBase::Started);
}

bool QFutureWatcherBase::isFinished() const
{
    Q_D(const QFutureWatcherBase);
    return d->finished;
}

bool QFutureWatcherBase::isRunning() const
{
    return futureInterface().queryState(QFutureInterfaceBase::Running);
}

bool QFutureWatcherBase::isCanceled() const
{
    return futureInterface().queryState(QFutureInterfaceBase::Canceled);
}

bool QFutureWatcherBase::isPaused() const
{
    return futureInterface().queryState(QFutureInterfaceBase::Paused);
}

void QFutureWatcherBase::waitForFinished()
{
    futureInterface().waitForFinished();
}

bool QFutureWatcherBase::event(QEvent *event)
{
    Q_D(QFutureWatcherBase);
    if (event->type() == QEvent::FutureCallOut) {
        QFutureCallOutEvent *callOutEvent = static_cast<QFutureCallOutEvent *>(event);

        if (futureInterface().isPaused()) {
            d->pendingCallOutEvents.append(callOutEvent->clone());
            return true;
        }

        if (callOutEvent->callOutType == QFutureCallOutEvent::Resumed
            && !d->pendingCallOutEvents.isEmpty()) {
            // send the resume
            d->sendCallOutEvent(callOutEvent);

            // next send all pending call outs
            for (int i = 0; i < d->pendingCallOutEvents.count(); ++i)
                d->sendCallOutEvent(d->pendingCallOutEvents.at(i));
            qDeleteAll(d->pendingCallOutEvents);
            d->pendingCallOutEvents.clear();
        } else {
            d->sendCallOutEvent(callOutEvent);
        }
        return true;
    }
    return QObject::event(event);
}

/*! \fn void QFutureWatcher::setPendingResultsLimit(int limit)

    The setPendingResultsLimit() provides throttling control. When the number
    of pending resultReadyAt() or resultsReadyAt() signals exceeds the
    \a limit, the computation represented by the future will be throttled
    automatically. The computation will resume once the number of pending
    signals drops below the \a limit.
*/
void QFutureWatcherBase::setPendingResultsLimit(int limit)
{
    Q_D(QFutureWatcherBase);
    d->maximumPendingResultsReady = limit;
}

void QFutureWatcherBase::connectNotify(const QMetaMethod &signal)
{
    Q_D(QFutureWatcherBase);
    static const QMetaMethod resultReadyAtSignal = QMetaMethod::fromSignal(&QFutureWatcherBase::resultReadyAt);
    if (signal == resultReadyAtSignal)
        d->resultAtConnected.ref();
#ifndef QT_NO_DEBUG
    static const QMetaMethod finishedSignal = QMetaMethod::fromSignal(&QFutureWatcherBase::finished);
    if (signal == finishedSignal) {
        if (futureInterface().isRunning()) {
            //connections should be established before calling stFuture to avoid race.
            // (The future could finish before the connection is made.)
            qWarning("QFutureWatcher::connect: connecting after calling setFuture() is likely to produce race");
        }
    }
#endif
}

void QFutureWatcherBase::disconnectNotify(const QMetaMethod &signal)
{
    Q_D(QFutureWatcherBase);
    static const QMetaMethod resultReadyAtSignal = QMetaMethod::fromSignal(&QFutureWatcherBase::resultReadyAt);
    if (signal == resultReadyAtSignal)
        d->resultAtConnected.deref();
}

/*!
    \internal
*/
QFutureWatcherBasePrivate::QFutureWatcherBasePrivate()
    : maximumPendingResultsReady(QThread::idealThreadCount() * 2),
      resultAtConnected(0),
      finished(true) /* the initial m_future is a canceledResult(), with Finished set */
{ }

/*!
    \internal
*/
void QFutureWatcherBase::connectOutputInterface()
{
    futureInterface().d->connectOutputInterface(d_func());
}

/*!
    \internal
*/
void QFutureWatcherBase::disconnectOutputInterface(bool pendingAssignment)
{
    if (pendingAssignment) {
        Q_D(QFutureWatcherBase);
        d->pendingResultsReady.store(0);
        qDeleteAll(d->pendingCallOutEvents);
        d->pendingCallOutEvents.clear();
        d->finished = false; /* May soon be amended, during connectOutputInterface() */
    }
    futureInterface().d->disconnectOutputInterface(d_func());
}

void QFutureWatcherBasePrivate::postCallOutEvent(const QFutureCallOutEvent &callOutEvent)
{
    Q_Q(QFutureWatcherBase);

    if (callOutEvent.callOutType == QFutureCallOutEvent::ResultsReady) {
        if (pendingResultsReady.fetchAndAddRelaxed(1) >= maximumPendingResultsReady)
            q->futureInterface().d->internal_setThrottled(true);
    }

    QCoreApplication::postEvent(q, callOutEvent.clone());
}

void QFutureWatcherBasePrivate::callOutInterfaceDisconnected()
{
    QCoreApplication::removePostedEvents(q_func(), QEvent::FutureCallOut);
}

// Watcher 接受 Future 的各个事件, 然后转化为新发发射出去.
void QFutureWatcherBasePrivate::sendCallOutEvent(QFutureCallOutEvent *event)
{
    Q_Q(QFutureWatcherBase);

    switch (event->callOutType) {
        case QFutureCallOutEvent::Started:
            emit q->started();
        break;
        case QFutureCallOutEvent::Finished:
            finished = true;
            emit q->finished();
        break;
        case QFutureCallOutEvent::Canceled:
            pendingResultsReady.store(0);
            emit q->canceled();
        break;
        case QFutureCallOutEvent::Paused:
            if (q->futureInterface().isCanceled())
                break;
            emit q->paused();
        break;
        case QFutureCallOutEvent::Resumed:
            if (q->futureInterface().isCanceled())
                break;
            emit q->resumed();
        break;
        case QFutureCallOutEvent::ResultsReady: {
            if (q->futureInterface().isCanceled())
                break;
            if (pendingResultsReady.fetchAndAddRelaxed(-1) <= maximumPendingResultsReady)
                q->futureInterface().setThrottled(false);

            const int beginIndex = event->index1;
            const int endIndex = event->index2;

            emit q->resultsReadyAt(beginIndex, endIndex);

            if (resultAtConnected.load() <= 0)
                break;

            for (int i = beginIndex; i < endIndex; ++i)
                emit q->resultReadyAt(i);

        } break;
        case QFutureCallOutEvent::Progress:
            if (q->futureInterface().isCanceled())
                break;

            emit q->progressValueChanged(event->index1);
            if (!event->text.isNull()) // ###
                q->progressTextChanged(event->text);
        break;
        case QFutureCallOutEvent::ProgressRange:
            emit q->progressRangeChanged(event->index1, event->index2);
        break;
        default: break;
    }
}

QT_END_NAMESPACE

#include "moc_qfuturewatcher.cpp"

#endif // QT_NO_QFUTURE
