# QOBJECT

QObject

* run-time introspection
* invocation of properties and methods 
* event system
* signals and slots mechanism


## The Meta-Object System

### 提供特性

* 信号槽机制, 用于对象之间交互
* 内省机制
* 动态属性

### 如何实现

* QObject 的子类
* Q_QBJECT 宏来填充代码
* MOC 编译重新编译出 Moc 版本的类


## QObject 功能

C++ 的 SharePtr, WeakPtr 等知识.