//
//  main.m
//  demo
//
//  Created by JustinLau on 2019/8/15.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Person.h"

@protocol TempProtocol <NSObject>

- (int)tempProtocolMethod;

@end

@interface SelfGeneric<__covariant ObjectType, __covariant KeyType>: NSObject

@property (nonatomic, strong) ObjectType value;

- (instancetype)initWithValue:(ObjectType)value;
- (ObjectType)valueCall;
- (BOOL)compare:(KeyType)value and:(KeyType)value_2;

@end

@implementation SelfGeneric

- (instancetype)initWithValue:(id)value {
    self = [super init];
    if (self) {
        _value = value;
    }
    return self;
}

- (id)valueCall {
    [_value valueCall];
    return _value;
}

- (BOOL)compare:(id)value and:(id)value_2 {
    return [value tempProtocolMethod] > [value_2 tempProtocolMethod];
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Person *aPerson = [[Person alloc] initWithAge:20];
        SelfGeneric<Person*, Person*> *generic = [[SelfGeneric alloc] initWithValue:aPerson];
        [generic compare:aPerson and:[NSObject alloc]];
    }
    return 0;
}
