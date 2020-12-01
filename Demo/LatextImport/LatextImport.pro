QT       += core gui

greaterThan(QT_MAJOR_VERSION, 4): QT += widgets

CONFIG += c++11

# You can make your code fail to compile if it uses deprecated APIs.
# In order to do so, uncomment the following line.
#DEFINES += QT_DISABLE_DEPRECATED_BEFORE=0x060000    # disables all the APIs deprecated before Qt 6.0.0

INCLUDEPATH += ./LatexRender \

SOURCES += \
    LatexRender/jkqtcommon/jkqtpalgorithms.cpp \
    LatexRender/jkqtcommon/jkqtparraytools.cpp \
    LatexRender/jkqtcommon/jkqtpbasicimagetools.cpp \
    LatexRender/jkqtcommon/jkqtpcodestructuring.cpp \
    LatexRender/jkqtcommon/jkqtpdebuggingtools.cpp \
    LatexRender/jkqtcommon/jkqtpdrawingtools.cpp \
    LatexRender/jkqtcommon/jkqtpenhancedpainter.cpp \
    LatexRender/jkqtcommon/jkqtpgeometrytools.cpp \
    LatexRender/jkqtcommon/jkqtphighrestimer.cpp \
    LatexRender/jkqtcommon/jkqtplinalgtools.cpp \
    LatexRender/jkqtcommon/jkqtpmathparser.cpp \
    LatexRender/jkqtcommon/jkqtpmathtools.cpp \
    LatexRender/jkqtcommon/jkqtpstatbasics.cpp \
    LatexRender/jkqtcommon/jkqtpstatgrouped.cpp \
    LatexRender/jkqtcommon/jkqtpstathistogram.cpp \
    LatexRender/jkqtcommon/jkqtpstatkde.cpp \
    LatexRender/jkqtcommon/jkqtpstatpoly.cpp \
    LatexRender/jkqtcommon/jkqtpstatregression.cpp \
    LatexRender/jkqtcommon/jkqtpstringtools.cpp \
    LatexRender/jkqtcommon/jkqttools.cpp \
    LatexRender/jkqtmathtext/jkqtmathtext.cpp \
    main.cpp \
    mainwindow.cpp \
    testform.cpp

HEADERS += \
    LatexRender/jkqtcommon/jkqtcommon_imexport.h \
    LatexRender/jkqtcommon/jkqtpalgorithms.h \
    LatexRender/jkqtcommon/jkqtparraytools.h \
    LatexRender/jkqtcommon/jkqtpbasicimagetools.h \
    LatexRender/jkqtcommon/jkqtpcodestructuring.h \
    LatexRender/jkqtcommon/jkqtpdebuggingtools.h \
    LatexRender/jkqtcommon/jkqtpdrawingtools.h \
    LatexRender/jkqtcommon/jkqtpenhancedpainter.h \
    LatexRender/jkqtcommon/jkqtpgeometrytools.h \
    LatexRender/jkqtcommon/jkqtphighrestimer.h \
    LatexRender/jkqtcommon/jkqtplinalgtools.h \
    LatexRender/jkqtcommon/jkqtpmathparser.h \
    LatexRender/jkqtcommon/jkqtpmathtools.h \
    LatexRender/jkqtcommon/jkqtpstatbasics.h \
    LatexRender/jkqtcommon/jkqtpstatgrouped.h \
    LatexRender/jkqtcommon/jkqtpstathistogram.h \
    LatexRender/jkqtcommon/jkqtpstatisticstools.h \
    LatexRender/jkqtcommon/jkqtpstatkde.h \
    LatexRender/jkqtcommon/jkqtpstatpoly.h \
    LatexRender/jkqtcommon/jkqtpstatregression.h \
    LatexRender/jkqtcommon/jkqtpstringtools.h \
    LatexRender/jkqtcommon/jkqttools.h \
    LatexRender/jkqtmathtext/jkqtmathtext.h \
    LatexRender/jkqtmathtext/jkqtmathtext_imexport.h \
    mainwindow.h \
    testform.h

FORMS += \
    mainwindow.ui \
    testform.ui

# Default rules for deployment.
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target

RESOURCES += \
    LatexRender/jkqtmathtext/resources/xits.qrc
