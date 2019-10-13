//license-placeholder 2017-3-13 wanglidan

#include "xmltools.h"
#include "numberutil.h"
#include "serializerutil.h"
#include <QXmlStreamWriter>
#include <QCoreApplication>

using namespace hoolai;

const QString XmlTools::NODE_NAME_BUTTON = QLatin1String("Button");
const QString XmlTools::NODE_NAME_EDITBOX = QLatin1String("EditBox");
const QString XmlTools::NODE_NAME_IMAGE = QLatin1String("ImageView");
const QString XmlTools::NODE_NAME_LABEL = QLatin1String("Label");
const QString XmlTools::NODE_NAME_SCROLLVIEW = QLatin1String("ScrollView");
const QString XmlTools::NODE_NAME_VIEW = QLatin1String("View");
const QString XmlTools::NODE_NAME_COMPONENT = QLatin1String("Component");

void XmlTools::writeBoolValue(QXmlStreamWriter *write, QString attName, UElement *ele, PropertyId id)
{
    bool value = ele->getProperty(id).toBool();
    if(id == PropertyId::visible) {
        //when property is visible, it's written to xml only if it's false
        if(!value) {
            write->writeAttribute(attName, QLatin1String("0"));
        }
    }else {
        //when property is not visible, it's written to xml only if it's true
        if(value) {
            write->writeAttribute(attName, QLatin1String("1"));
        }
    }
}

void XmlTools::writeColorValue(QXmlStreamWriter *write, QString attName, UElement *ele, PropertyId id)
{
    QColor color = ele->getProperty(id).value<QColor>();
    write->writeAttribute(attName, toXmlColor(color));
}

void XmlTools::writeDoubleValue(QXmlStreamWriter *write, QString attName, UElement *ele, PropertyId id)
{
    double rot = ele->getProperty(id).toDouble();
    if(rot != 0) {
        write->writeAttribute(attName, QString::number(rot));
    }
}

void XmlTools::writeIntValue(QXmlStreamWriter *write, QString attName, UElement *ele, PropertyId id)
{
    if(id == PropertyId::tag) {
        int tag = ele->getProperty(id).toInt();
        if(tag != 0) {
            write->writeAttribute(attName, QString::number(tag));
        }
    }else if(id == PropertyId::textAlignment) {
        int ali = ele->getProperty(id).toInt();
        int xmlAli = SerializerUtil::toXmlTextAlignment(ali);
        write->writeAttribute(attName, QString::number(xmlAli));
    }else {
        int ali = ele->getProperty(PropertyId::alignment).toInt();
        bool isVertical = (id != PropertyId::xAlignment);
        write->writeAttribute(attName, QString::number(SerializerUtil::toXmlXYAlignment(ali, isVertical)));
    }
}

void XmlTools::writeRectValue(QXmlStreamWriter *write, QString attName, UElement *ele, PropertyId id)
{
    write->writeAttribute(attName, toXmlRect(ele, id));
}

void XmlTools::writeStringValue(QXmlStreamWriter *write, QString attName, UElement *ele, PropertyId id)
{
    QString str = ele->getProperty(id).toString();
    if(id == PropertyId::buttonAction || id == PropertyId::nodeName || id == PropertyId::exportClassName) {
        if(!str.isEmpty()) {
            write->writeAttribute(attName, str);
        }
    }else {
        write->writeAttribute(attName, str);
    }
}

void XmlTools::readBoolValue(UElement *ele, PropertyId id, QString value, QString &err)
{
    Q_ASSERT(ele);	
    if(!ele) { return; }
    
    bool ok;
    bool boolValue = value.toInt(&ok);
    if (!ok) {
        err += QCoreApplication::translate("Serializer", "[%1]'s property(%2) is %3, which is invalid.\n").arg(ele->name()).arg(id).arg(value);
        return;
    }

    ele->setProperty(id, QVariant(boolValue));
}

void XmlTools::readColorValue(UElement *ele, PropertyId id, QString value, QString &err)
{
    Q_ASSERT(ele);
    if(!ele) { return; }

    QString msg;
    auto color = fromXmlColor(value, msg);
    if (!msg.isEmpty()) {
        err += QCoreApplication::translate("Serializer", "[%1]'s property(%2) is %3, %4.\n").arg(ele->name()).arg(id).arg(value).arg(msg);
    }
    ele->setProperty(id, QVariant(color));
}

void XmlTools::readDoubleValue(UElement *ele, PropertyId id, QString value, QString &err)
{
    Q_ASSERT(ele);
    if(!ele) { return; }

    bool ok;
    double doubleValue = value.toDouble(&ok);
    if (!ok) {
        err += QCoreApplication::translate("Serializer", "[%1]'s property(%2) is %3, which is invalid.\n").arg(ele->name()).arg(id).arg(value);
        return;
    }

    ele->setProperty(id, QVariant(doubleValue));
}

void XmlTools::readIntValue(UElement *ele, PropertyId id, QString value, QString &err)
{
    Q_ASSERT(ele);
    if(!ele) { return; }

    bool ok;
    int intValue = value.toInt(&ok);
    if (!ok) {
        err += QCoreApplication::translate("Serializer", "[%1]'s property(%2) is %3, which is invalid.\n").arg(ele->name()).arg(id).arg(value);
        return;
    }

    int ali = intValue;
    if(id == PropertyId::textAlignment) {
        ali = SerializerUtil::fromXmlTextAlignment(intValue);
    }

    ele->setProperty(id, QVariant(ali));
}

void XmlTools::readXAlignment(UElement *ele, PropertyId id, QString value, QString &err)
{
    Q_ASSERT(ele);
    if(!ele) { return; }

    bool ok;
    int xr = value.toInt(&ok);
    if (!ok) {
        err += QCoreApplication::translate("Serializer", "[%1]'s property(%2) is %3, which is invalid.\n").arg(ele->name()).arg(id).arg(value);
        return;
    }
    int yr = SerializerUtil::toXmlXYAlignment(ele->getProperty(PropertyId::alignment).toInt(), true);

    ele->setProperty(PropertyId::alignment, SerializerUtil::fromXmlViewAlignment(xr, yr));
}

void XmlTools::readYAlignment(UElement *ele, PropertyId id, QString value, QString &err)
{
    Q_ASSERT(ele);
    if(!ele) { return; }

    bool ok;
    int yr = value.toInt(&ok);
    if (!ok) {
        err += QCoreApplication::translate("Serializer", "[%1]'s property(%2) is %3, which is invalid.\n").arg(ele->name()).arg(id).arg(value);
        return;
    }
    int xr = SerializerUtil::toXmlXYAlignment(ele->getProperty(PropertyId::alignment).toInt(), false);

    ele->setProperty(PropertyId::alignment, SerializerUtil::fromXmlViewAlignment(xr, yr));
}

void XmlTools::readRectValue(UElement *ele, PropertyId id, QString value, QString &err)
{
    Q_ASSERT(ele);
    if(!ele) { return; }

    QRectF rect = fromXmlRect(value, err);
    ele->setProperty(PropertyId(id), QVariant(rect.x()));
    ele->setProperty(PropertyId(id + 1), QVariant(rect.y()));
    ele->setProperty(PropertyId(id + 2), QVariant(rect.width()));
    ele->setProperty(PropertyId(id + 3), QVariant(rect.height()));
}

void XmlTools::readStringValue(UElement *ele, PropertyId id, QString value, QString &err)
{
    (void)err;

    Q_ASSERT(ele);
    if(!ele) { return; }

    ele->setProperty(id, QVariant(value));
}

QString XmlTools::toXmlColor(QColor color)
{
    if(NumberUtil::aboutEqual(1, color.alphaF())) {
        return QString("rgb(%1, %2, %3)").arg(color.red()).arg(color.green()).arg(color.blue());
    }
    return QString("rgba(%1, %2, %3, %4)").arg(color.red()).arg(color.green()).arg(color.blue()).arg(color.alphaF());
}

QColor XmlTools::fromXmlColor(QString colorStr, QString &err)
{
    static const QColor defaultColor(Qt::white);

    if(colorStr.isEmpty()) {
        err = QCoreApplication::translate("Serializer", "the color string is empty");
        return defaultColor;
    }

    if(colorStr.startsWith("rgba(")) {
        if(!checkRGBAColorStr(colorStr)) {
            err = QCoreApplication::translate("Serializer", "the rgba string is invalid color");
            return defaultColor;
        }
        colorStr.remove("rgba(").remove(")");
        QStringList list = colorStr.split(",");
        return QColor(list[0].toInt(), list[1].toInt(), list[2].toInt(), (int)(list[3].toDouble()*255));

    }else if(colorStr.startsWith("rgb(")) {
        if(!checkRGBColorStr(colorStr)) {
            err = QCoreApplication::translate("Serializer", "the rgb string is invalid color");
            return defaultColor;
        }
        colorStr.remove("rgb(").remove(")");
        QStringList list = colorStr.split(",");
        return QColor(list[0].toInt(), list[1].toInt(), list[2].toInt());
    }
    if(!QColor(colorStr).isValid()) {
        err = QCoreApplication::translate("Serializer", "the color is invalid");
        return defaultColor;
    }

    return QColor(colorStr);
}

bool XmlTools::checkRGBAColorStr(QString colorStr)
{
    if(colorStr.isEmpty()) return false;

    QString regex = QLatin1String("rgba\\(\\s*\\d+\\s*,\\s*\\d+\\s*,\\s*\\d+\\s*,\\s*\\d\\.?\\d*\\s*\\)");
    QRegExp rx(regex);

    return rx.exactMatch(colorStr);
}

bool XmlTools::checkRGBColorStr(QString colorStr)
{
    if(colorStr.isEmpty()) return false;

    QString regex = QLatin1String("rgb\\(\\s*\\d+\\s*,\\s*\\d+\\s*,\\s*\\d+\\s*\\)");
    QRegExp rx(regex);

    return rx.exactMatch(colorStr);
}

QString XmlTools::toXmlRect(UElement *ele, PropertyId pid)
{
    double x = ele->getProperty(pid).toDouble();
    double y = ele->getProperty(PropertyId(pid + 1)).toDouble();
    double w = ele->getProperty(PropertyId(pid + 2)).toDouble();
    double h = ele->getProperty(PropertyId(pid + 3)).toDouble();

    return QString("%1,%2,%3,%4").arg(x).arg(y).arg(w).arg(h);
}

QRectF XmlTools::fromXmlRect(QString rectStr, QString &err)
{
    QRectF rect;
    bool result = checkRectStr(rectStr);
    if(!result) {
        err += QCoreApplication::translate("Serializer", "the value of image rect is invalid.\n");
        rect = QRectF(0,0,0,0);
    }else {
        QStringList list = rectStr.split(",");
        rect = QRectF(list[0].toDouble(), list[1].toDouble(), list[2].toDouble(), list[3].toDouble());
    }
    return rect;
}

bool XmlTools::checkRectStr(QString rectStr)
{
    if(rectStr.isEmpty())  return false;

    QString regex = QLatin1String("\\s*\\-*\\d+\\.?\\d*\\s*,\\s*\\-*\\d+\\.?\\d*\\s*,\\s*\\d+\\.?\\d*\\s*,\\s*\\d+\\.?\\d*\\s*");
    QRegExp rx(regex);

    return rx.exactMatch(rectStr);
}
