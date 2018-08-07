# NodeList, Collection

NodeList可以包含各种类型的节点，HTMLCollection只能包含 HTML 元素节点。

## NodeList

NodeList实例是一个类似数组的对象，它的成员是节点对象. 通过以下方法可以得到NodeList实例。

1. Node.childNodes
1. document.querySelectorAll() 等节点搜索方法

NodeList实例很像数组，可以使用length属性和forEach方法。但是，它不是数组，不能使用pop或push之类数组特有的方法

NodeList 实例可能是动态集合，也可能是静态集合。所谓动态集合就是一个活的集合，DOM 删除或新增一个相关节点，都会立刻反映在 NodeList 实例。目前，只有Node.childNodes返回的是一个动态集合，其他的 NodeList 都是静态集合。

```JS
document.body.childNodes instanceof NodeList // true

var children = document.body.childNodes;
children.length // 18
document.body.appendChild(document.createElement('p'));
children.length // 19
```

* length
* forEach
* item

item方法接受一个整数值作为参数，表示成员的位置，返回该位置上的成员。
如果参数值大于实际长度，或者索引不合法（比如负数），item方法返回null。如果省略参数，item方法会报错。
一般情况下，都是使用方括号运算符，而不使用item方法。
document.body.childNodes[0]

```JS
document.body.childNodes.item(0)
```

* NodeList.prototype.keys()，NodeList.prototype.values()，NodeList.prototype.entries()

返回三个遍历器, 用法和 Array 一样

## HTMLCollection

HTMLCollection是一个节点对象的集合，只能包含元素节点（element），不能包含其他类型的节点。它的返回值是一个类似数组的对象，但是与NodeList接口不同，HTMLCollection没有forEach方法，只能使用for循环遍历
返回HTMLCollection实例的，主要是一些Document对象的集合属性，比如document.links、docuement.forms、document.images等。
HTMLCollection实例都是动态集合，节点的变化会实时反映在集合中。
如果元素节点有id或name属性，那么HTMLCollection实例上面，可以使用id属性或name属性引用该节点元素。如果没有对应的节点，则返回null。

```JS
// HTML 代码如下
// <img id="pic" src="http://example.com/foo.jpg">
var pic = document.getElementById('pic');
document.images.pic === pic // true
```

* length
* item
* nameItem

```JS
var c = document.images;
var img0 = c.item(0);
// HTML 代码如下
// <img id="pic" src="http://example.com/foo.jpg">
var pic = document.getElementById('pic');
document.images.namedItem('pic') === pic // true
```