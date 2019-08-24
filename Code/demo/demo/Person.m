//
//  Person.m
//  demo
//
//  Created by JustinLau on 2019/8/15.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#import "Person.h"

@interface Student : Person

@end

@implementation Student

@end

@interface Person()

@property (nonatomic, assign) int age;

@end

@implementation Person

+ (instancetype)person {
    return [[self alloc] initWithAge:0];
}

+ (instancetype)getPerson {
    return [[Person alloc] init];
}

- (id)initWithAge:(int)age {
    self = [super init];
    if (self) {
        _age = age;
    }
    return self;
}

@end
