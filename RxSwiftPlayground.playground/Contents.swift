import RxSwift


// Except for the never() example, these observables automatically emit a .completed event
// and naturally terminate

example(of: "justs, of, from") {
    let one = 1
    let two = 2
    let three = 3
    
    let observable: Observable<Int> = Observable<Int>.just(one)
    let observable2 = Observable.of(one, two, three)
    let observable3 = Observable.of([one, two, three])
    let observable4 = Observable.from([one, two, three])
    
}

example(of: "empty") {
    
    // only emits .completed event
    //  it's handy when you want to return an observable that immediately terminates, or intentionally has zero values.
    let observable = Observable<Void>.empty()
    
    observable.subscribe(onCompleted: {
        print("completed")
    })
}

example(of: "never") {
    
    let disposeBag = DisposeBag()
    
    // never creates an observable that doesn’t emit anything and never terminates.
    // It can be used to represent an infinite duration.
    let observable = Observable<Any>.never()
    
    // The do operator allows you to insert side effects;
    // that is, handlers to do things that will not change
    // the emitted event in any way. do will just pass the
    // event through to the next operator in the chain.
    observable
    .debug("log: 0123")
    .do(onSubscribe: {
        print("do onSubscribe")
    }).subscribe(onNext: { element in
        print(element)
    }, onCompleted: {
        print("completed")
    })
    .disposed(by: disposeBag)
}


example(of: "range") {
    
    let observable = Observable<Int>.range(start: 1, count: 10)
    
    observable.subscribe(onNext: { i in
        let n = Double(i)
        let fibonacci = Int(((pow(1.61803, n) - pow(0.61803, n)) / 2.23606).rounded())
        print(fibonacci)
    })
}


// Disposing subscriptions

example(of: "dispose") {
    
    let observable = Observable.of("A", "B", "C")
    
    let subscription = observable.subscribe {  event in
        print(event)
    }
    
    subscription.dispose() // explicitly cancels a subscription
}

example(of: "DisposeBag") {
    
    // dispose bag holds disposables;
    // it will call dispose() on each one when the dispose bag is about to be deallocated
    
    let disposeBag = DisposeBag()
    
     Observable.of("A", "B", "C")
    .subscribe { print($0) }
    .disposed(by: disposeBag)
}

example(of: "create") {
    
    enum MyError: Error {
        case anError
    }
    
    let disposeBag = DisposeBag()
    
    // The create operator takes a single parameter named subscribe.
    // Its job is to provide the implementation of calling subscribe on the observable.
    // In other words, it defines all the events that will be emitted to subscribers.
    
    Observable<String>.create { observer in
        observer.onNext("1")
        
        observer.onError(MyError.anError) // emits error and terminated
        
        observer.onCompleted() // emits completed and terminated
        
        observer.onNext("?") // will not emit
        
        return Disposables.create() // creates an empty disposable. (Note: some disposables have side effects)
    }
    .subscribe(
        onNext: { print($0) },
        onError: { print($0) },
        onCompleted: { print("Completed") },
        onDisposed: { print("Disposed") }
    )
    .disposed(by: disposeBag)
}


example(of: "deferred") {
    
    let disposeBag = DisposeBag()
    
    var flip = false
    
    // creates observable factories that vend a new observable to each subscriber.
    
    let factory: Observable<Int> = Observable.deferred {
        
        flip = !flip
        
        if flip {
            return Observable.of(1,2,3)
        } else {
            return Observable.of(4,5,6)
        }
    }
    
    for _ in 0...3 {
        factory.subscribe(onNext: { print($0, terminator: "") })
        .disposed(by: disposeBag)
        print()
    }
}



// TRAITS
// Traits are observables with a narrower set of behaviors than regular observables.
// There are three kinds of traits in RxSwift: Single, Maybe, and Completable.

// Singles will emit either a .success(value) or .error event.
// .success(value) is actually a combination of the .next and .completed events

// A Completable will only emit a .completed or .error event. It doesn't emit any value.

// Maybe is a mashup of a Single and Completable. It can either emit
// a .success(value), .completed, or .error.


example(of: "Single") {
    
    let disposeBag = DisposeBag()
    
    enum FileReadError: Error {
        case fileNotFound, unreadable, encodingFailed
    }

    func loadText(from name: String) -> Single<String> {
        return Single.create { single in
            let disposable = Disposables.create()
            
            guard let path = Bundle.main.path(forResource: name, ofType: "txt") else {
                single(.error(FileReadError.fileNotFound))
                return disposable
            }
            
            guard let data = FileManager.default.contents(atPath: path) else {
                single(.error(FileReadError.unreadable))
                return disposable
            }
            
            guard let contents = String(data: data, encoding: .utf8) else {
                single(.error(FileReadError.encodingFailed))
                return disposable
            }
            
            single(.success(contents))
            return disposable
        }
    }
    
    loadText(from: "Copyright")
    .subscribe {
        switch $0 {
        case .success(let string):
            print(string)
        case .error(let error):
            print(error)
        }
    }
    .disposed(by: disposeBag)

}

// SUBJECTS
// can act as an observable and as an observer.
example(of: "PublishSubject") {
    
    let subject = PublishSubject<String>()
    
    subject.onNext("Is anyone listening?")
    
    let subscriptionOne = subject
    .subscribe(onNext: { string in
        print(string)
    })
    
    subject.on(.next("1"))
    subject.onNext("2")
    
    let subscriptionTwo = subject
    .subscribe { event in
        print("2)", event.element ?? event)
    }
    
    subject.onNext("3")
    
    subscriptionOne.dispose()
    subject.onNext("4")
    
    // When a publish subject receives a .completed or .error event,
    // also known as a stop event, it will emit that stop event to new
    // subscribers and it will no longer emit .next events.
    // However, it will re-emit its stop event to future subscribers.
    
    subject.onCompleted() // terminates the subject’s observable sequence.
    
    subject.onNext("5") // won’t be emitted
    
    subscriptionTwo.dispose()
    
    let disposeBag = DisposeBag()
    
    subject.subscribe {
        print("3)", $0.element ?? $0) //  gets .completed event
    }
    .disposed(by: disposeBag)
    
    subject.onNext("?")
}

// There are four subject types in RxSwift:
/*
 
 - PublishSubject: Starts empty and only emits new elements to subscribers.
 - BehaviorSubject: Starts with an initial value and replays it or the
   latest element to new subscribers.
 - ReplaySubject: Initialized with a buffer size and will maintain a buffer
   of elements up to that size and replay it to new subscribers.
 - Variable: Wraps a BehaviorSubject, preserves its current value as state,
   and replays only the latest/initial value to new subscribers.
 
 */


enum MyError: Error {
    case anError
}

func print<T: CustomStringConvertible>(label: String, event: Event<T>) {
    print(label, event.element ?? event.error ?? event)
}

example(of: "BehaviorSubject") {
    
    // Behavior subjects are useful when you want to pre-populate a view with the most recent data.
    
    let subject = BehaviorSubject(value: "Initial value")
    
    let disposeBag = DisposeBag()
    
    subject.onNext("X")
    
    subject
    .subscribe {
        print(label: "1)", event: $0)
    }
    .disposed(by: disposeBag)
    
    subject.onError(MyError.anError)
    
    subject.subscribe {
        print(label: "2)", event: $0)
    }
}


// Replay subjects will temporarily cache, or buffer, the latest elements they emit,
// up to a specified size of your choosing.
// They will then replay that buffer to new subscribers.

example(of: "ReplaySubject") {
    
    let subject = ReplaySubject<String>.create(bufferSize: 2)
    
    let disposeBag = DisposeBag()
    
    subject.onNext("1")
    subject.onNext("2")
    subject.onNext("3")
    
    subject.subscribe {
        print(label: "1)", event: $0)
    }
    .disposed(by: disposeBag)
    
    subject.subscribe {
        print(label: "2)", event: $0)
    }
    .disposed(by: disposeBag)
    
    subject.onNext("4")
    subject.onError(MyError.anError)
    subject.dispose()
    subject.subscribe {
        print(label: "3)", event: $0)
    }
    .disposed(by: disposeBag)
}


// Variable wraps a BehaviorSubject and stores its current value as state.
// You can access that current value via its value property, and, unlike
// other subjects and observables in general, you also use that value property
// to set a new element onto a variable. In other words, you don’t use onNext(_:).
// Because it wraps a behavior subject, a variable is created with an initial value,
// and it will replay its latest or initial value to new subscribers.
// In order to access a variable’s underlying behavior subject, you call asObservable() on it.

example(of: "Variable") {
    let variable = Variable("Initial value")
    
    let disposeBag = DisposeBag()
    
    variable.value = "New initial value"
    
    variable.asObservable()
    .subscribe { print(label: "1)", event: $0) }
    .disposed(by: disposeBag)
    
    variable.value = "1"
    
    variable.asObservable()
    .subscribe { print(label: "2)", event: $0) }
    .disposed(by: disposeBag)
    
    variable.value = "2"
    
}


example(of: "PublishSubject") {
    
    let disposeBag = DisposeBag()
    
    let dealtHand = PublishSubject<[(String, Int)]>()
    
    func deal(_ cardCount: UInt) {
        var deck = cards
        var cardsRemaining: UInt32 = 52
        var hand = [(String, Int)]()
        
        for _ in 0..<cardCount {
            let randomIndex = Int(arc4random_uniform(cardsRemaining))
            hand.append(deck[randomIndex])
            deck.remove(at: randomIndex)
            cardsRemaining -= 1
        }
        
        // Add code to update dealtHand here
        if points(for: hand) > 21 {
            dealtHand.onError(HandError.busted)
        } else {
            dealtHand.onNext(hand)
        }
        
    }
    
    // Add subscription to dealtHand here
    dealtHand.subscribe(onNext: { (hand) in
        print(hand)
    }, onError: { error in
        print(error)
    })
    
    deal(3)
}



example(of: "Variable") {
    
    enum UserSession {
        
        case loggedIn, loggedOut
    }
    
    enum LoginError: Error {
        
        case invalidCredentials
    }
    
    let disposeBag = DisposeBag()
    
    // Create userSession Variable of type UserSession with initial value of .loggedOut
    let userSession = Variable(UserSession.loggedOut)
    
    // Subscribe to receive next events from userSession
    userSession.asObservable()
    .subscribe { print($0) }
    .disposed(by: disposeBag)
    
    func logInWith(username: String, password: String, completion: (Error?) -> Void) {
        guard username == "johnny@appleseed.com",
            password == "appleseed"
            else {
                completion(LoginError.invalidCredentials)
                return
        }
        
        // Update userSession
        userSession.value = .loggedIn
    }
    
    func logOut() {
        // Update userSession
        userSession.value = .loggedOut
    }
    
    func performActionRequiringLoggedInUser(_ action: () -> Void) {
        // Ensure that userSession is loggedIn and then execute action()
        guard userSession.value == .loggedIn else { return }
        
        action()
    }
    
    for i in 1...2 {
        let password = i % 2 == 0 ? "appleseed" : "password"
        
        logInWith(username: "johnny@appleseed.com", password: password) { error in
            guard error == nil else {
                print(error!)
                return
            }
            
            print("User logged in.")
        }
        
        performActionRequiringLoggedInUser {
            print("Successfully did something only a logged in user can do.")
        }
    }
}


// Filtering Operators

// - ignoring operators

example(of: "ignoreElements") {
    
    let strikes = PublishSubject<String>()
    
    let disposeBag = DisposeBag()
    
    strikes
        .ignoreElements()
        .subscribe{ _ in print("You're out!") }
        .disposed(by: disposeBag)
    
    strikes.onNext("X")
    strikes.onNext("X")
    strikes.onNext("X")
    
    strikes.onCompleted()
}

example(of: "elementAt") {
    
    let strikes = PublishSubject<String>()
    
    let disposeBag = DisposeBag()
    
    strikes
        .elementAt(2)
        .subscribe(onNext: { _ in print("You're out!") })
        .disposed(by: disposeBag)
    
    strikes.onNext("X")
    strikes.onNext("X")
    strikes.onNext("X")
}


example(of: "filter") {
    let disposeBag = DisposeBag()
    
    Observable.of(1,2,3,4,5,6)
        .filter{ integer in integer % 2 == 0 }
        .subscribe(onNext: { print($0) })
        .disposed(by: disposeBag)
}

// - skipping operators

example(of: "skip") {
    
    let disposeBag = DisposeBag()
    
    Observable.of("A", "B", "C", "D", "E", "F")
        .skip(3)
        .subscribe(onNext: { print($0) }) // D E F
        .disposed(by: disposeBag)
}


example(of: "skipWhile") {
    
    let disposeBag = DisposeBag()
    
    Observable.of(2,2,3,4,4)
        .skipWhile({ integer in integer % 2 == 0 })
        .subscribe(onNext: { print($0) })
        .disposed(by: disposeBag)
}


example(of: "skipUntil") {
    
    let disposeBag = DisposeBag()
    
    let subject = PublishSubject<String>()
    let trigger = PublishSubject<String>()
    
    subject
        .skipUntil(trigger)
        .subscribe(onNext: { print($0) })
        .disposed(by: disposeBag)
    
    subject.onNext("A")
    subject.onNext("B")
    
    trigger.onNext("X")
    
    subject.onNext("C")
}

// - taking operators

example(of: "take") {
    
    let disposeBag = DisposeBag()
    
    Observable.of(1,2,3,4,5,6)
        .take(3)
        .subscribe(onNext: { print($0) })
        .disposed(by: disposeBag)
}


example(of: "takeWhile") {
    
    let disposeBag = DisposeBag()
    
    Observable.of(2,2,4,4,6,6)
        .enumerated()
        .takeWhile({ index, integer in integer % 2 == 0 && index < 3 })
        .map { $0.element }
        .subscribe(onNext: { print($0) })
        .disposed(by: disposeBag)
}


example(of: "takeUntil") {
    
    let disposeBag = DisposeBag()
    
    let subject = PublishSubject<String>()
    let trigger = PublishSubject<String>()
    
    subject
        .takeUntil(trigger)
        .subscribe(onNext: { print($0) })
        .disposed(by: disposeBag)
    
    subject.onNext("1")
    subject.onNext("2")
    
    trigger.onNext("X")
    
    subject.onNext("3")
}

// - distinct operators

example(of: "distinctUntilChanged") {
    
    let disposeBag = DisposeBag()
    
    Observable.of("A", "A", "B", "B", "A")
        .distinctUntilChanged()
        .subscribe(onNext: { print($0) })
        .disposed(by: disposeBag)
}


example(of: "distinctUntilChanged(_:)") {
    
    let disposeBag = DisposeBag()
    
    let formatter = NumberFormatter()
    formatter.numberStyle = .spellOut
    
    Observable<NSNumber>.of(10, 110, 20, 200, 210, 310)
        .distinctUntilChanged { a, b in
            guard
                let aWords = formatter.string(from: a)?.components(separatedBy: " "),
                let bWords = formatter.string(from: b)?.components(separatedBy: " ")
                else { return false }
            
            var containsMatch = false
            
            for aWord in aWords {
                for bWord in bWords {
                    if aWord == bWord {
                        containsMatch = true
                    }
                }
            }
            
            return containsMatch
        }
        .subscribe(onNext: { print($0) })
        .disposed(by: disposeBag)
}


/// summary

example(of: "Challenge 1") {
    
    let disposeBag = DisposeBag()
    
    let contacts = [
        "603-555-1212": "Florent",
        "212-555-1212": "Junior",
        "408-555-1212": "Marin",
        "617-555-1212": "Scott"
    ]
    
    func phoneNumber(from inputs: [Int]) -> String {
        var phone = inputs.map(String.init).joined()
        
        phone.insert("-", at: phone.index(
            phone.startIndex,
            offsetBy: 3)
        )
        
        phone.insert("-", at: phone.index(
            phone.startIndex,
            offsetBy: 7)
        )
        
        return phone
    }
    
    let input = PublishSubject<Int>()
    
    // Add your code here
    input
        .skipWhile({ $0 == 0 })
        .filter { $0 < 10 }
        .take(10)
        .toArray()
        .subscribe(onNext: {
            if let contact = contacts[phoneNumber(from: $0)] {
                print(contact)
            } else {
                print("Contact not found")
            }
        })
        .disposed(by: disposeBag)
    
    
    input.onNext(0)
    input.onNext(603)
    
    input.onNext(2)
    input.onNext(1)
    
    // Confirm that 7 results in "Contact not found", and then change to 2 and confirm that Junior is found
    input.onNext(2)
    
    "5551212".forEach {
        if let number = (Int("\($0)")) {
            input.onNext(number)
        }
    }
    
    input.onNext(9)
}




// TRANSFORMING OPERATORS

example(of: "toArray") {
    
    let disposeBag = DisposeBag()
    
    Observable.of("A", "B", "C")
    .toArray()
    .subscribe(onNext: { print($0) })
    .disposed(by: disposeBag)
    
}

example(of: "map") {
    
    let disposeBag = DisposeBag()
    
    let formatter = NumberFormatter()
    formatter.numberStyle = .spellOut
    
    Observable<NSNumber>.of(123, 4, 56)
    .map { formatter.string(from: $0) ?? "" }
    .subscribe(onNext: { print($0) })
    .disposed(by: disposeBag)
}

example(of: "enumerated and map") {
    
    let disposeBag = DisposeBag()
    
    Observable.of(1,2,3,4,5,6)
    .enumerated()
    .map { index, integer in index > 2 ? integer * 2 : integer }
    .subscribe(onNext: { print($0) })
    .disposed(by: disposeBag)
}

struct Student {
    var score: BehaviorSubject<Int>
}


example(of: "flatMap") {
    
    let disposeBag = DisposeBag()
    
    let ryan = Student(score: BehaviorSubject(value: 80))
    let charlotte = Student(score: BehaviorSubject(value: 90))
    
    let student = PublishSubject<Student>()
    
    
    // flatMap keeps projecting changes from each observable
    student
    .flatMap {
        $0.score
    }
    .subscribe(onNext: {
        print($0)
    })
    .disposed(by: disposeBag)
    
    student.onNext(ryan)
    ryan.score.onNext(85)
    
    student.onNext(charlotte)
    ryan.score.onNext(95)
    charlotte.score.onNext(100)
}

example(of: "flatMapLatest") {
    
    let disposeBag = DisposeBag()
    
    let ryan = Student(score: BehaviorSubject(value: 80))
    let charlotte = Student(score: BehaviorSubject(value: 90))
    
    let student = PublishSubject<Student>()
    
    
    // flatMapLatest will automatically switch to the latest observable and unsubscribe from the the previous one.
    student
        .flatMapLatest {
            $0.score
        }
        .subscribe(onNext: {
            print($0)
        })
        .disposed(by: disposeBag)
    
    student.onNext(ryan)
    ryan.score.onNext(85)
    
    student.onNext(charlotte)
    ryan.score.onNext(95)
    charlotte.score.onNext(100)
}

// Observing events

example(of: "materialize and dematerialize") {
    
    let disposeBag = DisposeBag()
    
    let ryan = Student(score: BehaviorSubject(value: 80))
    let charlotte = Student(score: BehaviorSubject(value: 100))
    let student = BehaviorSubject(value: ryan)
    
    let studentScore = student
    .flatMapLatest { $0.score.materialize() }
    
    studentScore
    .filter {
        guard $0.error == nil else {
            print($0.error!)
            return false
        }
        return true
    }
    .dematerialize()
    .subscribe(onNext: { print($0) })
    .disposed(by: disposeBag)
    
    ryan.score.onNext(85)
    ryan.score.onError(MyError.anError)
    ryan.score.onNext(90)
    
    student.onNext(charlotte)
}




example(of: "Challenge") {
    let disposeBag = DisposeBag()
    
    let contacts = [
        "603-555-1212": "Florent",
        "212-555-1212": "Junior",
        "408-555-1212": "Marin",
        "617-555-1212": "Scott"
    ]
    
    let convert: (String) -> UInt? = { value in
        if let number = UInt(value),
            number < 10 {
            return number
        }
        
        let keyMap: [String: UInt] = [
            "abc": 2, "def": 3, "ghi": 4,
            "jkl": 5, "mno": 6, "pqrs": 7,
            "tuv": 8, "wxyz": 9
        ]
        
        let converted = keyMap
            .filter { $0.key.contains(value.lowercased()) }
            .map { $0.value }
            .first
        
        return converted
    }
    
    let format: ([UInt]) -> String = {
        var phone = $0.map(String.init).joined()
        
        phone.insert("-", at: phone.index(
            phone.startIndex,
            offsetBy: 3)
        )
        
        phone.insert("-", at: phone.index(
            phone.startIndex,
            offsetBy: 7)
        )
        
        return phone
    }
    
    let dial: (String) -> String = {
        if let contact = contacts[$0] {
            return "Dialing \(contact) (\($0))..."
        } else {
            return "Contact not found"
        }
    }
    
    let input = Variable<String>("")
    
    // Add your code here
    input.asObservable()
    .map(convert)
    .filter { $0 != nil }
    .map { $0! }
    .skipWhile { $0 == 0 }
    .take(10)
    .toArray()
    .map(format)
    .subscribe(onNext: { print(dial($0)) })
    .disposed(by: disposeBag)
    
    
    
    input.value = ""
    input.value = "0"
    input.value = "408"
    
    input.value = "6"
    input.value = ""
    input.value = "0"
    input.value = "3"
    
    "JKL1A1B".forEach {
        input.value = "\($0)"
    }
    
    input.value = "9"
}


// COMBINING OPERATORS



// Prefixing and concatenating

example(of: "startWith") {

    let numbers = Observable.of(2,3,4)
    
    let observable = numbers.startWith(1)
    observable.subscribe(onNext: { value in
        print(value)
    })
}

example(of: "Observable.concat") {
    
    let first = Observable.of(1,2,3)
    let second = Observable.of(4,5,6)
    
    let observable = Observable.concat([first, second])
    
    observable.subscribe(onNext: { value in
        print(value)
    })
}

example(of: "concat") {
    
    let germanCities = Observable.of("Berlin", "Münich", "Frankfurt")
    let spanishCities = Observable.of("Madrid", "Barcelona", "Valencia")
    
    let observable = germanCities.concat(spanishCities)
    observable
    .subscribe(onNext: { value in
        print(value)
    })
}


example(of: "concatMap") {
    /*
    closely related to flatMap(_:). The closure you pass to flatMap(_:) returns
    an Observable sequence which is subscribed to, and the emitted observables are
    all merged. concatMap(_:) guarantees that each sequence produced by the closure
    will run to completion before the next is subscribed to. concatMap(_:) is therefore
    a handy way to guarantee sequential order.
    */
    
    let sequences = [
        "Germany": Observable.of("Berlin", "Münich", "Frankfurt"),
        "Spain": Observable.of("Madrid", "Barcelona", "Valencia")
    ]
    
    let observable = Observable.of("Germany", "Spain")
    .concatMap { country in sequences[country] ?? .empty() }
    
    _ = observable.subscribe(onNext: { string in
        print(string)
    })
    
}

// Merging

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
    
    
    /*
     merge(maxConcurrent:) limits the number of sequences subscribed to at once.
     This variant keeps subscribing to incoming sequences until it reaches the maxConcurrent limit.
     After that, it puts incoming observables in a queue. It will subscribe to them in order,
     as soon as one of current sequences completes.
    */
    
}


// Combining elements

example(of: "combineLatest") {
    
    let left = PublishSubject<String>()
    let right = PublishSubject<String>()
    
    let observable = Observable.combineLatest(left, right, resultSelector: {
        lastLeft, lastRight in
        "\(lastLeft) \(lastRight)"
    })
    
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
    
    // features:
    // 1. can combine sequences of heterogeneous types.
    // 2. Nothing happens until each of the combined observables emits one value.
}

example(of: "combine user choice and value") {
    
    let choice: Observable<DateFormatter.Style> = Observable.of(.short, .long)
    let dates = Observable.of(Date())
    
    let observable = Observable.combineLatest(choice, dates) {
        (format, when) -> String in
        let formatter = DateFormatter()
        formatter.dateStyle = format
        return formatter.string(from: when)
    }
    
    observable.subscribe(onNext: { value in
        print(value)
    })
    
    
    /*
     combineLatest completes only when the last of its inner sequences completes.
     Before that, it keeps sending combined values. If some sequences terminate,
     it uses the last value emitted to combine with new values from other sequences.
    */
}

example(of: "zip") {
    
    enum Weather {
        case cloudy
        case sunny
    }
    
    let left: Observable<Weather> = Observable.of(.sunny, .cloudy, .cloudy, .sunny)
    let right = Observable.of("Lisbon", "Copenhagen", "London", "Madrid", "Vienna")
    
    let observable = Observable.zip(left, right) { weather, city in // zip waits until each of the inner observables emits a new value. Called indexed sequencing.
        return "It's \(weather) in \(city)"
    }
    
    observable.subscribe(onNext: { value in
        print(value)
    })
}


// Triggers

example(of: "withLatestFrom") {
    
    let button = PublishSubject<Void>()
    let textField = PublishSubject<String>()
    
    let observable = button.withLatestFrom(textField)
    
    _ = observable.subscribe(onNext: { value in
        print(value)
    })
    
    textField.onNext("Par")
    textField.onNext("Pari")
    textField.onNext("Paris")
    button.onNext(())
    button.onNext(())
    
}


example(of: "sample") {
    
    
    // each time the trigger observable emits a value, sample(_:) emits the latest value
    // from the “other” observable, but only if it arrived since the last “tick”.
    // If no new data arrived, sample(_:) won’t emit anything.
    
    let button = PublishSubject<Void>()
    let textField = PublishSubject<String>()
    
    let observable = textField.sample(button)
    
    _ = observable.subscribe(onNext: { value in
        print(value)
    })
    
    textField.onNext("Par")
    textField.onNext("Pari")
    textField.onNext("Paris")
    button.onNext(()) // emit
    button.onNext(()) // doesn't emit
}


// Siwtches

example(of: "amb") {
    
    // The amb(_:) operator subscribes to left and right observables.
    // It waits for any of them to emit an element, then unsubscribes
    // from the other one.
    
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


example(of: "swiftchLatest") {
    
    let one = PublishSubject<String>()
    let two = PublishSubject<String>()
    let three = PublishSubject<String>()
    
    let source = PublishSubject<Observable<String>>()
    
    let observable = source.switchLatest() // subscription only prints items from the latest sequence pushed to the source observable.
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
    two.onNext("Why don't you see me?")
    one.onNext("I'm alone, help me")
    three.onNext("Hey it's three. I win.")
    source.onNext(one)
    one.onNext("Nope. It's me, one!")
    
    disposable.dispose()
}

// Combining elements within a sequence

example(of: "reduce") {
    
    // reduce(_:_:) produces its summary (accumulated) value only when the source observable completes.
    // Applying this operator to sequences that never complete won’t emit anything.
    
    let source = Observable.of(1,2,5,7,9)
    
    let observable = source.reduce(0, accumulator: +)
    observable.subscribe(onNext: { value in
        print(value)
    })
}

example(of: "scan") {
    let source = Observable.of(1,3,5,7,9)
    
    let observable = source.scan(0, accumulator: +)
    
    observable.subscribe(onNext: { value in
        print(value)
    })
}

example(of: "Challenge: The zip case 1") {
    let source = Observable.of(1,3,5,7,9)
    
    let observable = Observable.zip(source, source.scan(0, accumulator: +))
    
    observable.subscribe(onNext: { value in
        print(value)
    })
}

example(of: "Challenge: The no zip case 2") {
    let source = Observable.of(1,3,5,7,9)
    
    let observable = source.scan((0, 0), accumulator: { acc, current in
        return (current, acc.1 + current)
    })
    
    observable.subscribe(onNext: { value in
        print(value)
    })
}














