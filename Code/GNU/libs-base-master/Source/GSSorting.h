#import "Foundation/NSSortDescriptor.h"

#import "GNUstepBase/GSObjCRuntime.h"
#import "Foundation/NSException.h"
#import "GSPrivate.h"

enum
{
  GSComparisonTypeSortDescriptor = 0, /** Comparison using NSSortDescriptor */
  GSComparisonTypeComparatorBlock, /** Comparison using an NSComparator */
  GSComparisonTypeFunction, /** Comparison using a comparison function of type
  * NSInteger(*)(id,id,void*) */
  GSComparisonTypeMax
};

typedef NSUInteger GSComparisonType;

/**
 * This is the internal prototype of an unstable, non-concurrency safe sorting
 * function that can be used either through NSComparator or NSSortDescriptor. It
 * may or may not be implemented by one of the sorting implementations in
 * GNUstep.
 */
extern void (*_GSSortUnstable)(id *buffer, NSRange range, id comparisonEntity,
  GSComparisonType cmprType, void *context);

/**
 * This is the internal prototype of an stable, non-concurrency safe sorting
 * function that can be used either through NSComparator or NSSortDescriptor.
 * It may or may not be implemented by one of the sorting implementations in
 * GNUstep.
 */
extern void (*_GSSortStable)(id *buffer, NSRange range, id comparisonEntity,
  GSComparisonType cmprType, void *context);

/**
 * This is the internal prototype of an unstable, concurrency safe sorting
 * function that can be used either through NSComparator or NSSortDescriptor.
 * It may or may not be implemented by one of the sorting implementations in
 * GNUstep.
 */
extern void (*_GSSortUnstableConcurrent)(id *buffer, NSRange range,
  id comparisonEntity, GSComparisonType cmprType, void *context);

/**
 * This is the internal prototype of an stable, concurrency safe sorting
 * function that can be used either through NSComparator or NSSortDescriptor.
 * It may or may not be implemented by one of the sorting implementations in
 * GNUstep.
 */
extern void (*_GSSortStableConcurrent)(id *buffer, NSRange range,
  id comparisonEntity, GSComparisonType cmprType, void *context);

/**
 * GSSortUnstable() uses the above prototypes to provide sorting that does not
 * make any specific guarantees. If no explicit unstable sorting algorithm is
 * available, it will fall through to stable sorting.
 */
void
GSSortUnstable(id *buffer, NSRange range, id sortDecriptorOrCompatator,
  GSComparisonType cmprType, void *context);

/**
 * GSSortStable() uses one of the internal sorting algorithms to provide stable
 * sorting. If no stable sorting method is available, it raises an exception.
 */
void
GSSortStable(id *buffer, NSRange range, id sortDecriptorOrCompatator,
  GSComparisonType cmprType, void *context);

/**
 * GSSortUnstableConcurrent() uses the above prototypes to provide sorting that
 * does not make guarantees about stability, but allows for concurrent sorting.
 * If no such sorting algorithm is available, it first falls through to stable
 * concurrent sorting, then unstable non-concurrent sorting and finally stable
 * concurrent sorting.
 */
void
GSSortUnstableConcurrent(id *buffer, NSRange range,
  id sortDecriptorOrCompatator, GSComparisonType cmprType, void *context);

/**
 * GSSortStableConcurrent() uses one of the internal sorting algorithms to
 * provide stable sorting that may be executed concurrently. If no such
 * algorithm is available, it falls through to non-concurrent GSSortStable().
 */
void
GSSortStableConcurrent(id *buffer, NSRange range, id sortDecriptorOrCompatator,
  GSComparisonType cmprType, void *context);


/**
 * This function finds the proper point for inserting a new key into a sorted
 * range, placing the new key at the rightmost position of all equal keys.
 *
 * This function is provided using the implementation of the timsort algorithm.
 */
NSUInteger
GSRightInsertionPointForKeyInSortedRange(id key, id *buffer,
  NSRange range, NSComparator comparator);

/**
 * This function finds the proper point for inserting a new key into a sorted
 * range, placing the new key at the leftmost position of all equal keys.
 *
 * This function is provided using the implementation of the timsort algorithm.
 */
NSUInteger
GSLeftInsertionPointForKeyInSortedRange(id key, id *buffer,
  NSRange range, NSComparator comparator);

/**
 * Convenience function to operate with sort descriptors,
 * comparator blocks and functions.
 */
/*
 OC 提供了这么多比较的办法, 到头来, 还是一个 type 值进行了区分.
 */
static inline NSComparisonResult
GSCompareUsingDescriptorOrComparator(id first, id second, id descOrComp,
  GSComparisonType cmprType, void *context)
{

  switch (cmprType)
    {
      case GSComparisonTypeSortDescriptor:
        return [(NSSortDescriptor*)descOrComp compareObject: first
                                                   toObject: second];
      case GSComparisonTypeComparatorBlock:
        return CALL_BLOCK(((NSComparator)descOrComp), first, second);

      case GSComparisonTypeFunction:
        return ((NSInteger (*)(id, id, void *))descOrComp)(first,
          second, context);

      default:
        [NSException raise: @"NSInternalInconstitencyException"
                    format: @"Invalid comparison type"];
    }
  return 0;
}

