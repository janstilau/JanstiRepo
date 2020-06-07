#import "common.h"
#import "Foundation/NSSet.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSPortCoder.h"

#import "GSPrivate.h"

#define	GSI_MAP_RETAIN_VAL(M, X)	
#define	GSI_MAP_RELEASE_VAL(M, X)	
#define GSI_MAP_KTYPES	GSUNION_OBJ
#define GSI_MAP_VTYPES	GSUNION_NSINT

#include "GNUstepBase/GSIMap.h"

@interface GSCountedSet : NSCountedSet
{
@public
  GSIMapTable_t	map;
@private
  NSUInteger _version;
}
@end

@interface GSCountedSetEnumerator : NSEnumerator
{
    GSCountedSet		*set;// 在 Enumerator 里面, 存放了原有容器的指针.
  GSIMapEnumerator_t	enumerator;
}
@end

@implementation GSCountedSetEnumerator

- (id) initWithSet: (NSSet*)d
{
  self = [super init];
  if (self != nil)
    {
      set = RETAIN((GSCountedSet*)d);
      enumerator = GSIMapEnumeratorForMap(&set->map);
    }
  return self;
}

- (id) nextObject
{
  GSIMapNode node = GSIMapEnumeratorNextNode(&enumerator);

  if (node == 0)
    {
      return nil;
    }
  return node->key.obj;
}

@end


@implementation GSCountedSet

+ (void) initialize
{
  if (self == [GSCountedSet class])
    {
    }
}

/**
 * Adds an object to the set.  If the set already contains an object
 * equal to the specified object (as determined by the [-isEqual:]
 * method) then the count for that object is incremented rather
 * than the new object being added.
 */
- (void) addObject: (id)anObject
{
  GSIMapNode node;

  if (anObject == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Tried to nil value to counted set"];
    }

  _version++;
  node = GSIMapNodeForKey(&map, (GSIMapKey)anObject);
  if (node == 0)
    {
      GSIMapAddPair(&map,(GSIMapKey)anObject,(GSIMapVal)(NSUInteger)1);
    }
  else
    {
      node->value.nsu++;
    }
  _version++;
}

- (int) count
{
  return map.nodeCount;
}

- (int) countForObject: (id)anObject
{
  if (anObject)
    {
      GSIMapNode node = GSIMapNodeForKey(&map, (GSIMapKey)anObject);

      if (node)
	{
	  return node->value.nsu;
	}
    }
  return 0;
}

- (int) hash
{
  return map.nodeCount;
}

- (id) init
{
  return [self initWithCapacity: 0];
}

/* Designated initialiser */
- (id) initWithCapacity: (int)cap
{
  GSIMapInitWithZoneAndCapacity(&map, [self zone], cap);
  return self;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  unsigned	count;
  id		value;
  NSUInteger	valcnt;
  SEL		sel = @selector(decodeValueOfObjCType:at:);
  IMP		imp = [aCoder methodForSelector: sel];
  const char	*utype = @encode(unsigned);
  const char	*otype = @encode(id);

  (*imp)(aCoder, sel, utype, &count);

  GSIMapInitWithZoneAndCapacity(&map, [self zone], count);
  while (count-- > 0)
    {
      (*imp)(aCoder, sel, otype, &value);
      (*imp)(aCoder, sel, utype, &valcnt);
      GSIMapAddPairNoRetain(&map, (GSIMapKey)value, (GSIMapVal)valcnt);
    }

  return self;
}

- (id) initWithObjects: (const id[])objs count: (int)c
{
  NSUInteger	i;

  self = [self initWithCapacity: c];
  if (self == nil)
    {
      return nil;
    }
  for (i = 0; i < c; i++)
    {
      GSIMapNode     node;

      if (objs[i] == nil)
	{
	  DESTROY(self);
	  [NSException raise: NSInvalidArgumentException
		      format: @"Tried to init counted set with nil value"];
	}
      node = GSIMapNodeForKey(&map, (GSIMapKey)objs[i]);
      if (node == 0)
	{
	  GSIMapAddPair(&map,(GSIMapKey)objs[i],(GSIMapVal)(NSUInteger)1);
        }
      else
	{
	  node->value.nsu++;
	}
    }
  return self;
}

- (id) member: (id)anObject
{
  if (anObject != nil)
    {
      GSIMapNode node = GSIMapNodeForKey(&map, (GSIMapKey)anObject);

      if (node != 0)
	{
	  return node->key.obj;
	}
    }
  return nil;
}

- (NSEnumerator*) objectEnumerator
{
  return AUTORELEASE([[GSCountedSetEnumerator allocWithZone:
    NSDefaultMallocZone()] initWithSet: self]);
}

/**
 * Removes all objcts which have not been added more than level times
 * from the counted set.<br />
 * Note to GNUstep maintainers ... this method depends on the characteristic
 * of the GSIMap enumeration that, once enumerated, an object can be removed
 * from the map.  If GSIMap ever loses that characterstic, this will break.
 */
- (void) purge: (NSInteger)level
{
  if (level > 0)
    {
      GSIMapEnumerator_t	enumerator = GSIMapEnumeratorForMap(&map);
      GSIMapBucket       	bucket = GSIMapEnumeratorBucket(&enumerator);
      GSIMapNode 		node = GSIMapEnumeratorNextNode(&enumerator);

      while (node != 0)
	{
	  if (node->value.nsu <= (NSUInteger)level)
	    {
	      _version++;
	      GSIMapRemoveNodeFromMap(&map, bucket, node);
	      GSIMapFreeNode(&map, node);
	      _version++;
	    }
	  bucket = GSIMapEnumeratorBucket(&enumerator);
	  node = GSIMapEnumeratorNextNode(&enumerator);
	}
      GSIMapEndEnumerator(&enumerator);
    }
}

- (void) removeAllObjects
{
  _version++;
  GSIMapCleanMap(&map);
  _version++;
}

/**
 * Decrements the count of the number of times that the specified
 * object (or an object equal to it as determined by the
 * [-isEqual:] method) has been added to the set.  If the count
 * becomes zero, the object is removed from the set.
 */
- (void) removeObject: (id)anObject
{
  GSIMapBucket       bucket;

  if (anObject == nil)
    {
      NSWarnMLog(@"attempt to remove nil object");
      return;
    }
  _version++;
  bucket = GSIMapBucketForKey(&map, (GSIMapKey)anObject);
  if (bucket != 0)
    {
      GSIMapNode     node;

      node = GSIMapNodeForKeyInBucket(&map, bucket, (GSIMapKey)anObject);
      if (node != 0)
	{
	  if (--node->value.nsu == 0)
	    {
	      GSIMapRemoveNodeFromMap(&map, bucket, node);
	      GSIMapFreeNode(&map, node);
	    }
	}
    }
  _version++;
}

- (id) unique: (id)anObject
{
  GSIMapNode	node;
  id		result;
  _version++;

  if (anObject == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Tried to unique nil value in counted set"];
    }

  node = GSIMapNodeForKey(&map, (GSIMapKey)anObject);
  if (node == 0)
    {
      result = anObject;
      GSIMapAddPair(&map,(GSIMapKey)anObject,(GSIMapVal)(NSUInteger)1);
    }
  else
    {
      result = node->key.obj;
      node->value.nsu++;
      if (result != anObject)
	{
	  [anObject release];
	  [result retain];
	}
    }
  _version++;
  return result;
}

- (int) countByEnumeratingWithState: (NSFastEnumerationState*)state
                                   objects: (id*)stackbuf
                                     count: (int)len
{
  state->mutationsPtr = (unsigned long *)&_version;
  return GSIMapCountByEnumeratingWithStateObjectsCount
    (&map, state, stackbuf, len);
}

- (int) sizeInBytesExcluding: (NSHashTable*)exclude
{
  NSUInteger	size = GSPrivateMemorySize(self, exclude);

  if (size > 0)
    {
      GSIMapEnumerator_t	enumerator = GSIMapEnumeratorForMap(&map);
      GSIMapNode 		node = GSIMapEnumeratorNextNode(&enumerator);

      size += GSIMapSize(&map) - sizeof(map);
      while (node != 0)
        {
          size += [node->key.obj sizeInBytesExcluding: exclude];
          node = GSIMapEnumeratorNextNode(&enumerator);
        }
      GSIMapEndEnumerator(&enumerator);
    }
  return size;
}

@end
