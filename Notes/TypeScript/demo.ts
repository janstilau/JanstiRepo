
interface Length {
  length: number
}

function identity<T extends Length>(arg: T ): T {
  let a = arg.length;
  console.log(a)
  return arg;
}

let num = 1
identity(num)