//
//  Meeting.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/7/11.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

/*
 There are n flights, and they are labeled from 1 to n.

 We have a list of flight bookings.  The i-th booking bookings[i] = [i, j, k] means that we booked k seats from flights labeled i to j inclusive.

 Return an array answer of length n, representing the number of seats booked on each flight in order of their label.

  

 Example 1:

 Input: bookings = [[1,2,10],[2,3,20],[2,5,25]], n = 5
 Output: [10,55,45,25,25]
  

 Constraints:

 1 <= bookings.length <= 20000
 1 <= bookings[i][0] <= bookings[i][1] <= n <= 20000
 1 <= bookings[i][2] <= 10000
 */

class CorpFlightBookings {
    
    struct rangeTimes {
        let start: Int
        let end: Int
        let times: Int
    }
    
    func corpFlightBookings_FailForTime(_ bookings: [[Int]], _ n: Int) -> [Int] {
        var result = [Int](repeating: 0, count: n + 1)
        for aBooking in bookings {
            guard aBooking.count == 3 else {
                continue
            }
            let start = aBooking[0]
            let end = aBooking[1]
            let bookCount = aBooking[2]
            for n in start...end {
                result[n] += bookCount
            }
        }
        return [Int](result[1...n])
    }
    
    class Solution {
        func maxSubArray(_ nums: [Int]) -> Int {
            return 1
        }
    }
}

/*
 Say you have an array for which the ith element is the price of a given stock on day i.

 If you were only permitted to complete at most one transaction (i.e., buy one and sell one share of the stock), design an algorithm to find the maximum profit.

 Note that you cannot sell a stock before you buy one.

 Example 1:

 Input: [7,1,5,3,6,4]
 Output: 5
 Explanation: Buy on day 2 (price = 1) and sell on day 5 (price = 6), profit = 6-1 = 5.
              Not 7-1 = 6, as selling price needs to be larger than buying price.
 Example 2:

 Input: [7,6,4,3,1]
 Output: 0
 Explanation: In this case, no transaction is done, i.e. max profit = 0.
 */

class BuyStock {
    func maxProfit(_ prices: [Int]) -> Int {
        let count = prices.count
        guard count > 1 else {
            return 0
        }
        var minPrices = [Int](repeating: Int.max, count: count)
        minPrices[0] = prices[0]
        for idx in 1...count-1 {
            if prices[idx] < minPrices[idx-1] {
                minPrices[idx] = prices[idx]
            } else {
                minPrices[idx] = minPrices[idx-1]
            }
        }
        var max = 0
        for idx in 0...count-1 {
            let profit = prices[idx] - minPrices[idx]
            if profit > max { max = profit }
        }
        return max
    }
}


class IsPalindrome {
    func isPalindrome(_ txt: String) -> Bool {
        var charStash = [Character]()
        for aChar in txt {
            if aChar.isLetter {
                charStash.append(contentsOf: aChar.lowercased())
            }
            if aChar.isNumber {
                charStash.append(contentsOf: aChar.lowercased())
            }
        }
        
        var leftPtr = 0
        var rightPtr = charStash.count - 1
        while leftPtr <= rightPtr {
            if charStash[leftPtr] != charStash[rightPtr] { return false }
            leftPtr += 1
            rightPtr -= 1
        }
        
        return true
    }
}
