//
//  GSKVOSetter.h
//  Foundation
//
//  Created by JustinLau on 2019/4/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*
 这也是一个操作集合类, 主要用于重写原有类的各个 path 的set 方法.
 */
@interface    GSKVOSetter : NSObject
- (void) setter: (void*)val;
- (void) setterChar: (unsigned char)val;
- (void) setterDouble: (double)val;
- (void) setterFloat: (float)val;
- (void) setterInt: (unsigned int)val;
- (void) setterLong: (unsigned long)val;
#ifdef  _C_LNG_LNG
- (void) setterLongLong: (unsigned long long)val;
#endif
- (void) setterShort: (unsigned short)val;
- (void) setterRange: (NSRange)val;
- (void) setterPoint: (NSPoint)val;
- (void) setterSize: (NSSize)val;
- (void) setterRect: (NSRect)rect;
@end

NS_ASSUME_NONNULL_END
