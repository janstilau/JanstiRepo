/****************************************************************************
**
** Copyright (C) 2016 The Qt Company Ltd.
** Contact: https://www.qt.io/licensing/
**
** This file is part of the QtWidgets module of the Qt Toolkit.
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

#include "qframe.h"
#include "qbitmap.h"
#include "qdrawutil.h"
#include "qevent.h"
#include "qpainter.h"
#include "qstyle.h"
#include "qstyleoption.h"
#include "qapplication.h"

#include "qframe_p.h"

QT_BEGIN_NAMESPACE

QFramePrivate::QFramePrivate()
    : frect(0, 0, 0, 0),
      frameStyle(QFrame::NoFrame | QFrame::Plain),
      lineWidth(1),
      midLineWidth(0),
      frameWidth(0),
      leftFrameWidth(0), rightFrameWidth(0),
      topFrameWidth(0), bottomFrameWidth(0)
{
}

QFramePrivate::~QFramePrivate()
{
}

inline void QFramePrivate::init()
{
    setLayoutItemMargins(QStyle::SE_FrameLayoutItem);
}

QFrame::QFrame(QWidget* parent, Qt::WindowFlags f)
    : QWidget(*new QFramePrivate, parent, f)
{
    Q_D(QFrame);
    d->init();
}

/*! \internal */
QFrame::QFrame(QFramePrivate &dd, QWidget* parent, Qt::WindowFlags f)
    : QWidget(dd, parent, f)
{
    Q_D(QFrame);
    d->init();
}

void QFrame::initStyleOption(QStyleOptionFrame *option) const
{
    if (!option)
        return;

    Q_D(const QFrame);
    option->initFrom(this);

    int frameShape  = d->frameStyle & QFrame::Shape_Mask;
    int frameShadow = d->frameStyle & QFrame::Shadow_Mask;
    option->frameShape = Shape(int(option->frameShape) | frameShape);
    option->rect = frameRect();
    switch (frameShape) {
        case QFrame::Box:
        case QFrame::HLine:
        case QFrame::VLine:
        case QFrame::StyledPanel:
        case QFrame::Panel:
            option->lineWidth = d->lineWidth;
            option->midLineWidth = d->midLineWidth;
            break;
        default:
            // most frame styles do not handle customized line and midline widths
            // (see updateFrameWidth()).
            option->lineWidth = d->frameWidth;
            break;
    }

    if (frameShadow == Sunken)
        option->state |= QStyle::State_Sunken;
    else if (frameShadow == Raised)
        option->state |= QStyle::State_Raised;
}


QFrame::~QFrame()
{
}

int QFrame::frameStyle() const
{
    Q_D(const QFrame);
    return d->frameStyle;
}

QFrame::Shape QFrame::frameShape() const
{
    Q_D(const QFrame);
    return (Shape) (d->frameStyle & Shape_Mask);
}

void QFrame::setFrameShape(QFrame::Shape s)
{
    Q_D(QFrame);
    setFrameStyle((d->frameStyle & Shadow_Mask) | s);
}

QFrame::Shadow QFrame::frameShadow() const
{
    Q_D(const QFrame);
    return (Shadow) (d->frameStyle & Shadow_Mask);
}

void QFrame::setFrameShadow(QFrame::Shadow s)
{
    Q_D(QFrame);
    setFrameStyle((d->frameStyle & Shape_Mask) | s);
}

void QFrame::setFrameStyle(int style)
{
    Q_D(QFrame);
    if (!testAttribute(Qt::WA_WState_OwnSizePolicy)) {
        QSizePolicy sp;

        switch (style & Shape_Mask) {
        case HLine:
            sp = QSizePolicy(QSizePolicy::Minimum, QSizePolicy::Fixed, QSizePolicy::Line);
            break;
        case VLine:
            sp = QSizePolicy(QSizePolicy::Fixed, QSizePolicy::Minimum, QSizePolicy::Line);
            break;
        default:
            sp = QSizePolicy(QSizePolicy::Preferred, QSizePolicy::Preferred, QSizePolicy::Frame);
        }
        setSizePolicy(sp);
        setAttribute(Qt::WA_WState_OwnSizePolicy, false);
    }
    d->frameStyle = (short)style;
    update();
    d->updateFrameWidth();
}

void QFrame::setLineWidth(int w)
{
    Q_D(QFrame);
    if (short(w) == d->lineWidth)
        return;
    d->lineWidth = short(w);
    d->updateFrameWidth();
}

int QFrame::lineWidth() const
{
    Q_D(const QFrame);
    return d->lineWidth;
}

void QFrame::setMidLineWidth(int w)
{
    Q_D(QFrame);
    if (short(w) == d->midLineWidth)
        return;
    d->midLineWidth = short(w);
    d->updateFrameWidth();
}

int QFrame::midLineWidth() const
{
    Q_D(const QFrame);
    return d->midLineWidth;
}

/*!
  \internal
  Updates the frame widths from the style.
*/
void QFramePrivate::updateStyledFrameWidths()
{
    Q_Q(const QFrame);
    QStyleOptionFrame opt;
    q->initStyleOption(&opt);

    QRect cr = q->style()->subElementRect(QStyle::SE_ShapedFrameContents, &opt, q);
    leftFrameWidth = cr.left() - opt.rect.left();
    topFrameWidth = cr.top() - opt.rect.top();
    rightFrameWidth = opt.rect.right() - cr.right(),
    bottomFrameWidth = opt.rect.bottom() - cr.bottom();
    frameWidth = qMax(qMax(leftFrameWidth, rightFrameWidth),
                      qMax(topFrameWidth, bottomFrameWidth));
}

/*!
  \internal
  Updated the frameWidth parameter.
*/

void QFramePrivate::updateFrameWidth()
{
    Q_Q(QFrame);
    QRect fr = q->frameRect();
    updateStyledFrameWidths();
    q->setFrameRect(fr);
    setLayoutItemMargins(QStyle::SE_FrameLayoutItem);
}

int QFrame::frameWidth() const
{
    Q_D(const QFrame);
    return d->frameWidth;
}


QRect QFrame::frameRect() const
{
    Q_D(const QFrame);
    QRect fr = contentsRect();
    fr.adjust(-d->leftFrameWidth, -d->topFrameWidth, d->rightFrameWidth, d->bottomFrameWidth);
    return fr;
}

void QFrame::setFrameRect(const QRect &r)
{
    Q_D(QFrame);
    QRect cr = r.isValid() ? r : rect();
    cr.adjust(d->leftFrameWidth, d->topFrameWidth, -d->rightFrameWidth, -d->bottomFrameWidth);
    setContentsMargins(cr.left(), cr.top(), rect().right() - cr.right(), rect().bottom() - cr.bottom());
}

/*!\reimp
*/
QSize QFrame::sizeHint() const
{
    Q_D(const QFrame);
    //   Returns a size hint for the frame - for HLine and VLine
    //   shapes, this is stretchable one way and 3 pixels wide the
    //   other.  For other shapes, QWidget::sizeHint() is used.
    switch (d->frameStyle & Shape_Mask) {
    case HLine:
        return QSize(-1,3);
    case VLine:
        return QSize(3,-1);
    default:
        return QWidget::sizeHint();
    }
}

/*!\reimp
*/

void QFrame::paintEvent(QPaintEvent *)
{
    QPainter paint(this);
    drawFrame(&paint);
}

// 最最重要的方法, 画边框.
void QFrame::drawFrame(QPainter *p)
{
    QStyleOptionFrame opt;
    initStyleOption(&opt);
    style()->drawControl(QStyle::CE_ShapedFrame, &opt, p, this);
}


/*!\reimp
 */
void QFrame::changeEvent(QEvent *ev)
{
    Q_D(QFrame);
    if (ev->type() == QEvent::StyleChange
#ifdef Q_OS_MAC
            || ev->type() == QEvent::MacSizeChange
#endif
            )
        d->updateFrameWidth();
    QWidget::changeEvent(ev);
}

/*! \reimp */
bool QFrame::event(QEvent *e)
{
    if (e->type() == QEvent::ParentChange)
        d_func()->updateFrameWidth();
    bool result = QWidget::event(e);
    //this has to be done after the widget has been polished
    if (e->type() == QEvent::Polish)
        d_func()->updateFrameWidth();
    return result;
}

QT_END_NAMESPACE

#include "moc_qframe.cpp"
