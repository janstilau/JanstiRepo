# ParentNode_ChildNode

## ParentNode

如果当前节点是父节点，就会继承ParentNode接口。由于只有元素节点（element）、文档节点（document）和文档片段节点（documentFragment）拥有子节点，因此只有这三类节点会继承ParentNode接口。

* children

children属性返回一个HTMLCollection实例，成员是当前节点的所有元素子节点。该属性只读.
children属性只包括元素子节点，不包括其他类型的子节点（比如文本子节点）。如果没有元素类型的子节点，返回值HTMLCollection实例的length属性为0。

* firstElementChild

firstElementChild属性返回当前节点的第一个元素子节点。如果没有任何元素子节点，则返回null。

* lastElementChild

lastElementChild属性返回当前节点的最后一个元素子节点，如果不存在任何元素子节点，则返回null。

* childElementCount

childElementCount属性返回一个整数，表示当前节点的所有元素子节点的数目。如果不包含任何元素子节点，则返回0。

* append, prepend

append方法为当前节点追加一个或多个子节点，位置是最后一个元素子节点的后面。

```JS
var parent = document.body;

// 添加元素子节点
var p = document.createElement('p');
parent.append(p);

// 添加文本子节点
parent.append('Hello');

// 添加多个元素子节点
var p1 = document.createElement('p');
var p2 = document.createElement('p');
parent.append(p1, p2);

// 添加元素子节点和文本子节点
var p = document.createElement('p');
parent.append('Hello', p);
```

## ChildNode

如果一个节点有父节点，那么该节点就继承了ChildNode接口。

* remove

* before, after

before方法用于在当前节点的前面，插入一个或多个同级节点。两者拥有相同的父节点。
注意，该方法不仅可以插入元素节点，还可以插入文本节点。

* replaceWith
