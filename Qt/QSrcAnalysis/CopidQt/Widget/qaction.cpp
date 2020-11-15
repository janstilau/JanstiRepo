/****************************************************************************
**
** Copyright (C) 2016 The Qt Company Ltd.
** Contact: https://www.qt.io/licensing/
**
** This file is part of the QtWidgets module of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:LGPL$
** Commercial License Usage
** Licensees holding valid commercial Qt licenses may use this file in
** accordance with the commercial license agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and The Qt Company. For licensing terms
** and conditions see https://www.qt.io/terms-conditions. For further
** information use the contact form at https://www.qt.io/contact-us.
**
** GNU Lesser General Public License Usage
** Alternatively, this file may be used under the terms of the GNU Lesser
** General Public License version 3 as published by the Free Software
** Foundation and appearing in the file LICENSE.LGPL3 included in the
** packaging of this file. Please review the following information to
** ensure the GNU Lesser General Public License version 3 requirements
** will be met: https://www.gnu.org/licenses/lgpl-3.0.html.
**
** GNU General Public License Usage
** Alternatively, this file may be used under the terms of the GNU
** General Public License version 2.0 or (at your option) the GNU General
** Public license version 3 or any later version approved by the KDE Free
** Qt Foundation. The licenses are as published by the Free Software
** Foundation and appearing in the file LICENSE.GPL2 and LICENSE.GPL3
** included in the packaging of this file. Please review the following
** information to ensure the GNU General Public License requirements will
** be met: https://www.gnu.org/licenses/gpl-2.0.html and
** https://www.gnu.org/licenses/gpl-3.0.html.
**
** $QT_END_LICENSE$
**
****************************************************************************/

#include "qaction.h"
#include "qactiongroup.h"

#ifndef QT_NO_ACTION
#include "qaction_p.h"
#include "qapplication.h"
#include "qevent.h"
#include "qlist.h"
#include "qstylehints.h"
#include <private/qshortcutmap_p.h>
#include <private/qapplication_p.h>
#if QT_CONFIG(menu)
#include <private/qmenu_p.h>
#endif
#include <private/qdebug_p.h>

#define QAPP_CHECK(functionName) \
    if (Q_UNLIKELY(!qApp)) { \
        qWarning("QAction: Initialize QApplication before calling '" functionName "'."); \
        return; \
    }

QT_BEGIN_NAMESPACE

/*
  internal: guesses a descriptive text from a text suited for a menu entry
 */
static QString qt_strippedText(QString s)
{
    s.remove(QLatin1String("..."));
    for (int i = 0; i < s.size(); ++i) {
        if (s.at(i) == QLatin1Char('&'))
            s.remove(i, 1);
    }
    return s.trimmed();
}

// QActionPrivate 仅仅是一个数据类, 没有太多逻辑在里面.
QActionPrivate::QActionPrivate() : group(0), enabled(1), forceDisabled(0),
                                   visible(1), forceInvisible(0), checkable(0), checked(0), separator(0), fontSet(false),
                                   iconVisibleInMenu(-1),
                                   shortcutVisibleInContextMenu(-1),
                                   menuRole(QAction::TextHeuristicRole),
                                   priority(QAction::NormalPriority)
{
#ifndef QT_NO_SHORTCUT
    shortcutId = 0;
    shortcutContext = Qt::WindowShortcut;
    autorepeat = true;
#endif
}

QActionPrivate::~QActionPrivate()
{
}

bool QActionPrivate::showStatusText(QWidget *widget, const QString &str)
{
#if !QT_CONFIG(statustip)
    Q_UNUSED(widget);
    Q_UNUSED(str);
#else
    if(QObject *object = widget ? widget : parent) {
        QStatusTipEvent tip(str);
        // Qt 里面, 很多的处理, 都是根据 QApplication 的 event 进行的.
        QApplication::sendEvent(object, &tip);
        return true;
    }
#endif
    return false;
}

// 可以看到, Qt 里面, 很多时候事件的传递, 是需要相关的类, 存储一下对应的映射关系. 然后在合适的时候, 直接进行 event 的 send 处理.
// 就算是在 iOS 里面, 事件发生了, 也是直接可以获取到事件处理的 View 的.
// 目前, 认为 Applicaiton 可以直接指导应该发送 Event 的对象.
void QActionPrivate::sendDataChanged()
{
    Q_Q(QAction);
    QActionEvent e(QEvent::ActionChanged, q);
    for (int i = 0; i < widgets.size(); ++i) {
        QWidget *w = widgets.at(i);
        QApplication::sendEvent(w, &e);
    }
    QApplication::sendEvent(q, &e);

    emit q->changed();
}

#ifndef QT_NO_SHORTCUT
void QActionPrivate::redoGrab(QShortcutMap &map)
{
    Q_Q(QAction);
    if (shortcutId)
        map.removeShortcut(shortcutId, q);
    if (shortcut.isEmpty())
        return;
    shortcutId = map.addShortcut(q, shortcut, shortcutContext, qWidgetShortcutContextMatcher);
    if (!enabled)
        map.setShortcutEnabled(false, shortcutId, q);
    if (!autorepeat)
        map.setShortcutAutoRepeat(false, shortcutId, q);
}

void QActionPrivate::redoGrabAlternate(QShortcutMap &map)
{
    Q_Q(QAction);
    for(int i = 0; i < alternateShortcutIds.count(); ++i) {
        if (const int id = alternateShortcutIds.at(i))
            map.removeShortcut(id, q);
    }
    alternateShortcutIds.clear();
    if (alternateShortcuts.isEmpty())
        return;
    for(int i = 0; i < alternateShortcuts.count(); ++i) {
        const QKeySequence& alternate = alternateShortcuts.at(i);
        if (!alternate.isEmpty())
            alternateShortcutIds.append(map.addShortcut(q, alternate, shortcutContext, qWidgetShortcutContextMatcher));
        else
            alternateShortcutIds.append(0);
    }
    if (!enabled) {
        for(int i = 0; i < alternateShortcutIds.count(); ++i) {
            const int id = alternateShortcutIds.at(i);
            map.setShortcutEnabled(false, id, q);
        }
    }
    if (!autorepeat) {
        for(int i = 0; i < alternateShortcutIds.count(); ++i) {
            const int id = alternateShortcutIds.at(i);
            map.setShortcutAutoRepeat(false, id, q);
        }
    }
}

void QActionPrivate::setShortcutEnabled(bool enable, QShortcutMap &map)
{
    Q_Q(QAction);
    if (shortcutId)
        map.setShortcutEnabled(enable, shortcutId, q);
    for(int i = 0; i < alternateShortcutIds.count(); ++i) {
        if (const int id = alternateShortcutIds.at(i))
            map.setShortcutEnabled(enable, id, q);
    }
}
#endif // QT_NO_SHORTCUT


QAction::QAction(QObject* parent)
    : QAction(*new QActionPrivate, parent)
{
}

QAction::QAction(const QString &text, QObject* parent)
    : QAction(parent)
{
    Q_D(QAction);
    d->text = text;
}

QAction::QAction(const QIcon &icon, const QString &text, QObject* parent)
    : QAction(text, parent)
{
    Q_D(QAction);
    d->icon = icon;
}

QAction::QAction(QActionPrivate &dd, QObject *parent)
    : QObject(dd, parent)
{
    Q_D(QAction);
    d->group = qobject_cast<QActionGroup *>(parent);
    if (d->group)
        d->group->addAction(this);
}

// 不断地通过 Parent 寻找, 指导找到一个 widget 的对象.
QWidget *QAction::parentWidget() const
{
    QObject *ret = parent();
    while (ret && !ret->isWidgetType())
        ret = ret->parent();
    return (QWidget*)ret;
}


QList<QWidget *> QAction::associatedWidgets() const
{
    Q_D(const QAction);
    return d->widgets;
}

QList<QGraphicsWidget *> QAction::associatedGraphicsWidgets() const
{
    Q_D(const QAction);
    return d->graphicsWidgets;
}

void QAction::setShortcut(const QKeySequence &shortcut)
{
    QAPP_CHECK("setShortcut");

    Q_D(QAction);
    if (d->shortcut == shortcut)
        return;

    d->shortcut = shortcut;
    d->redoGrab(qApp->d_func()->shortcutMap);
    d->sendDataChanged();
}

void QAction::setShortcuts(const QList<QKeySequence> &shortcuts)
{
    Q_D(QAction);

    QList <QKeySequence> listCopy = shortcuts;

    QKeySequence primary;
    if (!listCopy.isEmpty())
        primary = listCopy.takeFirst();

    if (d->shortcut == primary && d->alternateShortcuts == listCopy)
        return;

    QAPP_CHECK("setShortcuts");

    d->shortcut = primary;
    d->alternateShortcuts = listCopy;
    d->redoGrab(qApp->d_func()->shortcutMap);
    d->redoGrabAlternate(qApp->d_func()->shortcutMap);
    d->sendDataChanged();
}

void QAction::setShortcuts(QKeySequence::StandardKey key)
{
    QList <QKeySequence> list = QKeySequence::keyBindings(key);
    setShortcuts(list);
}

QKeySequence QAction::shortcut() const
{
    Q_D(const QAction);
    return d->shortcut;
}

/*!
    \since 4.2

    Returns the list of shortcuts, with the primary shortcut as
    the first element of the list.

    \sa setShortcuts()
*/
QList<QKeySequence> QAction::shortcuts() const
{
    Q_D(const QAction);
    QList <QKeySequence> shortcuts;
    if (!d->shortcut.isEmpty())
        shortcuts << d->shortcut;
    if (!d->alternateShortcuts.isEmpty())
        shortcuts << d->alternateShortcuts;
    return shortcuts;
}

/*!
    \property QAction::shortcutContext
    \brief the context for the action's shortcut

    Valid values for this property can be found in \l Qt::ShortcutContext.
    The default value is Qt::WindowShortcut.
*/
void QAction::setShortcutContext(Qt::ShortcutContext context)
{
    Q_D(QAction);
    if (d->shortcutContext == context)
        return;
    QAPP_CHECK("setShortcutContext");
    d->shortcutContext = context;
    d->redoGrab(qApp->d_func()->shortcutMap);
    d->redoGrabAlternate(qApp->d_func()->shortcutMap);
    d->sendDataChanged();
}

Qt::ShortcutContext QAction::shortcutContext() const
{
    Q_D(const QAction);
    return d->shortcutContext;
}

void QAction::setAutoRepeat(bool on)
{
    Q_D(QAction);
    if (d->autorepeat == on)
        return;
    QAPP_CHECK("setAutoRepeat");
    d->autorepeat = on;
    d->redoGrab(qApp->d_func()->shortcutMap);
    d->redoGrabAlternate(qApp->d_func()->shortcutMap);
    d->sendDataChanged();
}

bool QAction::autoRepeat() const
{
    Q_D(const QAction);
    return d->autorepeat;
}
#endif // QT_NO_SHORTCUT

/*!
    \property QAction::font
    \brief the action's font

    The font property is used to render the text set on the
    QAction. The font will can be considered a hint as it will not be
    consulted in all cases based upon application and style.

    By default, this property contains the application's default font.

    \sa QAction::setText(), QStyle
*/
void QAction::setFont(const QFont &font)
{
    Q_D(QAction);
    if (d->font == font)
        return;

    d->fontSet = true;
    d->font = font;
    d->sendDataChanged();
}

QFont QAction::font() const
{
    Q_D(const QAction);
    return d->font;
}


/*!
    Destroys the object and frees allocated resources.
*/
QAction::~QAction()
{
    Q_D(QAction);
    for (int i = d->widgets.size()-1; i >= 0; --i) {
        QWidget *w = d->widgets.at(i);
        w->removeAction(this);
    }
#if QT_CONFIG(graphicsview)
    for (int i = d->graphicsWidgets.size()-1; i >= 0; --i) {
        QGraphicsWidget *w = d->graphicsWidgets.at(i);
        w->removeAction(this);
    }
#endif
    if (d->group)
        d->group->removeAction(this);
#ifndef QT_NO_SHORTCUT
    if (d->shortcutId && qApp) {
        qApp->d_func()->shortcutMap.removeShortcut(d->shortcutId, this);
        for(int i = 0; i < d->alternateShortcutIds.count(); ++i) {
            const int id = d->alternateShortcutIds.at(i);
            qApp->d_func()->shortcutMap.removeShortcut(id, this);
        }
    }
#endif
}

void QAction::setActionGroup(QActionGroup *group)
{
    Q_D(QAction);
    if(group == d->group)
        return;

    if(d->group)
        d->group->removeAction(this);
    d->group = group;
    if(group)
        group->addAction(this); // 这里, 在 set 函数里面封装关系的管理.
    d->sendDataChanged();
}

QActionGroup *QAction::actionGroup() const
{
    Q_D(const QAction);
    return d->group;
}

void QAction::setIcon(const QIcon &icon)
{
    Q_D(QAction);
    d->icon = icon;
    d->sendDataChanged();
}

QIcon QAction::icon() const
{
    Q_D(const QAction);
    return d->icon;
}

QMenu *QAction::menu() const
{
    Q_D(const QAction);
    return d->menu;
}

/*!
    Sets the menu contained by this action to the specified \a menu.
*/
void QAction::setMenu(QMenu *menu)
{
    Q_D(QAction);
    if (d->menu)
        d->menu->d_func()->setOverrideMenuAction(0); //we reset the default action of any previous menu
    d->menu = menu;
    if (menu)
        menu->d_func()->setOverrideMenuAction(this);
    d->sendDataChanged();
}
#endif // QT_CONFIG(menu)

void QAction::setSeparator(bool b)
{
    Q_D(QAction);
    if (d->separator == b)
        return;

    d->separator = b;
    d->sendDataChanged();
}

bool QAction::isSeparator() const
{
    Q_D(const QAction);
    return d->separator;
}

void QAction::setText(const QString &text)
{
    Q_D(QAction);
    if (d->text == text)
        return;

    d->text = text;
    d->sendDataChanged();
}

QString QAction::text() const
{
    Q_D(const QAction);
    QString s = d->text;
    if(s.isEmpty()) {
        s = d->iconText;
        s.replace(QLatin1Char('&'), QLatin1String("&&"));
    }
    return s;
}

void QAction::setIconText(const QString &text)
{
    Q_D(QAction);
    if (d->iconText == text)
        return;

    d->iconText = text;
    d->sendDataChanged();
}

QString QAction::iconText() const
{
    Q_D(const QAction);
    if (d->iconText.isEmpty())
        return qt_strippedText(d->text);
    return d->iconText;
}

void QAction::setToolTip(const QString &tooltip)
{
    Q_D(QAction);
    if (d->tooltip == tooltip)
        return;

    d->tooltip = tooltip;
    d->sendDataChanged();
}

QString QAction::toolTip() const
{
    Q_D(const QAction);
    if (d->tooltip.isEmpty()) {
        if (!d->text.isEmpty())
            return qt_strippedText(d->text);
        return qt_strippedText(d->iconText);
    }
    return d->tooltip;
}

void QAction::setStatusTip(const QString &statustip)
{
    Q_D(QAction);
    if (d->statustip == statustip)
        return;

    d->statustip = statustip;
    d->sendDataChanged();
}

QString QAction::statusTip() const
{
    Q_D(const QAction);
    return d->statustip;
}

void QAction::setWhatsThis(const QString &whatsthis)
{
    Q_D(QAction);
    if (d->whatsthis == whatsthis)
        return;

    d->whatsthis = whatsthis;
    d->sendDataChanged();
}

QString QAction::whatsThis() const
{
    Q_D(const QAction);
    return d->whatsthis;
}

void QAction::setPriority(Priority priority)
{
    Q_D(QAction);
    if (d->priority == priority)
        return;

    d->priority = priority;
    d->sendDataChanged();
}

QAction::Priority QAction::priority() const
{
    Q_D(const QAction);
    return d->priority;
}

void QAction::setCheckable(bool b)
{
    Q_D(QAction);
    if (d->checkable == b)
        return;

    d->checkable = b;
    d->checked = false;
    d->sendDataChanged();
}

bool QAction::isCheckable() const
{
    Q_D(const QAction);
    return d->checkable;
}

void QAction::toggle()
{
    Q_D(QAction);
    setChecked(!d->checked);
}

void QAction::setChecked(bool b)
{
    Q_D(QAction);
    if (!d->checkable || d->checked == b)
        return;

    QPointer<QAction> guard(this);
    d->checked = b;
    d->sendDataChanged();
    if (guard)
        emit toggled(b);
}

bool QAction::isChecked() const
{
    Q_D(const QAction);
    return d->checked;
}

void QAction::setEnabled(bool b)
{
    Q_D(QAction);
    if (b == d->enabled && b != d->forceDisabled)
        return;
    d->forceDisabled = !b;
    if (b && (!d->visible || (d->group && !d->group->isEnabled())))
        return;
    QAPP_CHECK("setEnabled");
    d->enabled = b;
#ifndef QT_NO_SHORTCUT
    d->setShortcutEnabled(b, qApp->d_func()->shortcutMap);
#endif
    d->sendDataChanged();
}

bool QAction::isEnabled() const
{
    Q_D(const QAction);
    return d->enabled;
}

void QAction::setVisible(bool b)
{
    Q_D(QAction);
    if (b == d->visible && b != d->forceInvisible)
        return;
    QAPP_CHECK("setVisible");
    d->forceInvisible = !b;
    d->visible = b;
    d->enabled = b && !d->forceDisabled && (!d->group || d->group->isEnabled()) ;
#ifndef QT_NO_SHORTCUT
    d->setShortcutEnabled(d->enabled, qApp->d_func()->shortcutMap);
#endif
    d->sendDataChanged();
}


bool QAction::isVisible() const
{
    Q_D(const QAction);
    return d->visible;
}

/*!
  这里就是, 快捷建可以出发操作的原因所在.
*/
bool
QAction::event(QEvent *e)
{
#ifndef QT_NO_SHORTCUT
    if (e->type() == QEvent::Shortcut) {
        QShortcutEvent *se = static_cast<QShortcutEvent *>(e);
        if (se->isAmbiguous())
            qWarning("QAction::event: Ambiguous shortcut overload: %s", se->key().toString(QKeySequence::NativeText).toLatin1().constData());
        else
            activate(Trigger);
        return true;
    }
#endif
    return QObject::event(e);
}

QVariant
QAction::data() const
{
    Q_D(const QAction);
    return d->userData;
}

void
QAction::setData(const QVariant &data)
{
    Q_D(QAction);
    if (d->userData == data)
        return;
    d->userData = data;
    d->sendDataChanged();
}


/*!
  Updates the relevant status bar for the \a widget specified by sending a
  QStatusTipEvent to its parent widget. Returns \c true if an event was sent;
  otherwise returns \c false.

  If a null widget is specified, the event is sent to the action's parent.

  \sa statusTip
*/
bool
QAction::showStatusText(QWidget *widget)
{
    return d_func()->showStatusText(widget, statusTip());
}

/*!
  Sends the relevant signals for ActionEvent \a event.

  Action based widgets use this API to cause the QAction
  to emit signals as well as emitting their own.
*/
void QAction::activate(ActionEvent event)
{
    Q_D(QAction);
    if(event == Trigger) {
        QPointer<QObject> guard = this;
        if(d->checkable) {
            // the checked action of an exclusive group cannot be  unchecked
            if (d->checked && (d->group && d->group->isExclusive()
                               && d->group->checkedAction() == this)) {
                if (!guard.isNull())
                    emit triggered(true);
                return;
            }
            setChecked(!d->checked);
        }
        if (!guard.isNull())
            emit triggered(d->checked);
    } else if(event == Hover) {
        emit hovered();
    }
}

void QAction::setMenuRole(MenuRole menuRole)
{
    Q_D(QAction);
    if (d->menuRole == menuRole)
        return;

    d->menuRole = menuRole;
    d->sendDataChanged();
}

QAction::MenuRole QAction::menuRole() const
{
    Q_D(const QAction);
    return d->menuRole;
}

/*!
    \property QAction::iconVisibleInMenu
    \brief Whether or not an action should show an icon in a menu
    \since 4.4

    In some applications, it may make sense to have actions with icons in the
    toolbar, but not in menus. If true, the icon (if valid) is shown in the menu, when it
    is false, it is not shown.

    The default is to follow whether the Qt::AA_DontShowIconsInMenus attribute
    is set for the application. Explicitly settings this property overrides
    the presence (or abscence) of the attribute.

    For example:
    \snippet code/src_gui_kernel_qaction.cpp 0

    \sa QAction::icon, QCoreApplication::setAttribute()
*/
void QAction::setIconVisibleInMenu(bool visible)
{
    Q_D(QAction);
    if (d->iconVisibleInMenu == -1 || visible != bool(d->iconVisibleInMenu)) {
        int oldValue = d->iconVisibleInMenu;
        d->iconVisibleInMenu = visible;
        // Only send data changed if we really need to.
        if (oldValue != -1
            || visible == !QApplication::instance()->testAttribute(Qt::AA_DontShowIconsInMenus)) {
            d->sendDataChanged();
        }
    }
}

bool QAction::isIconVisibleInMenu() const
{
    Q_D(const QAction);
    if (d->iconVisibleInMenu == -1) {
        return !QApplication::instance()->testAttribute(Qt::AA_DontShowIconsInMenus);
    }
    return d->iconVisibleInMenu;
}

/*!
    \property QAction::shortcutVisibleInContextMenu
    \brief Whether or not an action should show a shortcut in a context menu
    \since 5.10

    In some applications, it may make sense to have actions with shortcuts in
    context menus. If true, the shortcut (if valid) is shown when the action is
    shown via a context menu, when it is false, it is not shown.

    The default is to follow whether the Qt::AA_DontShowShortcutsInContextMenus attribute
    is set for the application, falling back to the widget style hint.
    Explicitly setting this property overrides the presence (or abscence) of the attribute.

    \sa QAction::shortcut, QCoreApplication::setAttribute()
*/
void QAction::setShortcutVisibleInContextMenu(bool visible)
{
    Q_D(QAction);
    if (d->shortcutVisibleInContextMenu == -1 || visible != bool(d->shortcutVisibleInContextMenu)) {
        int oldValue = d->shortcutVisibleInContextMenu;
        d->shortcutVisibleInContextMenu = visible;
        // Only send data changed if we really need to.
        if (oldValue != -1
            || visible == !QApplication::instance()->testAttribute(Qt::AA_DontShowShortcutsInContextMenus)) {
            d->sendDataChanged();
        }
    }
}

bool QAction::isShortcutVisibleInContextMenu() const
{
    Q_D(const QAction);
    if (d->shortcutVisibleInContextMenu == -1) {
        return !QCoreApplication::testAttribute(Qt::AA_DontShowShortcutsInContextMenus)
            && QGuiApplication::styleHints()->showShortcutsInContextMenus();
    }
    return d->shortcutVisibleInContextMenu;
}

#ifndef QT_NO_DEBUG_STREAM
Q_WIDGETS_EXPORT QDebug operator<<(QDebug d, const QAction *action)
{
    QDebugStateSaver saver(d);
    d.nospace();
    d << "QAction(" << static_cast<const void *>(action);
    if (action) {
        d << " text=" << action->text();
        if (!action->toolTip().isEmpty())
            d << " toolTip=" << action->toolTip();
        if (action->isCheckable())
            d << " checked=" << action->isChecked();
#ifndef QT_NO_SHORTCUT
        if (!action->shortcut().isEmpty())
            d << " shortcut=" << action->shortcut();
#endif
        d << " menuRole=";
        QtDebugUtils::formatQEnum(d, action->menuRole());
        d << " visible=" << action->isVisible();
    } else {
        d << '0';
    }
    d << ')';
    return d;
}
#endif // QT_NO_DEBUG_STREAM

QT_END_NAMESPACE

#include "moc_qaction.cpp"

#endif // QT_NO_ACTION
