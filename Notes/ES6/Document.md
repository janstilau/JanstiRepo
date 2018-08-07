# Document

document节点对象代表整个文档，每张网页都有自己的document对象。window.document属性就指向这个对象。只要浏览器开始载入 HTML 文档，该对象就存在了，可以直接使用。

## 属性

* doctype

对于 HTML 文档来说，document对象一般有两个子节点。第一个子节点是document.doctype，指向<DOCTYPE>节点，即文档类型（Document Type Declaration，简写DTD）节点。HTML 的文档类型节点，一般写成<!DOCTYPE html>。如果网页没有声明 DTD，该属性返回null。

document.firstChild通常就返回这个节点。

* documentElement

document.documentElement属性返回当前文档的根元素节点（root）。它通常是document节点的第二个子节点，紧跟在document.doctype节点后面。HTML网页的该属性，一般是<html>节点。

* body, head

document.body属性指向<body>节点，document.head属性指向<head>节点。
这两个属性总是存在的，如果网页源码里面省略了<head>或<body>，浏览器会自动创建。另外，这两个属性是可写的，如果改写它们的值，相当于移除所有子节点。

* scrollingElement

document.scrollingElement属性返回文档的滚动元素。也就是说，当文档整体滚动时，到底是哪个元素在滚动。
标准模式下，这个属性返回的文档的根元素document.documentElement（即<html>）。兼容（quirk）模式下，返回的是<body>元素，如果该元素不存在，返回null。

* activeElement

属性返回获得当前焦点（focus）的 DOM 元素。通常，这个属性返回的是<input>、<textarea>、<select>等表单元素，如果当前没有焦点元素，返回<body>元素或null。

* fullscreenElement

document.fullscreenElement属性返回当前以全屏状态展示的 DOM 元素。如果不是全屏状态，该属性返回null。

## 节点集合属性

* links

document.links属性返回当前文档所有设定了href属性的<a>及<area>节点。

* forms

document.forms属性返回所有<form>表单节点。
除了使用位置序号，id属性和name属性也可以用来引用表单。

```JS
/* HTML 代码如下
  <form name="foo" id="bar"></form>
*/
var selectForm = document.forms[0];
document.forms[0] === document.forms.foo // true
document.forms.bar === document.forms.foo // true
```

* images

document.images属性返回页面所有<img>图片节点。

* document.embeds，document.plugins

document.embeds属性和document.plugins属性，都返回所有<embed>节点。

* scripts

document.scripts属性返回所有<script>节点。

document.links instanceof HTMLCollection // true
document.images instanceof HTMLCollection // true
document.forms instanceof HTMLCollection // true
document.embeds instanceof HTMLCollection // true
document.scripts instanceof HTMLCollection // true

## 静态信息属性

* document.documentURI，document.URL

document.documentURI属性和document.URL属性都返回一个字符串，表示当前文档的网址。不同之处是它们继承自不同的接口，documentURI继承自Document接口，可用于所有文档；URL继承自HTMLDocument接口，只能用于 HTML 文档。

* document.domain

document.domain属性返回当前文档的域名，不包含协议和接口。比如，网页的网址是http://www.example.com:80/hello.html，那么domain属性就等于www.example.com。如果无法获取域名，该属性返回null。

* document.location

Location对象是浏览器提供的原生对象，提供 URL 相关的信息和操作方法

* document.lastModified

document.lastModified属性返回一个字符串，表示当前文档最后修改的时间。不同浏览器的返回值，日期格式是不一样的。

注意，document.lastModified属性的值是字符串，所以不能直接用来比较。Date.parse方法将其转为Date实例，才能比较两个网页。

* document.title

document.title属性返回当前文档的标题。默认情况下，返回<title>节点的值。但是该属性是可写的，一旦被修改，就返回修改后的值。

* document.characterSet

* document.referrer

document.referrer属性返回一个字符串，表示当前文档的访问者来自哪里。
如果无法获取来源，或者用户直接键入网址而不是从其他网页点击进入，document.referrer返回一个空字符串。

## 状态属性

* document.hidden

document.hidden属性返回一个布尔值，表示当前页面是否可见。如果窗口最小化、浏览器切换了 Tab，都会导致导致页面不可见，使得document.hidden返回true。

* document.visibilityState返回文档的可见状态

visible：页面可见。注意，页面可能是部分可见，即不是焦点窗口，前面被其他窗口部分挡住了。
hidden： 页面不可见，有可能窗口最小化，或者浏览器切换到了另一个 Tab。
prerender：页面处于正在渲染状态，对于用于来说，该页面不可见。
unloaded：页面从内存里面卸载了。

* document.readyState

document.readyState属性返回当前文档的状态

loading：加载 HTML 代码阶段（尚未完成解析）
interactive：加载外部资源阶段
complete：加载完成

1. 浏览器开始解析 HTML 文档，document.readyState属性等于loading。
1. 浏览器遇到 HTML 文档中的<script>元素，并且没有async或defer属性，就暂停解析，开始执行脚本，这时document.readyState属性还是等于loading。
1. HTML 文档解析完成，document.readyState属性变成interactive。
1. 浏览器等待图片、样式表、字体文件等外部资源加载完成，一旦全部加载完成，document.readyState属性变成complete。

* document.cookie

document.cookie属性用来操作浏览器 Cookie

* document.designMode

document.designMode属性控制当前文档是否可编辑。该属性只有两个值on和off，默认值为off。一旦设为on，用户就可以编辑整个文档的内容。

## 方法

* document.open()，document.close()

document.open方法清除当前文档所有内容，使得文档处于可写状态，供document.write方法写入内容。
document.close方法用来关闭document.open()打开的文档

```JS
document.open();
document.write('hello world');
document.close();
```

* document.write()，document.writeln()

document.write方法用于向当前文档写入内容.
在网页的首次渲染阶段，只要页面没有关闭写入（即没有执行document.close()），document.write写入的内容就会追加在已有内容的后面。
如果页面已经解析完成（DOMContentLoaded事件发生之后），再调用write方法，它会先调用open方法，擦除当前文档所有内容，然后再写入。
如果在页面渲染过程中调用write方法，并不会自动调用open方法。（可以理解成，open方法已调用，但close方法还未调用。）
应该尽量避免使用document.write这个方法。

* document.querySelector()，document.querySelectorAll() 

根据 css 的选择器来获取对象

* document.getElementsByTagName()

搜索 HTML 标签名，返回符合条件的元素。它的返回值是一个类似数组对象（HTMLCollection实例），可以实时反映 HTML 文档的变化。如果没有任何匹配的元素，就返回一个空集。

返回结果中，各个成员的顺序就是它们在文档中出现的顺序。

元素节点本身也定义了getElementsByTagName方法，返回该元素的后代元素中符合条件的元素。也就是说，这个方法不仅可以在document对象上调用，也可以在任何元素节点上调用。

```JS
var firstPara = document.getElementsByTagName('p')[0];
var spans = firstPara.getElementsByTagName('span');
```

* getElementsByClassName

回一个类似数组的对象（HTMLCollection实例），包括了所有class名字符合指定条件的元素，元素的变化实时反映在返回结果中。
参数可以是多个class，它们之间使用空格分隔。 返回值是多个 class 指定的元素.
与getElementsByTagName方法一样，getElementsByClassName方法不仅可以在document对象上调用，也可以在任何元素节点上调用。

* document.getElementsByName()

document.getElementById方法返回匹配指定id属性的元素节点。如果没有发现匹配的节点，则返回null。
document.getElementsByName方法用于选择拥有name属性的 HTML 元素（比如<form>、<radio>、<img>、<frame>、<embed>和<object>等），返回一个类似数组的的对象（NodeList实例），因为name属性相同的元素可能不止一个。

```JS
// 表单为 <form name="x"></form>
var forms = document.getElementsByName('x');
forms[0].tagName // "FORM"
```

* document.getElementById()

document.getElementById方法返回匹配指定id属性的元素节点。如果没有发现匹配的节点，则返回null。
document.getElementById方法与document.querySelector方法都能获取元素节点，不同之处是document.querySelector方法的参数使用 CSS 选择器语法，document.getElementById方法的参数是元素的id属性。

* document.elementFromPoint()，document.elementsFromPoint()

document.elementFromPoint方法返回位于页面指定位置最上层的元素节点。
elementFromPoint方法的两个参数，依次是相对于当前视口左上角的横坐标和纵坐标，单位是像素。如果位于该位置的 HTML 元素不可返回（比如文本框的滚动条），则返回它的父元素（比如文本框）。如果坐标值无意义（比如负值或超过视口大小），则返回null。
document.elementsFromPoint()返回一个数组，成员是位于指定坐标（相对于视口）的所有元素。

* document.createElement()

ocument.createElement方法用来生成元素节点，并返回该节点。
createElement方法的参数为元素的标签名，即元素节点的tagName属性，对于 HTML 网页大小写不敏感，即参数为div或DIV返回的是同一种节点。如果参数里面包含尖括号（即<和>）会报错。
注意，document.createElement的参数可以是自定义的标签名

* document.createTextNode()

document.createTextNode方法用来生成文本节点（Text实例），并返回该节点。它的参数是文本节点的内容。

```JS
var newDiv = document.createElement('div');
var newContent = document.createTextNode('Hello');
newDiv.appendChild(newContent);
```

* document.createAttribute()

document.createAttribute方法生成一个新的属性节点（Attr实例），并返回它.
document.createAttribute方法的参数name，是属性的名称。

```JS
var node = document.getElementById('div1');
var a = document.createAttribute('my_attrib');
a.value = 'newVal';
node.setAttributeNode(a);
node.setAttribute('my_attrib', 'newVal');
```

* document.createComment()

* document.createDocumentFragment()

DocumentFragment是一个存在于内存的 DOM 片段，不属于当前文档，常常用来生成一段较复杂的 DOM 结构，然后再插入当前文档。这样做的好处在于，因为DocumentFragment不属于当前文档，对它的任何改动，都不会引发网页的重新渲染，比直接修改当前文档的 DOM 有更好的性能表现。

```JS
var docfrag = document.createDocumentFragment();
[1, 2, 3, 4].forEach(function (e) {
  var li = document.createElement('li');
  li.textContent = e;
  docfrag.appendChild(li);
});
var element  = document.getElementById('ul');
element.appendChild(docfrag);
```

上面代码中，文档片断docfrag包含四个<li>节点，这些子节点被一次性插入了当前文档。

* document.createEvent()

document.createEvent方法生成一个事件对象（Event实例），该对象可以被element.dispatchEvent方法使用，触发指定事件。

* document.addEventListener()，document.removeEventListener()，document.dispatchEvent() 

* document.hasFocus()

document.hasFocus方法返回一个布尔值，表示当前文档之中是否有元素被激活或获得焦点

* document.adoptNode()，document.importNode()

后面的看不太懂了就