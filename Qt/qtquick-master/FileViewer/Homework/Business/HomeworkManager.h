// Created by liugquoqiang at 2020-11-18

#ifdef YD_HOMEWORK

#ifndef HOMEWORKMANAGER_H
#define HOMEWORKMANAGER_H

#include <QObject>
#include <QNetworkReply>
#include "Business/QuestionModel.h"

class HomeworkManager : public QObject
{
    Q_OBJECT

public:
    enum Stage {
        Init,
        ScanQuestion,
        ScanAnswer,
        ShowOralQuestion,
        ShowNormalQuestion
    };

public:
    static HomeworkManager& instance();
    ~HomeworkManager();

public:
    bool isInProcessing() const;
    bool isInOCRing() const;
    bool isScaningQuestion() const;
    bool isScaningAnswer() const;
    const QString& OCRContent() const;
    const QuestionModel* currentQuestion() const;

public:
    void startProcess();
    void stopProcess();
    void handleNetwork(const QNetworkReply *reply, const QString &response);
    void popBack();

signals:
    void OCRHomeworkStarted();
    void OCRHomeworkScanning();
    void OCRHomeworkCompleted();

    void stageUpdated(Stage stage);
    void answerUpdated(QuestionAnswer answer);

    void needToast(const QString &msg);
    void needQuit();

public slots:
    void onOCRStart();
    void onOCRScanning(const std::string&);
    void onOCRComplete(const std::string&);

private:
    explicit HomeworkManager(QObject *parent = nullptr);
    void reset();

private:
    Stage mCurrentStage;

    bool mIsInProcessing = false;
    bool mIsInOcring = false;
    QString mOCRContent;

    QuestionModel *mCurrentQuestion = nullptr;
};

Q_DECLARE_METATYPE(HomeworkManager::Stage);

#endif // HOMEWORKMANAGER_H

#endif
