
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
 *  Returns all objects remaining in the enumeration as an array.<br />
 *  Calling this method 'exhausts' the enumerator, leaving it at the
 *  end of the collection being enumerated.
 */

// nextObject 这个方法的具体实现, 是每个NSEnumerator根据自己依赖的容器的结构进行自定义的, allObjects 做的就是最后的统计工作.

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

- (int) countByEnumeratingWithState: (NSFastEnumerationState*)state 	
				   objects: (id*)stackbuf
				     count: (int)len
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

/**
 * objc_enumerationMutation() is called whenever a collection mutates in the
 * middle of fast enumeration.
 */
void objc_enumerationMutation(id obj)
{
  [NSException raise: NSGenericException 
    format: @"Collection %@ was mutated while being enumerated", obj];
}
