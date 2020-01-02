//
//  main.cpp
//  vector
//
//  Created by JustinLau on 2019/12/18.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#include <iostream>
#include <vector>

using namespace std;

class Person {
public:
    int age = 11;
    Person(){}
    Person(const Person&aPerson) {
        cout<< "Person Cpor" << endl;
    }
};

int main(int argc, const char * argv[]) {
    
    vector<Person> aVect;
    cout << aVect.capacity();
    Person aPerson;
    aVect.push_back(aPerson);
    cout << aVect.capacity();
    aVect.push_back(aPerson);
    cout << aVect.capacity();
    const Person& pRef = aVect[0];
    
    cout << "end";
    
    return 0;
}
