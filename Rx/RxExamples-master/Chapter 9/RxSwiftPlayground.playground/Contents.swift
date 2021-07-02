//: Playground - noun: a place where people can play

import UIKit
import RxSwift

// MARK: - Prefixing and concatenating -

example(of: "startWith") {
    let disposeBag = DisposeBag()
    let numbers = Observable.of(2, 3, 4)

    let observable = numbers.startWith(1)
        .subscribe(onNext: { number in
            print(number)
        })
        .disposed(by: disposeBag)
}

example(of: "Observable.concat") {
    let disposeBag = DisposeBag()
    let first = Observable.of(1, 2, 3)
    let second = Observable.of(4, 5, 6)

    let observable = Observable.concat([first, second])
    observable
        .subscribe(onNext: { number in
            print(number)
        })
        .disposed(by: disposeBag)
}

example(of: "conconcat") {
    let disposeBag = DisposeBag()
    let germanCities = Observable.of("Berlin", "Münich", "Frankfurt")
    let spanishCities = Observable.of("Madrid", "Barcelona", "Valencia")

    let observable = germanCities.concat(spanishCities)
    observable.subscribe(onNext: { value in
        print(value)
    })
    .disposed(by: disposeBag)
}

example(of: "concat one element") {
    let disposeBag = DisposeBag()
    let numbers = Observable.of(2, 3, 4)

    let observable = Observable
    .just(1)
    .concat(numbers)

    observable.subscribe(onNext: { value in
        print(value)
    })
    .disposed(by: disposeBag)
}

// MARK: - Merging -

example(of: "merge") { 
    let left = PublishSubject<String>()
    let right = PublishSubject<String>()

    let source = Observable.of(left.asObservable(), right.asObservable())
    let observable = source.merge()

    let disposable = observable.subscribe(onNext: { value in
        print(value)
    })

    var leftValues = ["Berlin", "Munich", "Frankfurt"]
    var rightValues = ["Madrid", "Barcelona", "Valencia"]

    repeat {
        if arc4random_uniform(2) == 0 {
            if !leftValues.isEmpty {
                left.onNext("Left: " + leftValues.removeFirst())
            }
        } else if !rightValues.isEmpty {
            right.onNext("Right: " + rightValues.removeFirst())
        }
    } while !leftValues.isEmpty || !rightValues.isEmpty
    
    disposable.dispose()
}

// MARK: - Combining elements -

example(of: "combineLatest") { 
    let left = PublishSubject<String>()
    let right = PublishSubject<String>()

    let observable = Observable.combineLatest([left, right]) { strings in
        strings.joined(separator: " ")
    }

    let disposable = observable.subscribe(onNext: { value in
        print(value)
    })

    print("> Sending a value to Left")
    left.onNext("Hello,")

    print("> Sending a value to Right")
    right.onNext("world")

    print("> Sending another value to Right")
    right.onNext("RxSwift")

    print("> Sending another value to Left")
    left.onNext("Have a good day,")

    disposable.dispose()
}

example(of: "combine user choice and value") {
    let disposeBag = DisposeBag()
    let choice: Observable<DateFormatter.Style> = Observable.of(.short, .long)
    let dates = Observable.of(Date())

    let observable = Observable.combineLatest(choice, dates) { (format, when) -> String in
        let formatter = DateFormatter()
        formatter.dateStyle = format
        return formatter.string(from: when)
    }

    observable.subscribe(onNext: { value in
        print(value)
    })
    .disposed(by: disposeBag)
}

example(of: "zip") {
    enum Weather {
        case cloudy
        case sunny
    }

    let left: Observable<Weather> = Observable.of(.sunny, .cloudy, .cloudy, .sunny)
    let right = Observable.of("Lisbon", "Copenhagen", "London", "Madrid", "Vienna")

    let observable = Observable.zip(left, right) { weather, city in
        return "It's \(weather) in \(city)"
    }

    observable
        .subscribe(onNext: { value in
            print(value)
        })
        .disposed(by: disposeBag)
}

// MARK: - Triggers -

example(of: "withLatestFrom") {
    let button = PublishSubject<Void>()
    let textField = PublishSubject<String>()

    //  let observable = button.withLatestFrom(textField)
    let observable = textField.sample(button)
    let disposable = observable.subscribe(onNext: { value in
        print(value)
    })

    textField.onNext("Par")
    textField.onNext("Pari")
    textField.onNext("Paris")
    button.onNext()
    button.onNext()
}

// MARK: - Switches -

example(of: "amb") {
    let left = PublishSubject<String>()
    let right = PublishSubject<String>()

    let observable = left.amb(right)
    let disposable = observable.subscribe(onNext: { value in
        print(value)
    })

    left.onNext("Lisbon")
    right.onNext("Copenhagen")
    left.onNext("London")
    left.onNext("Madrid")
    right.onNext("Vienna")

    disposable.dispose()
}

example(of: "switchLatest") {
    let one = PublishSubject<String>()
    let two = PublishSubject<String>()
    let three = PublishSubject<String>()

    let source = PublishSubject<Observable<String>>()

    let observable = source.switchLatest()
    let disposable = observable.subscribe(onNext: { value in
        print(value)
    })

    source.onNext(one)
    one.onNext("Some text from sequence one")
    two.onNext("Some text from sequence two")

    source.onNext(two)
    two.onNext("More text from sequence two")
    one.onNext("and also from sequence one")

    source.onNext(three)
    two.onNext("Why don't you seem me?")
    one.onNext("I'm alone, help me")
    three.onNext("Hey it's three. I win.")

    source.onNext(one)
    one.onNext("Nope. It's me, one!")

    disposable.dispose()
}

// MARK: - Combining elements within a sequence -

example(of: "reduce") {
    let source = Observable.of(1, 3, 5, 7, 9)

    let observable = source.reduce(0, accumulator: +)
    observable.subscribe(onNext: { value in
        print(value)
  })
}

example(of: "scan") {
    let disposeBag = DisposeBag()
    let source = Observable.of(1, 3, 5, 7, 9)
    let observable = source.scan(0, accumulator: +)

    observable.subscribe(onNext: { value in
        print(value)
    })
    .disposed(by: disposeBag)
}
