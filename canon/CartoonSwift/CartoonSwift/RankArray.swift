//
//  RankArray.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/25.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

class RankArray {
    func arrayRankTransform(_ arr: [Int]) -> [Int] {
        let sortedArray = arr.sorted()
        var rankDict = [Int:Int]()
        var rankNum = 1
        for aItem in sortedArray {
            if !rankDict.keys.contains(aItem) {
                rankDict[aItem] = rankNum
                rankNum += 1
            }
        }
        let result = arr.map { aItem -> Int in
            return rankDict[aItem]!
        }
        return result
    }
    
    /*
     上面我自己的写法, 还是最原始的写法, 没有利用好系统提供的类库.
     一定要利用好系统的类库, 这样才能写出更加优雅的代码.
     */
    func getFromWeb(_ arr: [Int]) -> [Int]{
        //初始化一个字典用来存储排序后原数组的元素和序号
        var map = [Int:Int]()
        //初始化返回值
        var result = [Int]()

        //将去重且排序后的数组元素和其对应的序号插入字典
        for (index, num) in Set<Int>(arr).sorted(by: < ).enumerated() {
            map.updateValue(index + 1, forKey: num)
        }

        //将每个元素的序号按原数组的顺序添加到返回值
        for num in arr {
            result.append(map[num]!)
        }

        return result

    }
}
