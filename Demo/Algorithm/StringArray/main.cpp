#include <iostream>
#include <unordered_map>
#include <vector>
#include <iterator>
#include <algorithm>

using namespace std;





int main() {

    vector<int> nums;
    fill_n(back_inserter(nums), 10, 10);
    std::cout << nums.size();

    vector<int> backup;
    replace_copy(nums.begin(), nums.end(), back_inserter(backup), 10 , 20);



    return 0;
}