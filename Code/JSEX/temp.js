class CustomElement {
    constructor() {
        this.html = 100
    }
    get html() {
        console.log('get')
    }
    set html(value) {
        console.log('set' + value)
    }

    static saySth() {
        console.log('say sth')
    }
}

class B extends CustomElement{
}

console.log(Object.getOwnPropertyNames(CustomElement));
console.log(Object.getPrototypeOf(B));
console.log(Object.getOwnPropertyNames(B));

let obj = new CustomElement();
console.log(obj);
Object.defineProperty(obj, 'html', {
    value: 2999
})

console.log(obj.html);
obj.html = 1;
console.log(obj.html);

let htmlDesc = Object.getOwnPropertyDescriptor(obj, 'html');
console.log(htmlDesc)


let protoHtmlDesc = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(obj), 'html');
console.log(protoHtmlDesc)


