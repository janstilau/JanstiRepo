#import "common.h"
#import "NSCallBacks.h"

/**** Type, Constant, and Macro Definitions **********************************/

/**** Function Implementations ***********************************************/

/** For `int's **/

NSUInteger
_NS_int_hash(void *table, void* i)
{
  return (uintptr_t)i;
}

BOOL
_NS_int_is_equal(void *table, void* i, void* j)
{
  return (i == j) ? YES : NO;
}

void
_NS_int_retain(void *table, void* i)
{
  return;
}

void
_NS_int_release(void *table, void* i)
{
  return;
}

NSString *
_NS_int_describe(void *table, void* i)
{
  return [NSString stringWithFormat: @"%d", (int)(intptr_t)i];
}

/** For owned `void *' **/

NSUInteger
_NS_owned_void_p_hash(void *table, void *p)
{
  /* P may be aligned, so we need to compensate. */
  return ((uintptr_t)p)/4;
}

BOOL
_NS_owned_void_p_is_equal(void *table, void *p, void *q)
{
  return (p == q) ? YES : NO;
}

void
_NS_owned_void_p_retain(void *table, void *p)
{
  return;
}

void
_NS_owned_void_p_release(void *table, void *p)
{
  if (p != 0)
    free(p);
  return;
}

NSString *
_NS_owned_void_p_describe(void *table, void *p)
{
  return [NSString stringWithFormat: @"%#"PRIxPTR, (NSUInteger)p];
}

/** For non-retained Objective-C objects **/

NSUInteger
_NS_non_retained_id_hash(void *table, id <NSObject> o)
{
  return [o hash];
}

BOOL
_NS_non_retained_id_is_equal(void *table, id <NSObject> o, id <NSObject> p)
{
  return [o isEqual: p];
}

void
_NS_non_retained_id_retain(void *table, id <NSObject> o)
{
  return;
}

void
_NS_non_retained_id_release(void *table, id <NSObject> o)
{
  return;
}

NSString *
_NS_non_retained_id_describe(void *table, id <NSObject> o)
{
  return [o description];
}

/** For(retainable) objects **/

NSUInteger
_NS_id_hash(void *table, id <NSObject> o)
{
  return [o hash];
}

BOOL
_NS_id_is_equal(void *table, id <NSObject> o, id <NSObject> p)
{
  return [o isEqual: p];
}

void
_NS_id_retain(void *table, id <NSObject> o)
{
  IF_NO_GC(RETAIN(o));
  return;
}

void
_NS_id_release(void *table, id <NSObject> o)
{
  RELEASE(o);
  return;
}

NSString *
_NS_id_describe(void *table, id <NSObject> o)
{
  return [o description];
}


/** For(non-owned) `void *' **/

NSUInteger
_NS_non_owned_void_p_hash(void *table, void *p)
{
  return ((uintptr_t)p)/4;
}

BOOL
_NS_non_owned_void_p_is_equal(void *table, void *p, void *q)
{
  return (p == q) ? YES : NO;
}

void
_NS_non_owned_void_p_retain(void *table, void *p)
{
  return;
}

void
_NS_non_owned_void_p_release(void *table, void *p)
{
  return;
}

NSString *
_NS_non_owned_void_p_describe(void *table, void *p)
{
  return [NSString stringWithFormat: @"%0"PRIxPTR, (NSUInteger)p];
}

/** For pointers to structures and `int *' **/

NSUInteger
_NS_int_p_hash(void *table, int *p)
{
  return ((uintptr_t)p)/4;
}

BOOL
_NS_int_p_is_equal(void *table, int *p, int *q)
{
  return (p == q) ? YES : NO;
}

void
_NS_int_p_retain(void *table, int *p)
{
  return;
}

void
_NS_int_p_release(void *table, int *p)
{
  return;
}

NSString *
_NS_int_p_describe(void *table, int *p)
{
  /* Is this useful? */
  return [NSString stringWithFormat: @"%d(%#"PRIxPTR")", *p, (NSUInteger)p];
}
