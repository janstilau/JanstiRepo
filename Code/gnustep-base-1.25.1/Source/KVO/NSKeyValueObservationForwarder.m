//
//  NSKeyValueObservationForwarder.m
//  Foundation
//
//  Created by JustinLau on 2019/4/20.
//

#import "NSKeyValueObservationForwarder.h"


@implementation NSKeyValueObservationForwarder
// 这个类没仔细看.

- (id) initWithKeyPath: (NSString *)keyPath
              ofObject: (id)Observable
            withTarget: (id)aTarget
               context: (void *)context
{
    NSString * remainingKeyPath;
    NSRange dot;
    
    target = aTarget;
    keyPathToForward = [keyPath copy];
    contextToForward = context;
    
    dot = [keyPath rangeOfString: @"."];
    if (dot.location == NSNotFound)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"NSKeyValueObservationForwarder was not given a key path"];
    }
    keyForUpdate = [[keyPath substringToIndex: dot.location] copy];
    remainingKeyPath = [keyPath substringFromIndex: dot.location + 1];
    observedObjectForUpdate = Observable;
    [Observable addObserver: self
             forKeyPath: keyForUpdate
                options: NSKeyValueObservingOptionNew
     | NSKeyValueObservingOptionOld
                context: target];
    dot = [remainingKeyPath rangeOfString: @"."];
    if (dot.location != NSNotFound)
    {
        child = [[NSKeyValueObservationForwarder alloc]
                 initWithKeyPath: remainingKeyPath
                 ofObject: [Observable valueForKey: keyForUpdate]
                 withTarget: self
                 context: NULL];
        observedObjectForForwarding = nil;
    }
    else
    {
        keyForForwarding = [remainingKeyPath copy];
        observedObjectForForwarding = [Observable valueForKey: keyForUpdate];
        [observedObjectForForwarding addObserver: self
                                      forKeyPath: keyForForwarding
                                         options: NSKeyValueObservingOptionNew
         | NSKeyValueObservingOptionOld
                                         context: target];
        child = nil;
    }
    
    return self;
}

- (void) finalize
{
    if (child)
    {
        [child finalize];
    }
    if (observedObjectForUpdate)
    {
        [observedObjectForUpdate removeObserver: self forKeyPath: keyForUpdate];
    }
    if (observedObjectForForwarding)
    {
        [observedObjectForForwarding removeObserver: self forKeyPath:
         keyForForwarding];
    }
    DESTROY(self);
}

- (void) dealloc
{
    [keyForUpdate release];
    [keyForForwarding release];
    [keyPathToForward release];
    
    [super dealloc];
}

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)anObject
                         change: (NSDictionary *)change
                        context: (void *)context
{
    if (anObject == observedObjectForUpdate)
    {
        [self keyPathChanged: nil];
    }
    else
    {
        [target observeValueForKeyPath: keyPathToForward
                              ofObject: observedObjectForUpdate
                                change: change
                               context: contextToForward];
    }
}

- (void) keyPathChanged: (id)objectToObserve
{
    if (objectToObserve != nil)
    {
        [observedObjectForUpdate removeObserver: self forKeyPath: keyForUpdate];
        observedObjectForUpdate = objectToObserve;
        [objectToObserve addObserver: self
                          forKeyPath: keyForUpdate
                             options: NSKeyValueObservingOptionNew
         | NSKeyValueObservingOptionOld
                             context: target];
    }
    if (child != nil)
    {
        [child keyPathChanged:
         [observedObjectForUpdate valueForKey: keyForUpdate]];
    }
    else
    {
        NSMutableDictionary *change;
        
        change = [NSMutableDictionary dictionaryWithObject:
                  [NSNumber numberWithInt: 1]
                                                    forKey:  NSKeyValueChangeKindKey];
        
        if (observedObjectForForwarding != nil)
        {
            id oldValue;
            
            oldValue
            = [observedObjectForForwarding valueForKey: keyForForwarding];
            [observedObjectForForwarding removeObserver: self forKeyPath:
             keyForForwarding];
            if (oldValue)
            {
                [change setObject: oldValue
                           forKey: NSKeyValueChangeOldKey];
            }
        }
        observedObjectForForwarding = [observedObjectForUpdate
                                       valueForKey:keyForUpdate];
        if (observedObjectForForwarding != nil)
        {
            id newValue;
            
            [observedObjectForForwarding addObserver: self
                                          forKeyPath: keyForForwarding
                                             options: NSKeyValueObservingOptionNew
             | NSKeyValueObservingOptionOld
                                             context: target];
            //prepare change notification
            newValue
            = [observedObjectForForwarding valueForKey: keyForForwarding];
            if (newValue)
            {
                [change setObject: newValue forKey: NSKeyValueChangeNewKey];
            }
        }
        [target observeValueForKeyPath: keyPathToForward
                              ofObject: observedObjectForUpdate
                                change: change
                               context: contextToForward];
    }
}

@end
