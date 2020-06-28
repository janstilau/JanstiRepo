
#import "common.h"
#import "Foundation/NSSortDescriptor.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSObjCRuntime.h"
#import "GSSorting.h"

/**
 * Sorts the provided object array's sortRange according to sortDescriptor.
 */
// Quicksort algorithm copied from Wikipedia :-).

static inline void
SwapObjects(id * o1, id * o2)
{
  id temp;

  temp = *o1;
  *o1 = *o2;
  *o2 = temp;
}

/*
 GS 的快速排序的实现.
 */
static void
_GSQuickSort(id *objects, NSRange sortRange, id comparisonEntity, GSComparisonType type, void *context)
{
    if (sortRange.length <= 1) { return; }
    
    /*
     这里, pivot 是取得第一个元素.
     */
    id pivot = objects[sortRange.location];
    unsigned int left = sortRange.location + 1;
    unsigned int right = NSMaxRange(sortRange);

    /*
     下面代码有些秀技, 本质上, 就是快速排序的思想.
     */
    while (left < right)
      {
        if (GSCompareUsingDescriptorOrComparator(objects[left], pivot,
      comparisonEntity, type, context) == NSOrderedDescending)
          {
            SwapObjects(&objects[left], &objects[--right]);
          }
        else
          {
            left++;
          }
      }

    SwapObjects(&objects[--left], &objects[sortRange.location]);
    
    _GSQuickSort(objects,
      NSMakeRange(sortRange.location, left - sortRange.location),
      comparisonEntity, type, context);
    _GSQuickSort(objects,
      NSMakeRange(right, NSMaxRange(sortRange) - right),
      comparisonEntity, type, context);
}

@interface GSQuickSortPlaceHolder : NSObject
+ (void) setUnstable;
@end

@implementation GSQuickSortPlaceHolder
+ (void) setUnstable
{
  _GSSortUnstable = _GSQuickSort;
}
@end
