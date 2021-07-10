// Created by liugquoqiang at 2020-11-20

#ifndef HOMEWORKSEARCHNETPARSER_H
#define HOMEWORKSEARCHNETPARSER_H

#include <QObject>
#include <QJsonObject>
#include "QuestionModel.h"


class HomeworkSearchNetParser : public QObject
{
    Q_OBJECT

public:
    enum BusinessCode{
        Ok = 0,
        QuestionUnFound = 1001,
        AnswerQuestionUnFound = 2001,
        ServerUnKownError = 500,
        UndefinedBusinessCode = 0xFF,
    };

    enum DataType {
        OralCalculation = 0,
        NormalQuestion = 1,
        Answer = 2,
        UndefinedDataType = 0xFF,
    };

    BusinessCode code = BusinessCode::UndefinedBusinessCode;
    DataType type = DataType::UndefinedDataType;
    QuestionModel parsedQuestion; // DataType 为口算, 搜题时有效. 替换现有问题. 口算时同时填充 parsedAnswer 数据
    QuestionAnswer parsedAnswer; // DataType 为批改时有效. 更新现有问题答案数据.
    QString msg;

public:
    explicit HomeworkSearchNetParser(QObject *parent = nullptr);
    void beginParse(const QString& response);

private:
    void parseResponse(const QJsonObject &jsonObj);
    void parseOralQuestion(const QJsonObject &jsonObj, const QString &ocr);
    void parseNormalQuestion(const QJsonObject &jsonObj, const QString &ocr);
    void parseAnswer(const QJsonObject &jsonObj, const QString &ocr);
};

#endif // HOMEWORKSEARCHNETPARSER_H
