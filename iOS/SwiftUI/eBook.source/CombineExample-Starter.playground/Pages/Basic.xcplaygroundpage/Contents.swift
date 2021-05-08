import Combine

//check("Empty") {
//    Empty<Int, SampleError>()
//}

//check("Just") {
//    Just("Hello SwiftUI")
//}

//check("Sequence") {
//    Publishers.Sequence<[Int], Never>(sequence: [1, 2, 3, 4, 5])
//}

check("Array") {
    [1, 2, 3]
        .publisher
        . map { $0 * 2 }
}
