#import "common.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"


/**
 *  Simple class for iterating over a collection of objects, usually returned
 *  from an [NSArray] or similar.
 */
@implementation NSEnumerator

/**

 这个接口是建立在 nextObject 之上的.
 
 */
- (NSArray*) allObjects
{
  NSMutableArray	*array;
  id			obj;
  SEL			nsel;
  IMP			nimp;
  SEL			asel;
  IMP			aimp;

  array = [NSMutableArray arrayWithCapacity: 10];

  nsel = @selector(nextObject);
  nimp = [self methodForSelector: nsel];
  asel = @selector(addObject:);
  aimp = [array methodForSelector: asel];

  while ((obj = (*nimp)(self, nsel)) != nil)
    {
      (*aimp)(array, asel, obj);
    }
  return array;
}

/**
 *  Returns next object in enumeration, or nil if none remain.  Use code like
 *  <code>while (object = [enumerator nextObject]) { ... }</code>.
 */
- (id) nextObject
{
  [self subclassResponsibility:_cmd];
  return nil;
}

- (NSUInteger) countByEnumeratingWithState: (NSFastEnumerationState*)state 	
				   objects: (id*)stackbuf
				     count: (NSUInteger)len
{
  IMP nextObject = [self methodForSelector: @selector(nextObject)];
  int i;

  state->itemsPtr = stackbuf;
  state->mutationsPtr = (unsigned long*)self;
  for (i = 0; i < len; i++)
    {
      id next = nextObject(self, @selector(nextObject));

      if (nil == next)
	{
	  return i;
	}
      *(stackbuf+i) = next;
    }
  return len;
}
@end