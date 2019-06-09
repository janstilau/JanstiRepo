//
//  GSKVOReplacement.h
//  Foundation
//
//  Created by JustinLau on 2019/4/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


/*
 * This holds information about a subclass replacing a class which is
 * being observed.
 这个数据类, 里面存放了, 原始的类型信息, KVO 替换的类型信息, 以及观测的 key 的值.
 */
@interface    GSKVOReplacement : NSObject
{
    Class         _original;       /* The original class */
    Class         _replacement;    /* The replacement class */
    NSMutableSet  *_observeredKeys;          /* The observed setter keys */
}
- (id) initWithClass: (Class)aClass;
- (void) overrideSetterFor: (NSString*)aKey;
- (Class) replacement;
@end


NS_ASSUME_NONNULL_END
