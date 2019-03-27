#ifndef __NSMapTable_h_GNUSTEP_BASE_INCLUDE
#define __NSMapTable_h_GNUSTEP_BASE_INCLUDE 1
#import	<GNUstepBase/GSVersionMacros.h>

/**** Included Headers *******************************************************/

#import	<Foundation/NSObject.h>
#import	<Foundation/NSString.h>
#import	<Foundation/NSArray.h>
#import	<Foundation/NSEnumerator.h>
#import	<Foundation/NSPointerFunctions.h>

#if	defined(__cplusplus)
extern "C" {
#endif

/**** Type, Constant, and Macro Definitions **********************************/

enum {
  NSMapTableStrongMemory
    = NSPointerFunctionsStrongMemory,
  NSMapTableZeroingWeakMemory
    = NSPointerFunctionsZeroingWeakMemory, // 垃圾回收相关
  NSMapTableCopyIn
    = NSPointerFunctionsCopyIn,
  NSMapTableObjectPointerPersonality
    = NSPointerFunctionsObjectPointerPersonality,
  NSMapTableWeakMemory
    = NSPointerFunctionsWeakMemory // equal to weak
};

typedef NSUInteger NSMapTableOptions;

@interface NSMapTable : NSObject <NSCopying, NSCoding, NSFastEnumeration>


// 这个类可以指定 key 和 value 的内存管理策略.
/** Return a map table initialised using the specified options for
 * keys and values.
 */
+ (id) mapTableWithKeyOptions: (NSPointerFunctionsOptions)keyOptions
		 valueOptions: (NSPointerFunctionsOptions)valueOptions;

/** Convenience method for creating a map table to store object values
 * using object keys.
 */
+ (id) mapTableWithStrongToStrongObjects;

/** Convenience method for creating a map table to store non-retained
 * object values with retained object keys.
 */
+ (id) mapTableWithStrongToWeakObjects;

/** Convenience method for creating a map table to store retained
 * object values with non-retained object keys.
 */
+ (id) mapTableWithWeakToStrongObjects;

/** Convenience method for creating a map table to store non-retained
 * object values with non-retained object keys.
 */
+ (id) mapTableWithWeakToWeakObjects;

/** Convenience method for creating a map table to store object values
 * using object keys.  The collection will retain both the key and the value.
 */
+ (id) strongToStrongObjectsMapTable;
/** Convenience method for creating a map table to store object values
 * using object keys.  The collection will retain the key, the value will be a
 * zeroing weak reference.
 */
+ (id) strongToWeakObjectsMapTable;
/** Convenience method for creating a map table to store object values
 * using object keys.  The collection will retain the value, the key will be a
 * zeroing weak reference.
 */
+ (id) weakToStrongObjectsMapTable;
/** Convenience method for creating a map table to store object values
 * using object keys.  The collection will use zeroing weak references for both
 * the key and the value.
 */
+ (id) weakToWeakObjectsMapTable;

// 上面的方法, 都是一些 convenience 方法.

/** Initialiser using option bitmasks to describe the keys and values.
 */
- (id) initWithKeyOptions: (NSPointerFunctionsOptions)keyOptions
	     valueOptions: (NSPointerFunctionsOptions)valueOptions
	         capacity: (NSUInteger)initialCapacity;

/** Initialiser using full pointer function information to describe
 * the keys and values.
 */
- (id) initWithKeyPointerFunctions: (NSPointerFunctions*)keyFunctions
	     valuePointerFunctions: (NSPointerFunctions*)valueFunctions
			  capacity: (NSUInteger)initialCapacity;

/** Return the number of items stored in the map.
 */
- (NSUInteger) count;

/** Return a dictionary containing the keys and values in the receiver.
 */
- (NSDictionary*) dictionaryRepresentation;

/** Return an enumerator able to enumerate the keys in the receiver.
 */
- (NSEnumerator*) keyEnumerator;

/** Return an NSPointerFunctions value describind the functions used by the
 * receiver to handle keys.
 */
- (NSPointerFunctions*) keyPointerFunctions;

/** Return an enumerator able to enumerate the values in the receiver.
 */
- (NSEnumerator*) objectEnumerator;

/** Return the object stored under the specified key.
 */
- (id) objectForKey: (id)aKey;

/** Empty the receiver of all stored values.
 */
- (void) removeAllObjects;

/** Remove the object stored under the specified key.
 */
- (void) removeObjectForKey: (id)aKey;

/** Store the object under the specified key, replacing any object which
 * was previously stored under that key.
 */
- (void) setObject: (id)anObject forKey: (id)aKey;

/** Return an NSPointerFunctions value describind the functions used by the
 * receiver to handle values.
 */
- (NSPointerFunctions*) valuePointerFunctions;
@end

/**
 * Type for enumerating.<br />
 * NB. Implementation detail ... in GNUstep the layout <strong>must</strong>
 * correspond to that used by the GSIMap macros.
 */
typedef struct { void *map; void *node; size_t bucket; } NSMapEnumerator;

/**
 * Callback functions for a key.
  为什么现在闭包这么流行, 因为在之前的情况下, 想要完成回调这个事情, 必须要这样, 将函数指针包裹到一个结构体里面, 然后传递出去. 因为, 能存贮的只有内存值.
 */
typedef struct _NSMapTableKeyCallBacks
{
  /*
   * Hashing function. Must not modify the key.<br />
   * NOTE: Elements with equal values must
   * have equal hash function values.
   */
  NSUInteger (*hash)(NSMapTable *, const void *);

  /**
   * Comparison function.  Must not modify either key.
   */
  BOOL (*isEqual)(NSMapTable *, const void *, const void *);

  /**
   * Retaining function called when adding elements to table.<br />
   * Notionally this must not modify the key (the key may not
   * actually have a retain count, or the retain count may be stored
   * externally to the key, but in practice this often actually
   * changes a counter within the key).
   */
  void (*retain)(NSMapTable *, const void *);

  /**
   * Releasing function called when a data element is
   * removed from the table.  This may decrease a retain count or may
   * actually destroy the key.
   */
  void (*release)(NSMapTable *, void *);

  /**
   * Description function. Generates a string describing the key
   * and does not modify the key itself.
   */ 
  NSString *(*describe)(NSMapTable *, const void *);

  /**
   * Quantity that is not a key to the map table.
   */
  const void *notAKeyMarker;
} NSMapTableKeyCallBacks;

/**
 * Callback functions for a value.
 */
typedef struct _NSMapTableValueCallBacks NSMapTableValueCallBacks;
struct _NSMapTableValueCallBacks
{
  /**
   * Retaining function called when adding elements to table.<br />
   * Notionally this must not modify the element (the element may not
   * actually have a retain count, or the retain count may be stored
   * externally to the element, but in practice this often actually
   * changes a counter within the element).
   */
  void (*retain)(NSMapTable *, const void *);

  /**
   * Releasing function called when a data element is
   * removed from the table.  This may decrease a retain count or may
   * actually destroy the element.
   */
  void (*release)(NSMapTable *, void *);

  /**
   * Description function. Generates a string describing the element
   * and does not modify the element itself.
   */ 
  NSString *(*describe)(NSMapTable *, const void *);
};

/* Quantities that are never map keys. */
#define NSNotAnIntMapKey     ((const void *)0x80000000)
#define NSNotAPointerMapKey  ((const void *)0xffffffff)

GS_EXPORT const NSMapTableKeyCallBacks NSIntegerMapKeyCallBacks;
GS_EXPORT const NSMapTableKeyCallBacks NSIntMapKeyCallBacks; /*DEPRECATED*/
GS_EXPORT const NSMapTableKeyCallBacks NSNonOwnedPointerMapKeyCallBacks;
GS_EXPORT const NSMapTableKeyCallBacks NSNonOwnedPointerOrNullMapKeyCallBacks;
GS_EXPORT const NSMapTableKeyCallBacks NSNonRetainedObjectMapKeyCallBacks;
GS_EXPORT const NSMapTableKeyCallBacks NSObjectMapKeyCallBacks;
GS_EXPORT const NSMapTableKeyCallBacks NSOwnedPointerMapKeyCallBacks;
GS_EXPORT const NSMapTableValueCallBacks NSIntegerMapValueCallBacks;
GS_EXPORT const NSMapTableValueCallBacks NSIntMapValueCallBacks; /*DEPRECATED*/
GS_EXPORT const NSMapTableValueCallBacks NSNonOwnedPointerMapValueCallBacks;
GS_EXPORT const NSMapTableValueCallBacks NSNonRetainedObjectMapValueCallBacks;
GS_EXPORT const NSMapTableValueCallBacks NSObjectMapValueCallBacks;
GS_EXPORT const NSMapTableValueCallBacks NSOwnedPointerMapValueCallBacks;

GS_EXPORT NSMapTable *
NSCreateMapTable(NSMapTableKeyCallBacks keyCallBacks,
                 NSMapTableValueCallBacks valueCallBacks,
                 NSUInteger capacity);

GS_EXPORT NSMapTable *
NSCreateMapTableWithZone(NSMapTableKeyCallBacks keyCallBacks,
                         NSMapTableValueCallBacks valueCallBacks,
                         NSUInteger capacity,
                         NSZone *zone);

GS_EXPORT NSMapTable *
NSCopyMapTableWithZone(NSMapTable *table, NSZone *zone);

GS_EXPORT void
NSFreeMapTable(NSMapTable *table);

GS_EXPORT void
NSResetMapTable(NSMapTable *table);

GS_EXPORT BOOL
NSCompareMapTables(NSMapTable *table1, NSMapTable *table2);

GS_EXPORT NSUInteger
NSCountMapTable(NSMapTable *table);

GS_EXPORT BOOL
NSMapMember(NSMapTable *table,
            const void *key,
            void **originalKey,
            void **value);

GS_EXPORT void *
NSMapGet(NSMapTable *table, const void *key);

GS_EXPORT void
NSEndMapTableEnumeration(NSMapEnumerator *enumerator);

GS_EXPORT NSMapEnumerator
NSEnumerateMapTable(NSMapTable *table);

GS_EXPORT BOOL
NSNextMapEnumeratorPair(NSMapEnumerator *enumerator,
                        void **key,
                        void **value);

GS_EXPORT NSArray *
NSAllMapTableKeys(NSMapTable *table);

GS_EXPORT NSArray *
NSAllMapTableValues(NSMapTable *table);

GS_EXPORT void
NSMapInsert(NSMapTable *table, const void *key, const void *value);

GS_EXPORT void *
NSMapInsertIfAbsent(NSMapTable *table, const void *key, const void *value);

GS_EXPORT void
NSMapInsertKnownAbsent(NSMapTable *table,
                       const void *key,
                       const void *value);

GS_EXPORT void
NSMapRemove(NSMapTable *table, const void *key);

GS_EXPORT NSString *NSStringFromMapTable (NSMapTable *table);

#if	defined(__cplusplus)
}
#endif

#endif /* __NSMapTable_h_GNUSTEP_BASE_INCLUDE */