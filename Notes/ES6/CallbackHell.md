# CallBackHell

```JS
fs.readdir(source, function (err, files) {
  if (err) {
    console.log('Error finding files: ' + err)
  } else {
    files.forEach(function (filename, fileIndex) {
      console.log(filename)
      gm(source + filename).size(function (err, values) {
        if (err) {
          console.log('Error identifying file size: ' + err)
        } else {
          console.log(filename + ' : ' + values)
          aspect = (values.width / values.height)
          widths.forEach(function (width, widthIndex) {
            height = Math.round(width / aspect)
            console.log('resizing ' + filename + 'to ' + height + 'x' + height)
            this.resize(width, height).write(dest + 'w' + width + '_' + filename, function(err) {
              if (err) console.log('Error writing file: ' + err)
            })
          }.bind(this))
        }
      })
    })
  }
})
```

首先应该明白回调到底是怎么回事?

在没有闭包这种东西的时候, 我们想要回调一件事情, 会怎么做. 函数指针, 或者是接口. 比如一个按钮点击的操作, 当按钮点击了之后, 应该做一些事情, 我们称之为回调. 所谓回调, 就是这个函数不是立马被调用的, 而是某些时机触发才会被调用, 所以这个函数应该被存起来. C 的时候铁定就是函数指针, 这个函数指针有着自己的参数个数, 参数类型以及返回值类型, 如此拿到函数指针的人, 将所需的参数填进去就可以调用了. 后来面向对象编程方式, 有了接口的概念, 这个时候存的就不是函数指针了, 而是一个对象, 而这个对象是有类型的, 可以通过它调用某些函数. 这个可以调用, 在 C++ 里面是编译的时候做的链接, 在动态语言里是运行时做的动态绑定, 在编阶段, 各个编辑器根据接口的 type 信息, 会对程序员有着友好的报错.

在闭包出现之后, 可以认为闭包还是函数指针的形式. 只不过闭包里面的这个函数指针所指向的函数, 定义的位置就在调用的时候, 这样编程人员可以按照需求随时定义一个新的函数, 闭包还有捕获的功能, 更是将数据传递这项工作完美的解决了, 这也是现在闭包流行的原因.

所以, 闭包仅仅是存储函数指针的一个手段, 他仅仅是存了起来, 到底什么时候调用, 是接受闭包的函数里面的逻辑决定的.
所以, 在含有大量闭包的一段代码里面, 逻辑很难进行梳理清, 因为我们不知道接受闭包的函数里面的实现逻辑, 这需要良好的函数命名, 在这, 闭包的定义位置其实和闭包的执行时机没有任何关系.

## 如何让解决 CallbackHell

* 清晰的命名.

上面的代码, 唯一的区别就是命名, 名称有着自我描述性, 所以其实能很好的解释闭包的作用, 并且, 如果想要把函数抽离到上层, 直接复制就可以了.

```JS
var form = document.querySelector('form')
form.onsubmit = function (submitEvent) {
  var name = document.querySelector('input').value
  request({
    uri: "http://example.com/upload",
    body: name,
    method: "POST"
  }, function (err, response, body) {
    var statusMessage = document.querySelector('.status')
    if (err) return statusMessage.value = err
    statusMessage.value = body
  })
}

var form = document.querySelector('form')
form.onsubmit = function formSubmit (submitEvent) {
  var name = document.querySelector('input').value
  request({
    uri: "http://example.com/upload",
    body: name,
    method: "POST"
  }, function postResponse (err, response, body) {
    var statusMessage = document.querySelector('.status')
    if (err) return statusMessage.value = err
    statusMessage.value = body
  })
}
```

* 模块化

Write small modules that each do one thing, and assemble them into other modules that do a bigger thing.

模块化最大的好处在于, 隔离了代码, 暴露给别人的仅仅是一个函数名. 而函数的具体实现在别的文件里面. 这其实是, 将闭包抽取成为函数的策略, 不过这里隔离到文件里面, 彻底将使用者从实现里面剥离出来.

```JS
module.exports.submit = formSubmit

function formSubmit (submitEvent) {
  var name = document.querySelector('input').value
  request({
    uri: "http://example.com/upload",
    body: name,
    method: "POST"
  }, postResponse)
}

function postResponse (err, response, body) {
  var statusMessage = document.querySelector('.status')
  if (err) return statusMessage.value = err
  statusMessage.value = body
}

var formUploader = require('formuploader')
document.querySelector('form').onsubmit = formUploader.submit
```

* 处理错误

闭包是一个回调, 那么到达回调之前, 到底发生了什么是不清楚的, 这里面很有可能发生了错误, 所以, 应该在回调里面处理错误. 在 nodejs 中, 默认的回调函数风格总是第一个参数是 error, 第二个参数才是真正有用的信息.

## 总结

* 不要尝试嵌套过多, 给闭包名称或者将他们提高到类方法要清晰地多.
* 每个闭包都要尝试处理错误.
* 将处理逻辑进行分离, 分离之后小函数的名称有着自我描述性, 而且更加容易复用. 闭包就是函数, 当没有必要复用的时候, 我们传入一个闭包, 当有复用的需求的时候, 抽取成为函数进行复用.

callBackHell 会让人逻辑混乱, 要极力避免, 这并不是高超的技术的体现. 相反, 这样的代码代表着, 所有的实现细节写在了一起, 没有一点封装性.