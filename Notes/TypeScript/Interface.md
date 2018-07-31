# Interface

One of TypeScript’s core principles is that type-checking focuses on the shape that values have.

简单来说, 相对于之前语言的固定类型, 例如明确的接口定义和明确的类型定义, TS 中的接口概念更多的是一种匹配的概念. JS 里面完全没有类型检查的过程, 只是在运行时, 发现没有对应的属性和方法的时候报错. TS 所做的, 则是在 JS 上添加一些类型核查工作. 实际上, 在一个 JS 方法内部, 一般只会调用 C++ 中接口或者类型中的几个方法, 或者几个属性, 那么对于这个 JS 方法来说, 它其实是想要一个 subtype, 但是为了一个 Subtype 专门定义一个接口又失去了 JS 这门语言的灵活和优雅. 所以, 可以在方法的定义时, 在参数列表中写出一个子类型的要求, 当然, 如果这个接口需要公布出去, 就写一个明确的 Interface 的定义. 这个概念很像是之前闭包的使用. 一个方法里面, 需要一个回调函数, 但是又没有必要写一个监听者模式, 那么在使用者那边, 看到回调方法的原型, 在调用的时候动态的生成一个符合 '回调接口' 的 block 对象, 完全可以运行. 调用回调的方法, 根本不用知道真正执行回调的对象的类型是什么, 只知道这个 block 符合自己的接口要求. 这样大大的减少了通信的成本. 不过缺点就是, 追查错误的时候变得困难.

明确的接口定义, 使得追踪变得简单, 因为每个对象的生成都有确定的类型限制. 而这种可以在需要的时候, 定义一个 subtype 的模式, 会让代码的结构难以控制.

## 接口

```TS
function printLabel(labelledObj: { label: string }) {
    console.log(labelledObj.label);
}

let myObj = {size: 10, label: "Size 10 Object"};
printLabel(myObj);

----
interface LabelledValue {
    label: string;
}

function printLabel(labelledObj: LabelledValue) {
    console.log(labelledObj.label);
}

let myObj = {size: 10, label: "Size 10 Object"};
printLabel(myObj);
```

上面这段代码, 如果是 JS 的就是, 运行的时候, 调用参数里面的 label 属性进行输出. 因为不是 obj.property.property 这样, 也不是函数需要后面(), 所以计算 undefined 也没有关系. 但是, TS 做的就是类型核查. 所以, 它在后面加了约束, 主要是为了 ts 的编译器帮助我们, 在编译阶段就把错误检查出来. 如果, 所有的变量我们都做了类型指定, 那么这就很容易能够推测出来.

刚做了实验, 如果你的参数是 any, 那么 ts 就不会给你做核查. 只要实参符合 itnerface 的要求, 那这就算是通过了.

注意, 我们的实参是没有必要写明, 实参是符合某个 interface 的.

## optional

```TS
interface SquareConfig {
    color?: string;
    width?: number;
}

function createSquare(config: SquareConfig): {color: string; area: number} {
    let newSquare = {color: "white", area: 100};
    if (config.color) {
        newSquare.color = config.color;
    }
    if (config.width) {
        newSquare.area = config.width * config.width;
    }
    return newSquare;
}

let mySquare = createSquare({color: "black"});
```

optianl 有两个好处

* 类型核对

当实参和形参名称能够匹配, 但是名字匹配之后类型不对的时候还是会报错

* type error

函数里面是面向接口编程, 只能用接口里面规定出来的属性, 所以这样能避免书写错误, 比如 color 写成了 colr

## readonly

``` TS
interface Point {
    readonly x: number;
    readonly y: number;
}
let p1: Point = { x: 10, y: 20 };
p1.x = 5; // error!

let a: number[] = [1, 2, 3, 4];
let ro: ReadonlyArray<number> = a;
ro[0] = 12; // error!
ro.push(5); // error!
ro.length = 100; // error!
a = ro; // error!
let b = ro as number[];
// 之后, 修改 b , 还是会影响到 ro 还有 a 的, 本质上来说, 就是个别名. 并没有新的拷贝发生
```

## Object literals

Object literals get special treatment and undergo excess property checking when assigning them to other variables, or passing them as arguments. If an object literal has any properties that the “target type” doesn’t have, you’ll get an error.

用字面量初始化的对象, 在传递给一个有类型的参数或者变量的时候, 会认为多余接口的属性是错误的. 将他们存储到一个对象, 然后传入那个对象则不会发生这样的问题. 所以, 这是 TS 为了确保字面量对象专门做的处理, 为了就是减少输入的错误.

## FunctionTypes

函数签名, 很像其他语言的概念, 里面的名字不是很重要, 但是返回值类型和参数的类型, 一定要根据位置关系匹配上.

当一个变量有了明确的类型信息之后, 那么在给这个变量赋值的时候, 可以略去某些类型的明确指定, 因为 TS 可以根据它的类型信息进行推断. 当函数体内发生了类型冲突, TS 会给出警告.

FunctionType 可以当做是一个类型, 可以放到其他的接口里面作为属性的类型, 也可以放到参数列表里面, 作为回调形参的类型.

```TS
interface SearchFunc {
    (source: string, subString: string): boolean;
}

let mySearch: SearchFunc;
mySearch = function(src, sub) {
    let result = src.search(sub);
    return result > -1;
}
```

## Indexable Types

下标运算符其实就是函数运算, 所以形式应该和函数的接口差不多, 这里专门用[]来表示这是一个下标的运算.

现在下标[]里面只有两种, number, stirng, 如果设置了 string 的接口, 那么返回值类型一定是包含数字接口的, 因为 number 的其实也是转换成为字符串数字进行取值的, 这是 JS 里面的规定.

string 下标接口会影响到属性的接口, 因为所有的属性其实都是最后都是 string 下标接口的调用, 所以这个接口其实会影响到很多东西.

```TS
interface StringArray {
     readonly [index: number]: string;
     [index: string]: number;
     length: number;    // ok, length is a number
     name: string;      // error, the type of 'name' is not a subtype of the indexer
}

let myArray: StringArray;
myArray = ["Bob", "Fred"];

let myStr: string = myArray[0];
```

## Class Types

Interfaces describe the public side of the class

```TS
interface ClockInterface {
    currentTime: Date;
}

class Clock implements ClockInterface {
    currentTime: Date;
    constructor(h: number, m: number) { }
}
```

## Extending Interfaces

在扩展接口的时候, 如果发现了同名但是类型定义不同的, 会报错.

```TS
interface Shape {
    color: string;
}

interface Square extends Shape {
    sideLength: number;
}

let square = <Square>{};
square.color = "blue";
square.sideLength = 10;
```

## Hybrid Types

这里, Counter 既是一个函数类型, 又是一个对象, 对象里面有两个属性, 一个 number 类型, 一个函数类型. 下面我们也看到, Counter 是一个函数对象, 添加了两个属性. 这是因为 JS 里面, 函数就是对象, 才能实现这样的功能.

```TS
interface Counter {
    (start: number): string;
    interval: number;
    reset(): void;
}

function getCounter(): Counter {
    let counter = <Counter>function (start: number) { };
    counter.interval = 123;
    counter.reset = function () { };
    return counter;
}

let c = getCounter();
c(10);
c.reset();
c.interval = 5.0;
```

## Interfaces Extending Classes

接口扩展 class , 仅仅是接口的继承