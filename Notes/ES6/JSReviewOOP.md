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



