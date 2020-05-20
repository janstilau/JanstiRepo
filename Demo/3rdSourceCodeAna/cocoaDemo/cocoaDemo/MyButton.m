//
//  MyButton.m
//  cocoaDemo
//
//  Created by JustinLau on 2019/1/12.
//  Copyright © 2019年 JustinLau. All rights reserved.
//

#import "MyButton.h"

@implementation MyButton

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
}

- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
    [super sendAction:action to:target forEvent:event];
    NSLog(@"sel %@", NSStringFromSelector(action));
    NSLog(@"target %@", target);
    NSLog(@"event %@", event);
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    NSLog(@"%s", __func__);
    return [super beginTrackingWithTouch:touch withEvent:event];
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    NSLog(@"%s", __func__);
    return [super continueTrackingWithTouch:touch withEvent:event];
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    NSLog(@"%s", __func__);
    [super endTrackingWithTouch:touch withEvent:event];
}

- (void)cancelTrackingWithEvent:(UIEvent *)event {
    NSLog(@"%s", __func__);
    [super cancelTrackingWithEvent:event];
}



@end
