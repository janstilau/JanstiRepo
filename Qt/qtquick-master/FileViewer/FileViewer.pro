TEMPLATE = app

QT += qml quick network multimedia widgets

DEFINES += YD_HOMEWORK

INCLUDEPATH += Homework \
                Homework/Network \
                Homework/Notification

SOURCES += main.cpp \
    Homework/AsyncOperation/YdOperation.cpp \
    Homework/AsyncOperation/YdOperationQueue.cpp \
    Homework/Business/HomeworkManager.cpp \
    Homework/Business/HomeworkSearchNetParser.cpp \
    Homework/Business/QuestionModel.cpp \
    Homework/Business/YdDefer.cpp \
    Homework/Network/YdHttpDownloader.cpp \
    Homework/Network/YdHttpManager.cpp \
    Homework/Network/YdHttpSession.cpp \
    Homework/Network/YdHttpUtil.cpp \
    Homework/Network/YdImageCache.cpp \
    Homework/Notification/YdNotiObservation.cpp \
    Homework/Notification/YdNotification.cpp \
    Homework/Notification/YdNotificationCenter.cpp \
    Homework/Notification/YdNotificationiUtil.cpp \
    Homework/YdViewUtil.cpp \
    Homework/colormaker.cpp

RESOURCES += qml.qrc

# Additional import path used to resolve QML modules in Qt Creator's code model
QML_IMPORT_PATH =

# Default rules for deployment.
include(deployment.pri)

HEADERS += \
    Homework/AsyncOperation/YdOperation.h \
    Homework/AsyncOperation/YdOperationQueue.h \
    Homework/Business/HomeworkManager.h \
    Homework/Business/HomeworkSearchNetParser.h \
    Homework/Business/QuestionModel.h \
    Homework/Business/YdDefer.h \
    Homework/Network/YdHttpDownloader.h \
    Homework/Network/YdHttpManager.h \
    Homework/Network/YdHttpSession.h \
    Homework/Network/YdHttpUtil.h \
    Homework/Network/YdImageCache.h \
    Homework/Notification/YdNotiObservation.h \
    Homework/Notification/YdNotification.h \
    Homework/Notification/YdNotificationCenter.h \
    Homework/Notification/YdNotificationiUtil.h \
    Homework/YdBusinessCommon.h \
    Homework/YdSystemCommon.h \
    Homework/YdViewUtil.h \
    Homework/colormaker.h
