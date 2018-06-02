# Protocol Buffers

## protobuf是什么, 它的作用是什么

程序的运转, 可以分为 读取数据, 操作数据, 存储数据 三个过程, 不同程序或者程序子系统三个过程具体实现各不相同, 但基本都符合这个逻辑. 对于数据而言, 只有将其序列化为后才可以进行存储和传输. 对于一个结构化的数据, 有以下的序列化策略:

* 原始的内存状态值存储. 这种方式数据量最小, 但是程序非常脆弱. 读取操作必须依赖读取程序完全了解内存的分布情况, 还要熟悉当前机器的字节排列顺序, 并且要扩展数据格式是几乎不可能的.
* 自定义数据存储的策略. 例如, 对于一个仅仅有 人名(只有英文字母组成), 电话号码 的电话簿数据, 我们规定, 前十个字节存储人名, 后十个字节存储号码, 而存储号码的字节可以用一个字节存储两个数字, 因为十进制数字最大值是9 . 这种方式的优点是可以按照自己的方案尽可能的压缩存储空间, 但是需要读取的时候完全了解存储过程, 也难以扩展.
* 用文本文件的方式, 将数据构建成为一个含有结构系统的文本文件, 这种文件非常方便扩展数据结构, 拥有通用的存储解析的过程, 并且带有自我描述性, 打开文件之后人工就可以解读数据. 这种方式应用非常广, 例如 xml, json. 问题在于, 变成文本文件后, 数据会变得非常大, 并且存储和解析的过程, 也会占用相对较高的计算性能.

protobuf是谷歌开发的一套数据存储解析为二进制形式的框架系统, 它可以将数据序列化成为二进制形式, 并从二进制数据中解析出原始的数据, 存储解析的过程都由框架自动完成. protobuf 是一个不依赖平台和编程语言的框架, 在一个平台用一种语言序列化的数据, 可以在另外一个平台用另外一种语言进行解析. protobuf 支持数据的扩展, 老版本的代码可以被新版本的代码解析, 老版本的代码可以解析新版本的数据.

## protobuf 的基本使用过程

* 定义一个 proto 文件, 在该文件中, 定义需要需要序列化的数据结构

* 安装 protobuf 的编译环境并编译 proto 文件

protobuf 的编译环境作用在于, 将 proto 文件编译成不同语言可以直接使用的源文件. protobuf 流行的原因在于, 就是可以根据一份 proto 文件, 生成不同语言需要的源文件. 这样不同语言的程序可以操作由同一份 proto 文件定义的二进制数据.

* 在自己的工程中, 包含生成的源文件, 并用生成的源文件进行 序列化和反序列化 的操作

 在工程里面存储的逻辑一般为 `生成 protobuf 定义的类的对象 -> 根据程序中的数据填充该对象的数值 -> 该对象调用序列化函数, 生成二进制文件`, 而读取的逻辑则刚好相反 `读取二进制文件数据 -> 生成 protobuf 定义的类的对象, 调用对象的反序列化函数, 填充这个对象的各项数据 -> 读取这个对象的数据到程序中`. 由于操作的是二进制数据, 所以序列化和反序列化的速度相对较快, 整个过程框架自动完成.

## .proto 文件

protobuf 需要知道进行操作的数据的结构信息, 这些信息定义在 proto 文件中.

.proto 文件中, 数据类型类似于 c 语言的结构体的概念, 一个数据类型称为一个 message, 在 message 中定义这个数据结构各个属性的详细信息.

``` proto
message Person {
  string name = 1;
  int32 id = 2;
  string email = 3;

  enum PhoneType {
    MOBILE = 0;
    HOME = 1;
    WORK = 2;
  }

  message PhoneNumber {
    string number = 1;
    PhoneType type = 2;
  }

  repeated PhoneNumber phones = 4;

  google.protobuf.Timestamp last_updated = 5;
}

message AddressBook {
  repeated Person people = 1;
}
```

和编程语言类似, 各个属性有着类型和名称信息. 在 protobuf 运行时程序生成的代码中, 会根据这两个信息生成对应的 get, set 函数.

类型包括基本数据类型(float, double, 不同位数的 int, bool, string, bytes), 也包括定义好的枚举类型和 message 类型.

在各个属性最后的 = num 指定各个字段的序号, 这些序号用来在二进制文件中辨识各个字段的值, 不可重复也不可在扩展 proto 文件的时候更改.

在各个属性之前需要定义字段的 rule 信息

* required, 表示该属性必须明确赋值, 否则不会在序列化和反序列化过程中会被报错
* optional, 表示该属性可以为空
* repeated, 表示该属性可以重复多次, 类似于数组的概念

### proto 文件编码风格

* 驼峰(首字母大写)命名 message 的名字
* 小写字母加下划线的方式命名各个 属性 的名字
* 驼峰(首字母大写)命名 枚举 的名字
* 全大写加下划线的方式命名 枚举各个值用

``` proto
message SongServerRequest {
  required string song_name = 1;
}
enum Foo {
  FIRST_VALUE = 0;
  SECOND_VALUE = 1;
}
```

### 更新 proto 文件

如果之前的数据格式不满足现有业务的需要, 那么需要更新 proto 文件中的数据格式, 遵循以下原则, 可以让新代码读取原有格式数据, 原有代码读取新格式数据.

* 不能改变原有的字段的字段序号.
* 新添加的数据 应该 optional, 或者 repeated 前缀. required 表示这个字段是必有属性, 如果在新的格式添加一个 '必有' 属性, 原来的数据就都作废了.
* 应该为新添加的数据明确的指定默认数据. 这样新代码在读取老数据的时候, 可以为缺失的数据填充默认值. 而老代码在读取新数据的时候, 新添加的数据会被忽略, 而在序列化的时候, 这些被忽略的新数据会被原封不动的填充到二进制流中.
* 原有的 not required 的数据可以被删除.

文档中还有对于数据类型, 枚举, 嵌套类型的相关规则, 具体使用的时候可以请查阅 [update proto](https://developers.google.com/protocol-buffers/docs/proto#updating)

## 安装 protobuf 的编译环境

[Protocol Compiler Installation](https://github.com/google/protobuf)

## Qt 中使用 protobuf

* 根据 protobuf 的编译环境, 编译 proto 文件成为 c++代码, 在控制台中输入如下命令

 `protoc -I=工程目录 --cpp_out=输出目录 proto文件路径`

* 添加 protobuf 的代码文件

``` qmake
INCLUDEPATH += $$_PRO_FILE_PWD_/protobuf/src
```

* 添加 protobuf 的库文件

```qmake
LibProtobuf = $$PWD/protobuf/libprotobuf-lite.a
!exists($$LibProtobuf): error("Not existing $$LibProtobuf")
message("using lib: $$LibProtobuf")
LIBS += $$LibProtobuf
```

* 添加 protobuf 编译系统生成的 c++ 文件
* 在序列化和反序列化的位置, 利用 protobuf 生成的类进行操作
