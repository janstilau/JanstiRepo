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
- (NSArray*) allObjects
{
  NSMutableArray	*array;
  id			obj;
  SEL			nextObjectSEL;
  IMP			nextObjectIMP;
  SEL			addObjectSEL;
  IMP			addObjectIMP;

  array = [NSMutableArray arrayWithCapacity: 10];

  nextObjectSEL = @selector(nextObject);
  nextObjectIMP = [self methodForSelector: nextObjectSEL];
  addObjectSEL = @selector(addObject:);
  addObjectIMP = [array methodForSelector: addObjectSEL];

  while ((obj = (*nextObjectIMP)(self, nextObjectSEL)) != nil)
    {
      (*addObjectIMP)(array, addObjectSEL, obj);
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

/**
 * objc_enumerationMutation() is called whenever a collection mutates in the
 * middle of fast enumeration.
 */
void objc_enumerationMutation(id obj)
{
  [NSException raise: NSGenericException 
    format: @"Collection %@ was mutated while being enumerated", obj];
}
