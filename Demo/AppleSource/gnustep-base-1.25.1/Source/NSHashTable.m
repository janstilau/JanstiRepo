#import "common.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSException.h"
#import "Foundation/NSPointerFunctions.h"
#import "Foundation/NSSet.h"
#import "Foundation/NSHashTable.h"
#import "NSCallBacks.h"
#import "GSPrivate.h"

@interface	NSConcreteHashTable : NSHashTable
@end

@implementation	NSHashTable


static Class	abstractClass = 0;
static Class	concreteClass = 0;

+ (id) allocWithZone: (NSZone*)aZone
{
  if (self == abstractClass)
    {
      return NSAllocateObject(concreteClass, 0, aZone);
    }
  return NSAllocateObject(self, 0, aZone);
}

+ (void) initialize
{
  if (abstractClass == 0)
    {
      abstractClass = [NSHashTable class];
      concreteClass = [NSConcreteHashTable class];
    }
}

+ (id) hashTableWithOptions: (NSPointerFunctionsOptions)options
{
  NSHashTable	*t;

  t = [self allocWithZone: NSDefaultMallocZone()];
  t = [t initWithOptions: options
		capacity: 0];
  return AUTORELEASE(t);
}

+ (id) hashTableWithWeakObjects
{
  return [self hashTableWithOptions:
    NSPointerFunctionsObjectPersonality | NSPointerFunctionsZeroingWeakMemory];
}

+ (id) weakObjectsHashTable
{
  return [self hashTableWithOptions:
    NSPointerFunctionsObjectPersonality | NSPointerFunctionsWeakMemory];
}

- (id) initWithOptions: (NSPointerFunctionsOptions)options
	      capacity: (int)initialCapacity
{
  NSPointerFunctions	*k;
  id			o;

  k = [[NSPointerFunctions alloc] initWithOptions: options];
  o = [self initWithPointerFunctions: k capacity: initialCapacity];
  [k release];
  return o;
}

- (id) initWithPointerFunctions: (NSPointerFunctions*)functions
		       capacity: (int)initialCapacity
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (void) addObject: (id)object
{
  [self subclassResponsibility: _cmd];
}

- (NSArray*) allObjects
{
  NSEnumerator	*enumerator;
  unsigned	nodeCount = [self count];
  unsigned	index;
  NSArray	*a;
  GS_BEGINITEMBUF(objects, nodeCount, id);

  enumerator = [self objectEnumerator];
  index = 0;
  while (index < nodeCount && (objects[index] = [enumerator nextObject]) != nil)
    {
      index++;
    }
  a = [[[NSArray alloc] initWithObjects: objects count: index] autorelease];
  GS_ENDITEMBUF();
  return a;
}

- (id) anyObject
{
  return [[self objectEnumerator] nextObject];
}

- (BOOL) containsObject: (id)anObject
{
  return [self member: anObject] ? YES : NO;
}

- (id) copyWithZone: (NSZone*)aZone
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (int) count
{
  return (NSUInteger)[self subclassResponsibility: _cmd];
}

- (int) countByEnumeratingWithState: (NSFastEnumerationState*)state 	
				   objects: (id*)stackbuf
				     count: (int)len
{
  return (NSUInteger)[self subclassResponsibility: _cmd];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [self subclassResponsibility: _cmd];
}

- (int) hash
{
  return [self count];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  [self subclassResponsibility: _cmd];
  return nil;
}

// 两层遍历操作.
- (void) intersectHashTable: (NSHashTable*)other
{
  unsigned		count = [self count];

  if (count > 0)
    {
      NSEnumerator	*enumerator;
      NSMutableArray	*array;
      id		object;

      array = [NSMutableArray arrayWithCapacity: count];
      enumerator = [self objectEnumerator];
      while ((object = [enumerator nextObject]) != nil)
	{
	  if ([other member: object] == nil)
	    {
	      [array addObject: object];
	    }
	}
      enumerator = [array objectEnumerator];
      while ((object = [enumerator nextObject]) != nil)
	{
	  [self removeObject: object];
	}
    }
}

- (BOOL) intersectsHashTable: (NSHashTable*)other
{
  NSEnumerator	*enumerator;
  id		object;

  enumerator = [self objectEnumerator];
  while ((object = [enumerator nextObject]) != nil)
    {
      if ([other member: object] != nil)
	{
	  return YES;
	}
    }
  return NO;
}

- (BOOL) isEqual: (id)other
{
  if ([other isKindOfClass: abstractClass] == NO) return NO;
  return NSCompareHashTables(self, other);
}

- (BOOL) isEqualToHashTable: (NSHashTable*)other
{
  return NSCompareHashTables(self, other);
}

- (BOOL) isSubsetOfHashTable: (NSHashTable*)other
{
  NSEnumerator	*enumerator;
  id		object;

  enumerator = [self objectEnumerator];
  while ((object = [enumerator nextObject]) != nil)
    {
      if ([other member: object] == nil)
	{
	  return NO;
	}
    }
  return YES;
}

- (id) member: (id)object
{
  return [self subclassResponsibility: _cmd];
}

- (void) minusHashTable: (NSHashTable*)other
{
  if ([self count] > 0 && [other count] > 0)
    {
      NSEnumerator	*enumerator;
      id		object;

      enumerator = [other objectEnumerator];
      while ((object = [enumerator nextObject]) != nil)
	{
	  [self removeObject: object];
	}
    }
}

- (NSEnumerator*) objectEnumerator
{
  return [self subclassResponsibility: _cmd];
}

- (NSPointerFunctions*) pointerFunctions
{
  return [self subclassResponsibility: _cmd];
}

- (void) removeAllObjects
{
  NSEnumerator	*enumerator;
  id		object;

  enumerator = [[self allObjects] objectEnumerator];
  while ((object = [enumerator nextObject]) != nil)
    {
      [self removeObject: object];
    }
}

- (void) removeObject: (id)object
{
  [self subclassResponsibility: _cmd];
}

- (NSSet*) setRepresentation 
{
  NSEnumerator	*enumerator;
  NSMutableSet	*set;
  id		object;

  set = [NSMutableSet setWithCapacity: [self count]];
  enumerator = [[self allObjects] objectEnumerator];
  while ((object = [enumerator nextObject]) != nil)
    {
      [set addObject: object];
    }
  return [[set copy] autorelease];
}

- (void) unionHashTable: (NSHashTable*)other
{
  NSEnumerator	*enumerator;
  id		object;

  enumerator = [other objectEnumerator];
  while ((object = [enumerator nextObject]) != nil)
    {
      [self addObject: object];
    }
}

@end

