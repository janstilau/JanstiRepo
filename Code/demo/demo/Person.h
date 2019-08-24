//
//  Person.h
//  demo
//
//  Created by JustinLau on 2019/8/15.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Person : NSObject

+ (instancetype)getPerson;
+ (instancetype)person;
- (instancetype)initWithAge:(int)age;

@end

NS_ASSUME_NONNULL_END
