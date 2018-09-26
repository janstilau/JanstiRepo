# 面向对象

需要一个模板，表示某一类实物的共同特征，然后对象根据这个模板生成.
JavaScript 语言使用构造函数（constructor）作为对象的模板。所谓”构造函数”，就是专门用来生成实例对象的函数。它就是对象的模板，描述实例对象的基本结构。一个构造函数，可以生成多个实例对象，这些实例对象都有相同的结构。

函数体内部使用了this关键字，代表了所要生成的对象实例。
生成对象的时候，必须使用new命令。

## new

new命令的作用，就是执行构造函数，返回一个实例对象。

使用new命令时，它后面的函数依次执行下面的步骤。

1. 创建一个空对象，作为将要返回的对象实例。
1. 将这个空对象的原型，指向构造函数的prototype属性。
1. 将这个空对象赋值给函数内部的this关键字。
1. 开始执行构造函数内部的代码。

构造函数内部，this指的是一个新生成的空对象，所有针对this的操作，都会发生在这个空对象上。
如果构造函数内部有return语句，而且return后面跟着一个对象，new命令会返回return语句指定的对象；否则，就会不管return语句，返回this对象。

```JS
function _new(/* 构造函数 */ constructor, /* 构造函数参数 */ params) {
  // 将 arguments 对象转为数组
  var args = [].slice.call(arguments);
  // 取出构造函数
  var constructor = args.shift();
  // 创建一个空对象，继承构造函数的 prototype 属性
  var context = Object.create(constructor.prototype);
  // 执行构造函数
  var result = constructor.apply(context, args);
  // 如果返回结果是对象，就直接返回，否则返回 context 对象
  return (typeof result === 'object' && result != null) ? result : context;
}
```

### this

我觉得, this 就是 JS 中方法和对象之间的一种引用机制, 因为 JS 中方法是一个独立的单位, 并不是作为某个类成员保存的, 而是一个独立的, 可以被赋值的内存区域, 所以, JS 中的其实是没有 this 指针这种东西的. 那么 JS 又要进行一个方法和数据的绑定, 用来实现基于对象的设计. 所以, 解释器就有了 this 这个关键字. this 应该来说就是方法里面引用方法想要操作数据所在所在对象的一个占位符. 索引方法的方式不同, 解释器会将 this 翻译成为不同的值.

1. 直接使用函数.

所谓直接使用函数, 就是不是通过对象 --> 函数 这样的方式得到函数.

例如 let f = obj.foo; f() 的时候, f 直接引用到了函数对象, 这样调用 f 的时候, 是直接调用函数, 这个时候函数内部的 this 就是全局对象.

1. 对象的方法

obj.foo(). 解释器发现引用到 foo 这个函数对象, 是根据 obj 这个对象的地址. 那这个时候, obj 就是 this 了

可以这样理解，JavaScript 引擎内部，obj和obj.foo储存在两个内存地址，称为地址一和地址二。obj.foo()这样调用时，是从地址一调用地址二，因此地址二的运行环境是地址一，this指向obj

1. 构造函数

构造函数的处理逻辑是, 首先, 生成一个 OBJECT 空对象, 这个空对象的原型 constructor 的prototype, 然后调用 constructor 为这个空对象赋值, 最后返回这个对象.
构造函数中的this，指的是实例对象.
这里, this 是这个空对象, 就是解释器的行为. 所以你看, this 到底指的是什么, 和书上的解释什么方法的运行环境没有什么关系, 这就是解释器的一个行为.


### this的注意点

* 避免多层 this

```JS
var o = {
  f1: function () {
    console.log(this);
    var f2 = function () {
      console.log(this);
    }();
  }
}
o.f1()
```

o.f1() 的时候, f1 里面的 this, 根据上面的理论, f1是根据 o 的地址访问到的, 所以就是f1里面的 this 就是 o. 但是 f2 在调用的时候, f2 是一个独立的内存单元, 并没有根据一个对象才能够访问到, 这个时候 f2 里面的 this 就是顶级对象.

解决的办法, 就是在第二层改用指向现在 this 的一个变量.

``` JS
var o = {
  f1: function() {
    console.log(this);
    var that = this;
    var f2 = function() {
      console.log(that);
    }();
  }
}
```

这个代码里面, f2 中捕获了 that, 而 that 的值就是 this 的值. 根据闭包的理论, 闭包捕获的变量的值, 是闭包定义的时候的值. 那么f2运行的时候的 that, 就是f2的定义的时候 this 的值. 如果 f1 不是 o.f1() 这样调用的话, that 的值还会是顶级对象.

* 数组方法里面的 this

数组方法里面有很多的回调函数的设置, 而我们经常是在类的方法里面使用数组方法, 这个时候, 回调里面的 this, 其实是顶级对象的, 原因在于, 回调方法是直接引用的, 不是根据 obj.回调() 这样使用的. 不过, Array 里面专门为这些方法指定了第二参数, 用来作为 this 的指向.

## 绑定 this 的方法

* Function.prototype.call()

call方法的参数，应该是一个对象。如果参数为空、null和undefined，则默认传入全局对象。
call的第一个参数就是this所要指向的那个对象，后面的参数则是函数调用时所需的参数

``` JS
var n = 123;
var obj = { n: 456 };

function a() {
  console.log(this.n);
}

a.call() // 123
a.call(null) // 123
a.call(undefined) // 123
a.call(window) // 123
a.call(obj) // 456
```

* Function.prototype.apply() 

apply方法的作用与call方法类似，也是改变this指向，然后再调用该函数。唯一的区别就是，它接收一个数组作为函数执行时的参数.

* Function.prototype.bind()

bind方法用于将函数体内的this绑定到某个对象，然后返回一个新函数。
bind还可以接受更多的参数，将这些参数绑定原函数的参数。
如果bind方法的第一个参数是null或undefined，等于将this绑定到全局对象，函数运行时this指向顶层对象（浏览器为window）。
bind方法每运行一次，就返回一个新函数

这里, 想象一下在 C++ 里面的 bind. C++ 里面的 bind, 接受一个可调函数对象, 然后可以绑定某些参数, 在这个 bind 的内部, 会产生一个匿名类, 这个匿名类里面会将可调函数对象, bind 的参数作为自己的成员变量, 并且重载 operator() 操作符, 重载函数里面会调用保存的可调对象, 并且把绑定的参数传过去, 这样就实现了某些参数固定的效果, 然后返回这个匿名类的对象, 这样调用bind 的结果的时候, 就只用传入那些没有绑定的参数就可以了.

JS 里面铁定还是这样的一个过程, 不过, JS 可以绑定 this, 这个就是解释器的事情了.

```HTML
利用bind方法，可以改写一些 JavaScript 原生方法的使用形式，以数组的slice方法为例。

[1, 2, 3].slice(0, 1) // [1]
// 等同于
Array.prototype.slice.call([1, 2, 3], 0, 1) // [1]
上面的代码中，数组的slice方法从[1, 2, 3]里面，按照指定位置和长度切分出另一个数组。这样做的本质是在[1, 2, 3]上面调用Array.prototype.slice方法，因此可以用call方法表达这个过程，得到同样的结果。

call方法实质上是调用Function.prototype.call方法，因此上面的表达式可以用bind方法改写。

var slice = Function.prototype.call.bind(Array.prototype.slice);
slice([1, 2, 3], 0, 1) // [1]
上面代码的含义就是，将Array.prototype.slice变成Function.prototype.call方法所在的对象，调用时就变成了Array.prototype.slice.call
```

上面的这一段看了好久, Array.prototype.slice.call([1, 2, 3], 0, 1) 的时候, call 中的 this 就是 slice, 所以 var slice = Function.prototype.call.bind(Array.prototype.slice); 的时候, 绑定的是 call 这个函数, 不过把 call 中的 this 绑定成为了 slice 函数对象了. call, apply 怎么实现的, 还是值得研究的.

## 继承

* 为什么要有原型这种东西.

因为, 构造函数里面, 给 this 赋值的那些属性, 应该是专属于对象的一些属性. 类似于类系统的成员变量. 因为 JS 中函数其实是一个内存对象, 每次都给 this 赋值一个函数对象的话, 其实是一种浪费的事情. 所以, 需要有一个地方存放这些共有的东西. 这就是原型对象.

JavaScript 继承机制的设计思想就是，原型对象的所有属性和方法，都能被实例对象共享。也就是说，如果属性和方法定义在原型上，那么所有实例对象就能共享，不仅节省了内存，还体现了实例对象之间的联系。

JavaScript 规定，每个函数都有一个prototype属性，指向一个对象。普通函数来说，该属性基本无用。但是，对于构造函数来说，生成实例的时候，该属性会自动成为实例对象的原型。原型对象的属性不是实例对象自身的属性。只要修改原型对象，变动就立刻会体现在所有实例对象上。

* 原型链

所有对象都有自己的原型对象（prototype）。一方面，任何一个对象，都可以充当其他对象的原型；另一方面，由于原型对象也是对象，所以它也有自己的原型。因此，就会形成一个“原型链”（prototype chain）：对象到原型，再到原型的原型……

如果一层层地上溯，所有对象的原型最终都可以上溯到Object.prototype，即Object构造函数的prototype属性。也就是说，所有对象都继承了Object.prototype的属性。这就是所有对象都有valueOf和toString方法的原因，因为这是从Object.prototype继承的。Object.prototype的原型是null。null没有任何属性和方法，也没有自己的原型。因此，原型链的尽头就是null。

读取对象的某个属性时，JavaScript 引擎先寻找对象本身的属性，如果找不到，就到它的原型去找，如果还是找不到，就到原型的原型去找。如果直到最顶层的Object.prototype还是找不到，则返回undefined。如果对象自身和它的原型，都定义了一个同名属性，那么优先读取对象自身的属性，这叫做“覆盖”（overriding）。

* constructor 属性

prototype对象有一个constructor属性，默认指向prototype对象所在的构造函数. 由于constructor属性定义在prototype对象上面，意味着可以被所有实例对象继承。constructor属性的作用是，可以得知某个实例对象，到底是哪一个构造函数产生的。有了constructor属性，就可以从一个实例对象新建另一个实例.

还记得原型模式吗, 原型模式最大的用处就是, 在得到一个对象的实例之后, 想要生成这个对象, 但是却不知道应该调用哪个构造方法. 因为 new Person 这种东西, 明确的写出类的名称是和设计模式的原则不相符的. 所以, 原型模式里面, 要求基类里面有个 clone 函数, 然后每个子类都要实现这个函数. 现在, 这个模式在 JS 里面不存在了, 在语言层面上就消灭了原型模式存在的意义.

constructor属性表示原型对象与构造函数之间的关联关系，如果修改了原型对象，一般会同时修改constructor属性，防止引用的时候出错。如果不能确定constructor属性是什么函数，还有一个办法：通过name属性，从实例得到构造函数的名称。

```JS
function Constr() {}
var x = new Constr();

var y = new x.constructor();
y instanceof Constr // true
```

* instanceof 运算符

instanceof运算符返回一个布尔值，表示对象是否为某个构造函数的实例

instanceof运算符的左边是实例对象，右边是构造函数。它会检查右边构建函数的原型对象（prototype），是否在左边对象的原型链上。因此，下面两种写法是等价的。

由于instanceof检查整个原型链，因此同一个实例对象，可能会对多个构造函数都返回true

利用instanceof运算符，还可以巧妙地解决，调用构造函数时，忘了加new命令的问题。

```JS
function Fubar (foo, bar) {
  if (this instanceof Fubar) {
    this._foo = foo;
    this._bar = bar;
  } else {
    return new Fubar(foo, bar);
  }
}
```

* 构造函数的继承

让一个构造函数继承另一个构造函数，是非常常见的需求。这可以分成两步实现。第一步是在子类的构造函数中，调用父类的构造函数。
Sub是子类的构造函数，this是子类的实例。在实例上调用父类的构造函数Super，就会让子类实例具有父类实例的属性。
第二步，是让子类的原型指向父类的原型，这样子类就可以继承父类原型。

```JS
function Sub(value) {
  Super.call(this);
  this.prop = value;
}
Sub.prototype = Object.create(Super.prototype);
Sub.prototype.constructor = Sub;
Sub.prototype.method = '...';
```

## Object 方法

这些方法, 有些是 Object 的, 有些是 Object.prototype 的

* Object.getPrototypeOf方法返回参数对象的原型。这是获取原型对象的标准方法。
* Object.setPrototypeOf方法为参数对象设置原型，返回该参数对象。它接受两个参数，第一个是现有对象，第二个是原型对象。
* Object.create方法接受一个对象作为参数，然后以它为原型，返回一个实例对象。该实例完全继承原型对象的属性。
* Object.prototype.isPrototypeOf()

实例对象的isPrototypeOf方法，用来判断该对象是否为参数对象的原型。

* Object.getOwnPropertyNames方法返回一个数组，成员是参数对象本身的所有属性的键名，不包含继承的属性键名Object.getOwnPropertyNames方法返回所有键名，不管是否可以遍历。只获取那些可以遍历的属性，使用Object.keys方法。
* Object.prototype.hasOwnProperty()

对象实例的hasOwnProperty方法返回一个布尔值，用于判断某个属性定义在对象自身，还是定义在原型链上。

* in 运算符和 for...in 循环

in运算符返回一个布尔值，表示一个对象是否具有某个属性。它不区分该属性是对象自身的属性，还是继承的属性。
获得对象的所有可遍历属性（不管是自身的还是继承的），可以使用for...in循环。
为了在for...in循环中获得对象自身的属性，可以采用hasOwnProperty方法判断一下。