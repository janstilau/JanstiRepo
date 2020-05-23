#ifndef _NSIndexPath_h_GNUSTEP_BASE_INCLUDE
#define _NSIndexPath_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_4,GS_API_LATEST) && GS_API_VERSION( 10200,GS_API_LATEST)

/**
 * Instances of this class represent a series of indexes into a hierarchy
 * of arrays.<br />
 * Each instance is a unique shared object.
 */
@interface	NSIndexPath : NSObject <NSCopying, NSCoding>
{
#if	GS_EXPOSE(NSIndexPath)
@private
  NSUInteger	_hash;
  NSUInteger	_length;
  NSUInteger	*_indexes;
#endif
#if     GS_NONFRAGILE
#else
  /* Pointer to private additional data used to avoid breaking ABI
   * when we don't have the non-fragile ABI available.
   * Use this mechanism rather than changing the instance variable
   * layout (see Source/GSInternal.h for details).
   */
  @private id _internal GS_UNUSED_IVAR;
#endif
}

/**
 * Return a path containing the single value anIndex.
 */
+ (id) indexPathWithIndex: (int)anIndex;

/**
 * Return a path containing all the indexes in the supplied array.
 */
+ (id) indexPathWithIndexes: (NSUInteger*)indexes length: (int)length;

/**
 * Compares other with the receiver.<br />
 * Returns NSOrderedSame if the two are identical.<br />
 * Returns NSOrderedAscending if other is less than the receiver in a
 * depth-wise comparison.<br />
 * Returns NSOrderedDescending otherwise.
 */
- (NSComparisonResult) compare: (NSIndexPath*)other;

/**
 * Copies all index values from the receiver into aBuffer.
 */
- (void) getIndexes: (NSUInteger*)aBuffer;

/**
 * Return the index at the specified position or NSNotFound if there
 * is no index at the specified position.
 */
- (int) indexAtPosition: (int)position;

/**
 * Return path formed by adding anIndex to the receiver.
 */
- (NSIndexPath *) indexPathByAddingIndex: (int)anIndex;

/**
 * Return path formed by removing the last index from the receiver.
 */
- (NSIndexPath *) indexPathByRemovingLastIndex;

/** <init />
 * Returns the shared instance containing the specified index, creating it
 * and destroying the receiver if necessary.
 */
- (id) initWithIndex: (int)anIndex;

/** <init />
 * Returns the shared instance containing the specified index array,
 * creating it and destroying the receiver if necessary.
 */
- (id) initWithIndexes: (NSUInteger*)indexes length: (int)length;

/**
 * Returns the number of index values present in the receiver.
 */
- (int) length;

@end

#endif

#if	defined(__cplusplus)
}
#endif

#endif
