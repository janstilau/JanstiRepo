//
//  main.cpp
//  excep
//
//  Created by JustinLau on 2019/12/15.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#include <iostream>

int sayHello() throw(int) {
     std::cout << "Hello, World!\n";
    throw 1;
    return 1;
}

int main(int argc, const char * argv[]) {
    // insert code here...
    sayHello();
    return 0;
}
