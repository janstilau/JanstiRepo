#ifndef _NSIndexPath_h_GNUSTEP_BASE_INCLUDE
#define _NSIndexPath_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSObject.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_4,GS_API_LATEST) && GS_API_VERSION( 10200,GS_API_LATEST)

/**
 * Instances of this class represent a series of indexes into a hierarchy
 * of arrays.<br />
 * Each instance is a unique shared object.
 */
@interface	NSIndexPath : NSObject <NSCopying, NSCoding>
{
@private
    NSUInteger	_hash;
    NSUInteger	_length;
    NSUInteger	*_indexes;
}

/**
 * Return a path containing the single value anIndex.
 */
+ (id) indexPathWithIndex: (NSUInteger)anIndex;

/**
 * Return a path containing all the indexes in the supplied array.
 */
+ (id) indexPathWithIndexes: (NSUInteger*)indexes length: (NSUInteger)length;

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
- (NSUInteger) indexAtPosition: (NSUInteger)position;

/**
 * Return path formed by adding anIndex to the receiver.
 */
- (NSIndexPath *) indexPathByAddingIndex: (NSUInteger)anIndex;

/**
 * Return path formed by removing the last index from the receiver.
 */
- (NSIndexPath *) indexPathByRemovingLastIndex;

/** <init />
 * Returns the shared instance containing the specified index, creating it
 * and destroying the receiver if necessary.
 */
- (id) initWithIndex: (NSUInteger)anIndex;

/** <init />
 * Returns the shared instance containing the specified index array,
 * creating it and destroying the receiver if necessary.
 */
- (id) initWithIndexes: (NSUInteger*)indexes length: (NSUInteger)length;

/**
 * Returns the number of index values present in the receiver.
 */
- (NSUInteger) length;

@end

#endif

#endif
