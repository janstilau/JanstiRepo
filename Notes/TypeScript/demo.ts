class Person {
  protected _age: number;
  constructor(){
    this.age = 100
  }

  set age(newage: number) {
    this._age = newage
  }

  get age() {
    return this._age
  }
}

class Student extends Person {

  private score: number
  constructor(score: number) {
    super()
    this.score = score
  }
}

let ins = new Person()
console.log(ins.age)
ins.age = 2000
console.log(ins.age)