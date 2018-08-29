#include <iostream>
#include <memory>
#include <vector>

using  namespace std;


class A
{
public:
    A (int value){
        cout << "A ctor ";
    }

    A (const A& backuo) {
        cout << "A cpor ";
    }

    A& operator=(const A& back) {
        cout << "A assign ";
        return *this;
    }
};

class B : public  A{
public:
    explicit B(int value, int bvalue):
            A(value),
            mBvalue(bvalue) {
        cout << " B ctor ";
    }

    B (const B& backuo): A(backuo) {
        cout << "B cpor ";
    }

    B& operator=(const B& back) {
        A::operator=(back);
        cout << "B assign ";
        return *this;
    }

    int mBvalue;
};


int main() {

   B b(1, 20);
   B ba(b);
   ba = b;


    return 0;
}