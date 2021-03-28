#include "mainwindow.h"
#include "ui_mainwindow.h"
#include <QDebug>
#include <QPrintDialog>
#include <QPrinter>
#include <QTextDocument>
#include <QFile>
#include <QWebEngineView>
#include <QPageLayout>
#include <QPageSize>
#include <QWebEngineSettings>
#include <QDir>
#include <QDirIterator>
#include <QVector>

class PrintItem
{
public:
    QString url;
    QString name;
    QString destPath;
    QString srcPath;
    int idx;
};

static QWebEngineView *_view = nullptr;
static QString _inputDirPath;
static QString _outputDirPath;
static QString _baseUrl;
static QStringList _filters;
static QVector<PrintItem> _data;

static int _printIdx = 0;
static QStringList _toPrintlist;



MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::MainWindow)
{
    ui->setupUi(this);
}

MainWindow::~MainWindow()
{
    delete ui;
}

void MainWindow::on_initBtn_clicked()
{
    if (_view == nullptr) {
        _view = new QWebEngineView;
        connect(_view, &QWebEngineView::loadFinished, this, [this](bool ok){
            if (_data.isEmpty()) { return; }
            if (ok) {
                this->printLoadedPage();
            }
        });
        _view->resize(1650, 1112);
        _view->setZoomFactor(1.2);
        _view->load(QUrl("https://www.baidu.com/"));
        _view->show();
    }
    _inputDirPath = ui->srcInputField->toPlainText().trimmed();
    _outputDirPath = ui->destInputField->toPlainText().trimmed();
    _baseUrl = ui->urlInputField->toPlainText().trimmed();
    _filters = ui->filterInputField->toPlainText().split(" ");
    _printIdx = 0;
    _toPrintlist.clear();
    _data.clear();
}

void MainWindow::on_startBtn_clicked()
{
    QDir dir(_inputDirPath);
    QStringList nameFilters;
    for (int i = 0; i < _filters.size(); i++) {
        QString filterItem = _filters[i];
        filterItem = filterItem.trimmed();
        if (filterItem.isEmpty()) { continue; }
        nameFilters.append(filterItem);
    }
    QDirIterator dir_iterator(_inputDirPath, nameFilters, QDir::Files | QDir::NoSymLinks, QDirIterator::Subdirectories);
    QStringList string_list;
    while(dir_iterator.hasNext())
    {
       dir_iterator.next();
       QFileInfo file_info = dir_iterator.fileInfo();
       QString absolute_file_path = file_info.absoluteFilePath();
       _toPrintlist.append(absolute_file_path);
    }

    for (int i = 0; i< _toPrintlist.size(); i++) {
        PrintItem item;
        item.idx = i;
        item.srcPath = _toPrintlist[i];
        QFileInfo fileinfo(item.srcPath);
        item.name = fileinfo.baseName();
        item.destPath =  QString("%1/%2.pdf").arg(_outputDirPath).arg(item.name);
        // /Users/justinlau/JanstiRepo/Code/SwiftSourceCode/core/Print.swift
        // https://github.com/apple/swift/blob/main/stdlib/public/core/Array.swift
        int relativeSize = item.srcPath.size() - _inputDirPath.size();
        QString relativeUrl = item.srcPath.right(relativeSize);
        item.url = QString("%1%2").arg(_baseUrl).arg(relativeUrl);
        _data.append(item);
    }
    schedule();
}

void MainWindow::schedule()
{
    if (_printIdx >= _toPrintlist.count()) {
        log("End");
        return;
    }
    PrintItem item = _data[_printIdx];
    _view->load(item.url);
}

void MainWindow::printLoadedPage()
{
    PrintItem item = _data[_printIdx];
    log(QString("id: %1: %2 Load Finished"));
    _view->page()->printToPdf(item.destPath, QPageLayout(QPageSize(QPageSize::A4), QPageLayout::Landscape, QMarginsF()));
    _printIdx++;
    log(QString("Begin To Load %1").arg(_printIdx));
    schedule();
}

void MainWindow::log(const QString &msg)
{
    ui->logPanel->setText(msg);
}
