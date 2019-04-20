//
//  GSKVOPathInfo.m
//  Foundation
//
//  Created by JustinLau on 2019/4/20.
//

#import "GSKVOPathInfo.h"


@implementation    GSKVOPathInfo
- (void) dealloc
{
    [change release];
    [observations release];
    [super dealloc];
}

- (id) init
{
    change = [NSMutableDictionary new];
    observations = [NSMutableArray new];
    return self;
}

- (void) notifyForKey: (NSString *)aKey ofInstance: (id)instance prior: (BOOL)f
{
    unsigned      count;
    id            oldValue;
    id            newValue;
    
    if (f == YES)
    {
        if ((allOptions & NSKeyValueObservingOptionPrior) == 0)
        {
            return;   // Nothing to do.
        }
        [change setObject: [NSNumber numberWithBool: YES]
                   forKey: NSKeyValueChangeNotificationIsPriorKey];
    }
    else
    {
        [change removeObjectForKey: NSKeyValueChangeNotificationIsPriorKey];
    }
    
    oldValue = [[change objectForKey: NSKeyValueChangeOldKey] retain];
    if (oldValue == nil)
    {
        oldValue = null;
    }
    newValue = [[change objectForKey: NSKeyValueChangeNewKey] retain];
    if (newValue == nil)
    {
        newValue = null;
    }
    
    /* Retain self so that we won't be deallocated during the
     * notification process.
     */
    [self retain];
    count = [observations count];
    while (count-- > 0)
    {
        GSKVOObservation  *o = [observations objectAtIndex: count];
        
        // 根据每一个 GSKVOObservation 的配置, 进行修改.
        if (f == YES)
        {
            if ((o->options & NSKeyValueObservingOptionPrior) == 0)
            {
                continue;
            }
        }
        else
        {
            if (o->options & NSKeyValueObservingOptionNew)
            {
                [change setObject: newValue
                           forKey: NSKeyValueChangeNewKey];
            }
        }
        
        if (o->options & NSKeyValueObservingOptionOld)
        {
            [change setObject: oldValue
                       forKey: NSKeyValueChangeOldKey];
        }
        
        [o->observer observeValueForKeyPath: aKey
                                   ofObject: instance
                                     change: change
                                    context: o->context];
    }
    
    [change setObject: oldValue forKey: NSKeyValueChangeOldKey];
    [oldValue release];
    [change setObject: newValue forKey: NSKeyValueChangeNewKey];
    [newValue release];
    [self release];
}
@end
