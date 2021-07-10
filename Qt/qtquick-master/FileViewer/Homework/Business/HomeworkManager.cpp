// Created by liugquoqiang at 2020-11-18

#ifdef YD_HOMEWORK

#include "HomeworkManager.h"
#include "HomeworkSearchNetParser.h"
#include "Network/YdHttpManager.h"
#include <QCoreApplication>
#include <QDebug>

HomeworkManager& HomeworkManager::instance()
{
    static HomeworkManager mInstance;
    return mInstance;
}

HomeworkManager::HomeworkManager(QObject* parent):
    QObject(parent)
{
}

HomeworkManager::~HomeworkManager()
{
    if (mCurrentQuestion) {
        delete  mCurrentQuestion;
        mCurrentQuestion = nullptr;
    }
}

#pragma mark - Get

bool HomeworkManager::isInProcessing() const
{
    return mIsInProcessing;
}

bool HomeworkManager::isInOCRing() const
{
    return mIsInOcring;
}

const QString& HomeworkManager::OCRContent() const
{
    return mOCRContent;
}

const QuestionModel* HomeworkManager::currentQuestion() const
{
    return mCurrentQuestion;
}

bool HomeworkManager::isScaningQuestion() const
{
    return mCurrentStage == Stage::ScanQuestion;
}

bool HomeworkManager::isScaningAnswer() const
{
    return mCurrentStage == Stage::ScanAnswer;
}

#pragma mark - OCR

void HomeworkManager::onOCRStart()
{
    if (!mIsInProcessing) { return; }

    mIsInOcring = true;

    if (mCurrentStage == Stage::ShowNormalQuestion &&
        mCurrentQuestion->remainAnswerCount > 0) {
        mCurrentStage = Stage::ScanAnswer;
    } else if (mCurrentStage == Stage::ScanAnswer &&
               mCurrentQuestion->remainAnswerCount > 0) {
        mCurrentStage = Stage::ScanAnswer;
    } else {
        mCurrentStage = Stage::ScanQuestion;
    }
    emit stageUpdated(mCurrentStage);

    mOCRContent = "";
    emit OCRHomeworkStarted();

}

void HomeworkManager::onOCRScanning(const std::string &txt)
{
    if (!mIsInProcessing) { return; }

    mIsInOcring = true;
    mOCRContent = QString::fromStdString(txt);
    emit OCRHomeworkScanning();
}

void HomeworkManager::onOCRComplete(const std::string &txt)
{
    if (!mIsInProcessing) { return; }

    mIsInOcring = false;
    mOCRContent = QString::fromStdString(txt);
    emit OCRHomeworkCompleted();
    mOCRContent = "";
}

#pragma mark - StageControl

void HomeworkManager::startProcess()
{
    reset();
    mIsInProcessing = true;
    mCurrentStage = Stage::Init;
    emit stageUpdated(mCurrentStage);
}

void HomeworkManager::stopProcess()
{
    reset();
}

void HomeworkManager::reset()
{
    mIsInOcring = false;
    mIsInProcessing = false;
    mOCRContent = "";
    mCurrentStage = Stage::Init;
    if (mCurrentQuestion) {
        delete  mCurrentQuestion;
        mCurrentQuestion = nullptr;
    }
}

void HomeworkManager::popBack()
{
    QSet<Stage> needQuitStages = {
        Stage::Init,
        Stage::ScanQuestion,
        Stage::ShowNormalQuestion,
        Stage::ShowOralQuestion,
    };
    if (needQuitStages.contains(mCurrentStage)) {
        emit needQuit();
    } else {
        if (mCurrentStage == Stage::ScanAnswer) {
            mCurrentStage = Stage::ShowNormalQuestion;
            emit stageUpdated(mCurrentStage);
        }
    }
}

void HomeworkManager::handleNetwork(const QNetworkReply *reply, const QString &response)
{
    if (reply->error() != QNetworkReply::NoError) {
        emit needToast(QCoreApplication::translate("Homework", "网络异常，请重试"));
        return;
    }

    HomeworkSearchNetParser parser;
    parser.beginParse(response);
    if (parser.code == HomeworkSearchNetParser::UndefinedBusinessCode) {
        emit needToast(QCoreApplication::translate("Homework", "网络异常，请重试"));
        return;
    }


    //YdTodo: AnswerQuestionUnFound 处理流程, 需要和产品确认. AnswerQuestionUnFound
    if (parser.code == HomeworkSearchNetParser::QuestionUnFound ||
        parser.code == HomeworkSearchNetParser::AnswerQuestionUnFound ||
        parser.code == HomeworkSearchNetParser::ServerUnKownError ||
        parser.type == HomeworkSearchNetParser::UndefinedDataType) {
        emit needToast(parser.msg);
        return;
    }

    switch (parser.type) {
        case HomeworkSearchNetParser::OralCalculation: {
            if (mCurrentQuestion) { delete  mCurrentQuestion; }
            mCurrentQuestion = new QuestionModel(parser.parsedQuestion);
            mCurrentStage = Stage::ShowOralQuestion;
            emit stageUpdated(mCurrentStage);
        }break;
        case HomeworkSearchNetParser::NormalQuestion:{
            if (mCurrentQuestion) { delete  mCurrentQuestion; }
            mCurrentQuestion = new QuestionModel(parser.parsedQuestion);
            mCurrentStage = Stage::ShowNormalQuestion;
            emit stageUpdated(mCurrentStage);
            if (mCurrentQuestion->answerCount > 0 &&
                mCurrentQuestion->remainAnswerCount <= 0) {
                bool allRight = true;
                for (auto &aAnswer : mCurrentQuestion->answers) {
                    if (aAnswer.state != AnswerState::Right) {
                        allRight = false;
                        break;
                    }
                }
                if (allRight) {
                } else {
                }
            } else {
                QString prompt = QString("本题有%1个答案, 请扫描剩余%2个答案").
                        arg(mCurrentQuestion->answerCount).
                        arg(mCurrentQuestion->remainAnswerCount);
            }
        }break;
        case HomeworkSearchNetParser::Answer:{
            Q_ASSERT(mCurrentQuestion != nullptr);
            Q_ASSERT(mCurrentQuestion->remainAnswerCount > 0);
            int dugedAnswerIdx = mCurrentQuestion->answerCount-mCurrentQuestion->remainAnswerCount;
            if (dugedAnswerIdx < 0 || mCurrentQuestion->answers.count() <= dugedAnswerIdx) { return; }
            mCurrentQuestion->answers[dugedAnswerIdx] = parser.parsedAnswer;
            mCurrentQuestion->remainAnswerCount--;
            if (mCurrentQuestion->remainAnswerCount <= 0 ) {
                mCurrentStage = ShowNormalQuestion;
                emit stageUpdated(mCurrentStage);
            } else {
                emit answerUpdated(parser.parsedAnswer);
            }
        }break;
        default:
            break;
    }
}



#endif
