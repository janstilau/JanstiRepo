# Dom

操作网页的接口. Document Object Model. 可以将网页转化成为一个 JS 对象, 从而可以用脚本进行各种操作.
浏览器会根据 DOM 模型, 将 HTML, XML 解析成为一系列的节点, 再由这些节点转化成为一个树状结构.
还有 BOM, 是浏览器对象模型, 是用来操作浏览器的接口.

## 节点

Document：整个文档树的顶层节点
DocumentType：doctype标签（比如<!DOCTYPE html>）
Element：网页的各种HTML标签（比如<body>、<a>等）
Attribute：网页元素的属性（比如class="right"）
Text：标签之间或标签包含的文本
Comment：注释
DocumentFragment：文档的片段

所有的节点, 组成了一颗节点树, Document 节点由浏览器提供, 代表整个文档. 它是 html 标签.

### Node 属性

* nodeType

节点的类型.

文档节点（document）：9，对应常量Node.DOCUMENT_NODE
元素节点（element）：1，对应常量Node.ELEMENT_NODE
属性节点（attr）：2，对应常量Node.ATTRIBUTE_NODE
文本节点（text）：3，对应常量Node.TEXT_NODE
文档片断节点（DocumentFragment）：11，对应常量Node.DOCUMENT_FRAGMENT_NODE // 这是什么??
文档类型节点（DocumentType）：10，对应常量Node.DOCUMENT_TYPE_NODE
注释节点（Comment）：8，对应常量Node.COMMENT_NODE

* nodeName

节点的名称

文档节点（document）：#document
元素节点（element）：大写的标签名 // DIV SPAN TITLE 
属性节点（attr）：属性的名称 // src
文本节点（text）：#text
文档片断节点（DocumentFragment）：#document-fragment
文档类型节点（DocumentType）：文档的类型
注释节点（Comment）：#comment

* nodeValue

返回一个字符串，表示当前节点本身的文本值，该属性可读写.

只有文本节点（text）和注释节点（comment）有文本值，因此这两类节点的nodeValue可以返回结果，其他类型的节点一律返回null。同样的，也只有这两类节点可以设置nodeValue属性的值，其他类型的节点设置无效。

```JS
// HTML 代码如下
// <div id="d1">hello world</div>
var div = document.getElementById('d1');
div.nodeValue // null
div.firstChild.nodeValue // "hello world"
```

* textContent

返回当前节点和它的所有后代节点的文本内容。
textContent属性自动忽略当前节点内部的 HTML 标签，返回所有文本内容。
该属性是可读写的，设置该属性的值，会用一个新的文本节点，替换所有原来的子节点。它还有一个好处，就是自动对 HTML 标签转义。这很适合用于用户提供的内容。
对于文本节点（text）和注释节点（comment），textContent属性的值与nodeValue属性相同。对于其他类型的节点，该属性会将每个子节点的内容连接在一起返回，但是不包括注释节点。如果一个节点没有子节点，则返回空字符串。

```JS
// HTML 代码为
// <div id="divA">This is <span>some</span> text</div>

document.getElementById('divA').textContent
// This is some text
```

* baseURI

返回一个字符串，表示当前网页的绝对路径。浏览器根据这个属性，计算网页上的相对路径的 URL。该属性为只读。

* ownerDocument

返回当前节点所在的顶层文档对象，即document对象。
document对象本身的ownerDocument属性，返回null

* nextSibling

属性返回紧跟在当前节点后面的第一个同级节点。如果当前节点后面没有同级节点，则返回null。
该属性还包括文本节点和注释节点（<!-- comment -->）。因此如果当前节点后面有空格，该属性会返回一个文本节点，内容为空格。
nextSibling属性可以用来遍历所有子节点。

```JS
// HTML 代码如下
// <div id="d1">hello</div><div id="d2">world</div>
var div1 = document.getElementById('d1');
var div2 = document.getElementById('d2');
d1.nextSibling === d2 // true
// 遍历操作
var el = document.getElementById('div1').firstChild;
while (el !== null) {
  console.log(el.nodeName);
  el = el.nextSibling;
}
```

* previousSibling

返回当前节点前面的、距离最近的一个同级节点。如果当前节点前面没有同级节点，则返回null。
操作和 nextSibling 一样.

* parentNode

返回当前节点的父节点。对于一个节点来说，它的父节点只可能是三种类型：元素节点（element）、文档节点（document）和文档片段节点（documentfragment）

```JS
if (node.parentNode) {
  node.parentNode.removeChild(node);
}
```

* parentElement

返回当前节点的父元素节点。如果当前节点没有父节点，或者父节点类型不是元素节点，则返回null。
由于父节点只可能是三种类型：元素节点、文档节点（document）和文档片段节点（documentfragment）。parentElement属性相当于把后两种父节点都排除了。

* firstChild, lastChild

firstChild属性返回当前节点的第一个子节点，如果当前节点没有子节点，则返回null
firstChild返回的除了元素节点，还可能是文本节点或注释节点。

```JS
// HTML 代码如下
// <p id="p1"><span>First span</span></p>
var p1 = document.getElementById('p1');
p1.firstChild.nodeName // "SPAN"

// HTML 代码如下
// <p id="p1">
//   <span>First span</span>
//  </p>
var p1 = document.getElementById('p1');
p1.firstChild.nodeName // "#text"
// p元素与span元素之间有空白字符，这导致firstChild返回的是文本节点
```

* childNodes

返回一个类似数组的对象（NodeList集合），成员包括当前节点的所有子节点.
使用该属性，可以遍历某个节点的所有子节点。

```JS
var div = document.getElementById('div1');
var children = div.childNodes;
for (var i = 0; i < children.length; i++) {
  // ...
}
```

文档节点（document）就有两个子节点：文档类型节点（docType）和 HTML 根元素节点。
除了元素节点，childNodes属性的返回值还包括文本节点和注释节点。如果当前节点不包括任何子节点，则返回一个空的NodeList集合。由于NodeList对象是一个动态集合，一旦子节点发生变化，立刻会反映在返回结果之中

* isConnected

返回一个布尔值，表示当前节点是否在文档之中

### Node 方法

* appendChild

接受一个节点对象作为参数，将其作为最后一个子节点，插入当前节点。该方法的返回值就是插入文档的子节点。

```JS
var p = document.createElement('p');
document.body.appendChild(p);
```

如果appendChild方法的参数是DocumentFragment节点，那么插入的是DocumentFragment的所有子节点，而不是DocumentFragment节点本身。返回值是一个空的DocumentFragment节点。

* hasChildNodes

返回一个布尔值，表示当前节点是否有子节点。
子节点包括所有类型的节点，并不仅仅是元素节点。哪怕节点只包含一个空格，hasChildNodes方法也会返回true。

```JS
var foo = document.getElementById('foo');
if (foo.hasChildNodes()) {
  foo.removeChild(foo.childNodes[0]);
}
```

判断一个节点有没有子节点，有许多种方法，下面是其中的三种。

node.hasChildNodes()
node.firstChild !== null
node.childNodes && node.childNodes.length > 0

* cloneNode

克隆一个节点。它接受一个布尔值作为参数，表示是否同时克隆子节点。它的返回值是一个克隆出来的新节点

注意:

1. 克隆一个节点，会拷贝该节点的所有属性，但是会丧失addEventListener方法和on-属性（即node.onclick = fn），添加在这个节点上的事件回调函数。
1. 该方法返回的节点不在文档之中，即没有任何父节点，必须使用诸如Node.appendChild这样的方法添加到文档之中。
1. 克隆一个节点之后，DOM 有可能出现两个有相同id属性（即id="xxx"）的网页元素，这时应该修改其中一个元素的id属性。如果原节点有name属性，可能也需要修改。

* insertBefore

用于将某个节点插入父节点内部的指定位置。

```JS
var insertedNode = parentNode.insertBefore(newNode, referenceNode);

var p = document.createElement('p');
document.body.insertBefore(p, document.body.firstChild);
```

insertBefore方法接受两个参数，第一个参数是所要插入的节点newNode，第二个参数是父节点parentNode内部的一个子节点referenceNode。newNode将插在referenceNode这个子节点的前面。返回值是插入的新节点newNode。
如果insertBefore方法的第二个参数为null，则新节点将插在当前节点内部的最后位置，即变成最后一个子节点。
如果所要插入的节点是当前 DOM 现有的节点，则该节点将从原有的位置移除，插入新的位置。
由于不存在insertAfter方法，如果新节点要插在父节点的某个子节点后面，可以用insertBefore方法结合nextSibling属性模拟。

```JS
parent.insertBefore(s1, s2.nextSibling);
```

如果要插入的节点是DocumentFragment类型，那么插入的将是DocumentFragment的所有子节点，而不是DocumentFragment节点本身。返回值将是一个空的DocumentFragment节点。

* removeChild

接受一个子节点作为参数，用于从当前节点移除该子节点。返回值是移除的子节点。
注意，这个方法是在divA的父节点上调用的，不是在divA上调用的。
被移除的节点依然存在于内存之中，但不再是 DOM 的一部分。所以，一个节点移除以后，依然可以使用它，比如插入到另一个节点下面。
如果参数节点不是当前节点的子节点，removeChild方法将报错。

```JS
var divA = document.getElementById('A');
divA.parentNode.removeChild(divA);
```

* replaceChild

将一个新的节点，替换当前节点的某一个子节点。
replaceChild方法接受两个参数，第一个参数newChild是用来替换的新节点，第二个参数oldChild是将要替换走的子节点。返回值是替换走的那个节点oldChild.
整个方法也是作用在父节点上.

```JS
var divA = document.getElementById('divA');
var newSpan = document.createElement('span');
newSpan.textContent = 'Hello World!';
divA.parentNode.replaceChild(newSpan, divA);
```

* contains

返回一个布尔值，表示参数节点是否满足以下三个条件之一

1. 参数节点为当前节点。
1. 参数节点为当前节点的子节点。
1. 参数节点为当前节点的后代节点。

* compareDocumentPosition

与contains方法完全一致，返回一个七个比特位的二进制值，表示参数节点与当前节点的关系。
由于compareDocumentPosition返回值的含义，定义在每一个比特位上，所以如果要检查某一种特定的含义，就需要使用比特位运算符。

```JS

// 000000	0	两个节点相同
// 000001	1	两个节点不在同一个文档（即有一个节点不在当前文档）
// 000010	2	参数节点在当前节点的前面
// 000100	4	参数节点在当前节点的后面
// 001000	8	参数节点包含当前节点
// 010000	16	当前节点包含参数节点
// 100000	32	浏览器内部使用

// HTML 代码如下
// <div id="mydiv">
//   <form><input id="test" /></form>
// </div>

var div = document.getElementById('mydiv');
var input = document.getElementById('test');

div.compareDocumentPosition(input) // 20
input.compareDocumentPosition(div) // 10

var head = document.head;
var body = document.body;
if (head.compareDocumentPosition(body) & 4) {
  console.log('文档结构正确');
} else {
  console.log('<body> 不能在 <head> 前面');
}

```

* isEqualNode

方法返回一个布尔值，用于检查两个节点是否相等。所谓相等的节点，指的是两个节点的类型相同、属性相同、子节点相同。

* isSameNode

返回一个布尔值，表示两个节点是否为同一个节点。

## normalize

用于清理当前节点内部的所有文本节点（text）。它会去除空的文本节点，并且将毗邻的文本节点合并成一个，也就是说不存在空的文本节点，以及毗邻的文本节点。

```js
var wrapper = document.createElement('div');

wrapper.appendChild(document.createTextNode('Part 1 '));
wrapper.appendChild(document.createTextNode('Part 2 '));

wrapper.childNodes.length // 2
wrapper.normalize();
wrapper.childNodes.length // 1
```

* getRootNode

返回当前节点所在文档的根节点，与ownerDocument属性的作用相同。
