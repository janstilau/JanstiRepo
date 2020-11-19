#ifndef QLAYOUTENGINE_P_H
#define QLAYOUTENGINE_P_H

#include <QtWidgets/private/qtwidgetsglobal_p.h>
#include "QtWidgets/qlayoutitem.h"
#include "QtWidgets/qstyle.h"

QT_BEGIN_NAMESPACE

template <typename T> class QVector;

struct QLayoutStruct
{
    inline void init(int stretchFactor = 0, int minSize = 0) {
        stretch = stretchFactor;
        minimumSize = sizeHint = minSize;
        maximumSize = QLAYOUTSIZE_MAX;
        expansive = false;
        empty = true;
        spacing = 0;
    }

    int smartSizeHint() {
        return (stretch > 0) ? minimumSize : sizeHint;
    }
    int effectiveSpacer(int uniformSpacer) const {
        Q_ASSERT(uniformSpacer >= 0 || spacing >= 0);
        return (uniformSpacer >= 0) ? uniformSpacer : spacing;
    }

    // parameters
    int stretch;
    int sizeHint;
    int maximumSize;
    int minimumSize;
    int spacing;
    bool expansive;
    bool empty;

    // temporary storage
    bool done;

    // result
    int pos;
    int size;
};


Q_WIDGETS_EXPORT void qGeomCalc(QVector<QLayoutStruct> &chain, int start, int count,
                            int pos, int space, int spacer = -1);
Q_WIDGETS_EXPORT QSize qSmartMinSize(const QSize &sizeHint, const QSize &minSizeHint,
                                 const QSize &minSize, const QSize &maxSize,
                                 const QSizePolicy &sizePolicy);
Q_WIDGETS_EXPORT QSize qSmartMinSize(const QWidgetItem *i);
Q_WIDGETS_EXPORT QSize qSmartMinSize(const QWidget *w);
Q_WIDGETS_EXPORT QSize qSmartMaxSize(const QSize &sizeHint,
                                 const QSize &minSize, const QSize &maxSize,
                                 const QSizePolicy &sizePolicy, Qt::Alignment align = 0);
Q_WIDGETS_EXPORT QSize qSmartMaxSize(const QWidgetItem *i, Qt::Alignment align = 0);
Q_WIDGETS_EXPORT QSize qSmartMaxSize(const QWidget *w, Qt::Alignment align = 0);

Q_WIDGETS_EXPORT int qSmartSpacing(const QLayout *layout, QStyle::PixelMetric pm);

/*
  Modify total maximum (max), total expansion (exp), and total empty
  when adding boxmax/boxexp.

  Expansive boxes win over non-expansive boxes.
  Non-empty boxes win over empty boxes.
*/
static inline void qMaxExpCalc(int & max, bool &exp, bool &empty,
                               int boxmax, bool boxexp, bool boxempty)
{
    if (exp) {
        if (boxexp)
            max = qMax(max, boxmax);
    } else {
        if (boxexp || (empty && (!boxempty || max == 0)))
            max = boxmax;
        else if (empty == boxempty)
            max = qMin(max, boxmax);
    }
    exp = exp || boxexp;
    empty = empty && boxempty;
}

QT_END_NAMESPACE

#endif // QLAYOUTENGINE_P_H
