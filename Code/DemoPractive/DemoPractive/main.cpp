//
//  main.cpp
//  DemoPractive
//
//  Created by JustinLau on 2019/3/4.
//  Copyright © 2019年 JustinLau. All rights reserved.
//

#include <iostream>
#include <vector>
#include <map>


using namespace std;

class Solution {
public:
    vector<int> twoSum(vector<int>& nums, int target) {
        map<int, int> container;
        for (int i = 0; i < nums.size(); ++i) {
            container[nums[i]] = i;
        }
        for (int i = 0; i < nums.size(); ++i) {
            auto it = container.find(target - nums[i]);
            if (it != container.end()) {
                vector<int> result;
                result.push_back(i);
                result.push_back(it->second);
                return result;
            }
        }
        
        vector<int> notFound;
        notFound.push_back(-1);
        notFound.push_back(-1);
        return notFound;
    };
};

int main(int argc, const char * argv[]) {
    
    vector<int> array = {2, 7,  11, 15};
    Solution().twoSum(array, 9);
    
    return 0;
}
