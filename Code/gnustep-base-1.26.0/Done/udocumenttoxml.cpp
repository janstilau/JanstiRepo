//license-placeholder 2017-1-1 Tao Cheng

#include "udocument.h"
#include "udocumenttoxml.h"
#include "xmltools.h"
#include "docmanager.h"
#include "ucomponent.h"
#include <QFile>
#include <QXmlStreamAttributes>
#include <QCoreApplication>

using namespace hoolai;

UDocumentToXml::UDocumentToXml(UDocument *doc)
    : mDoc(doc)
    , mStartElement(nullptr)
    , mOutputElement(nullptr)
    , mXmlWriter(nullptr)
    , mXmlReader(nullptr)
{
    setIdToAttributeNameMap();
}

bool UDocumentToXml::write(QXmlStreamWriter *writer, QString &err)
{
    Q_ASSERT(writer);
    if(!writer) { return false; }

    mXmlWriter = writer;
    mXmlWriter->setAutoFormatting(true);
    return this->write(err);
}

UElement *UDocumentToXml::read(QXmlStreamReader *reader, QString &err)
{
    Q_ASSERT(reader);
    if (!reader) { return nullptr; }

    mXmlReader = reader;
    if(!this->read(err)) {
        delete mOutputElement;
        return nullptr;
    }
    return mOutputElement;
}

bool UDocumentToXml::read(QString &err)
{
    err.clear();
    if (!mDoc) { return false; }

    UElement *ele = nullptr;
    UElement *parentEle = mStartElement;
    mOutputElement = nullptr;
    // 通过 mXmlReader, 略去了那些复杂的读字符, 分析字符, 略过空字符的操作. 直接在 XML 的解析的上层, 进行业务数据的解析.
    for (auto tokenType = mXmlReader->readNext(); !mXmlReader->atEnd(); tokenType = mXmlReader->readNext()) {
        switch (tokenType) {
        case QXmlStreamReader::StartElement:
        {
            ele = readElement(err);
            if (!ele) { return false; }
            if (!mOutputElement) {
                mOutputElement = ele;
            } else {
                parentEle->addChild(ele);
            }
            parentEle = ele;
            break;
        }
        case QXmlStreamReader::EndElement:
        {
            Q_ASSERT(parentEle);
            if (!parentEle) { return false; }
            parentEle = parentEle->parent();
            break;
        }
        default:  break;
        }
    }
    return true;
}

UElement *UDocumentToXml::readElement(QString &err)
{
    QString nodeName = mXmlReader->name().toString();
    auto ele = mDoc->createElement((UElementType)mNodeNameToType.value(nodeName));
    if(!ele) {
        err += QCoreApplication::translate("Serializer", "element create failed");
        return nullptr;
    }

    XmlTools tools;
    auto map = mNodeNameToAttributeName.value(nodeName);
    for(auto att : mXmlReader->attributes()) {
        auto id = map.key(att.name().toString());
        auto value = att.value();
        switch (id) {
        case PropertyId::id:
        case PropertyId::className:
        case PropertyId::comment:
        case PropertyId::nodeName:
        case PropertyId::exportClassName:
        case PropertyId::text:
        case PropertyId::image:
        case PropertyId::buttonTitle:
        case PropertyId::buttonImage:
        case PropertyId::buttonTitleSelected:
        case PropertyId::buttonImageSelected:
        case PropertyId::buttonTitleHighLighted:
        case PropertyId::buttonImageHighLighted:
        case PropertyId::buttonTitleDisabled:
        case PropertyId::buttonImageDisabled:
        case PropertyId::buttonAction:
        case PropertyId::componentPath:
        {
            tools.readStringValue(ele, id, value.toString(), err);
            break;
        }
        case PropertyId::xPosition:
        case PropertyId::yPosition:
        case PropertyId::width:
        case PropertyId::height:
        case PropertyId::imageBrightness:
        case PropertyId::imageRotation:
        {
            tools.readDoubleValue(ele, id, value.toString(), err);
            break;
        }
        case PropertyId::documentWidth:
        {
            double width = value.toString().toDouble();
            mDoc->setSize(QSize(width, mDoc->size().height()));
            break;
        }
        case PropertyId::documentHeight:
        {
            double height = value.toString().toDouble();
            mDoc->setSize(QSize(mDoc->size().width(), height));
            break;
        }
        case PropertyId::xAlignment:
            tools.readXAlignment(ele, id, value.toString(), err);
            break;
        case PropertyId::yAlignment:
            tools.readYAlignment(ele, id, value.toString(), err);
            break;
        case PropertyId::tag:
        case PropertyId::textAlignment:
        case PropertyId::textSize:
        case PropertyId::buttonState:
        {
            tools.readIntValue(ele, id, value.toString(), err);
            break;
        }
        case PropertyId::locked:
        case PropertyId::visible:
        case PropertyId::sizeIsPercent:
        case PropertyId::positionIsPercent:
        case PropertyId::textIsBold:
        case PropertyId::textIsStroke:
        case PropertyId::imageIsGray:
        case PropertyId::imageIsFlipX:
        case PropertyId::imageIsFlipY:
        case PropertyId::imageRepeatStretch:
        case PropertyId::buttonZoomToTouchDown:
        case PropertyId::buttonRepeatStretch:
        case PropertyId::componentIsShowRoot:
        {
            tools.readBoolValue(ele, id, value.toString(), err);
            break;
        }
        case PropertyId::backgroundColor:
        case PropertyId::imageTintColor:
        case PropertyId::textColorTopLeft:
        case PropertyId::textColorTopRight:
        case PropertyId::textColorBottomLeft:
        case PropertyId::textColorBottomRight:
        case PropertyId::textStrokeColor:
        {
            tools.readColorValue(ele, id, value.toString(), err);
            break;
        }
        case PropertyId::imageX:
        case PropertyId::buttonImageX:
        case PropertyId::buttonImageXSelected:
        case PropertyId::buttonImageXHighLighted:
        case PropertyId::buttonImageXDisabled:
        {
            tools.readRectValue(ele, id, value.toString(), err);
            break;
        }
        default:  break;
        }
    }
    return ele;
}

void UDocumentToXml::setReferencePathList(QList<QString> filePathList)
{
    mReferencePathList = filePathList;
}

bool UDocumentToXml::readComponent(UElement *ele, QString &err)
{
    QString filePath = ele->getProperty(PropertyId::componentPath).toString();

    if(!checkCircularReference(filePath, err)) { return false; }

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        err = QCoreApplication::translate("Serializer", "Reading file failed");
        return false;
    }

    UDocument *doc = new UDocument(DocManager::instance()->elementFactory());
    UDocumentToXml xml(doc);
    xml.setReferencePathList(mReferencePathList);
    QXmlStreamReader reader(&file);
    UElement *outputElement = xml.read(&reader, err);
    if(!outputElement) { return false; }

    auto component = dynamic_cast<UComponent*>(ele);
    component->setContent(outputElement);

    if(mReferencePathList.size() > 1) {
        QString filePath = mReferencePathList.first();
        mReferencePathList.clear();
        mReferencePathList.append(filePath);
    }

    return true;
}

bool UDocumentToXml::checkCircularReference(QString &filePath, QString &err)
{
    if(!mReferencePathList.contains(filePath)) {
        mReferencePathList.append(filePath);
        return true;
    }

    int index = mReferencePathList.indexOf(filePath);
    mReferencePathList.append(filePath);

    QList<QString> circularList;
    for(int i = index; i < mReferencePathList.count(); i++) {
        circularList.append(mReferencePathList.at(i));
    }

    QString info = QCoreApplication::translate("Serializer", "circular reference occurs during loading[%1]:\n").arg(mReferencePathList.first());
    for(int i = 0; i < circularList.count(); i++) {
        info += QCoreApplication::translate("Serializer", "[%1]").arg(circularList.at(i));
        if(i < circularList.count() - 1) {
            info += QLatin1String(" ->\n");
        }
    }
    err = info;
    return false;
}

bool UDocumentToXml::write(QString &err)
{
    err.clear();
    if (!mDoc) { return false; }

    bool result = true;

    mXmlWriter->writeStartDocument();
    result &= writeElement(mStartElement ? mStartElement : mDoc->rootElement(), err);
    mXmlWriter->writeEndDocument();
    
    return result;
}

bool UDocumentToXml::writeElement(UElement *ele, QString &err)
{
    if (!ele) {
        err = QCoreApplication::translate("Serializer", "element is null that in function of %1").arg("writeElement()");
        return false;
    }

    bool result = true;

    writeElementAttributes(ele); // 写自己的数据

    auto children = ele->children();
    for (auto child : children) {
        result &= writeElement(child, err); // 写子数据.
    }

    mXmlWriter->writeEndElement();

    return result;
}

void UDocumentToXml::writeElementAttributes(UElement *ele)
{
    XmlTools tools;
    QString nodeName = mNodeNameToType.key(ele->type());
    mXmlWriter->writeStartElement(nodeName);

    auto map = mNodeNameToAttributeName.value(nodeName);
    auto iterator = map.begin();
    for(; iterator != map.end(); iterator++) {
        auto id = iterator.key();
        switch (id) {
        case PropertyId::id:
        case PropertyId::className:
        case PropertyId::comment:
        case PropertyId::nodeName:
        case PropertyId::exportClassName:
        case PropertyId::xPosition:
        case PropertyId::yPosition:
        case PropertyId::width:
        case PropertyId::height:
        case PropertyId::text:
        case PropertyId::textSize:
        case PropertyId::image:
        case PropertyId::imageBrightness:
        case PropertyId::buttonTitle:
        case PropertyId::buttonImage:
        case PropertyId::buttonTitleSelected:
        case PropertyId::buttonImageSelected:
        case PropertyId::buttonTitleHighLighted:
        case PropertyId::buttonImageHighLighted:
        case PropertyId::buttonTitleDisabled:
        case PropertyId::buttonImageDisabled:
        case PropertyId::buttonState:
        case PropertyId::buttonAction:
        case PropertyId::componentPath:
        {
            tools.writeStringValue(mXmlWriter, iterator.value(), ele, id);
            break;
        }
        case PropertyId::documentWidth:
        {
            mXmlWriter->writeAttribute(QLatin1String("srw"), QString("%1").arg(mDoc->size().width()));
            break;
        }
        case PropertyId::documentHeight:
        {
            mXmlWriter->writeAttribute(QLatin1String("srh"), QString("%1").arg(mDoc->size().height()));
            break;
        }
        case PropertyId::tag:
        case PropertyId::xAlignment:
        case PropertyId::yAlignment:
        case PropertyId::textAlignment:
        {
            tools.writeIntValue(mXmlWriter, iterator.value(), ele, id);
            break;
        }
        case PropertyId::backgroundColor:
        case PropertyId::imageTintColor:
        case PropertyId::textColorTopLeft:
        case PropertyId::textColorTopRight:
        case PropertyId::textColorBottomLeft:
        case PropertyId::textColorBottomRight:
        case PropertyId::textStrokeColor:
        {
            tools.writeColorValue(mXmlWriter, iterator.value(), ele, id);
            break;
        }
        case PropertyId::locked:
        case PropertyId::visible:
        case PropertyId::sizeIsPercent:
        case PropertyId::positionIsPercent:
        case PropertyId::textIsBold:
        case PropertyId::textIsStroke:
        case PropertyId::imageIsGray:
        case PropertyId::imageIsFlipX:
        case PropertyId::imageIsFlipY:
        case PropertyId::imageRepeatStretch:
        case PropertyId::buttonZoomToTouchDown:
        case PropertyId::buttonRepeatStretch:
        case PropertyId::componentIsShowRoot:
        {
            tools.writeBoolValue(mXmlWriter, iterator.value(), ele, id);
            break;
        }
        case PropertyId::imageRotation:
        {
            tools.writeDoubleValue(mXmlWriter, iterator.value(), ele, id);
            break;
        }
        case PropertyId::imageX: 
        case PropertyId::buttonImageX:
        case PropertyId::buttonImageXSelected:
        case PropertyId::buttonImageXHighLighted:
        case PropertyId::buttonImageXDisabled:
            tools.writeRectValue(mXmlWriter, iterator.value(), ele, id);
            break;
        default: break;
        }
    }
}

void UDocumentToXml::setIdToAttributeNameMap()
{
    QMap<PropertyId, QString> viewMap{
        { PropertyId::id, QLatin1String("id") },
        { PropertyId::className, QLatin1String("clsn") },
        { PropertyId::comment, QLatin1String("pn") },
        { PropertyId::exportClassName, QLatin1String("exc") },
        { PropertyId::nodeName, QLatin1String("nn") },
        { PropertyId::xPosition, QLatin1String("x") },
        { PropertyId::yPosition, QLatin1String("y") },
        { PropertyId::width, QLatin1String("w") },
        { PropertyId::height, QLatin1String("h") },
        { PropertyId::documentWidth, QLatin1String("srw") },
        { PropertyId::documentHeight, QLatin1String("srh") },
        { PropertyId::xAlignment, QLatin1String("xr") },
        { PropertyId::yAlignment, QLatin1String("yr") },
        { PropertyId::backgroundColor, QLatin1String("bgc") },
        { PropertyId::visible, QLatin1String("iv") },
        { PropertyId::sizeIsPercent, QLatin1String("sp") },
        { PropertyId::positionIsPercent, QLatin1String("pp") },
        { PropertyId::tag, QLatin1String("tag") },
        { PropertyId::locked, QLatin1String("locked") },
    };

    QMap<PropertyId, QString> labelMap = viewMap;
    labelMap.unite({
        { PropertyId::text, QLatin1String("t") },
        { PropertyId::textSize, QLatin1String("ts") },
        { PropertyId::textColorTopLeft, QLatin1String("tctl") },
        { PropertyId::textColorTopRight, QLatin1String("tctr") },
        { PropertyId::textColorBottomLeft, QLatin1String("tcbl") },
        { PropertyId::textColorBottomRight, QLatin1String("tcbr") },
        { PropertyId::textStrokeColor, QLatin1String("sc") },
        { PropertyId::textIsStroke, QLatin1String("stroke") },
        { PropertyId::textIsBold, QLatin1String("bold") },
        { PropertyId::textAlignment, QLatin1String("ta") },
    });

    QMap<PropertyId, QString> imageMap = viewMap;
    imageMap.unite({
        { PropertyId::image, QLatin1String("i") },
        { PropertyId::imageX, QLatin1String("ic") },
        { PropertyId::imageTintColor, QLatin1String("tc") },
        { PropertyId::imageBrightness, QLatin1String("bri") },
        { PropertyId::imageIsGray, QLatin1String("gray") },
        { PropertyId::imageRepeatStretch, QLatin1String("repeat") },
        { PropertyId::imageIsFlipX, QLatin1String("fx") },
        { PropertyId::imageIsFlipY, QLatin1String("fy") },
        { PropertyId::imageRotation, QLatin1String("rot") }
    });

    QMap<PropertyId, QString> buttonMap = labelMap;
    buttonMap.remove(PropertyId::text);
    buttonMap.unite({
        { PropertyId::buttonTitle, QLatin1String("nt") },
        { PropertyId::buttonImage, QLatin1String("ni") },
        { PropertyId::buttonImageX, QLatin1String("nic") },
        { PropertyId::buttonTitleSelected, QLatin1String("st") },
        { PropertyId::buttonImageSelected, QLatin1String("si") },
        { PropertyId::buttonImageXSelected, QLatin1String("sic") },
        { PropertyId::buttonTitleHighLighted, QLatin1String("ht") },
        { PropertyId::buttonImageHighLighted, QLatin1String("hi") },
        { PropertyId::buttonImageXHighLighted, QLatin1String("hic") },
        { PropertyId::buttonTitleDisabled, QLatin1String("dt") },
        { PropertyId::buttonImageDisabled, QLatin1String("di") },
        { PropertyId::buttonImageXDisabled, QLatin1String("dic") },
        { PropertyId::buttonZoomToTouchDown, QLatin1String("zot") },
        { PropertyId::buttonRepeatStretch, QLatin1String("repeat") },
        { PropertyId::buttonState, QLatin1String("state") },
        { PropertyId::buttonAction, QLatin1String("act") }
    });

    QMap<PropertyId, QString> editboxMap = labelMap;
    editboxMap.remove(PropertyId::text);
    editboxMap.unite({
        { PropertyId::text, QLatin1String("et") }
    });

    QMap<PropertyId, QString> componentMap = viewMap;
    componentMap.unite({
         { PropertyId::componentPath, QLatin1String("path") },
         { PropertyId::componentIsShowRoot, QLatin1String("showRoot") },
    });

    mNodeNameToType.clear();
    mNodeNameToType.unite({
        { XmlTools::NODE_NAME_BUTTON, UElementType::Button },
        { XmlTools::NODE_NAME_EDITBOX, UElementType::EditBox },
        { XmlTools::NODE_NAME_IMAGE, UElementType::Image },
        { XmlTools::NODE_NAME_LABEL, UElementType::Label },
        { XmlTools::NODE_NAME_SCROLLVIEW, UElementType::ScrollView },
        { XmlTools::NODE_NAME_VIEW, UElementType::View },
        { XmlTools::NODE_NAME_COMPONENT, UElementType::Component}
    });
    
    mNodeNameToAttributeName.clear();
    mNodeNameToAttributeName.unite({
        { XmlTools::NODE_NAME_VIEW, viewMap },
        { XmlTools::NODE_NAME_SCROLLVIEW, viewMap },
        { XmlTools::NODE_NAME_LABEL, labelMap },
        { XmlTools::NODE_NAME_IMAGE, imageMap },
        { XmlTools::NODE_NAME_BUTTON, buttonMap },
        { XmlTools::NODE_NAME_EDITBOX, editboxMap },
        { XmlTools::NODE_NAME_COMPONENT, componentMap }
    });
}

void UDocumentToXml::setStartElement(UElement *startElement)
{
    mStartElement = startElement;
}
