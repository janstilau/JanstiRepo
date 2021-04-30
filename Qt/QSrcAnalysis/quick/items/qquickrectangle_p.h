#ifndef QQUICKRECTANGLE_P_H
#define QQUICKRECTANGLE_P_H

//
//  W A R N I N G
//  -------------
//
// This file is not part of the Qt API.  It exists purely as an
// implementation detail.  This header file may change from version to
// version without notice, or even be removed.
//
// We mean it.
//

#include "qquickitem.h"

#include <QtGui/qbrush.h>

#include <private/qtquickglobal_p.h>

QT_BEGIN_NAMESPACE

class Q_QUICK_PRIVATE_EXPORT QQuickPen : public QObject
{
    Q_OBJECT

    Q_PROPERTY(qreal width READ width WRITE setWidth NOTIFY penChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY penChanged)
    Q_PROPERTY(bool pixelAligned READ pixelAligned WRITE setPixelAligned NOTIFY penChanged)
    QML_ANONYMOUS
public:
    QQuickPen(QObject *parent=nullptr);

    qreal width() const;
    void setWidth(qreal w);

    QColor color() const;
    void setColor(const QColor &c);

    bool pixelAligned() const;
    void setPixelAligned(bool aligned);

    bool isValid() const;

Q_SIGNALS:
    void penChanged();

private:
    qreal m_width;
    QColor m_color;
    bool m_aligned : 1;
    bool m_valid : 1;
};

class Q_QUICK_PRIVATE_EXPORT QQuickGradientStop : public QObject
{
    Q_OBJECT

    Q_PROPERTY(qreal position READ position WRITE setPosition)
    Q_PROPERTY(QColor color READ color WRITE setColor)
    QML_NAMED_ELEMENT(GradientStop)

public:
    QQuickGradientStop(QObject *parent=nullptr);

    qreal position() const;
    void setPosition(qreal position);

    QColor color() const;
    void setColor(const QColor &color);

private:
    void updateGradient();

private:
    qreal m_position;
    QColor m_color;
};

class Q_QUICK_PRIVATE_EXPORT QQuickGradient : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QQmlListProperty<QQuickGradientStop> stops READ stops)
    Q_PROPERTY(Orientation orientation READ orientation WRITE setOrientation NOTIFY orientationChanged REVISION 12)
    Q_CLASSINFO("DefaultProperty", "stops")
    QML_NAMED_ELEMENT(Gradient)

    Q_ENUMS(QGradient::Preset)
public:
    QQuickGradient(QObject *parent=nullptr);
    ~QQuickGradient() override;

    enum Orientation { Vertical = Qt::Vertical,
                       Horizontal = Qt::Horizontal };
    Q_ENUM(Orientation)

    QQmlListProperty<QQuickGradientStop> stops();

    Orientation orientation() const { return m_orientation; }
    void setOrientation(Orientation orientation);

    QGradientStops gradientStops() const;

Q_SIGNALS:
    void updated();
    void orientationChanged();

private:
    void doUpdate();

private:
    QList<QQuickGradientStop *> m_stops;
    Orientation m_orientation = Vertical;
    friend class QQuickRectangle;
    friend class QQuickGradientStop;
};

class QQuickRectanglePrivate;
class Q_QUICK_PRIVATE_EXPORT QQuickRectangle : public QQuickItem
{
    Q_OBJECT

    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(QJSValue gradient READ gradient WRITE setGradient RESET resetGradient)
    Q_PROPERTY(QQuickPen * border READ border CONSTANT)
    Q_PROPERTY(qreal radius READ radius WRITE setRadius NOTIFY radiusChanged)
    QML_NAMED_ELEMENT(Rectangle)
public:
    QQuickRectangle(QQuickItem *parent=nullptr);

    QColor color() const;
    void setColor(const QColor &);

    QQuickPen *border();

    QJSValue gradient() const;
    void setGradient(const QJSValue &gradient);
    void resetGradient();

    qreal radius() const;
    void setRadius(qreal radius);

Q_SIGNALS:
    void colorChanged();
    void radiusChanged();

protected:
    QSGNode *updatePaintNode(QSGNode *, UpdatePaintNodeData *) override;

private Q_SLOTS:
    void doUpdate();

private:
    Q_DISABLE_COPY(QQuickRectangle)
    Q_DECLARE_PRIVATE(QQuickRectangle)
};

QT_END_NAMESPACE

QML_DECLARE_TYPE(QQuickPen)
QML_DECLARE_TYPE(QQuickGradientStop)
QML_DECLARE_TYPE(QQuickGradient)
QML_DECLARE_TYPE(QQuickRectangle)

#endif // QQUICKRECTANGLE_P_H
