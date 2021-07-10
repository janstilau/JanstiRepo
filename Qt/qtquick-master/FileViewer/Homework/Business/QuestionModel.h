// Created by liugquoqiang at 2020-11-18

#ifdef YD_HOMEWORK

#ifndef QUESTIONMODEL_H
#define QUESTIONMODEL_H

#include <QObject>
#include <QString>
#include <QVector>

enum AnswerState {
    Right = 0, // 正确
    Wrong, // 错误
    NotSure, // 未回答
};

enum QuestionType {
    OralCalculation = 0, // 口算题
    NormalQuestion, // 搜题, 目前认为是非口算题
    Unvalid = 0xFFFF, // 非法值
};

struct QuestionAnswer {
    QString correctContent; // 正确答案
    QString userContent; // 用户答案
    QString prompt; // 提示信息
    AnswerState state = AnswerState::NotSure; // 当前状态
};

struct QuestionModel {
    QuestionType type = QuestionType::Unvalid; // 问题类型
    QString id; // identifier, 目前只有搜题类型有效.
    QString body; // 题干
    QString ocr; // ocr 内容, 搜题依据
    QString explanation; // 题目解析
    int answerCount = 0; // 答案总数
    int remainAnswerCount = 0; // 未回答个数
    QVector<QuestionAnswer> answers; // 答案列表
    QString bodyHtml;
};

Q_DECLARE_METATYPE(QuestionModel);
Q_DECLARE_METATYPE(QuestionAnswer);

#endif // QUESTIONMODEL_H

#endif
