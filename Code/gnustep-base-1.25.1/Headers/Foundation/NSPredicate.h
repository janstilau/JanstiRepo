#ifndef __NSPredicate_h_GNUSTEP_BASE_INCLUDE
#define __NSPredicate_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if	OS_API_VERSION(MAC_OS_X_VERSION_10_4, GS_API_LATEST)

#import	<Foundation/NSObject.h>
#import	<Foundation/NSArray.h>
#import	<Foundation/NSDictionary.h>
#import	<Foundation/NSSet.h>
#import <Foundation/NSString.h>

#if	defined(__cplusplus)
extern "C" {
#endif
    
#if	OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
    DEFINE_BLOCK_TYPE(GSBlockPredicateBlock, BOOL, id, GS_GENERIC_CLASS(NSDictionary,NSString*,id)*);
#endif
    
    @interface NSPredicate : NSObject <NSCoding, NSCopying>

+ (NSPredicate *) predicateWithFormat: (NSString *)format, ...;
+ (NSPredicate *) predicateWithFormat: (NSString *)format
                        argumentArray: (NSArray *)args;
+ (NSPredicate *) predicateWithFormat: (NSString *)format
                            arguments: (va_list)args;
+ (NSPredicate *) predicateWithValue: (BOOL)value;
#if	OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
+ (NSPredicate *) predicateWithBlock: (GSBlockPredicateBlock)block;
#endif
- (BOOL) evaluateWithObject: (id)object;
- (NSString *) predicateFormat;
- (NSPredicate *) predicateWithSubstitutionVariables:
(GS_GENERIC_CLASS(NSDictionary,NSString*,id)*)variables;
#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)
- (BOOL) evaluateWithObject: (id)object
      substitutionVariables: 
(GS_GENERIC_CLASS(NSDictionary,NSString*,id)*)variables;
#endif
@end
    
    @interface NSArray (NSPredicate)
/** Evaluate each object in the array using the specified predicate and
 * return an array containing all the objects which evaluate to YES.
 */
- (NSArray *) filteredArrayUsingPredicate: (NSPredicate *)predicate;
@end
    
    @interface NSMutableArray (NSPredicate)
/** Evaluate each object in the array using the specified predicate and
 * remove each objects which evaluates to NO.
 */
- (void) filterUsingPredicate: (NSPredicate *)predicate;
@end
    
    @interface NSSet (NSPredicate)
/** Evaluate each object in the set using the specified predicate and
 * return an set containing all the objects which evaluate to YES.
 */
- (NSSet *) filteredSetUsingPredicate: (NSPredicate *)predicate;
@end
    
    @interface NSMutableSet (NSPredicate)
/** Evaluate each object in the set using the specified predicate and
 * remove each objects which evaluates to NO.
 */
- (void) filterUsingPredicate: (NSPredicate *)predicate;
@end
    
#if	defined(__cplusplus)
}
#endif

#endif	/* 100400 */
#endif /* __NSPredicate_h_GNUSTEP_BASE_INCLUDE */
