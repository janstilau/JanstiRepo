# ES6编程风格

## let 全面替代 var

var命令存在变量提升效用，let命令没有这个问题。var 的变量提升会造成很多的问题, 而且和其他语言的通用习惯不相符, 而 let 和和其他语言是相同的.

## 常量和线程安全

let 和 const 之间, 优先 const, 这在所有语言里面都是一样的.

全局环境下, 应该都是 const. 并且, 编译器会对 const 进行优化, 所以 const 和 let 有着本质区别.

## 字符串

字符串一律使用单引号, 动态祖父穿使用反引号, 舍弃双引号.

## 解构赋值

使用数组成员对变量赋值的时候, 优先使用解构赋值.
函数的参数如果是对象的成员, 优先使用解构赋值
如果函数返回多个值，优先使用对象的解构赋值，而不是数组的解构赋值。这样便于以后添加返回值，以及更改返回值的顺序。

``` js
const arr = [1, 2, 3, 4];
const [first, second] = arr;

// good
function getFullName(obj) {
  const { firstName, lastName } = obj;
}
// best
function getFullName({ firstName, lastName }) {
}

// bad
function processInput(input) {
  return [left, right, top, bottom];
}

// good
function processInput(input) {
  return { left, right, top, bottom };
}

const { left, right } = processInput(input);
```

## ESLine

