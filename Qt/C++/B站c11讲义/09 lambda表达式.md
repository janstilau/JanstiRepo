

# lambda表达式 / 匿名函数

**Lambda** 表达式  是一个源自阿隆佐·邱奇（Alonzo Church）——艾伦·图灵（Alan Turing）的老师——的术语。邱奇创立了 λ 演算 ，后来被证明和图灵机是等价的。

**Lambda** 表达式是 C++ 11 中最重要的新特性之一，而 Lambda 表达式，实际上就是提供了一个类似匿名函数的特性，而匿名函数则是在需要一个函数，但是又不想费力去命名一个函数的情况下去使用的。这样的场景其实有很多很多，所以匿名函数几乎是现代编程语言的标配。



#### （1）Lambda 表达式基础



Lambda 表达式的基本语法如下：

```txt
[捕获列表](参数列表) mutable(可选) 异常属性 -> 返回类型 {
    // 函数体
}
[ caputrue ] ( params ) opt -> ret { body; };
```

- Lambda 表达式以一对**中括号**开始。

- 跟函数定义一样，我们有**参数列表**

- 跟正常的函数定义一样，我们会有一个函数体，里面会有 return 语句

- Lambda 表达式一般不需要说明返回值（相当于 auto）；有特殊情况需要说明时，则应使用箭头语法的方式

- 每个 lambda 表达式都有一个全局唯一的类型，要精确捕捉 lambda 表达式到一个变量中，只能通过 auto 声明的方式



#### 基本使用

- 参数列表

- 返回类型

- 函数体

  ```C++
  #include "stdafx.h"
  #include <algorithm>
  #include <iostream>
  #include <vector>
  using namespace std;
  
  int main()
  {
    int c =  [](int a, int b) -> int{
          return a+b;
    }(1, 2);
  
    cout << c << endl;
  
    int d = [](int n) {
      return [n](int x){
          return n + x;
      }(2);
    }(1);
  
    cout << d << endl;
  
    //函数式编程
    //adder=λn.(λx.(+ x n))
    auto adder = [](int n) {
        return [n](int x) {
            return n + x;
        };
    };
  
    cout << adder(1)(2) << endl;
  }
  ```

#### mutable

```c++
#include "stdafx.h"
#include <algorithm>
#include <iostream>
#include <vector>
using namespace std;

int main()
{
    int t = 10;

    auto l = [t]() mutable {
        return ++t;
    };

    auto l2 = [t]() mutable {
        return ++t;
    };

    cout << l() << endl;
    cout << l2() << endl;
    cout << l() << endl;
    cout << l2() << endl;
    cout << t << endl;
}
```



#### 捕获列表



所谓**捕获列表**，其实可以理解为参数的一种类型，lambda 表达式内部函数体在默认情况下是不能够使用函数体外部的变量的，这时候捕获列表可以起到传递外部数据的作用。根据传递的行为，捕获列表也分为以下几种：

**1. 值捕获**

与参数传值类似，值捕获的前期是变量可以拷贝，不同之处则在于，被捕获的变量在 lambda 表达式被创建时拷贝，而非调用时才拷贝：

```cpp
void learn_lambda_func_1() {
    int value_1 = 1;
    auto copy_value_1 = [value_1] {
        return value_1;
    };
    value_1 = 100;
    auto stored_value_1 = copy_value_1();
    // 这时, stored_value_1 == 1, 而 value_1 == 100.
    // 因为 copy_value_1 在创建时就保存了一份 value_1 的拷贝
    cout << "value_1 = " << value_1 << endl;
    cout << "stored_value_1 = " << stored_value_1 << endl;
}
```

**2. 引用捕获**

与引用传参类似，引用捕获保存的是引用，值会发生变化。

```cpp
void learn_lambda_func_2() {
    int value_2 = 1;
    auto copy_value_2 = [&value_2] {
        return value_2;
    };
    value_2 = 100;
    auto stored_value_2 = copy_value_2();
    // 这时, stored_value_2 == 100, value_1 == 100.
    // 因为 copy_value_2 保存的是引用
    cout << "value_2 = " << value_2 << endl;
    cout << "stored_value_2 = " << stored_value_2 << endl;
}
```

**3. 隐式捕获**

手动书写捕获列表有时候是非常复杂的，这种机械性的工作可以交给编译器来处理，这时候可以在捕获列表中写一个 `&` 或 `=` 向编译器声明采用 引用捕获或者值捕获.

总结一下，捕获提供了 Lambda 表达式对外部值进行使用的功能，捕获列表的最常用的四种形式可以是：

- `[]` 空捕获列表
- `[name1, name2, ...]` 捕获一系列变量
- `[&]` 引用捕获, 让编译器自行推导捕获列表
- `[=]` 值捕获, 让编译器执行推导应用列表

##### 使用案例

```C++
#include "stdafx.h"
#include <algorithm>
#include <iostream>
#include <vector>
using namespace std;

int main()
{
    // Create a vector object that contains 10 elements.
    vector<int> v;
    for (int i = 0; i < 10; ++i) {
        v.push_back(i);
    }

    // Count the number of even numbers in the vector by 
    // using the for_each function and a lambda.
    int evenCount = 0;
    for_each(v.begin(), v.end(), [&evenCount](int n) {
        cout << n;

        if (n % 2 == 0) {
            cout << " is even " << endl;
            ++evenCount;
        }
        else {
            cout << " is odd " << endl;
        }
    });

    // Print the count of even numbers to the console.
    cout << "There are " << evenCount
        << " even numbers in the vector." << endl;
}
```

