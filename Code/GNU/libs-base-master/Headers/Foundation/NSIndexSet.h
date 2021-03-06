#ifndef _NSIndexSet_h_GNUSTEP_BASE_INCLUDE
#define _NSIndexSet_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>
#import <GNUstepBase/GSBlocks.h>

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)

#import	<Foundation/NSObject.h>
#import	<Foundation/NSRange.h>

/*
 NSIndexSet 里面, 真正的内存里面存的, 是 sorted Range
 这个实现的思路, 和自己之前实现的 id 生成器是一样的.
 1. 节约了内存. 不会把所有的 int 值都存储在内存里面
 2. 排序之后的数据, 可以直接使用二分查找了.
 */
@interface	NSIndexSet : NSObject <NSCopying, NSMutableCopying, NSCoding>
{
#if	GS_EXPOSE(NSIndexSet)
  void	*_data;
#endif
}

/**
 * Return an empty set.
 */
+ (id) indexSet;

/**
 * Return a set containing the single value anIndex, or returns nil if
 * anIndex is NSNotFound.
 */
+ (id) indexSetWithIndex: (NSUInteger)anIndex;

/**
 * Return a set containing all the values in aRange, or returns nil if
 * aRange contains NSNotFound.
 */
+ (id) indexSetWithIndexesInRange: (NSRange)aRange;

/**
 * Returns YES if the receiver contains anIndex, NO otherwise.
 */
- (BOOL) containsIndex: (NSUInteger)anIndex;

/**
 * Returns YES if the receiver contains all the index values present
 * in aSet, NO otherwise.
 */
- (BOOL) containsIndexes: (NSIndexSet*)aSet;

/**
 * Returns YES if the receiver contains all the index values present
 * in aRange, NO otherwise.
 */
- (BOOL) containsIndexesInRange: (NSRange)aRange;

/**
 * Returns the number of index values present in the receiver.
 */
- (NSUInteger) count;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5,GS_API_LATEST)
/** Not implemented
 * Returns the number of indexes set within the specified range.
 */
- (NSUInteger) countOfIndexesInRange: (NSRange)range;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6,GS_API_LATEST)
DEFINE_BLOCK_TYPE(GSIndexSetEnumerationBlock, void, NSUInteger, BOOL*);
- (void) enumerateIndexesInRange: (NSRange)range
                         options: (NSEnumerationOptions)opts
		      usingBlock: (GSIndexSetEnumerationBlock)aBlock;
/**
 * Enumerate all indices in the set by applying a block to them.
 */
- (void) enumerateIndexesUsingBlock: (GSIndexSetEnumerationBlock)aBlock;

- (void) enumerateIndexesWithOptions: (NSEnumerationOptions)opts
		          usingBlock: (GSIndexSetEnumerationBlock)aBlock;

#endif

/**
 * Returns the first index value in the receiver or NSNotFound if the
 * receiver is empty.
 */
- (NSUInteger) firstIndex;

/**
 * Copies index values into aBuffer until there are no index values left or
 * aBuffer is full (assuming that the size of aBuffer is given by aCount).<br />
 * Only copies index values present in aRange and copies them in order.<br />
 * Returns the number of index values placed in aBuffer.<br />
 * Modifies aRange to start after the last index value copied.<br />
 * If aRange is a null pointer, this method attempts to get <em>all</em>
 * index values from the set (and of course no range can be returned in it).
 */
- (NSUInteger) getIndexes: (NSUInteger*)aBuffer
		 maxCount: (NSUInteger)aCount
	     inIndexRange: (NSRangePointer)aRange;

/**
 * Return the first index value in the receiver which is greater than
 * anIndex.
 */
- (NSUInteger) indexGreaterThanIndex: (NSUInteger)anIndex;

/**
 * Return the first index value in the receiver which is greater than
 * or equal to anIndex.
 */
- (NSUInteger) indexGreaterThanOrEqualToIndex: (NSUInteger)anIndex;

/**
 * Return the first index value in the receiver which is less than
 * anIndex.
 */
- (NSUInteger) indexLessThanIndex: (NSUInteger)anIndex;

/**
 * Return the first index value in the receiver which is less than
 * or equal to anIndex.
 */
- (NSUInteger) indexLessThanOrEqualToIndex: (NSUInteger)anIndex;

/**
 * Initialise the receiver to contain anIndex.  Returns the initialised
 * object or nil if anIndex is NSNotFound.
 */
- (id) initWithIndex: (NSUInteger)anIndex;

/** <init />
 * Initialise the receiver to contain all index values in aRange.
 * Returns the initialised object or nil if aRange contains NSNotFound.
 */
- (id) initWithIndexesInRange: (NSRange)aRange;

/**
 * Initialises the receiver with the index values from aSet.
 */
- (id) initWithIndexSet: (NSIndexSet*)aSet;

/**
 * Returns YES if the receiver contains any index values which lie in aRange,
 * No otherwise.
 */
- (BOOL) intersectsIndexesInRange: (NSRange)aRange;

/**
 * Tests two index sets for equality and returns either YES or NO.
 */
- (BOOL) isEqualToIndexSet: (NSIndexSet*)aSet;

/**
 * Returns the last index value in the receiver or NSNotFound if the
 * receiver is empty.
 */
- (NSUInteger) lastIndex;
@end


@interface	NSMutableIndexSet : NSIndexSet

/**
 * Adds anIndex to the set of indexes stored in the receiver.
 */
- (void) addIndex: (NSUInteger)anIndex;

/**
 * Adds all the indexes from aSet to the set of indexes stored in the receiver.
 */
- (void) addIndexes: (NSIndexSet*)aSet;

/**
 * Adds all the indexes in aRange to the set of indexes stored in the receiver.
 */
- (void) addIndexesInRange: (NSRange)aRange;

/**
 * Removes all indexes stored in the receiver.
 */
- (void) removeAllIndexes;

/**
 * Removes anIndex from the set of indexes stored in the receiver.
 */
- (void) removeIndex: (NSUInteger)anIndex;

/**
 * Removes all the indexes in aSet from the set of indexes
 * stored in the receiver.
 */
- (void) removeIndexes: (NSIndexSet*)aSet;

/**
 * Removes all the indexes in aRange from the set of indexes
 * stored in the receiver.
 */
- (void) removeIndexesInRange: (NSRange)aRange;

/**
 * Moves all the indexes from anIndex upwards by the amount specified.<br />
 * If amount is negative, index values below anIndex will be overwritten
 * by the shifted values.<br />
 * If amount is positive, a 'hole' will be left in the index range after
 * anIndex.
 */
- (void) shiftIndexesStartingAtIndex: (NSUInteger)anIndex
				  by: (NSInteger)amount;

@end

#endif
#endif
