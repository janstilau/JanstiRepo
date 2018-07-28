#include <iostream>
#include <memory>
#include <vector>

using  namespace std;


class A
{
public:
    A (int value){
        cout << "ctor ";
    }

    A (const A& backuo) {
        cout << "cpor ";
    }
};


int main() {

    A a = 5;
    A b(2);
    A c(a);
    A d = b;
    A e = 123;

    vector<A> stash;
    stash.push_back(a);

  
    std::cout << "vectyor  ";
    stash.insert(stash.begin(), b);


    return 0;
}