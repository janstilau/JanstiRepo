#ifndef QACTION_H
#define QACTION_H

#include <QtWidgets/qtwidgetsglobal.h>
#include <QtGui/qkeysequence.h>
#include <QtCore/qstring.h>
#include <QtWidgets/qwidget.h>
#include <QtCore/qvariant.h>
#include <QtGui/qicon.h>

QT_BEGIN_NAMESPACE


#ifndef QT_NO_ACTION

class QMenu;
class QActionGroup;
class QActionPrivate;
class QGraphicsWidget;

// 这是一个数据类, 它被各个 view 进行添加.
// 这个数据类, 存储了一些显示相关的一些东西, 存储了回调关系.
// 在 View 被点击之后, 会触发这个类的事件, 然后这个类会触发对应的 connnection.

class Q_WIDGETS_EXPORT QAction : public QObject
{
    Q_OBJECT
    Q_DECLARE_PRIVATE(QAction)

    // Q_PROPERTY 很鸡肋, 属性声明了之后, Set 方法, Get 方法全部要自己实现了, NOTIFY changed 很好用.
    // Q_PROPERTY 里面, 属性名真正的存储没有任何关系, 它仅仅是在 元信息里面进行了体现.
    // QObject 里面, 成员变量都放在对应的 Class##Private 类里面.
    Q_PROPERTY(bool checkable READ isCheckable WRITE setCheckable NOTIFY changed)
    // DESIGNABLE 使得可以在 UI 编辑界面, 直接可以在 UI 的属性列表上进行设置.
    Q_PROPERTY(bool checked READ isChecked WRITE setChecked DESIGNABLE isCheckable NOTIFY toggled)
    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY changed)
    Q_PROPERTY(QIcon icon READ icon WRITE setIcon NOTIFY changed)
    Q_PROPERTY(QString text READ text WRITE setText NOTIFY changed)
    Q_PROPERTY(QString iconText READ iconText WRITE setIconText NOTIFY changed)
    Q_PROPERTY(QString toolTip READ toolTip WRITE setToolTip NOTIFY changed)
    Q_PROPERTY(QString statusTip READ statusTip WRITE setStatusTip NOTIFY changed)
    Q_PROPERTY(QString whatsThis READ whatsThis WRITE setWhatsThis NOTIFY changed)
    Q_PROPERTY(QFont font READ font WRITE setFont NOTIFY changed)
#ifndef QT_NO_SHORTCUT
    Q_PROPERTY(QKeySequence shortcut READ shortcut WRITE setShortcut NOTIFY changed)
    Q_PROPERTY(Qt::ShortcutContext shortcutContext READ shortcutContext WRITE setShortcutContext NOTIFY changed)
    Q_PROPERTY(bool autoRepeat READ autoRepeat WRITE setAutoRepeat NOTIFY changed)
#endif
    Q_PROPERTY(bool visible READ isVisible WRITE setVisible NOTIFY changed)
    Q_PROPERTY(MenuRole menuRole READ menuRole WRITE setMenuRole NOTIFY changed)
    Q_PROPERTY(bool iconVisibleInMenu READ isIconVisibleInMenu WRITE setIconVisibleInMenu NOTIFY changed)
    Q_PROPERTY(bool shortcutVisibleInContextMenu READ isShortcutVisibleInContextMenu WRITE setShortcutVisibleInContextMenu NOTIFY changed)
    Q_PROPERTY(Priority priority READ priority WRITE setPriority)

public:
    // note this is copied into qplatformmenu.h, which must stay in sync
    enum MenuRole { NoRole = 0, TextHeuristicRole, ApplicationSpecificRole, AboutQtRole,
                    AboutRole, PreferencesRole, QuitRole };
    Q_ENUM(MenuRole)
    enum Priority { LowPriority = 0,
                    NormalPriority = 128,
                    HighPriority = 256};
    Q_ENUM(Priority)

    explicit QAction(QObject *parent = nullptr);
    explicit QAction(const QString &text, QObject *parent = nullptr);
    explicit QAction(const QIcon &icon, const QString &text, QObject *parent = nullptr);

    ~QAction();

    void setActionGroup(QActionGroup *group);
    QActionGroup *actionGroup() const;
    void setIcon(const QIcon &icon);
    QIcon icon() const;

    void setText(const QString &text);
    QString text() const;

    void setIconText(const QString &text);
    QString iconText() const;

    void setToolTip(const QString &tip);
    QString toolTip() const;

    void setStatusTip(const QString &statusTip);
    QString statusTip() const;

    void setWhatsThis(const QString &what);
    QString whatsThis() const;

    void setPriority(Priority priority);
    Priority priority() const;

#if QT_CONFIG(menu)
    QMenu *menu() const;
    void setMenu(QMenu *menu);
#endif

    void setSeparator(bool b);
    bool isSeparator() const;

#ifndef QT_NO_SHORTCUT
    void setShortcut(const QKeySequence &shortcut);
    QKeySequence shortcut() const;

    void setShortcuts(const QList<QKeySequence> &shortcuts);
    void setShortcuts(QKeySequence::StandardKey);
    QList<QKeySequence> shortcuts() const;

    void setShortcutContext(Qt::ShortcutContext context);
    Qt::ShortcutContext shortcutContext() const;

    void setAutoRepeat(bool);
    bool autoRepeat() const;
#endif

    void setFont(const QFont &font);
    QFont font() const;

    void setCheckable(bool);
    bool isCheckable() const;

    QVariant data() const;
    void setData(const QVariant &var);

    bool isChecked() const;

    bool isEnabled() const;

    bool isVisible() const;

    enum ActionEvent { Trigger, Hover };
    void activate(ActionEvent event);
    bool showStatusText(QWidget *widget = nullptr);

    void setMenuRole(MenuRole menuRole);
    MenuRole menuRole() const;

    void setIconVisibleInMenu(bool visible);
    bool isIconVisibleInMenu() const;

    void setShortcutVisibleInContextMenu(bool show);
    bool isShortcutVisibleInContextMenu() const;

    QWidget *parentWidget() const;

    QList<QWidget *> associatedWidgets() const;
#if QT_CONFIG(graphicsview)
    QList<QGraphicsWidget *> associatedGraphicsWidgets() const; // ### suboptimal
#endif

protected:
    bool event(QEvent *) override;
    QAction(QActionPrivate &dd, QObject *parent);

public Q_SLOTS:
    void trigger() { activate(Trigger); }
    void hover() { activate(Hover); }
    void setChecked(bool);
    void toggle();
    void setEnabled(bool);
    inline void setDisabled(bool b) { setEnabled(!b); }
    void setVisible(bool);

Q_SIGNALS:
    void changed();
    void triggered(bool checked = false);
    void hovered();
    void toggled(bool);

private:
    Q_DISABLE_COPY(QAction)

    friend class QGraphicsWidget;
    friend class QWidget;
    friend class QActionGroup;
    friend class QMenu;
    friend class QMenuPrivate;
    friend class QMenuBar;
    friend class QToolButton;
#ifdef Q_OS_MAC
    friend void qt_mac_clear_status_text(QAction *action);
#endif
};

#ifndef QT_NO_DEBUG_STREAM
Q_WIDGETS_EXPORT QDebug operator<<(QDebug, const QAction *);
#endif

QT_BEGIN_INCLUDE_NAMESPACE
#include <QtWidgets/qactiongroup.h>
QT_END_INCLUDE_NAMESPACE

#endif // QT_NO_ACTION

QT_END_NAMESPACE

#endif // QACTION_H
