/****************************************************************************
**
** Copyright (C) 2016 The Qt Company Ltd.
** Copyright (C) 2016 Intel Corporation.
** Contact: https://www.qt.io/licensing/
**
** This file is part of the QtCore module of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:LGPL$
** Commercial License Usage
** Licensees holding valid commercial Qt licenses may use this file in
** accordance with the commercial license agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and The Qt Company. For licensing terms
** and conditions see https://www.qt.io/terms-conditions. For further
** information use the contact form at https://www.qt.io/contact-us.
**
** GNU Lesser General Public License Usage
** Alternatively, this file may be used under the terms of the GNU Lesser
** General Public License version 3 as published by the Free Software
** Foundation and appearing in the file LICENSE.LGPL3 included in the
** packaging of this file. Please review the following information to
** ensure the GNU Lesser General Public License version 3 requirements
** will be met: https://www.gnu.org/licenses/lgpl-3.0.html.
**
** GNU General Public License Usage
** Alternatively, this file may be used under the terms of the GNU
** General Public License version 2.0 or (at your option) the GNU General
** Public license version 3 or any later version approved by the KDE Free
** Qt Foundation. The licenses are as published by the Free Software
** Foundation and appearing in the file LICENSE.GPL2 and LICENSE.GPL3
** included in the packaging of this file. Please review the following
** information to ensure the GNU General Public License requirements will
** be met: https://www.gnu.org/licenses/gpl-2.0.html and
** https://www.gnu.org/licenses/gpl-3.0.html.
**
** $QT_END_LICENSE$
**
****************************************************************************/

#include "qsharedpointer.h"

// to be sure we aren't causing a namespace clash:
#include "qshareddata.h"

#include <qset.h>
#include <qmutex.h>

#if !defined(QT_NO_QOBJECT)

QT_BEGIN_NAMESPACE

/*!
    \internal
    This function is called for a just-created QObject \a obj, to enable
    the use of QSharedPointer and QWeakPointer in the future.
 */
void QtSharedPointer::ExternalRefCountData::setQObjectShared(const QObject *, bool)
{}

/*!
    \internal
    This function is called when a QSharedPointer is created from a QWeakPointer

    We check that the QWeakPointer was really created from a QSharedPointer, and
    not from a QObject.
*/
void QtSharedPointer::ExternalRefCountData::checkQObjectShared(const QObject *)
{
    if (strongref.load() < 0)
        qWarning("QSharedPointer: cannot create a QSharedPointer from a QObject-tracking QWeakPointer");
}

QtSharedPointer::ExternalRefCountData *QtSharedPointer::ExternalRefCountData::getAndRef(const QObject *obj)
{
    QObjectPrivate *d = QObjectPrivate::get(const_cast<QObject *>(obj));

    ExternalRefCountData *that = d->sharedRefcount.load();
    if (that) {
        that->weakref.ref();
        return that;
    }

    // we can create the refcount data because it doesn't exist
    ExternalRefCountData *x = new ExternalRefCountData(Qt::Uninitialized);
    x->strongref.store(-1); // 这里, 与其说是存储的 -1, 不如说是存储的 Int_max. 因为, weakPointer 判断强指针的方式是是否等于零, 而不是小于零.
    x->weakref.store(2);  // the QWeakPointer that called us plus the QObject itself

    ExternalRefCountData *ret;
    if (d->sharedRefcount.testAndSetOrdered(nullptr, x, ret)) {     // ought to be release+acquire; this is acq_rel+acquire
        ret = x;
    } else {
        // ~ExternalRefCountData has a Q_ASSERT, so we use this trick to
        // only execute this if Q_ASSERTs are enabled
        Q_ASSERT((x->weakref.store(0), true));
        delete x;
        ret->weakref.ref();
    }
    return ret;
}

/**
    \internal
    Returns a QSharedPointer<QObject> if the variant contains
    a QSharedPointer<T> where T inherits QObject. Otherwise the behaviour is undefined.
*/
QSharedPointer<QObject> QtSharedPointer::sharedPointerFromVariant_internal(const QVariant &variant)
{
    Q_ASSERT(QMetaType::typeFlags(variant.userType()) & QMetaType::SharedPointerToQObject);
    return *reinterpret_cast<const QSharedPointer<QObject>*>(variant.constData());
}

/**
    \internal
    Returns a QWeakPointer<QObject> if the variant contains
    a QWeakPointer<T> where T inherits QObject. Otherwise the behaviour is undefined.
*/
QWeakPointer<QObject> QtSharedPointer::weakPointerFromVariant_internal(const QVariant &variant)
{
    Q_ASSERT(QMetaType::typeFlags(variant.userType()) & QMetaType::WeakPointerToQObject || QMetaType::typeFlags(variant.userType()) & QMetaType::TrackingPointerToQObject);
    return *reinterpret_cast<const QWeakPointer<QObject>*>(variant.constData());
}

QT_END_NAMESPACE

#endif


namespace {
    QT_USE_NAMESPACE
    struct Data {
        const volatile void *pointer;
#  ifdef BACKTRACE_SUPPORTED
        QByteArray backtrace;
#  endif
    };

    class KnownPointers
    {
    public:
        QMutex mutex;
        QHash<const void *, Data> dPointers;
        QHash<const volatile void *, const void *> dataPointers;
    };
}

Q_GLOBAL_STATIC(KnownPointers, knownPointers)

QT_BEGIN_NAMESPACE

namespace QtSharedPointer {
    Q_AUTOTEST_EXPORT void internalSafetyCheckCleanCheck();
}

/*!
    \internal
*/
void QtSharedPointer::internalSafetyCheckAdd(const void *d_ptr, const volatile void *ptr)
{
    KnownPointers *const kp = knownPointers();
    if (!kp)
        return;                 // end-game: the application is being destroyed already

    QMutexLocker lock(&kp->mutex);
    Q_ASSERT(!kp->dPointers.contains(d_ptr));

    //qDebug("Adding d=%p value=%p", d_ptr, ptr);

    const void *other_d_ptr = kp->dataPointers.value(ptr, 0);
    if (Q_UNLIKELY(other_d_ptr)) {
#  ifdef BACKTRACE_SUPPORTED
        printBacktrace(knownPointers()->dPointers.value(other_d_ptr).backtrace);
#  endif
        qFatal("QSharedPointer: internal self-check failed: pointer %p was already tracked "
               "by another QSharedPointer object %p", ptr, other_d_ptr);
    }

    Data data;
    data.pointer = ptr;
#  ifdef BACKTRACE_SUPPORTED
    data.backtrace = saveBacktrace();
#  endif

    kp->dPointers.insert(d_ptr, data);
    kp->dataPointers.insert(ptr, d_ptr);
    Q_ASSERT(kp->dPointers.size() == kp->dataPointers.size());
}

/*!
    \internal
*/
void QtSharedPointer::internalSafetyCheckRemove(const void *d_ptr)
{
    KnownPointers *const kp = knownPointers();
    if (!kp)
        return;                 // end-game: the application is being destroyed already

    QMutexLocker lock(&kp->mutex);

    const auto it = kp->dPointers.constFind(d_ptr);
    if (Q_UNLIKELY(it == kp->dPointers.cend())) {
        qFatal("QSharedPointer: internal self-check inconsistency: pointer %p was not tracked. "
               "To use QT_SHAREDPOINTER_TRACK_POINTERS, you have to enable it throughout "
               "in your code.", d_ptr);
    }

    const auto it2 = kp->dataPointers.constFind(it->pointer);
    Q_ASSERT(it2 != kp->dataPointers.cend());

    //qDebug("Removing d=%p value=%p", d_ptr, it->pointer);

    // remove entries
    kp->dataPointers.erase(it2);
    kp->dPointers.erase(it);
    Q_ASSERT(kp->dPointers.size() == kp->dataPointers.size());
}

/*!
    \internal
    Called by the QSharedPointer autotest
*/
void QtSharedPointer::internalSafetyCheckCleanCheck()
{
#  ifdef QT_BUILD_INTERNAL
    KnownPointers *const kp = knownPointers();
    Q_ASSERT_X(kp, "internalSafetyCheckSelfCheck()", "Called after global statics deletion!");

    if (Q_UNLIKELY(kp->dPointers.size() != kp->dataPointers.size()))
        qFatal("Internal consistency error: the number of pointers is not equal!");

    if (Q_UNLIKELY(!kp->dPointers.isEmpty()))
        qFatal("Pointer cleaning failed: %d entries remaining", kp->dPointers.size());
#  endif
}

QT_END_NAMESPACE
