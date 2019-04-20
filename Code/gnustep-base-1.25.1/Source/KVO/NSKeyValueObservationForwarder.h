//
//  NSKeyValueObservationForwarder.h
//  Foundation
//
//  Created by JustinLau on 2019/4/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*
 * This is the template class whose methods are added to KVO classes to
 * override the originals and make the swizzled class look like the
 * original class.
 */

@interface NSKeyValueObservationForwarder : NSObject
{
    id                                    target;
    NSKeyValueObservationForwarder        *child;
    void                                  *contextToForward;
    id                                    observedObjectForUpdate;
    NSString                              *keyForUpdate;
    id                                    observedObjectForForwarding;
    NSString                              *keyForForwarding;
    NSString                              *keyPathToForward;
}

- (id) initWithKeyPath: (NSString *)keyPath
              ofObject: (id)object
            withTarget: (id)aTarget
               context: (void *)context;

- (void) keyPathChanged: (id)objectToObserve;
@end


NS_ASSUME_NONNULL_END
