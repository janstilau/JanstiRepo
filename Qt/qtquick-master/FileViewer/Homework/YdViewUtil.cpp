// Created by liugquoqiang at 2020-11-18

#ifdef YD_HOMEWORK

#include "YdViewUtil.h"
#include "YdSystemCommon.h"

void YdViewUtil::setBackgroundColor(QWidget* view, const QColor& aColor)
{
    if (view == nullptr) { return; }
    QPalette pal = view->palette();
    pal.setColor(QPalette::Background, aColor);
    view->setPalette(pal);
}

void YdViewUtil::setLabelPixelSize(QLabel *label, double size)
{
    if (label == nullptr) { return; }
    QFont ft = label->font();
    ft.setPixelSize(size);
    label->setFont(ft);
}

void YdViewUtil::setLabelWeight(QLabel *label, double weight)
{
    if (label == nullptr) { return; }
    QFont ft = label->font();
    ft.setWeight(weight);
    label->setFont(ft);
}

void YdViewUtil::setLabelFontFamily(QLabel *label, const QString& family)
{
    if (label == nullptr) { return; }
    if (family.isEmpty()) { return; }
    QFont ft = label->font();
    ft.setFamily(family);
    label->setFont(ft);
}

void YdViewUtil::setLabelColor(QLabel *label, QColor color)
{
    QPalette pal = label->palette();
    pal.setColor(QPalette::WindowText, color);
    label->setPalette(pal);
}


void YdViewUtil::addBorder(QWidget *view)
{
    QString style;
    style.append("border-style: outset;");
    style.append("border-width: 1.5px;");
    style.append("border-color: rgb(");
    style.append(QString("%1,").arg(std::rand() % 255));
    style.append(QString("%1,").arg(std::rand() % 255));
    style.append(QString("%1)").arg(std::rand() % 255));
    view->setStyleSheet(style);
}

void YdViewUtil::removeBorder(QWidget *view)
{
    view->setStyleSheet("border-width: 0px");
}

#endif
