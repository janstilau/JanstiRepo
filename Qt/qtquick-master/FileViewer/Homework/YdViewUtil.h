// Created by liugquoqiang at 2020-11-18

#ifdef YD_HOMEWORK

#ifndef YDVIEWUTIL_H
#define YDVIEWUTIL_H

#include "YdSystemCommon.h"


namespace YdViewUtil {

    void setBackgroundColor(QWidget *view, const QColor& aColor);
    void setLabelPixelSize(QLabel *label, double size);
    void setLabelWeight(QLabel *label, double weight);
    void setLabelFontFamily(QLabel *label, const QString& family);
    void setLabelColor(QLabel *label, QColor color);

    // Debug Usage
    void addBorder(QWidget *view);
    void removeBorder(QWidget *view);
}

#endif // YDVIEWUTIL_H

#endif
