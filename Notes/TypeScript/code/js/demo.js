"use strict";
var MinClas = /** @class */ (function () {
    function MinClas() {
        this.list = [];
    }
    MinClas.prototype.add = function (value) {
        this.list.push(value);
    };
    MinClas.prototype.min = function () {
        var minNum = this.list[0];
        for (var i = 0; i < this.list.length; i++) {
            if (minNum > this.list[i]) {
                minNum = this.list[i];
            }
        }
        return minNum;
    };
    return MinClas;
}());
var Person = /** @class */ (function () {
    function Person(name) {
        this.name = name;
    }
    return Person;
}());
var obj = new MinClas();
obj.add(new Person('a'));
obj.add(new Person('b'));
obj.add(new Person('c'));
obj.add(new Person('d'));
var min = obj.min();
console.log(min.name);
