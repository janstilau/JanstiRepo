#ifndef	INCLUDED_NSArray_GNUstepBase_h
#define	INCLUDED_NSArray_GNUstepBase_h

#import <GNUstepBase/GSVersionMacros.h>
#import <Foundation/NSArray.h>

#if	OS_API_VERSION(GS_API_NONE,GS_API_LATEST)

@interface NSArray (GNUstepBase)

/** <p>Method for working with sorted arrays - use a binary chop
 * to determine the insertion location for an object.  If equal objects
 * already exist in the array, they will be located immediately before
 * the insertion position.
 * </p>
 * <p>The comparator function takes two items as arguments, the first is the
 * item to be added, the second is the item already in the array.
 * The function should return NSOrderedAscending if the item to be
 * added is 'less than' the item in the array, NSOrderedDescending
 * if it is greater, and NSOrderedSame if it is equal.
 * </p>
 */
- (NSUInteger) insertionPosition: (id)item
		   usingFunction: (NSComparisonResult (*)(id, id, void *))sorter
		         context: (void *)context;

/* <p>Method for working with sorted arrays - use a binary chop
 * to determine the insertion location for an object.  If equal objects
 * already exist in the array, they will be located immediately before
 * the insertion position.
 * </p> 
 * <p>The selector identifies a method returning NSOrderedAscending if
 * the receiver is 'less than' the argument, and NSOrderedDescending if
 * it is greate.
 * </p>
 */
- (NSUInteger) insertionPosition: (id)item
		   usingSelector: (SEL)comp;
@end

#endif	/* OS_API_VERSION */

#endif	/* INCLUDED_NSArray_GNUstepBase_h */

