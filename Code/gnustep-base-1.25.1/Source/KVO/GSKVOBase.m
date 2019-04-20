//
//  GSKVOBase.m
//  Foundation
//
//  Created by JustinLau on 2019/4/20.
//

#import "GSKVOBase.h"


@implementation    GSKVOBase
- (void) dealloc
{
    // Turn off KVO for self ... then call the real dealloc implementation.
    [self setObservationInfo: nil];
    object_setClass(self, [self class]);
    [self dealloc];
}
- (Class) class
{
    return class_getSuperclass(object_getClass(self));
}
- (void) setValue: (id)anObject forKey: (NSString*)aKey
{
    Class        c = [self class];
    void        (*imp)(id,SEL,id,id);
    
    imp = (void (*)(id,SEL,id,id))[c instanceMethodForSelector: _cmd];
    
    if ([[self class] automaticallyNotifiesObserversForKey: aKey])
    {
        [self willChangeValueForKey: aKey];
        imp(self,_cmd,anObject,aKey);
        [self didChangeValueForKey: aKey];
    }
    else
    {
        imp(self,_cmd,anObject,aKey);
    }
}
- (Class) superclass
{
    return class_getSuperclass(class_getSuperclass(object_getClass(self)));
}
@end
