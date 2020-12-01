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

DISTFILES += \
    LatexRender/jkqtcommon/CMakeLists.txt \
    LatexRender/jkqtcommon/LibTarget.cmake.in \
    LatexRender/jkqtmathtext/CMakeLists.txt \
    LatexRender/jkqtmathtext/LibTarget.cmake.in \
    LatexRender/jkqtmathtext/jkqtmathtext.readme \
    LatexRender/jkqtmathtext/resources/xits.pri \
    LatexRender/jkqtmathtext/resources/xits/FONTLOG.txt.in \
    LatexRender/jkqtmathtext/resources/xits/OFL-FAQ.txt \
    LatexRender/jkqtmathtext/resources/xits/OFL.txt \
    LatexRender/jkqtmathtext/resources/xits/README.md \
    LatexRender/jkqtmathtext/resources/xits/XITS-Bold.otf \
    LatexRender/jkqtmathtext/resources/xits/XITS-BoldItalic.otf \
    LatexRender/jkqtmathtext/resources/xits/XITS-Italic.otf \
    LatexRender/jkqtmathtext/resources/xits/XITS-Regular.otf \
    LatexRender/jkqtmathtext/resources/xits/XITSMath-Bold.otf \
    LatexRender/jkqtmathtext/resources/xits/XITSMath-Regular.otf \
    LatexRender/jkqtmathtext/resources/xits/documentation/documentation-sources/user-guide.tex \
    LatexRender/jkqtmathtext/resources/xits/documentation/documentation-sources/xits-specimen.tex \
    LatexRender/jkqtmathtext/resources/xits/documentation/user-guide.pdf \
    LatexRender/jkqtmathtext/resources/xits/documentation/xits-specimen.pdf \
    LatexRender/jkqtmathtext/resources/xits/requirements.txt \
    LatexRender/jkqtmathtext/resources/xits/sources/XITS-Bold.fea \
    LatexRender/jkqtmathtext/resources/xits/sources/XITS-Bold.sfd \
    LatexRender/jkqtmathtext/resources/xits/sources/XITS-BoldItalic.fea \
    LatexRender/jkqtmathtext/resources/xits/sources/XITS-BoldItalic.sfd \
    LatexRender/jkqtmathtext/resources/xits/sources/XITS-Italic.fea \
    LatexRender/jkqtmathtext/resources/xits/sources/XITS-Italic.sfd \
    LatexRender/jkqtmathtext/resources/xits/sources/XITS-Regular.fea \
    LatexRender/jkqtmathtext/resources/xits/sources/XITS-Regular.sfd \
    LatexRender/jkqtmathtext/resources/xits/sources/XITSMath-Bold.fea \
    LatexRender/jkqtmathtext/resources/xits/sources/XITSMath-Bold.sfd \
    LatexRender/jkqtmathtext/resources/xits/sources/XITSMath-Regular.fea \
    LatexRender/jkqtmathtext/resources/xits/sources/XITSMath-Regular.sfd \
    LatexRender/jkqtmathtext/resources/xits/sources/altonum.fea \
    LatexRender/jkqtmathtext/resources/xits/sources/frac.fea \
    LatexRender/jkqtmathtext/resources/xits/sources/langsys.fea \
    LatexRender/jkqtmathtext/resources/xits/sources/locl.fea \
    LatexRender/jkqtmathtext/resources/xits/sources/numrdnom.fea \
    LatexRender/jkqtmathtext/resources/xits/sources/smallcaps.fea \
    LatexRender/jkqtmathtext/resources/xits/sources/xits.fea \
    LatexRender/jkqtmathtext/resources/xits/test-suite/README \
    LatexRender/jkqtmathtext/resources/xits/test-suite/accents.cld \
    LatexRender/jkqtmathtext/resources/xits/test-suite/amsmath.ltx \
    LatexRender/jkqtmathtext/resources/xits/test-suite/arabic.tex \
    LatexRender/jkqtmathtext/resources/xits/test-suite/hat.tex \
    LatexRender/jkqtmathtext/resources/xits/test-suite/integrals.cld \
    LatexRender/jkqtmathtext/resources/xits/test-suite/mathcal.tex \
    LatexRender/jkqtmathtext/resources/xits/test-suite/mathkern.tex \
    LatexRender/jkqtmathtext/resources/xits/test-suite/overunder.cld \
    LatexRender/jkqtmathtext/resources/xits/test-suite/sscript.cld \
    LatexRender/jkqtmathtext/resources/xits/test-suite/upintegrals.tex \
    LatexRender/jkqtmathtext/resources/xits/test-suite/varselector.cld \
    LatexRender/jkqtmathtext/resources/xits/test-suite/varselector.tex \
    LatexRender/jkqtmathtext/resources/xits/test-suite/vert.tex \
    LatexRender/jkqtmathtext/resources/xits/test-suite/xits-env.tex \
    LatexRender/jkqtmathtext/resources/xits/tex/xits-math.lfg \
    LatexRender/jkqtmathtext/resources/xits/tools/changelog.py \
    LatexRender/jkqtmathtext/resources/xits/tools/copy-math-from-amiri.py \
    LatexRender/jkqtmathtext/resources/xits/tools/fontcoverage.py \
    LatexRender/jkqtmathtext/resources/xits/tools/makefnt.py \
    LatexRender/jkqtmathtext/resources/xits/tools/makeweb.py \
    LatexRender/jkqtmathtext/resources/xits/tools/sfdnormalize.py

RESOURCES += \
    LatexRender/jkqtmathtext/resources/xits.qrc
