# Element节点

Element节点对象对应网页的 HTML 元素。每一个 HTML 元素，在 DOM 树上都会转化成一个Element节点对象（以下简称元素节点）。
元素节点的nodeType属性都是1。
元素节点继承自 Node 接口, 因此 Node 的属性和方法都在 Element 节点存在.
不同的 HTML 元素对应的元素节点是不一样的，浏览器使用不同的构造函数，生成不同的元素节点，比如<a>元素的节点对象由HTMLAnchorElement构造函数生成，<button>元素的节点对象由HTMLButtonElement构造函数生成。因此，元素节点不是一种对象，而是一组对象，这些对象除了继承Element的属性和方法，还有各自构造函数的属性和方法。

## 属性

* Element.id

返回指定元素的id属性，该属性可读写。

```JS
// HTML 代码为 <p id="foo">
var p = document.querySelector('p');
p.id // "foo"
```

* Element.tagName

Element.tagName属性返回指定元素的大写标签名，与nodeName属性的值相等。

```JS
// HTML代码为
// <span id="myspan">Hello</span>
var span = document.getElementById('myspan');
span.id // "myspan"
span.tagName // "SPAN"
```

* Element.draggable

Element.draggable属性返回一个布尔值，表示当前元素是否可拖动。该属性可读写。

* Element.lang

Element.lang属性返回当前元素的语言设置。该属性可读写

```JS
// HTML 代码如下
// <html lang="en">
document.documentElement.lang // "en"
```

* Element.tabIndex

Element.tabIndex属性返回一个整数，表示当前元素在 Tab 键遍历时的顺序。该属性可读写。
tabIndex属性值如果是负值（通常是-1），则 Tab 键不会遍历到该元素。如果是正整数，则按照顺序，从小到大遍历。如果两个元素的tabIndex属性的正整数值相同，则按照出现的顺序遍历。遍历完所有tabIndex为正整数的元素以后，再遍历所有tabIndex等于0、或者属性值是非法值、或者没有tabIndex属性的元素，顺序为它们在网页中出现的顺序。

* Element.title

Element.title属性用来读写当前元素的 HTML 属性title。该属性通常用来指定，鼠标悬浮时弹出的文字提示框。

## 状态相关属性

* Element.hidden

```JS
var btn = document.getElementById('btn');
var mydiv = document.getElementById('mydiv');
btn.addEventListener('click', function () {
  mydiv.hidden = !mydiv.hidden;
}, false);
```

注意，该属性与 CSS 设置是互相独立的。CSS 对这个元素可见性的设置，Element.hidden并不能反映出来。也就是说，这个属性并不能用来判断当前元素的实际可见性
CSS 的设置高于Element.hidden。如果 CSS 指定了该元素不可见（display: none）或可见（display: hidden），那么Element.hidden并不能改变该元素实际的可见性。换言之，这个属性只在 CSS 没有明确设定当前元素的可见性时才有效

* Element.contentEditable，Element.isContentEditable

HTML 元素可以设置contentEditable属性，使得元素的内容可以编辑。

```JS
<div contenteditable>123</div>
```

Element.contentEditable属性返回一个字符串，表示是否设置了contenteditable属性，有三种可能的值。该属性可写。

1. true"：元素内容可编辑
1. "false"：元素内容不可编辑
1. "inherit"：元素是否可编辑，继承了父元素的设置

Element.isContentEditable属性返回一个布尔值，同样表示是否设置了contenteditable属性。该属性只读。

* Element.attributes

```JS
var p = document.querySelector('p');
var attrs = p.attributes;
for (var i = attrs.length - 1; i >= 0; i--) {
  console.log(attrs[i].name + '->' + attrs[i].value);
}
```

* Element.className，Element.classList

className属性用来读写当前元素节点的class属性。它的值是一个字符串，每个class之间用空格分割。
classList属性返回一个类似数组的对象，当前元素节点的每个class就是这个对象的一个成员

```JS
// HTML 代码 <div class="one two three" id="myDiv"></div>
var div = document.getElementById('myDiv');
div.className
// "one two three"
div.classList
// {
//   0: "one"
//   1: "two"
//   2: "three"
//   length: 3
// }
```

上面代码中，className属性返回一个空格分隔的字符串，而classList属性指向一个类似数组的对象，该对象的length属性（只读）返回当前元素的class数量。

classList对象有下列方法。
add()：增加一个 class。
remove()：移除一个 class。
contains()：检查当前元素是否包含某个 class。
toggle()：将某个 class 移入或移出当前元素。
item()：返回指定索引位置的 class。
toString()：将 class 的列表转为字符串。

下面比较一下，className和classList在添加和删除某个 class 时的写法

```JS
var foo = document.getElementById('foo');
// 添加class
foo.className += 'bold';
foo.classList.add('bold');
// 删除class
foo.classList.remove('bold');
foo.className = foo.className.replace(/^bold$/, '');
```

toggle方法可以接受一个布尔值，作为第二个参数。如果为true，则添加该属性；如果为false，则去除该属性。

```JS
el.classList.toggle('abc', boolValue);
// 等同于
if (boolValue) {
  el.classList.add('abc');
} else {
  el.classList.remove('abc');
}
```

## Element.innerHTML

Element.innerHTML属性返回一个字符串，等同于该元素包含的所有 HTML 代码。该属性可读写，常用来设置某个节点的内容。它能改写所有元素节点的内容，包括<HTML>和<body>元素。
如果将innerHTML属性设为空，等于删除所有它包含的所有节点。

注意，读取属性值的时候，如果文本节点包含&、小于号（<）和大于号（>），innerHTML属性会将它们转为实体形式&amp;、&lt;、&gt;。如果想得到原文，建议使用element.textContent属性。

```JS
// HTML代码如下 <p id="para"> 5 > 3 </p>
document.getElementById('para').innerHTML
// 5 &gt; 3
```

因此为了安全考虑，如果插入的是文本，最好用textContent属性代替innerHTML。

## Element.outerHTML

Element.outerHTML属性返回一个字符串，表示当前元素节点的所有 HTML 代码，包括该元素本身和所有子元素。

```JS
// HTML 代码如下
// <div id="d"><p>Hello</p></div>
var d = document.getElementById('d');
d.outerHTML
// '<div id="d"><p>Hello</p></div>'
```

outerHTML属性是可读写的，对它进行赋值，等于替换掉当前元素。
它和 innerHTML 的区别就是, 这个返回的字符串会包含自身.

```JS
// HTML 代码如下
// <div id="container"><div id="d">Hello</div></div>
var container = document.getElementById('container');
var d = document.getElementById('d');
container.firstChild.nodeName // "DIV"
d.nodeName // "DIV"
d.outerHTML = '<p>Hello</p>';
container.firstChild.nodeName // "P"
d.nodeName // "DIV"
```

上面代码中，变量d代表子节点，它的outerHTML属性重新赋值以后，内层的div元素就不存在了，被p元素替换了。但是，**变量d依然指向原来的div元素，这表示被替换的DIV元素还存在于内存中**。