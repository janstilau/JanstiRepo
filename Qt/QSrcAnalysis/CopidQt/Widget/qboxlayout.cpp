#include "qboxlayout.h"
#include "qapplication.h"
#include "qwidget.h"
#include "qlist.h"
#include "qsizepolicy.h"
#include "qvector.h"

#include "qlayoutengine_p.h"
#include "qlayout_p.h"

QT_BEGIN_NAMESPACE

struct QBoxLayoutItem
{
    QBoxLayoutItem(QLayoutItem *it, int stretch_ = 0)
        : item(it), stretch(stretch_), magic(false) { }
    ~QBoxLayoutItem() { delete item; }

    int hfw(int w) {
        if (item->hasHeightForWidth()) {
            return item->heightForWidth(w);
        } else {
            return item->sizeHint().height();
        }
    }
    int mhfw(int w) {
        if (item->hasHeightForWidth()) {
            return item->heightForWidth(w);
        } else {
            return item->minimumSize().height();
        }
    }
    int hStretch() {
        if (stretch == 0 && item->widget()) {
            return item->widget()->sizePolicy().horizontalStretch();
        } else {
            return stretch;
        }
    }
    int vStretch() {
        if (stretch == 0 && item->widget()) {
            return item->widget()->sizePolicy().verticalStretch();
        } else {
            return stretch;
        }
    }

    QLayoutItem *item;
    int stretch;
    bool magic;
};

class QBoxLayoutPrivate : public QLayoutPrivate
{
    Q_DECLARE_PUBLIC(QBoxLayout)
public:
    QBoxLayoutPrivate() : hfwWidth(-1), dirty(true), spacing(-1) { }
    ~QBoxLayoutPrivate();

    void setDirty() {
        geomArray.clear();
        hfwWidth = -1;
        hfwHeight = -1;
        dirty = true;
    }

    QList<QBoxLayoutItem *> itemLists; // 所管理的所有 layout 或者 widget.
    QVector<QLayoutStruct> geomArray;
    int hfwWidth;
    int hfwHeight;
    int hfwMinHeight;
    QSize sizeHint;
    QSize minSize;
    QSize maxSize;
    int leftMargin, topMargin, rightMargin, bottomMargin;
    Qt::Orientations expanding;
    uint hasHfw : 1;
    uint dirty : 1; // 通过一个方法, 计算出所有的值. 非 dirty 状态下取缓存值, dirty 的话, 重新调用那个方法更新所有值.

    QBoxLayout::Direction boxDirtection;
    int spacing;

    inline void deleteAll() { while (!itemLists.isEmpty()) delete itemLists.takeFirst(); }

    void setupGeom();
    void calcHfw(int);

    void effectiveMargins(int *left, int *top, int *right, int *bottom) const;
    QLayoutItem* replaceAt(int index, QLayoutItem*) override;
};

QBoxLayoutPrivate::~QBoxLayoutPrivate()
{
}

static inline bool horz(QBoxLayout::Direction dir)
{
    return dir == QBoxLayout::RightToLeft || dir == QBoxLayout::LeftToRight;
}

/**
 * The purpose of this function is to make sure that widgets are not laid out outside its layout.
 * E.g. the layoutItemRect margins are only meant to take of the surrounding margins/spacings.
 * However, if the margin is 0, it can easily cover the area of a widget above it.
 */
void QBoxLayoutPrivate::effectiveMargins(int *left, int *top, int *right, int *bottom) const
{
    int l = leftMargin;
    int t = topMargin;
    int r = rightMargin;
    int b = bottomMargin;
#ifdef Q_OS_MAC
    Q_Q(const QBoxLayout);
    if (horz(boxDirtection)) {
        QBoxLayoutItem *leftBox = 0;
        QBoxLayoutItem *rightBox = 0;

        if (left || right) {
            leftBox = itemLists.value(0);
            rightBox = itemLists.value(itemLists.count() - 1);
            if (boxDirtection == QBoxLayout::RightToLeft)
                qSwap(leftBox, rightBox);

            int leftDelta = 0;
            int rightDelta = 0;
            if (leftBox) {
                QLayoutItem *itm = leftBox->item;
                if (QWidget *w = itm->widget())
                    leftDelta = itm->geometry().left() - w->geometry().left();
            }
            if (rightBox) {
                QLayoutItem *itm = rightBox->item;
                if (QWidget *w = itm->widget())
                    rightDelta = w->geometry().right() - itm->geometry().right();
            }
            QWidget *w = q->parentWidget();
            Qt::LayoutDirection layoutDirection = w ? w->layoutDirection() : QApplication::layoutDirection();
            if (layoutDirection == Qt::RightToLeft)
                qSwap(leftDelta, rightDelta);

            l = qMax(l, leftDelta);
            r = qMax(r, rightDelta);
        }

        int count = top || bottom ? itemLists.count() : 0;
        for (int i = 0; i < count; ++i) {
            QBoxLayoutItem *box = itemLists.at(i);
            QLayoutItem *itm = box->item;
            QWidget *w = itm->widget();
            if (w) {
                QRect lir = itm->geometry();
                QRect wr = w->geometry();
                if (top)
                    t = qMax(t, lir.top() - wr.top());
                if (bottom)
                    b = qMax(b, wr.bottom() - lir.bottom());
            }
        }
    } else {    // vertical layout
        QBoxLayoutItem *topBox = 0;
        QBoxLayoutItem *bottomBox = 0;

        if (top || bottom) {
            topBox = itemLists.value(0);
            bottomBox = itemLists.value(itemLists.count() - 1);
            if (boxDirtection == QBoxLayout::BottomToTop) {
                qSwap(topBox, bottomBox);
            }

            if (top && topBox) {
                QLayoutItem *itm = topBox->item;
                QWidget *w = itm->widget();
                if (w)
                    t = qMax(t, itm->geometry().top() - w->geometry().top());
            }

            if (bottom && bottomBox) {
                QLayoutItem *itm = bottomBox->item;
                QWidget *w = itm->widget();
                if (w)
                    b = qMax(b, w->geometry().bottom() - itm->geometry().bottom());
            }
        }

        int count = left || right ? itemLists.count() : 0;
        for (int i = 0; i < count; ++i) {
            QBoxLayoutItem *box = itemLists.at(i);
            QLayoutItem *itm = box->item;
            QWidget *w = itm->widget();
            if (w) {
                QRect lir = itm->geometry();
                QRect wr = w->geometry();
                if (left)
                    l = qMax(l, lir.left() - wr.left());
                if (right)
                    r = qMax(r, wr.right() - lir.right());
            }
        }
    }
#endif
    if (left)
        *left = l;
    if (top)
        *top = t;
    if (right)
        *right = r;
    if (bottom)
        *bottom = b;
}


/*
    这应该是非常重要的更新方法.
*/
void QBoxLayoutPrivate::setupGeom()
{
    if (!dirty)
        return;

    Q_Q(QBoxLayout);
    int maxWidth = horz(boxDirtection) ? 0 : QLAYOUTSIZE_MAX;
    int maxHeight = horz(boxDirtection) ? QLAYOUTSIZE_MAX : 0;
    int minWidth = 0;
    int minHeight = 0;
    int hintWidth = 0;
    int hintHeight = 0;

    bool horexp = false;
    bool verexp = false;

    hasHfw = false;

    int itemCount = itemLists.count();
    geomArray.clear();

    QVector<QLayoutStruct> updatedGeos(itemCount);

    int fixedSpacing = q->spacing(); // 这里, 之所以用函数, 是因为如果没有设置过 spacing, 那么就会是 0, 而系统会有默认值. 感觉可以初始化的时候设置下啊.
    int previousNonEmptyIndex = -1;

    QStyle *style = 0;
    if (fixedSpacing < 0) {
        if (QWidget *parentWidget = q->parentWidget())
            style = parentWidget->style();
    }

    QSizePolicy::ControlTypes controlTypes1;
    QSizePolicy::ControlTypes controlTypes2;
    for (int i = 0; i < itemCount; i++) {
        QBoxLayoutItem *aItem = itemLists.at(i); // 这里, 如果 item 也是 layout 的话, 就会递归去计算了.
        QSize max = aItem->item->maximumSize();
        QSize min = aItem->item->minimumSize();
        QSize hint = aItem->item->sizeHint();

        Qt::Orientations exp = aItem->item->expandingDirections();
        bool empty = aItem->item->isEmpty();
        int spacing = 0;

        // 首先, 根据 item , 取出一顿值出来.

        if (!empty) { // 这里, 是计算 spacing 的值.
            if (fixedSpacing >= 0) {
                spacing = (previousNonEmptyIndex >= 0) ? fixedSpacing : 0;
            } else {
                controlTypes1 = controlTypes2;
                controlTypes2 = aItem->item->controlTypes();
                if (previousNonEmptyIndex >= 0) {
                    QSizePolicy::ControlTypes actual1 = controlTypes1;
                    QSizePolicy::ControlTypes actual2 = controlTypes2;
                    if (boxDirtection == QBoxLayout::RightToLeft || boxDirtection == QBoxLayout::BottomToTop)
                        qSwap(actual1, actual2);

                    if (style) {
                        spacing = style->combinedLayoutSpacing(actual1, actual2,
                                             horz(boxDirtection) ? Qt::Horizontal : Qt::Vertical,
                                             0, q->parentWidget());
                        if (spacing < 0)
                            spacing = 0;
                    }
                }
            }

            if (previousNonEmptyIndex >= 0)
                updatedGeos[previousNonEmptyIndex].spacing = spacing;
            previousNonEmptyIndex = i;
        }

        bool ignore = empty && aItem->item->widget(); // ignore hidden widgets
        bool dummy = true;
        if (horz(boxDirtection)) { // 如果是横向.
            bool expand = (exp & Qt::Horizontal || aItem->stretch > 0);
            horexp = horexp || expand;
            maxWidth += spacing + max.width();
            minWidth += spacing + min.width();
            hintWidth += spacing + hint.width();
            if (!ignore)
                qMaxExpCalc(maxHeight, verexp, dummy,
                            max.height(), exp & Qt::Vertical, aItem->item->isEmpty());
            minHeight = qMax(minHeight, min.height());
            hintHeight = qMax(hintHeight, hint.height());

            updatedGeos[i].sizeHint = hint.width();
            updatedGeos[i].maximumSize = max.width();
            updatedGeos[i].minimumSize = min.width();
            updatedGeos[i].expansive = expand;
            updatedGeos[i].stretch = aItem->stretch ? aItem->stretch : aItem->hStretch();
        } else {
            bool expand = (exp & Qt::Vertical || aItem->stretch > 0);
            verexp = verexp || expand;
            maxHeight += spacing + max.height();
            minHeight += spacing + min.height();
            hintHeight += spacing + hint.height();
            if (!ignore)
                qMaxExpCalc(maxWidth, horexp, dummy,
                            max.width(), exp & Qt::Horizontal, aItem->item->isEmpty());
            minWidth = qMax(minWidth, min.width());
            hintWidth = qMax(hintWidth, hint.width());

            updatedGeos[i].sizeHint = hint.height();
            updatedGeos[i].maximumSize = max.height();
            updatedGeos[i].minimumSize = min.height();
            updatedGeos[i].expansive = expand;
            updatedGeos[i].stretch = aItem->stretch ? aItem->stretch : aItem->vStretch();
        }

        updatedGeos[i].empty = empty;
        updatedGeos[i].spacing = 0;   // might be initialized with a non-zero value in a later iteration
        hasHfw = hasHfw || aItem->item->hasHeightForWidth();
    }

    geomArray = updatedGeos;

    expanding = (Qt::Orientations)
                       ((horexp ? Qt::Horizontal : 0)
                         | (verexp ? Qt::Vertical : 0));

    minSize = QSize(minWidth, minHeight);
    maxSize = QSize(maxWidth, maxHeight).expandedTo(minSize);
    sizeHint = QSize(hintWidth, hintHeight).expandedTo(minSize).boundedTo(maxSize);

    q->getContentsMargins(&leftMargin, &topMargin, &rightMargin, &bottomMargin);
    int left, top, right, bottom;
    effectiveMargins(&left, &top, &right, &bottom);
    QSize extra(left + right, top + bottom);

    minSize += extra;
    maxSize += extra;
    sizeHint += extra;

    dirty = false;
}

/*
  Calculates and stores the preferred height given the width \a w.
*/
void QBoxLayoutPrivate::calcHfw(int w)
{
    QVector<QLayoutStruct> &a = geomArray;
    int n = a.count();
    int h = 0;
    int mh = 0;

    Q_ASSERT(n == itemLists.size());

    if (horz(boxDirtection)) {
        qGeomCalc(a, 0, n, 0, w);
        for (int i = 0; i < n; i++) {
            QBoxLayoutItem *box = itemLists.at(i);
            h = qMax(h, box->hfw(a.at(i).size));
            mh = qMax(mh, box->mhfw(a.at(i).size));
        }
    } else {
        for (int i = 0; i < n; ++i) {
            QBoxLayoutItem *box = itemLists.at(i);
            int spacing = a.at(i).spacing;
            h += box->hfw(w);
            mh += box->mhfw(w);
            h += spacing;
            mh += spacing;
        }
    }
    hfwWidth = w;
    hfwHeight = h;
    hfwMinHeight = mh;
}

QLayoutItem* QBoxLayoutPrivate::replaceAt(int index, QLayoutItem *item)
{
    Q_Q(QBoxLayout);
    if (!item)
        return 0;
    QBoxLayoutItem *b = itemLists.value(index);
    if (!b)
        return 0;
    QLayoutItem *r = b->item;

    b->item = item;
    q->invalidate();
    return r;
}

QBoxLayout::QBoxLayout(Direction dir, QWidget *parent)
    : QLayout(*new QBoxLayoutPrivate, 0, parent)
{
    Q_D(QBoxLayout);
    d->boxDirtection = dir;
}


QBoxLayout::~QBoxLayout()
{
    Q_D(QBoxLayout);
    d->deleteAll(); // must do it before QObject deletes children, so can't be in ~QBoxLayoutPrivate
}

// 如果, 通过 setSpacing 明确了 spacing, 那就用设置的值. 否则, 会取 QStyle 的默认值. QStyle 表示, 一个视图的外观. 系统有一套默认规则.
int QBoxLayout::spacing() const
{
    Q_D(const QBoxLayout);
    if (d->spacing >=0) {
        return d->spacing;
    } else {
        return qSmartSpacing(this, d->boxDirtection == LeftToRight || d->boxDirtection == RightToLeft
                                           ? QStyle::PM_LayoutHorizontalSpacing
                                           : QStyle::PM_LayoutVerticalSpacing);
    }
}

void QBoxLayout::setSpacing(int spacing)
{
    Q_D(QBoxLayout);
    d->spacing = spacing;
    invalidate();
}

/*!
   计算并缓存.
*/
QSize QBoxLayout::sizeHint() const
{
    Q_D(const QBoxLayout);
    if (d->dirty)
        const_cast<QBoxLayout*>(this)->d_func()->setupGeom();
    return d->sizeHint;
}

/*!
    \reimp
*/
QSize QBoxLayout::minimumSize() const
{
    Q_D(const QBoxLayout);
    if (d->dirty)
        const_cast<QBoxLayout*>(this)->d_func()->setupGeom();
    return d->minSize;
}

/*!
    \reimp
*/
QSize QBoxLayout::maximumSize() const
{
    Q_D(const QBoxLayout);
    if (d->dirty)
        const_cast<QBoxLayout*>(this)->d_func()->setupGeom();

    QSize s = d->maxSize.boundedTo(QSize(QLAYOUTSIZE_MAX, QLAYOUTSIZE_MAX));

    if (alignment() & Qt::AlignHorizontal_Mask)
        s.setWidth(QLAYOUTSIZE_MAX);
    if (alignment() & Qt::AlignVertical_Mask)
        s.setHeight(QLAYOUTSIZE_MAX);
    return s;
}

/*!
    \reimp
*/
bool QBoxLayout::hasHeightForWidth() const
{
    Q_D(const QBoxLayout);
    if (d->dirty)
        const_cast<QBoxLayout*>(this)->d_func()->setupGeom();
    return d->hasHfw;
}

/*!
    \reimp
*/
int QBoxLayout::heightForWidth(int w) const
{
    Q_D(const QBoxLayout);
    if (!hasHeightForWidth())
        return -1;

    int left, top, right, bottom;
    d->effectiveMargins(&left, &top, &right, &bottom);

    w -= left + right;
    if (w != d->hfwWidth)
        const_cast<QBoxLayout*>(this)->d_func()->calcHfw(w);

    return d->hfwHeight + top + bottom;
}

/*!
    \reimp
*/
int QBoxLayout::minimumHeightForWidth(int w) const
{
    Q_D(const QBoxLayout);
    (void) heightForWidth(w);
    int top, bottom;
    d->effectiveMargins(0, &top, 0, &bottom);
    return d->hasHfw ? (d->hfwMinHeight + top + bottom) : -1;
}

/*!
    Resets cached information.
*/
void QBoxLayout::invalidate()
{
    Q_D(QBoxLayout);
    d->setDirty();
    QLayout::invalidate();
}

/*!
    \reimp
*/
int QBoxLayout::count() const
{
    Q_D(const QBoxLayout);
    return d->itemLists.count();
}

/*!
    \reimp
*/
QLayoutItem *QBoxLayout::itemAt(int index) const
{
    Q_D(const QBoxLayout);
    return index >= 0 && index < d->itemLists.count() ? d->itemLists.at(index)->item : 0;
}

/*!
    \reimp
*/
QLayoutItem *QBoxLayout::takeAt(int index)
{
    Q_D(QBoxLayout);
    if (index < 0 || index >= d->itemLists.count())
        return 0;
    QBoxLayoutItem *b = d->itemLists.takeAt(index);
    QLayoutItem *item = b->item;
    b->item = 0;
    delete b;

    if (QLayout *l = item->layout()) {
        // sanity check in case the user passed something weird to QObject::setParent()
        if (l->parent() == this)
            l->setParent(0);
    }

    invalidate();
    return item;
}


/*!
    \reimp
*/
Qt::Orientations QBoxLayout::expandingDirections() const
{
    Q_D(const QBoxLayout);
    if (d->dirty)
        const_cast<QBoxLayout*>(this)->d_func()->setupGeom();
    return d->expanding;
}

/*!
    \reimp
*/
void QBoxLayout::setGeometry(const QRect &r)
{
    Q_D(QBoxLayout);
    if (d->dirty || r != geometry()) {
        QRect oldRect = geometry();
        QLayout::setGeometry(r);
        if (d->dirty)
            d->setupGeom();
        QRect cr = alignment() ? alignmentRect(r) : r;

        int left, top, right, bottom;
        d->effectiveMargins(&left, &top, &right, &bottom);
        QRect s(cr.x() + left, cr.y() + top,
                cr.width() - (left + right),
                cr.height() - (top + bottom));

        QVector<QLayoutStruct> a = d->geomArray;
        int pos = horz(d->boxDirtection) ? s.x() : s.y();
        int space = horz(d->boxDirtection) ? s.width() : s.height();
        int n = a.count();
        if (d->hasHfw && !horz(d->boxDirtection)) {
            for (int i = 0; i < n; i++) {
                QBoxLayoutItem *box = d->itemLists.at(i);
                if (box->item->hasHeightForWidth()) {
                    int width = qBound(box->item->minimumSize().width(), s.width(), box->item->maximumSize().width());
                    a[i].sizeHint = a[i].minimumSize =
                                    box->item->heightForWidth(width);
                }
            }
        }

        Direction visualDir = d->boxDirtection;
        QWidget *parent = parentWidget();
        if (parent && parent->isRightToLeft()) {
            if (d->boxDirtection == LeftToRight)
                visualDir = RightToLeft;
            else if (d->boxDirtection == RightToLeft)
                visualDir = LeftToRight;
        }

        qGeomCalc(a, 0, n, pos, space);

        bool reverse = (horz(visualDir)
                        ? ((r.right() > oldRect.right()) != (visualDir == RightToLeft))
                        : r.bottom() > oldRect.bottom());
        for (int j = 0; j < n; j++) {
            int i = reverse ? n-j-1 : j;
            QBoxLayoutItem *box = d->itemLists.at(i);

            switch (visualDir) {
            case LeftToRight:
                box->item->setGeometry(QRect(a.at(i).pos, s.y(), a.at(i).size, s.height()));
                break;
            case RightToLeft:
                box->item->setGeometry(QRect(s.left() + s.right() - a.at(i).pos - a.at(i).size + 1,
                                             s.y(), a.at(i).size, s.height()));
                break;
            case TopToBottom:
                box->item->setGeometry(QRect(s.x(), a.at(i).pos, s.width(), a.at(i).size));
                break;
            case BottomToTop:
                box->item->setGeometry(QRect(s.x(),
                                             s.top() + s.bottom() - a.at(i).pos - a.at(i).size + 1,
                                             s.width(), a.at(i).size));
            }
        }
    }
}

/*!
    \reimp
*/
void QBoxLayout::addItem(QLayoutItem *item)
{
    Q_D(QBoxLayout);
    QBoxLayoutItem *it = new QBoxLayoutItem(item);
    d->itemLists.append(it);
    invalidate();
}

/*!
    Inserts \a item into this box layout at position \a index. If \a
    index is negative, the item is added at the end.

    \sa addItem(), insertWidget(), insertLayout(), insertStretch(),
        insertSpacing()
*/
void QBoxLayout::insertItem(int index, QLayoutItem *item)
{
    Q_D(QBoxLayout);
    if (index < 0)                                // append
        index = d->itemLists.count();

    QBoxLayoutItem *it = new QBoxLayoutItem(item);
    d->itemLists.insert(index, it);
    invalidate();
}

/*!
    Inserts a non-stretchable space (a QSpacerItem) at position \a index, with
    size \a size. If \a index is negative the space is added at the end.

    The box layout has default margin and spacing. This function adds
    additional space.

    \sa addSpacing(), insertItem(), QSpacerItem
*/
void QBoxLayout::insertSpacing(int index, int size)
{
    Q_D(QBoxLayout);
    if (index < 0)                                // append
        index = d->itemLists.count();

    QLayoutItem *b;
    if (horz(d->boxDirtection))
        b = QLayoutPrivate::createSpacerItem(this, size, 0, QSizePolicy::Fixed, QSizePolicy::Minimum);
    else
        b = QLayoutPrivate::createSpacerItem(this, 0, size, QSizePolicy::Minimum, QSizePolicy::Fixed);

    QBoxLayoutItem *it = new QBoxLayoutItem(b);
    it->magic = true;
    d->itemLists.insert(index, it);
    invalidate();
}

/*!
    Inserts a stretchable space (a QSpacerItem) at position \a
    index, with zero minimum size and stretch factor \a stretch. If \a
    index is negative the space is added at the end.

    \sa addStretch(), insertItem(), QSpacerItem
*/
void QBoxLayout::insertStretch(int index, int stretch)
{
    Q_D(QBoxLayout);
    if (index < 0)                                // append
        index = d->itemLists.count();

    QLayoutItem *b;
    if (horz(d->boxDirtection))
        b = QLayoutPrivate::createSpacerItem(this, 0, 0, QSizePolicy::Expanding, QSizePolicy::Minimum);
    else
        b = QLayoutPrivate::createSpacerItem(this, 0, 0, QSizePolicy::Minimum, QSizePolicy::Expanding);

    QBoxLayoutItem *it = new QBoxLayoutItem(b, stretch);
    it->magic = true;
    d->itemLists.insert(index, it);
    invalidate();
}

/*!
    \since 4.4

    Inserts \a spacerItem at position \a index, with zero minimum
    size and stretch factor. If \a index is negative the
    space is added at the end.

    \sa addSpacerItem(), insertStretch(), insertSpacing()
*/
void QBoxLayout::insertSpacerItem(int index, QSpacerItem *spacerItem)
{
    Q_D(QBoxLayout);
    if (index < 0)                                // append
        index = d->itemLists.count();

    QBoxLayoutItem *it = new QBoxLayoutItem(spacerItem);
    it->magic = true;
    d->itemLists.insert(index, it);
    invalidate();
}

/*!
    Inserts \a layout at position \a index, with stretch factor \a
    stretch. If \a index is negative, the layout is added at the end.

    \a layout becomes a child of the box layout.

    \sa addLayout(), insertItem()
*/
void QBoxLayout::insertLayout(int index, QLayout *layout, int stretch)
{
    Q_D(QBoxLayout);
    if (!d->checkLayout(layout))
        return;
    if (!adoptLayout(layout))
        return;
    if (index < 0)                                // append
        index = d->itemLists.count();
    QBoxLayoutItem *it = new QBoxLayoutItem(layout, stretch);
    d->itemLists.insert(index, it);
    invalidate();
}

/*!
    Inserts \a widget at position \a index, with stretch factor \a
    stretch and alignment \a alignment. If \a index is negative, the
    widget is added at the end.

    The stretch factor applies only in the \l{direction()}{direction}
    of the QBoxLayout, and is relative to the other boxes and widgets
    in this QBoxLayout. Widgets and boxes with higher stretch factors
    grow more.

    If the stretch factor is 0 and nothing else in the QBoxLayout has
    a stretch factor greater than zero, the space is distributed
    according to the QWidget:sizePolicy() of each widget that's
    involved.

    The alignment is specified by \a alignment. The default alignment
    is 0, which means that the widget fills the entire cell.

    \sa addWidget(), insertItem()
*/
void QBoxLayout::insertWidget(int index, QWidget *widget, int stretch,
                              Qt::Alignment alignment)
{
    Q_D(QBoxLayout);
    if (!d->checkWidget(widget))
         return;
    addChildWidget(widget);
    if (index < 0)                                // append
        index = d->itemLists.count();
    QWidgetItem *b = QLayoutPrivate::createWidgetItem(this, widget);
    b->setAlignment(alignment);

    QBoxLayoutItem *it = new QBoxLayoutItem(b, stretch);
    d->itemLists.insert(index, it);
    invalidate();
}

/*!
    Adds a non-stretchable space (a QSpacerItem) with size \a size
    to the end of this box layout. QBoxLayout provides default margin
    and spacing. This function adds additional space.

    \sa insertSpacing(), addItem(), QSpacerItem
*/
void QBoxLayout::addSpacing(int size)
{
    insertSpacing(-1, size);
}

/*!
    Adds a stretchable space (a QSpacerItem) with zero minimum
    size and stretch factor \a stretch to the end of this box layout.

    \sa insertStretch(), addItem(), QSpacerItem
*/
void QBoxLayout::addStretch(int stretch)
{
    insertStretch(-1, stretch);
}

/*!
    \since 4.4

    Adds \a spacerItem to the end of this box layout.

    \sa addSpacing(), addStretch()
*/
void QBoxLayout::addSpacerItem(QSpacerItem *spacerItem)
{
    insertSpacerItem(-1, spacerItem);
}

/*!
    Adds \a widget to the end of this box layout, with a stretch
    factor of \a stretch and alignment \a alignment.

    The stretch factor applies only in the \l{direction()}{direction}
    of the QBoxLayout, and is relative to the other boxes and widgets
    in this QBoxLayout. Widgets and boxes with higher stretch factors
    grow more.

    If the stretch factor is 0 and nothing else in the QBoxLayout has
    a stretch factor greater than zero, the space is distributed
    according to the QWidget:sizePolicy() of each widget that's
    involved.

    The alignment is specified by \a alignment. The default
    alignment is 0, which means that the widget fills the entire cell.

    \sa insertWidget(), addItem(), addLayout(), addStretch(),
        addSpacing(), addStrut()
*/
void QBoxLayout::addWidget(QWidget *widget, int stretch, Qt::Alignment alignment)
{
    insertWidget(-1, widget, stretch, alignment);
}

/*!
    Adds \a layout to the end of the box, with serial stretch factor
    \a stretch.

    \sa insertLayout(), addItem(), addWidget()
*/
void QBoxLayout::addLayout(QLayout *layout, int stretch)
{
    insertLayout(-1, layout, stretch);
}

/*!
    Limits the perpendicular dimension of the box (e.g. height if the
    box is \l LeftToRight) to a minimum of \a size. Other constraints
    may increase the limit.

    \sa addItem()
*/
void QBoxLayout::addStrut(int size)
{
    Q_D(QBoxLayout);
    QLayoutItem *b;
    if (horz(d->boxDirtection))
        b = QLayoutPrivate::createSpacerItem(this, 0, size, QSizePolicy::Fixed, QSizePolicy::Minimum);
    else
        b = QLayoutPrivate::createSpacerItem(this, size, 0, QSizePolicy::Minimum, QSizePolicy::Fixed);

    QBoxLayoutItem *it = new QBoxLayoutItem(b);
    it->magic = true;
    d->itemLists.append(it);
    invalidate();
}

/*!
    Sets the stretch factor for \a widget to \a stretch and returns
    true if \a widget is found in this layout (not including child
    layouts); otherwise returns \c false.

    \sa setAlignment()
*/
bool QBoxLayout::setStretchFactor(QWidget *widget, int stretch)
{
    Q_D(QBoxLayout);
    if (!widget)
        return false;
    for (int i = 0; i < d->itemLists.size(); ++i) {
        QBoxLayoutItem *box = d->itemLists.at(i);
        if (box->item->widget() == widget) {
            box->stretch = stretch;
            invalidate();
            return true;
        }
    }
    return false;
}

/*!
    \overload

    Sets the stretch factor for the layout \a layout to \a stretch and
    returns \c true if \a layout is found in this layout (not including
    child layouts); otherwise returns \c false.
*/
bool QBoxLayout::setStretchFactor(QLayout *layout, int stretch)
{
    Q_D(QBoxLayout);
    for (int i = 0; i < d->itemLists.size(); ++i) {
        QBoxLayoutItem *box = d->itemLists.at(i);
        if (box->item->layout() == layout) {
            if (box->stretch != stretch) {
                box->stretch = stretch;
                invalidate();
            }
            return true;
        }
    }
    return false;
}

/*!
    Sets the stretch factor at position \a index. to \a stretch.

    \since 4.5
*/

void QBoxLayout::setStretch(int index, int stretch)
{
    Q_D(QBoxLayout);
    if (index >= 0 && index < d->itemLists.size()) {
        QBoxLayoutItem *box = d->itemLists.at(index);
        if (box->stretch != stretch) {
            box->stretch = stretch;
            invalidate();
        }
    }
}

/*!
    Returns the stretch factor at position \a index.

    \since 4.5
*/

int QBoxLayout::stretch(int index) const
{
    Q_D(const QBoxLayout);
    if (index >= 0 && index < d->itemLists.size())
        return d->itemLists.at(index)->stretch;
    return -1;
}

/*!
    Sets the direction of this layout to \a direction.
*/
void QBoxLayout::setDirection(Direction direction)
{
    Q_D(QBoxLayout);
    if (d->boxDirtection == direction)
        return;
    if (horz(d->boxDirtection) != horz(direction)) {
        //swap around the spacers (the "magic" bits)
        //#### a bit yucky, knows too much.
        //#### probably best to add access functions to spacerItem
        //#### or even a QSpacerItem::flip()
        for (int i = 0; i < d->itemLists.size(); ++i) {
            QBoxLayoutItem *box = d->itemLists.at(i);
            if (box->magic) {
                QSpacerItem *sp = box->item->spacerItem();
                if (sp) {
                    if (sp->expandingDirections() == Qt::Orientations(0) /*No Direction*/) {
                        //spacing or strut
                        QSize s = sp->sizeHint();
                        sp->changeSize(s.height(), s.width(),
                            horz(direction) ? QSizePolicy::Fixed:QSizePolicy::Minimum,
                            horz(direction) ? QSizePolicy::Minimum:QSizePolicy::Fixed);

                    } else {
                        //stretch
                        if (horz(direction))
                            sp->changeSize(0, 0, QSizePolicy::Expanding,
                                            QSizePolicy::Minimum);
                        else
                            sp->changeSize(0, 0, QSizePolicy::Minimum,
                                            QSizePolicy::Expanding);
                    }
                }
            }
        }
    }
    d->boxDirtection = direction;
    invalidate();
}

/*!
    \fn QBoxLayout::Direction QBoxLayout::direction() const

    Returns the direction of the box. addWidget() and addSpacing()
    work in this direction; the stretch stretches in this direction.

    \sa QBoxLayout::Direction, addWidget(), addSpacing()
*/

QBoxLayout::Direction QBoxLayout::direction() const
{
    Q_D(const QBoxLayout);
    return d->boxDirtection;
}

/*!
    \class QHBoxLayout
    \brief The QHBoxLayout class lines up widgets horizontally.

    \ingroup geomanagement
    \inmodule QtWidgets

    This class is used to construct horizontal box layout objects. See
    QBoxLayout for details.

    The simplest use of the class is like this:

    \snippet layouts/layouts.cpp 0
    \snippet layouts/layouts.cpp 1
    \snippet layouts/layouts.cpp 2
    \codeline
    \snippet layouts/layouts.cpp 3
    \snippet layouts/layouts.cpp 4
    \snippet layouts/layouts.cpp 5

    First, we create the widgets we want in the layout. Then, we
    create the QHBoxLayout object and add the widgets into the
    layout. Finally, we call QWidget::setLayout() to install the
    QHBoxLayout object onto the widget. At that point, the widgets in
    the layout are reparented to have \c window as their parent.

    \image qhboxlayout-with-5-children.png Horizontal box layout with five child widgets

    \sa QVBoxLayout, QGridLayout, QStackedLayout, {Layout Management}, {Basic Layouts Example}
*/


/*!
    Constructs a new top-level horizontal box with
    parent \a parent.
*/
QHBoxLayout::QHBoxLayout(QWidget *parent)
    : QBoxLayout(LeftToRight, parent)
{
}

/*!
    Constructs a new horizontal box. You must add
    it to another layout.
*/
QHBoxLayout::QHBoxLayout()
    : QBoxLayout(LeftToRight)
{
}





/*!
    Destroys this box layout.

    The layout's widgets aren't destroyed.
*/
QHBoxLayout::~QHBoxLayout()
{
}

/*!
    \class QVBoxLayout
    \brief The QVBoxLayout class lines up widgets vertically.

    \ingroup geomanagement
    \inmodule QtWidgets

    This class is used to construct vertical box layout objects. See
    QBoxLayout for details.

    The simplest use of the class is like this:

    \snippet layouts/layouts.cpp 6
    \snippet layouts/layouts.cpp 7
    \snippet layouts/layouts.cpp 8
    \codeline
    \snippet layouts/layouts.cpp 9
    \snippet layouts/layouts.cpp 10
    \snippet layouts/layouts.cpp 11

    First, we create the widgets we want in the layout. Then, we
    create the QVBoxLayout object and add the widgets into the
    layout. Finally, we call QWidget::setLayout() to install the
    QVBoxLayout object onto the widget. At that point, the widgets in
    the layout are reparented to have \c window as their parent.

    \image qvboxlayout-with-5-children.png Horizontal box layout with five child widgets

    \sa QHBoxLayout, QGridLayout, QStackedLayout, {Layout Management}, {Basic Layouts Example}
*/

/*!
    Constructs a new top-level vertical box with
    parent \a parent.
*/
QVBoxLayout::QVBoxLayout(QWidget *parent)
    : QBoxLayout(TopToBottom, parent)
{
}

/*!
    Constructs a new vertical box. You must add
    it to another layout.

*/
QVBoxLayout::QVBoxLayout()
    : QBoxLayout(TopToBottom)
{
}


/*!
    Destroys this box layout.

    The layout's widgets aren't destroyed.
*/
QVBoxLayout::~QVBoxLayout()
{
}

QT_END_NAMESPACE

#include "moc_qboxlayout.cpp"
