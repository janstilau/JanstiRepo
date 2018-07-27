
var temp = 123123
let obj = {
    name : 'janst',
    speak: function () {
        let value = 100
        let savedFunc = function() {
            console.log(this.name)
            console.log(value)
            console.log(temp)
            console.log(this.temp)
        }
        value = 2000
        console.log(this)
        return savedFunc
    }
}

let getedFunc = obj.speak()
obj.speak = null
getedFunc()
console.log(this)