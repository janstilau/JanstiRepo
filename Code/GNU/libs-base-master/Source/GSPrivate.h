#ifndef _GSPrivate_h_
#define _GSPrivate_h_

#include <errno.h>

#import "Foundation/NSBundle.h"
#import "Foundation/NSError.h"

@class	_GSInsensitiveDictionary;
@class	_GSMutableInsensitiveDictionary;

@class	NSNotification;

#if ( (__GNUC__ > 3 || (__GNUC__ == 3 && __GNUC_MINOR__ >= 3) ) && HAVE_VISIBILITY_ATTRIBUTE )
#define GS_ATTRIB_PRIVATE __attribute__ ((visibility("internal")))
#else
#define GS_ATTRIB_PRIVATE
#endif

/* Absolute Gregorian date for NSDate reference date Jan 01 2001
 *
 *  N = 1;                 // day of month
 *  N = N + 0;             // days in prior months for year
 *  N = N +                // days this year
 *    + 365 * (year - 1)   // days in previous years ignoring leap days
 *    + (year - 1)/4       // Julian leap days before this year...
 *    - (year - 1)/100     // ...minus prior century years...
 *    + (year - 1)/400     // ...plus prior years divisible by 400
 */
#define GREGORIAN_REFERENCE 730486

NSTimeInterval   GSPrivateTimeNow() GS_ATTRIB_PRIVATE;

#include "GNUstepBase/GSObjCRuntime.h"

#include "Foundation/NSArray.h"

#ifdef __GNUSTEP_RUNTIME__
struct objc_category;
typedef struct objc_category* Category;
#endif

@interface GSArray : NSArray
{
@public
  id		*_contents_array;
  unsigned	_count;
}
@end

@interface GSMutableArray : NSMutableArray
{
@public
  id		*_contents_array;
  unsigned	_count;
  unsigned	_capacity;
  int		_grow_factor;
  unsigned long		_version;
    /*
     _version 这个东西, 没有真正的用到, 不过, 王振的数据结构里面, 不变的 iterator 里面用到了一个相似的概念. 记录当前容器的版本号.
     */
}
@end

@interface GSPlaceholderArray : NSArray
{
}
@end

#include "Foundation/NSString.h"

/**
 * Macro to manage memory for chunks of code that need to work with
 * arrays of items.  Use this to start the block of code using
 * the array and GS_ENDITEMBUF() to end it.  The idea is to ensure that small
 * arrays are allocated on the stack (for speed), but large arrays are
 * allocated from the heap (to avoid stack overflow).
 */
#if __GNUC__ > 3 && !defined(__clang__)
__attribute__((unused)) static void GSFreeTempBuffer(void **b)
{
  if (NULL != *b) free(*b);
}
#  define	GS_BEGINITEMBUF(P, S, T) { \
  T _ibuf[GS_MAX_OBJECTS_FROM_STACK];\
  T *P = _ibuf;\
  __attribute__((cleanup(GSFreeTempBuffer))) void *_base = 0;\
  if (S > GS_MAX_OBJECTS_FROM_STACK)\
    {\
      _base = malloc((S) * sizeof(T));\
      P = _base;\
    }
#  define	GS_BEGINITEMBUF2(P, S, T) { \
  T _ibuf2[GS_MAX_OBJECTS_FROM_STACK];\
  T *P = _ibuf2;\
  __attribute__((cleanup(GSFreeTempBuffer))) void *_base2 = 0;\
  if (S > GS_MAX_OBJECTS_FROM_STACK)\
    {\
      _base2 = malloc((S) * sizeof(T));\
      P = _base2;\
    }
#else
/* Make minimum size of _ibuf 1 to avoid compiler warnings.
 */
#  define	GS_BEGINITEMBUF(P, S, T) { \
  T _ibuf[(S) > 0 && (S) <= GS_MAX_OBJECTS_FROM_STACK ? (S) : 1]; \
  T *_base = ((S) <= GS_MAX_OBJECTS_FROM_STACK) ? _ibuf \
    : (T*)malloc((S) * sizeof(T)); \
  T *(P) = _base;
#  define	GS_BEGINITEMBUF2(P, S, T) { \
  T _ibuf2[(S) > 0 && (S) <= GS_MAX_OBJECTS_FROM_STACK ? (S) : 1]; \
  T *_base2 = ((S) <= GS_MAX_OBJECTS_FROM_STACK) ? _ibuf2 \
    : (T*)malloc((S) * sizeof(T)); \
  T *(P) = _base2;
#endif

/**
 * Macro to manage memory for chunks of code that need to work with
 * arrays of items.  Use GS_BEGINITEMBUF() to start the block of code using
 * the array and this macro to end it.
 */
#if __GNUC__ > 3 && !defined(__clang__)
# define	GS_ENDITEMBUF() }
# define	GS_ENDITEMBUF2() }
#else
#  define	GS_ENDITEMBUF() \
  if (_base != _ibuf) \
    free(_base); \
  }
#  define	GS_ENDITEMBUF2() \
  if (_base2 != _ibuf2) \
    free(_base2); \
  }
#endif

/**
 * Macro to manage memory for chunks of code that need to work with
 * arrays of objects.  Use this to start the block of code using
 * the array and GS_ENDIDBUF() to end it.  The idea is to ensure that small
 * arrays are allocated on the stack (for speed), but large arrays are
 * allocated from the heap (to avoid stack overflow).
 */
#define	GS_BEGINIDBUF(P, S) GS_BEGINITEMBUF(P, S, id * objects = extracted(_base);
