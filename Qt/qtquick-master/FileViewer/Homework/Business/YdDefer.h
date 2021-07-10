// Created by liugquoqiang at 2020-11-21

#ifndef YDDEFER_H
#define YDDEFER_H

#include <iostream>
#include <functional>

class YdDefer
{
public:
    YdDefer(std::function<void(void)> action);
    ~YdDefer();
    void waitInvoke();
private:
    std::function<void(void)> mAction = nullptr;
};

#endif // YDDEFER_H
