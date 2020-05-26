
*/
#import "common.h"
#import "Foundation/NSException.h"
#import "GNUstepBase/NSArray+GNUstepBase.h"
#import "GSPrivate.h"

@implementation NSArray (GNUstepBase)

- (int) insertionPosition: (id)item
            usingFunction: (NSComparisonResult (*)(id, id, void *))sorter
                  context: (void *)context
{
    NSUInteger	count = [self count];
    NSUInteger	upper = count;
    NSUInteger	lower = 0;
    NSUInteger	index;
    SEL		oaiSel;
    IMP		oai;
    
    if (item == nil)
    {
        [NSException raise: NSGenericException
                    format: @"Attempt to find position for nil object in array"];
    }
    if (sorter == 0)
    {
        [NSException raise: NSGenericException
                    format: @"Attempt to find position with null comparator"];
    }
    
    oaiSel = @selector(objectAtIndex:);
    oai = [self methodForSelector: oaiSel];
    /*
     *	Binary search for an item equal to the one to be inserted.
     */
    for (index = upper/2; upper != lower; index = lower+(upper-lower)/2)
    {
        NSComparisonResult comparison;
        
        comparison = (*sorter)(item, (*oai)(self, oaiSel, index), context);
        if (comparison == NSOrderedAscending)
        {
            upper = index;
        }
        else if (comparison == NSOrderedDescending)
        {
            lower = index + 1;
        }
        else
        {
            break;
        }
    }
    /*
     *	Now skip past any equal items so the insertion point is AFTER any
     *	items that are equal to the new one.
     */
    while (index < count && (*sorter)(item, (*oai)(self, oaiSel, index), context)
           != NSOrderedAscending)
    {
        index++;
    }
    return index;
}

- (int) insertionPosition: (id)item
            usingSelector: (SEL)comp
{
    NSUInteger	count = [self count];
    NSUInteger	upper = count;
    NSUInteger	lower = 0;
    NSUInteger	index;
    NSComparisonResult	(*imp)(id, SEL, id);
    SEL		oaiSel;
    IMP		oai;
    
    if (item == nil)
    {
        [NSException raise: NSGenericException
                    format: @"Attempt to find position for nil object in array"];
    }
    if (comp == 0)
    {
        [NSException raise: NSGenericException
                    format: @"Attempt to find position with null comparator"];
    }
    imp = (NSComparisonResult (*)(id, SEL, id))[item methodForSelector: comp];
    if (imp == 0)
    {
        [NSException raise: NSGenericException
                    format: @"Attempt to find position with unknown method"];
    }
    
    oaiSel = @selector(objectAtIndex:);
    oai = [self methodForSelector: oaiSel];
    /*
     *	Binary search for an item equal to the one to be inserted.
     */
    for (index = upper/2; upper != lower; index = lower+(upper-lower)/2)
    {
        NSComparisonResult comparison;
        
        comparison = (*imp)(item, comp, (*oai)(self, oaiSel, index));
        if (comparison == NSOrderedAscending)
        {
            upper = index;
        }
        else if (comparison == NSOrderedDescending)
        {
            lower = index + 1;
        }
        else
        {
            break;
        }
    }
    /*
     *	Now skip past any equal items so the insertion point is AFTER any
     *	items that are equal to the new one.
     */
    while (index < count
           && (*imp)(item, comp, (*oai)(self, oaiSel, index)) != NSOrderedAscending)
    {
        index++;
    }
    return index;
}

@end
