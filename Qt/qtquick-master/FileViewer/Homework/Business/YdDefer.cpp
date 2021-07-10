// Created by liugquoqiang at 2020-11-21

#include "YdDefer.h"

YdDefer::YdDefer(std::function<void(void)> action):mAction(action)
{

}

YdDefer::~YdDefer()
{
    if (mAction) {
        mAction();
    }
}

void YdDefer::waitInvoke()
{

}
