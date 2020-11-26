#include "qlayout.h"

#include "qapplication.h"
#include "qlayoutengine_p.h"
#if QT_CONFIG(menubar)
#include "qmenubar.h"
#endif
#if QT_CONFIG(toolbar)
#include "qtoolbar.h"
#endif
#include "qevent.h"
#include "qstyle.h"
#include "qvariant.h"
#include "qwidget_p.h"

QT_BEGIN_NAMESPACE

inline static QRect fromLayoutItemRect(QWidgetPrivate *priv, const QRect &rect)
{
    return rect.adjusted(priv->leftLayoutItemMargin, priv->topLayoutItemMargin,
                         -priv->rightLayoutItemMargin, -priv->bottomLayoutItemMargin);
}

inline static QSize fromLayoutItemSize(QWidgetPrivate *priv, const QSize &size)
{
    return fromLayoutItemRect(priv, QRect(QPoint(0, 0), size)).size();
}

inline static QRect toLayoutItemRect(QWidgetPrivate *priv, const QRect &rect)
{
    return rect.adjusted(-priv->leftLayoutItemMargin, -priv->topLayoutItemMargin,
                         priv->rightLayoutItemMargin, priv->bottomLayoutItemMargin);
}

inline static QSize toLayoutItemSize(QWidgetPrivate *priv, const QSize &size)
{
    return toLayoutItemRect(priv, QRect(QPoint(0, 0), size)).size();
}


void QLayoutItem::setAlignment(Qt::Alignment alignment)
{
    align = alignment;
}


QSpacerItem::~QSpacerItem() {}


void QSpacerItem::changeSize(int w, int h, QSizePolicy::Policy hPolicy,
                             QSizePolicy::Policy vPolicy)
{
    width = w;
    height = h;
    sizeP = QSizePolicy(hPolicy, vPolicy);
}


QWidgetItem::~QWidgetItem() {}

QLayoutItem::~QLayoutItem()
{
}

void QLayoutItem::invalidate()
{
}


QLayout * QLayoutItem::layout()
{
    return 0;
}

QSpacerItem * QLayoutItem::spacerItem()
{
    return 0;
}

QLayout * QLayout::layout()
{
    return this;
}


QSpacerItem * QSpacerItem::spacerItem()
{
    return this;
}

QWidget * QLayoutItem::widget()
{
    return 0;
}


QWidget *QWidgetItem::widget()
{
    return wid;
}


bool QLayoutItem::hasHeightForWidth() const
{
    return false;
}

int QLayoutItem::minimumHeightForWidth(int w) const
{
    return heightForWidth(w);
}

int QLayoutItem::heightForWidth(int /* w */) const
{
    return -1;
}

QSizePolicy::ControlTypes QLayoutItem::controlTypes() const
{
    return QSizePolicy::DefaultType;
}

void QSpacerItem::setGeometry(const QRect &r)
{
    rect = r;
}

// QWidgeItem 在设置坐标的时候, 会考虑对齐方式, 然后最后计算出坐标出来.
void QWidgetItem::setGeometry(const QRect &rect)
{
    if (isEmpty())
        return;

    QRect r = !wid->testAttribute(Qt::WA_LayoutUsesWidgetRect)
            ? fromLayoutItemRect(wid->d_func(), rect)
            : rect;
    const QSize widgetRectSurplus = r.size() - rect.size();

    /*
       For historical reasons, this code is done using widget rect
       coordinates, not layout item rect coordinates. However,
       QWidgetItem's sizeHint(), maximumSize(), and heightForWidth()
       all work in terms of layout item rect coordinates, so we have to
       add or subtract widgetRectSurplus here and there. The code could
       be much simpler if we did everything using layout item rect
       coordinates and did the conversion right before the call to
       QWidget::setGeometry().
     */

    QSize s = r.size().boundedTo(maximumSize() + widgetRectSurplus);
    int x = r.x();
    int y = r.y();
    if (align & (Qt::AlignHorizontal_Mask | Qt::AlignVertical_Mask)) {
        QSize pref(sizeHint());
        QSizePolicy sp = wid->sizePolicy();
        if (sp.horizontalPolicy() == QSizePolicy::Ignored)
            pref.setWidth(wid->sizeHint().expandedTo(wid->minimumSize()).width());
        if (sp.verticalPolicy() == QSizePolicy::Ignored)
            pref.setHeight(wid->sizeHint().expandedTo(wid->minimumSize()).height());
        pref += widgetRectSurplus;
        if (align & Qt::AlignHorizontal_Mask)
            s.setWidth(qMin(s.width(), pref.width()));
        if (align & Qt::AlignVertical_Mask) {
            if (hasHeightForWidth())
                s.setHeight(qMin(s.height(),
                                 heightForWidth(s.width() - widgetRectSurplus.width())
                                 + widgetRectSurplus.height()));
            else
                s.setHeight(qMin(s.height(), pref.height()));
        }
    }
    Qt::Alignment alignHoriz = QStyle::visualAlignment(wid->layoutDirection(), align);
    if (alignHoriz & Qt::AlignRight)
        x = x + (r.width() - s.width());
    else if (!(alignHoriz & Qt::AlignLeft))
        x = x + (r.width() - s.width()) / 2;

    if (align & Qt::AlignBottom)
        y = y + (r.height() - s.height());
    else if (!(align & Qt::AlignTop))
        y = y + (r.height() - s.height()) / 2;

    wid->setGeometry(x, y, s.width(), s.height());
}

QRect QSpacerItem::geometry() const
{
    return rect;
}


QRect QWidgetItem::geometry() const
{
    return !wid->testAttribute(Qt::WA_LayoutUsesWidgetRect)
           ? toLayoutItemRect(wid->d_func(), wid->geometry())
           : wid->geometry();
}


bool QWidgetItem::hasHeightForWidth() const
{
    if (isEmpty())
        return false;
    return wid->hasHeightForWidth(); // 各个不同的 widget, 是否widthheight 保持比例是不同的.
}

/*!
    \reimp
*/
int QWidgetItem::heightForWidth(int w) const
{
    if (isEmpty())
        return -1;

    w = !wid->testAttribute(Qt::WA_LayoutUsesWidgetRect)
      ? fromLayoutItemSize(wid->d_func(), QSize(w, 0)).width()
      : w;

    int heightForWidth;
    if (wid->layout())
        heightForWidth = wid->layout()->totalHeightForWidth(w);
    else
        heightForWidth = wid->heightForWidth(w);
    // 如果, widget 有 layout, layout 说了算, 否则自己的定义.

    if (heightForWidth > wid->maximumHeight())
        heightForWidth = wid->maximumHeight();
    if (heightForWidth < wid->minimumHeight())
        heightForWidth = wid->minimumHeight();

    heightForWidth = !wid->testAttribute(Qt::WA_LayoutUsesWidgetRect)
        ? toLayoutItemSize(wid->d_func(), QSize(0, heightForWidth)).height()
        : heightForWidth;

    if (heightForWidth < 0)
        heightForWidth = 0;
    return heightForWidth;
}

/*!
    \reimp
*/
Qt::Orientations QSpacerItem::expandingDirections() const
{
    return sizeP.expandingDirections();
}

/*!
    \reimp
*/
Qt::Orientations QWidgetItem::expandingDirections() const
{
    if (isEmpty())
        return Qt::Orientations(0);

    Qt::Orientations e = wid->sizePolicy().expandingDirections();
    /*
      If the layout is expanding, we make the widget expanding, even if
      its own size policy isn't expanding.
    */
    if (wid->layout()) {
        if (wid->sizePolicy().horizontalPolicy() & QSizePolicy::GrowFlag
                && (wid->layout()->expandingDirections() & Qt::Horizontal))
            e |= Qt::Horizontal;
        if (wid->sizePolicy().verticalPolicy() & QSizePolicy::GrowFlag
                && (wid->layout()->expandingDirections() & Qt::Vertical))
            e |= Qt::Vertical;
    }

    if (align & Qt::AlignHorizontal_Mask)
        e &= ~Qt::Horizontal;
    if (align & Qt::AlignVertical_Mask)
        e &= ~Qt::Vertical;
    return e;
}

// 示弱就挨打.
QSize QSpacerItem::minimumSize() const
{
    return QSize(sizeP.horizontalPolicy() & QSizePolicy::ShrinkFlag ? 0 : width,
                 sizeP.verticalPolicy() & QSizePolicy::ShrinkFlag ? 0 : height);
}

/*!
    \reimp
*/
QSize QWidgetItem::minimumSize() const
{
    if (isEmpty())
        return QSize(0, 0);
    return !wid->testAttribute(Qt::WA_LayoutUsesWidgetRect)
           ? toLayoutItemSize(wid->d_func(), qSmartMinSize(this))
           : qSmartMinSize(this);
}

QSize QSpacerItem::maximumSize() const
{
    return QSize(sizeP.horizontalPolicy() & QSizePolicy::GrowFlag ? QLAYOUTSIZE_MAX : width,
                 sizeP.verticalPolicy() & QSizePolicy::GrowFlag ? QLAYOUTSIZE_MAX : height);
}

/*!
    \reimp
*/
QSize QWidgetItem::maximumSize() const
{
    if (isEmpty()) {
        return QSize(0, 0);
    } else {
        return !wid->testAttribute(Qt::WA_LayoutUsesWidgetRect)
               ? toLayoutItemSize(wid->d_func(), qSmartMaxSize(this, align))
               : qSmartMaxSize(this, align);
    }
}

/*!
    // 这里, 就返回明确的值了.
*/
QSize QSpacerItem::sizeHint() const
{
    return QSize(width, height);
}

/*!
    \reimp
*/
QSize QWidgetItem::sizeHint() const
{
    QSize s(0, 0);
    if (!isEmpty()) {
        s = wid->sizeHint().expandedTo(wid->minimumSizeHint());
        s = s.boundedTo(wid->maximumSize())
             .expandedTo(wid->minimumSize());
        s = !wid->testAttribute(Qt::WA_LayoutUsesWidgetRect)
           ? toLayoutItemSize(wid->d_func(), s)
           : s;

        if (wid->sizePolicy().horizontalPolicy() == QSizePolicy::Ignored)
            s.setWidth(0);
        if (wid->sizePolicy().verticalPolicy() == QSizePolicy::Ignored)
            s.setHeight(0);
    }
    return s;
}

/*!
    Returns \c true.
*/
bool QSpacerItem::isEmpty() const
{
    return true;
}

// 这就是为什么 Widget hidden 了之后, 就会坍塌的原因所在了. 所以也可以 retainSizeWhenHidden 让某个 widget 不坍塌.
// 不过, 知道了 widget hidden 之后, 可以自动布局了

bool QWidgetItem::isEmpty() const
{
    return (wid->isHidden() && !wid->sizePolicy().retainSizeWhenHidden()) || wid->isWindow();
}

QSizePolicy::ControlTypes QWidgetItem::controlTypes() const
{
    return wid->sizePolicy().controlType();
}

QT_END_NAMESPACE
