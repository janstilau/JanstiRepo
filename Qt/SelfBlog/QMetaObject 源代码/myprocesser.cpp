#include "myprocesser.h"

MyProcesser::MyProcesser(QObject *parent) : QObject(parent), mValue(0)
{

}


MyProcesser::MyProcesser(int value): QObject(nullptr) {

}
void MyProcesser::onValueNeedReset(int value)
{
    mValue = value;
}

void MyProcesser::_reset()
{
    emit valueDidChanged(mValue);
}
