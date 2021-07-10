// Created by liugquoqiang at 2020-11-20

#include "HomeworkSearchNetParser.h"
#include <QJsonObject>
#include <QJsonDocument>
#include <QJsonArray>
#include "YdHttpManager.h"
#include <QFile>

HomeworkSearchNetParser::HomeworkSearchNetParser(QObject *parent) : QObject(parent)
{
}

void HomeworkSearchNetParser::beginParse(const QString &response)
{
    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(response.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError) { return; }
    if (!doc.isObject()) { return; }
    QJsonObject responseJsonObj =  doc.object();
    parseResponse(responseJsonObj);
}

void HomeworkSearchNetParser::parseResponse(const QJsonObject &jsonObj)
{
    this->msg = jsonObj["msg"].toString();
    int defaultCode = BusinessCode::UndefinedBusinessCode;
    this->code = (BusinessCode)jsonObj["code"].toInt(defaultCode);
    if (this->code != BusinessCode::Ok) { return; }

    QJsonObject dataJsonObj = jsonObj["data"].toObject();
    int defaultDataType = DataType::UndefinedDataType;
    this->type = (DataType)dataJsonObj["type"].toInt(defaultDataType);
    if (this->type == DataType::UndefinedDataType) { return; }

    QString ocrTxt = dataJsonObj["ocr"].toString();
    switch (this->type) {
    case DataType::OralCalculation:
        parseOralQuestion(dataJsonObj, ocrTxt);
        break;
    case DataType::NormalQuestion:
        parseNormalQuestion(dataJsonObj, ocrTxt);
        break;
    case DataType::Answer:
        parseAnswer(dataJsonObj, ocrTxt);
        break;
    default:
        break;
    }
}

// 当数据不全时, 大部分数据, 在 UI 上没有用途, 按照逻辑予以构建.
void HomeworkSearchNetParser::parseOralQuestion(const QJsonObject &jsonObj, const QString &ocr)
{
    const QString key = "oral";
    QJsonObject oralJsonObj = jsonObj[key].toObject();

    this->parsedQuestion.type = QuestionType::OralCalculation;
    this->parsedQuestion.body = ocr;
    this->parsedQuestion.answerCount = 1;
    this->parsedQuestion.remainAnswerCount = 0;

    QuestionAnswer oralAnswer;
    oralAnswer.prompt = oralJsonObj["display"].toString();
    oralAnswer.correctContent = ocr;
    oralAnswer.userContent = ocr;
    oralAnswer.state = (AnswerState)oralJsonObj["judgeType"].toInt();
    this->parsedQuestion.answers = {oralAnswer};
    this->parsedAnswer = oralAnswer;
}

void HomeworkSearchNetParser::parseNormalQuestion(const QJsonObject &jsonObj, const QString &ocr)
{
    const QString key = "search";
    QJsonObject questionJsonObj = jsonObj[key].toObject();

    this->parsedQuestion.type = QuestionType::NormalQuestion;
    this->parsedQuestion.id = questionJsonObj["quesId"].toString();
    this->parsedQuestion.body = questionJsonObj["quesBody"].toString();
    this->parsedQuestion.bodyHtml = questionJsonObj["quesHtml"].toString();
    this->parsedQuestion.ocr = ocr;
    this->parsedQuestion.explanation = questionJsonObj["analysis"].toString();
    this->parsedQuestion.answerCount = questionJsonObj["totalAnswer"].toInt();
    this->parsedQuestion.remainAnswerCount = questionJsonObj["remainAnswer"].toInt();
    QJsonArray rawAnswers = questionJsonObj["answers"].toArray();
    QVector<QuestionAnswer> answers;
    for (int i = 0; i < rawAnswers.count(); ++i) {
        QJsonObject aRawAnswer = rawAnswers[i].toObject();
        QuestionAnswer aAnswer;
        aAnswer.userContent = aRawAnswer["userAnswer"].toString();
        aAnswer.correctContent = aRawAnswer["answer"].toString();
        aAnswer.state = (AnswerState)aRawAnswer["judgeType"].toInt();
        if  (aAnswer.state == AnswerState::Right) {
            aAnswer.prompt = "正确";
        } else {
            aAnswer.prompt = "错误";
        }
        answers.append(aAnswer);
    }
    this->parsedQuestion.answers = answers;

    QFile htmlFile("/Users/liugq01/output/test2.html");
    htmlFile.open(QFile::ReadOnly);
    QString html(htmlFile.readAll());
    this->parsedQuestion.explanation = html;
}

void HomeworkSearchNetParser::parseAnswer(const QJsonObject &jsonObj, const QString &ocr)
{
    Q_UNUSED(ocr);
    const QString key = "judge";
    QJsonObject answerJsonObj = jsonObj[key].toObject();

    this->parsedAnswer.correctContent = answerJsonObj["answer"].toString();
    this->parsedAnswer.userContent = answerJsonObj["userAnswer"].toString();
    this->parsedAnswer.state = (AnswerState)answerJsonObj["judgeType"].toInt();
    if  (this->parsedAnswer.state == AnswerState::Right) {
        this->parsedAnswer.prompt = "正确";
    } else {
        this->parsedAnswer.prompt = "错误";
    }
}








