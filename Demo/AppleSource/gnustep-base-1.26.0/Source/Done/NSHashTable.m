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

// 父类, 是公共的接口的概念. 在 GNU 的环境里面, 父类的接口的实现, 是建立在一些 primitive 的 method 的基础上的. 这些 primitive 到底如何进行数据的存储, 被放到了子类
// 这也是为什么这么多的父类, 子类, 都是 1:1 的关系. 作为一个类库, 他会认为自己的类有会子类化的可能. 可以这样认为, 子类的都是 privimite method, 而父类的都是高层函数.
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


// Designated init
- (id) initWithOptions: (NSPointerFunctionsOptions)options
	      capacity: (NSUInteger)initialCapacity
{
  NSPointerFunctions	*k;
  id			o;

  k = [[NSPointerFunctions alloc] initWithOptions: options];
  o = [self initWithPointerFunctions: k capacity: initialCapacity];
  [k release];
  return o;
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
  return [[self objectEnumerator] nextObject]; // 创建一个迭代器然后调用它的方法. 按照原理来说, 应该是哈希表的第一个可以查找到的数据.
}

- (BOOL) containsObject: (id)anObject
{
  return [self member: anObject] ? YES : NO;
}

- (NSUInteger) hash
{
  return [self count];
}

- (void) intersectHashTable: (NSHashTable*)other
{
  unsigned		count = [self count];
    // 就是查找相交的数据, 然后最后一期删除. 注意就是, 不能在遍历的过程中删除数据. 只能是先记录, 然后删除.
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

// 和上面的逻辑一眼, 如果有交叉的数据, 立马返回, 略去后面的操作.
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
  // 还是 M*N 的复杂度, 双重的遍历, 应该有剪枝操作.
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

- (void) removeAllObjects
{
  NSEnumerator	*enumerator;
  id		object;
    
    // 在遍历的过程中, 有删除, 这是因为 hash 表的结构, 每次删除都是一个查找操作.
  enumerator = [[self allObjects] objectEnumerator];
  while ((object = [enumerator nextObject]) != nil)
    {
      [self removeObject: object];
    }
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
      [self addObject: object]; // addObject 里面应该会有去重的处理. 所以这里就没有查找的操作.
    }
}

@end

