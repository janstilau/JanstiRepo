/****************************************************************************
**
** Copyright (C) 2016 The Qt Company Ltd.
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

#include "qelapsedtimer.h"
#include "qdeadlinetimer.h"
#include "qdatetime.h"

QT_BEGIN_NAMESPACE

QElapsedTimer::ClockType QElapsedTimer::clockType() Q_DECL_NOTHROW
{
    return SystemTime;
}

bool QElapsedTimer::isMonotonic() Q_DECL_NOTHROW
{
    return false;
}

// start 里面, 调用 restart. restart 有着更加强大的功能, 本身有着重置的功能.
// start 通过调用一个更加强大的功能, 舍弃其中的某些效果, 来实现自己的含义.
void QElapsedTimer::start() Q_DECL_NOTHROW
{
    restart();
}

qint64 QElapsedTimer::restart() Q_DECL_NOTHROW
{
    qint64 old = t1;
    t1 = QDateTime::currentMSecsSinceEpoch();
    t2 = 0;
    return t1 - old;
}

qint64 QElapsedTimer::nsecsElapsed() const Q_DECL_NOTHROW
{
    return elapsed() * 1000000;
}

// 所以, 其实就是当前时间减去记录的开始时间.
qint64 QElapsedTimer::elapsed() const Q_DECL_NOTHROW
{
    return QDateTime::currentMSecsSinceEpoch() - t1;
}

// 提供一个接口, 来返回自己记录的起始时间.
qint64 QElapsedTimer::msecsSinceReference() const Q_DECL_NOTHROW
{
    return t1;
}

/*!
    Returns the number of milliseconds between this QElapsedTimer and \a
    other. If \a other was started before this object, the returned value
    will be negative. If it was started later, the returned value will be
    positive.

    The return value is undefined if this object or \a other were invalidated.

    \sa secsTo(), elapsed()
*/
qint64 QElapsedTimer::msecsTo(const QElapsedTimer &other) const Q_DECL_NOTHROW
{
    qint64 diff = other.t1 - t1;
    return diff;
}

/*!
    Returns the number of seconds between this QElapsedTimer and \a other. If
    \a other was started before this object, the returned value will be
    negative. If it was started later, the returned value will be positive.

    Calling this function on or with a QElapsedTimer that is invalid
    results in undefined behavior.

    \sa msecsTo(), elapsed()
*/
qint64 QElapsedTimer::secsTo(const QElapsedTimer &other) const Q_DECL_NOTHROW
{
    return msecsTo(other) / 1000;
}

/*!
    \relates QElapsedTimer

    Returns \c true if \a v1 was started before \a v2, false otherwise.

    The returned value is undefined if one of the two parameters is invalid
    and the other isn't. However, two invalid timers are equal and thus this
    function will return false.
*/
bool operator<(const QElapsedTimer &v1, const QElapsedTimer &v2) Q_DECL_NOTHROW
{
    return v1.t1 < v2.t1;
}

QDeadlineTimer QDeadlineTimer::current(Qt::TimerType timerType) Q_DECL_NOTHROW
{
    QDeadlineTimer result;
    result.t1 = QDateTime::currentMSecsSinceEpoch() * 1000 * 1000;
    result.type = timerType;
    return result;
}

QT_END_NAMESPACE
