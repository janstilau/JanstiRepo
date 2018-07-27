# ClosureInJS

A closure is the combination of a function and the lexical environment within which that function was declared.

```JS
function makeFunc() {
  var name = 'Mozilla';
  function displayName() {
    alert(name);
  }
  return displayName;
}

var myFunc = makeFunc();
myFunc();

function makeAdder(x) {
  return function(y) {
    return x + y;
  };
}

var add5 = makeAdder(5);
var add10 = makeAdder(10);
```

Functions in JavaScript form closures. A closure is the combination of a function and the lexical environment within which that function was declared. This environment consists of any local variables that were in-scope at the time the closure was created. The instance of displayName maintains a reference to its lexical environment, within which the variable name exists. For this reason, when myFunc is invoked, the variable name remains available for use and "Mozilla" is passed to alert.

add5 and add10 are both closures. They share the same function body definition, but store different lexical environments. In add5's lexical environment, x is 5, while in the lexical environment for add10, x is 10.

This environment consists of any local variables that were in-scope at the time the closure was created. 这句话表明了, 环境这个东西, 是每次函数调用的时候生成的. 而 add5 和 add10 也表明了, 同样的一个函数, 在两次执行的时候, 其实是两个环境. JS 里面, 所有的变量其实都是作为一个环境的变量对象的属性的, 我们把变量对象去掉, 就是每一个变量都是和环境捆绑在一起的. The instance of displayName maintains a reference to its lexical environment 表明, 函数其实就是一个对象, 在我们写下

```JS
 var name = 'Mozilla';
  function displayName() {
    alert(name);
  }
  return displayName;
```

的时候, 实际上是生成了一个闭包对象, 然后将这个闭包对象传出去. 那么其实, 我们在定义一个对象的时候, 实际上这个对象的一个函数属性, 对应的也是一个内存块而已, 这个内存块代表一个闭包对象. JS 里面的闭包, 保存的不是它捕获的各个变量, 而是它所在环境. 通过这个环境, 可以在访问到没有见到的变量的时候, 从这个环境里面进行寻找. 这样就能够找到对应变量的值了.

## 函数

函数是一个对象, 是一个 Function 类型的实例, 和其他引用类型一样, 都有属性和方法. 所以函数名, 也仅仅是一个指向函数对象的指针, 不会和某个函数进行绑定. 所以, 下面的代码是几乎没有差别的.

```JS
function sum_1(num1, num2) {
    return num1 + num2
}

let sum_2 = function (num1, num2) {
    return num1 + num2
}

var sum = new Function("num1", "num2", "return num1 + num2"); 
```

函数是对象这个观念非常的重要, 需要分辨出来的是, 定义函数的时候的执行环境, 和函数运行的时候执行环境 是两个不同的概念, 函数和闭包的不同, 可以看做是, 如果一个函数, 引用了它外部的变量, 就会变成一个闭包. 那么其实, 函数在定义的时候, 其实就已经分配了内存空间了, 而这个内存空间里面, 如果捕获了外界的变量, 那么这个空间就会存储它的外界环境的引用, 然后在函数真正执行的时候, 会将存储的外界环境的引用, 传到自己的引用链条上, 这样函数执行的时候, 就能够访问到捕获的外界变量了. 这个捕获的外界环境是不会改变的. 是函数定义的时候将这个值确定下来的.

因为, 函数仅仅是对象, 函数名仅仅是对于这个对象的一个引用. 所以, JS 中的函数是没有重载的. 重载的观念要建立在函数原型上, 但是 JS 没有函数原型这个概念.

函数声明, 和函数表达式, 在解析器在向执行环境加载数据的时候, 并不是一视同仁. 函数表达式, 会在执行任何代码之前进行加载, 保证执行代码的时候, 函数可用, 这就是 function declare hoisting, 而函数表达式则是必须等到解析器执行到所在的代码才会被真正的执行. 除了这一点, 函数声明和函数表达式是等价的.

## 函数的内部属性

arguments, 类似数组的对象, 里面包含着传入的所有的参数. 里面还有一个 callee 的属性, 是一个指针, 指向了拥有 arguments 的函数.

this, 引用的是函数执行的时候的环境对象.