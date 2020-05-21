//
//  GSKVOPathInfo.h
//  Foundation
//
//  Created by JustinLau on 2019/4/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/* An instance of thsi records the observations for a key path and the
 * recursion state of the process of sending notifications.
 */
@interface    GSKVOPathInfo : NSObject
{
@public
    unsigned              recursion;
    unsigned              allOptions;
    NSMutableArray        *observations;
    NSMutableDictionary   *change;
}
- (void) notifyForKey: (NSString *)aKey ofInstance: (id)instance prior: (BOOL)f;
@end

NS_ASSUME_NONNULL_END
