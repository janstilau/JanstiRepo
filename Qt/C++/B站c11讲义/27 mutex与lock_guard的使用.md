# mutex与lock_guard的使用

```c++
// TestC11.cpp : 定义控制台应用程序的入口点。
//

#include "stdafx.h"
#include <iostream>
#include <thread>
#include <mutex>
#include <windows.h>
using namespace std;

int g_nData = 0;

//创建临界区对象--等价于锁
std::mutex g_mtx;


void foo() {

    {
        std::lock_guard<std::mutex> lg(g_mtx);
        //g_mtx.lock();
        //进来上锁（颗粒度）
        for (int i = 0; i < 100000; i++) {
            g_nData++;
        }
        //出去解锁
        //g_mtx.unlock();

    }

}

int _tmain(int argc, _TCHAR* argv[])
{
    std::thread t(foo);
    //进来上锁
    {
        std::lock_guard<std::mutex> lg(g_mtx);
        //g_mtx.lock();
        for (int i = 0; i < 100000; i++) {
            g_nData++;
        }
        //g_mtx.unlock();
    }
    t.join();

    std::cout << g_nData << std::endl;

    return 0;
}
```

