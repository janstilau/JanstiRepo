// custom iterator for array
function makeArrayIterator(array) {
    let idx = 0;
    function next() {
        if (idx < array.length) {
            return {
                value: array[idx++],
                done: false,
                index: idx-1
            };
        } else {
            return {
                value: undefined,
                done: true,
                index: idx
            };
        }
    }
    return {
        next: next
    };
}

// LinkedObject Definition
function LinkedObject(value) {
    this.value = value;
    this.next = null
}
// 这个迭代器的作用是, 可以像是链表一样迭代所有的元素. 而 LinkedObject 这个东西, 并不是一个容器类, 可以自定义每一个对象的 Symbol.iterator 的实现, 给了我们很多自由度.
LinkedObject.prototype[Symbol.iterator] = function() {
    let iterator = { next: next}
    let current = this;
    function next() {
        if (current) {
            let value = current.value;
            current = current.next;
            return {
                done: false,
                value: value
            }
        } else {
            return {
                done: true,
                value: undefined
            }
        }
    }
    return iterator
}

function useLinkedObject() {
    // 自定义 迭代器, 可以做成超越容器类迭代器限制的迭代器来.
    let one = new LinkedObject('hehe 1');
    let two = new LinkedObject('haha 2');
    let three = new LinkedObject('yibei 3');
    one.next = two;
    two.next = three;
    for (const linkObjectValue of one) {
        console.log(linkObjectValue)
    }
}
useLinkedObject();

function useCustomArrayIter() {
    let array = [1, 2, 3, 4, , 6, 7]
    let arrayIter = makeArrayIterator(array)
    let item = arrayIter.next()
    while (!item.done) {
        console.log(`value:${item.value}`)
        console.log(`index:${item.index}`)
        item = arrayIter.next()
    }
}

function useSystemArrayIter() {
    let array = [1, 2, 3, 4, , 6, 7]
    let arrayIter = array[Symbol.iterator]()
    let item = arrayIter.next()
    while (!item.done) {
        console.log(`value:${item.value}`)
        console.log(`done:${item.done}`)
        item = arrayIter.next()
    }
}


function useCustomObjIter() {
    let customObj = {
    }
    customObj[Symbol.iterator] = function() {
        let index = 0
        return {
            next: function() {
                index++
                return {
                    value: 'unstopped value ' + index,
                    done: index >= 5
                }
            }
        }
    }
    for (const objItem of customObj) {
        console.log(objItem);
        // 看来, for of 里面直接将 value 赋值到了 objItem 上面. 这也是符合遍历的常规使用的.
        // console.log(objItem.value);
        // console.log(objItem.done);
    }
}
