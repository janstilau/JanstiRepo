# unique_ptr

前面我们讲解了auto_ptr的使用及为什么会被C++11标准抛弃，接下来，我们来学习unique_ptr的使用：

unique_ptr提供了以下操作：

![img](file:///C:/Users/Halo/Documents/My Knowledge/temp/b1d45e13-ec86-424f-b65b-54da3a6d7aba/128/index_files/94b82bb3-7752-4769-b00e-07bd1f867d77.png)

看起来似乎与auto_ptr相似，但是其实有区别。

**1. 构造函数**

![img](file:///C:/Users/Halo/Documents/My Knowledge/temp/b1d45e13-ec86-424f-b65b-54da3a6d7aba/128/index_files/0523ffce-b180-4911-9efe-8f161b45e0bc.png)

 虽然这里的构造函数比较多，但是可以发现，实际上是没有类似auto_ptr的那种拷贝构造：

 

```c++
void foo_constuct()
{
    //这样构造是可以的
    std::unique_ptr<int> p(new int(3));

    //空构造
    std::unique_ptr<int> p4;

    //下面三种写法会报错
    std::unique_ptr<int> p2 = p;
    std::unique_ptr<int> p3(p);
    p4 = p;

}
```

因此，这就从根源上杜绝了auto_ptr作为参数传递的写法了。

**2. reset**

 reset的用法和auto_ptr是一致的：

 

```c++
void foo_reset()
{
    //释放
    int* pNew = new int(3);
    int*p = new int(5);
    {
        std::unique_ptr<int> uptr(pNew);
        uptr.reset(p);

    }
}
```

**3.release**

release与reset一样，也不会释放原来的内部指针，只是简单的将自身置空。

 

```c++
void foo_release()
{
    //释放
    int* pNew = new int(3);
    int* p = NULL;
    {
        std::unique_ptr<int> uptr(pNew);
        p = uptr.release();
    }
}
```

![img](file:///C:/Users/Halo/Documents/My Knowledge/temp/b1d45e13-ec86-424f-b65b-54da3a6d7aba/128/index_files/a95cd403-92ea-40fb-bdd6-97e3e750bab2.png)

**4.move**

但是多了个move的用法：

 

```c++
void foo_move()
{
    int* p = new int(3);
    
    std::unique_ptr<int> uptr(p);
    std::unique_ptr<int> uptr2 = std::move(uptr);
    
}
```

因为unique_ptr不能将自身对象内部指针直接赋值给其他unique_ptr，所以这里可以使用std::move()函数，让unique_ptr交出其内部指针的所有权，而自身置空，内部指针不会释放。

![img](file:///C:/Users/Halo/Documents/My Knowledge/temp/b1d45e13-ec86-424f-b65b-54da3a6d7aba/128/index_files/3017dd59-f79d-48a8-be40-7804f5b9ef2b.png)

**5.数组**

可以采用move的方法来使用数组。

直接使用仍然会报错：

 

```c++
void foo_ary()
{
    std::vector<std::unique_ptr<int>> Ary;
    std::unique_ptr<int> p(new int(3));
    Ary.push_back(p);

    printf("%d\r\n", *p);

}
```

![img](file:///C:/Users/Halo/Documents/My Knowledge/temp/b1d45e13-ec86-424f-b65b-54da3a6d7aba/128/index_files/0bdb5112-0c91-44c7-ab6d-4f49d5dd4a58.png)

但是可以采用move的办法，这样就编译通过了：

 

```c++
void foo_ary()
{
    std::vector<std::unique_ptr<int>> Ary;
    std::unique_ptr<int> uptr(new int(3));
    Ary.push_back(std::move(uptr));

    printf("%d\r\n", *uptr);

}
```

但是因为uptr的语义，所以作为参数传递了， 转移了内部指针的所有权，原来的uptr就不能使用了。

![img](file:///C:/Users/Halo/Documents/My Knowledge/temp/b1d45e13-ec86-424f-b65b-54da3a6d7aba/128/index_files/ad0758a2-f240-41e7-a3ae-900ec5c2b414.png)

所以综上，unique_ptr指的是只有一个对象拥有指针的所有权，可以转移，但是不能直接赋值或者拷贝构造。

所有示例代码如下：

 

```c++
// testUniqueptr.cpp : 定义控制台应用程序的入口点。
//

#include "stdafx.h"
#include <iostream>
#include <memory>
#include <vector>

void foo_constuct()
{
    //这样构造是可以的
    std::unique_ptr<int> p(new int(3));

    //空构造
    std::unique_ptr<int> p4;

    //下面三种写法会报错
//  std::unique_ptr<int> p2 = p;
//  std::unique_ptr<int> p3(p);
//  p4 = p;

}

void foo_reset()
{
    //释放
    int* pNew = new int(3);
    int*p = new int(5);
    {
        std::unique_ptr<int> uptr(pNew);
        uptr.reset(p);

    }
}

void foo_release()
{
    //释放
    int* pNew = new int(3);
    int* p = NULL;
    {
        std::auto_ptr<int> uptr(pNew);
        p = uptr.release();
    }
}



void foo_move()
{
    int* p = new int(3);
    std::unique_ptr<int> uptr(p);
    std::unique_ptr<int> uptr2 = std::move(uptr);
}

void foo_ary()
{
    std::vector<std::unique_ptr<int>> Ary;
    std::unique_ptr<int> uptr(new int(3));
    Ary.push_back(std::move(uptr));

    printf("%d\r\n", *uptr);

}


int _tmain(int argc, _TCHAR* argv[])
{
    foo_ary();




    return 0;
}


```