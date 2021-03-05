#ifndef QFONTINFO_H
#define QFONTINFO_H

#include <QtGui/qtguiglobal.h>
#include <QtGui/qfont.h>
#include <QtCore/qsharedpointer.h>

QT_BEGIN_NAMESPACE

// 这个类里面, 存储的是真实使用的 Font 的信息,
// 操作系统, 会选择最接近 Font 的字体做实际的绘制工作, 这些信息, 就存在 QFontInfo 里面.
class Q_GUI_EXPORT QFontInfo
{
public:
    QFontInfo(const QFont &);
    QFontInfo(const QFontInfo &);
    ~QFontInfo();

    QFontInfo &operator=(const QFontInfo &);

    void swap(QFontInfo &other) { qSwap(d, other.d); }

    QString family() const;
    QString styleName() const;
    int pixelSize() const;
    int pointSize() const;
    qreal pointSizeF() const;
    bool italic() const;
    QFont::Style style() const;
    int weight() const;
    inline bool bold() const { return weight() > QFont::Normal; }
    bool underline() const;
    bool overline() const;
    bool strikeOut() const;
    bool fixedPitch() const;
    QFont::StyleHint styleHint() const;
    bool exactMatch() const;

private:
    QExplicitlySharedDataPointer<QFontPrivate> d;
};

Q_DECLARE_SHARED(QFontInfo)

QT_END_NAMESPACE

#endif // QFONTINFO_H
