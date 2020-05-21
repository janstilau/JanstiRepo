//
//  GSKVOObservation.h
//  Foundation
//
//  Created by JustinLau on 2019/4/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/* An instance of this records all the information for a single observation.
 这里, 记录观察者的信息, context, options, 观察者本身
 */
@interface    GSKVOObservation : NSObject
{
@public
    NSObject      *observer;      // Not retained (zeroing weak pointer)
    void          *context;
    int           options;
}
@end

NS_ASSUME_NONNULL_END
