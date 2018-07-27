# Types

* Boolean
* Number
  As in JavaScript, all numbers in TypeScript are floating point values.
* String
* Array
  number[]
  Array<number>
* Tuple
  Tuple types allow you to express an array where the type of a fixed number of elements is known, but need not be the same. 
* Enum
   A way of giving more friendly names to sets of numeric values.
   A handy feature of enums is that you can also go from a numeric value to the name of that value in the enum
* Any
  Opt-out type-checking
* Void
  the absence of having any type at all.
* Null and Undefined
  By default null and undefined are subtypes of all other types. That means you can assign null and undefined to something like number.
  However, when using the --strictNullChecks flag, null and undefined are only assignable to void and their respective types.
* Never
  The never type represents the type of values that never occur
* Object
  object is a type that represents the non-primitive type, i.e. any thing that is not number, string, boolean, symbol, null, or undefined.

```TypeScript
let isDone: boolean = false;

let decimal: number = 6;

let color: string = "blue";
color = 'red';
let fullName: string = `Bob Bobbington`;
let age: number = 37;
let sentence: string = `Hello, my name is ${ fullName }.
I'll be ${ age + 1 } years old next month.`;

let list: number[] = [1, 2, 3];
let list: Array<number> = [1, 2, 3];

// Declare a tuple type
let x: [string, number];
// Initialize it
x = ["hello", 10]; // OK
// Initialize it incorrectly
x = [10, "hello"]; // Error

enum Color {Red, Green, Blue}
let c: Color = Color.Green;
enum Color {Red = 1, Green, Blue}
let colorName: string = Color[2];

let notSure: any = 4;
notSure = "maybe a string instead";
notSure = false; // okay, definitely a boolean

function warnUser(): void {
    alert("This is my warning message");
}
```