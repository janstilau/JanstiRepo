/********************************************************************************
** Form generated from reading UI file 'mainwindow.ui'
**
** Created by: Qt User Interface Compiler version 5.15.1
**
** WARNING! All changes made in this file will be lost when recompiling UI file!
********************************************************************************/

#ifndef UI_MAINWINDOW_H
#define UI_MAINWINDOW_H

#include <QtCore/QVariant>
#include <QtWidgets/QApplication>
#include <QtWidgets/QLabel>
#include <QtWidgets/QMainWindow>
#include <QtWidgets/QMenuBar>
#include <QtWidgets/QPlainTextEdit>
#include <QtWidgets/QPushButton>
#include <QtWidgets/QStatusBar>
#include <QtWidgets/QTextBrowser>
#include <QtWidgets/QVBoxLayout>
#include <QtWidgets/QWidget>

QT_BEGIN_NAMESPACE

class Ui_MainWindow
{
public:
    QWidget *centralwidget;
    QVBoxLayout *verticalLayout;
    QLabel *label;
    QPlainTextEdit *srcInputField;
    QLabel *label_5;
    QPlainTextEdit *urlInputField;
    QLabel *label_4;
    QPlainTextEdit *destInputField;
    QLabel *label_2;
    QPlainTextEdit *filterInputField;
    QLabel *label_3;
    QTextBrowser *logPanel;
    QPushButton *initBtn;
    QPushButton *startBtn;
    QMenuBar *menubar;
    QStatusBar *statusbar;

    void setupUi(QMainWindow *MainWindow)
    {
        if (MainWindow->objectName().isEmpty())
            MainWindow->setObjectName(QString::fromUtf8("MainWindow"));
        MainWindow->resize(1136, 713);
        centralwidget = new QWidget(MainWindow);
        centralwidget->setObjectName(QString::fromUtf8("centralwidget"));
        verticalLayout = new QVBoxLayout(centralwidget);
        verticalLayout->setObjectName(QString::fromUtf8("verticalLayout"));
        label = new QLabel(centralwidget);
        label->setObjectName(QString::fromUtf8("label"));

        verticalLayout->addWidget(label);

        srcInputField = new QPlainTextEdit(centralwidget);
        srcInputField->setObjectName(QString::fromUtf8("srcInputField"));
        srcInputField->setMaximumSize(QSize(16777215, 50));

        verticalLayout->addWidget(srcInputField);

        label_5 = new QLabel(centralwidget);
        label_5->setObjectName(QString::fromUtf8("label_5"));

        verticalLayout->addWidget(label_5);

        urlInputField = new QPlainTextEdit(centralwidget);
        urlInputField->setObjectName(QString::fromUtf8("urlInputField"));
        urlInputField->setMaximumSize(QSize(16777215, 50));

        verticalLayout->addWidget(urlInputField);

        label_4 = new QLabel(centralwidget);
        label_4->setObjectName(QString::fromUtf8("label_4"));

        verticalLayout->addWidget(label_4);

        destInputField = new QPlainTextEdit(centralwidget);
        destInputField->setObjectName(QString::fromUtf8("destInputField"));
        destInputField->setMaximumSize(QSize(16777215, 50));

        verticalLayout->addWidget(destInputField);

        label_2 = new QLabel(centralwidget);
        label_2->setObjectName(QString::fromUtf8("label_2"));

        verticalLayout->addWidget(label_2);

        filterInputField = new QPlainTextEdit(centralwidget);
        filterInputField->setObjectName(QString::fromUtf8("filterInputField"));
        filterInputField->setMaximumSize(QSize(16777215, 50));

        verticalLayout->addWidget(filterInputField);

        label_3 = new QLabel(centralwidget);
        label_3->setObjectName(QString::fromUtf8("label_3"));

        verticalLayout->addWidget(label_3);

        logPanel = new QTextBrowser(centralwidget);
        logPanel->setObjectName(QString::fromUtf8("logPanel"));

        verticalLayout->addWidget(logPanel);

        initBtn = new QPushButton(centralwidget);
        initBtn->setObjectName(QString::fromUtf8("initBtn"));
        initBtn->setMinimumSize(QSize(0, 100));

        verticalLayout->addWidget(initBtn);

        startBtn = new QPushButton(centralwidget);
        startBtn->setObjectName(QString::fromUtf8("startBtn"));
        startBtn->setMinimumSize(QSize(0, 100));

        verticalLayout->addWidget(startBtn);

        MainWindow->setCentralWidget(centralwidget);
        menubar = new QMenuBar(MainWindow);
        menubar->setObjectName(QString::fromUtf8("menubar"));
        menubar->setGeometry(QRect(0, 0, 1136, 24));
        MainWindow->setMenuBar(menubar);
        statusbar = new QStatusBar(MainWindow);
        statusbar->setObjectName(QString::fromUtf8("statusbar"));
        MainWindow->setStatusBar(statusbar);

        retranslateUi(MainWindow);

        QMetaObject::connectSlotsByName(MainWindow);
    } // setupUi

    void retranslateUi(QMainWindow *MainWindow)
    {
        MainWindow->setWindowTitle(QCoreApplication::translate("MainWindow", "MainWindow", nullptr));
        label->setText(QCoreApplication::translate("MainWindow", "\346\272\220\346\226\207\344\273\266\347\233\256\345\275\225", nullptr));
        label_5->setText(QCoreApplication::translate("MainWindow", "BaseUrl", nullptr));
        label_4->setText(QCoreApplication::translate("MainWindow", "\350\276\223\345\207\272\347\233\256\345\275\225", nullptr));
        label_2->setText(QCoreApplication::translate("MainWindow", "\346\211\223\345\215\260\346\226\207\344\273\266\347\261\273\345\236\213\347\251\272\346\240\274\345\210\206\345\211\262", nullptr));
        label_3->setText(QCoreApplication::translate("MainWindow", "lOG", nullptr));
        initBtn->setText(QCoreApplication::translate("MainWindow", "\345\210\235\345\247\213\345\214\226", nullptr));
        startBtn->setText(QCoreApplication::translate("MainWindow", "\345\274\200\345\247\213", nullptr));
    } // retranslateUi

};

namespace Ui {
    class MainWindow: public Ui_MainWindow {};
} // namespace Ui

QT_END_NAMESPACE

#endif // UI_MAINWINDOW_H
