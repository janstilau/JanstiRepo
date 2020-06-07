#import "common.h"
#import	"NSConcretePointerFunctions.h"

static Class	abstractClass = Nil;
static Class	concreteClass = Nil;

@implementation NSPointerFunctions

+ (id) allocWithZone: (NSZone*)zone
{
  if (self == abstractClass)
    {
      return (id) NSAllocateObject(concreteClass, 0, zone);
    }
  return [super allocWithZone: zone];
}

+ (void) initialize
{
  if (abstractClass == nil)
    {
      abstractClass = [NSPointerFunctions class];
      concreteClass = [NSConcretePointerFunctions class];
    }
}

+ (id) pointerFunctionsWithOptions: (NSPointerFunctionsOptions)options
{
  return AUTORELEASE([[self alloc] initWithOptions: options]);
}

- (id) copyWithZone: (NSZone*)zone
{
  return NSCopyObject(self, 0, zone);
}

- (id) initWithOptions: (NSPointerFunctionsOptions)options
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (void* (*)(const void *item,
  NSUInteger (*size)(const void *item), BOOL shouldCopy)) acquireFunction
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (NSString *(*)(const void *item)) descriptionFunction
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (NSUInteger (*)(const void *item,
  NSUInteger (*size)(const void *item))) hashFunction
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (BOOL (*)(const void *item1, const void *item2,
  NSUInteger (*size)(const void *item))) isEqualFunction
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (void (*)(const void *item,
  NSUInteger (*size)(const void *item))) relinquishFunction
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (void) setAcquireFunction: (void* (*)(const void *item,
  NSUInteger (*size)(const void *item), BOOL shouldCopy))func
{
  [self subclassResponsibility: _cmd];
}

- (void) setDescriptionFunction: (NSString *(*)(const void *item))func
{
  [self subclassResponsibility: _cmd];
}

- (void) setHashFunction: (NSUInteger (*)(const void *item,
  NSUInteger (*size)(const void *item)))func
{
  [self subclassResponsibility: _cmd];
}

- (void) setIsEqualFunction: (BOOL (*)(const void *item1, const void *item2,
  NSUInteger (*size)(const void *item)))func
{
  [self subclassResponsibility: _cmd];
}

- (void) setRelinquishFunction: (void (*)(const void *item,
  NSUInteger (*size)(const void *item))) func
{
  [self subclassResponsibility: _cmd];
}

- (void) setSizeFunction: (NSUInteger (*)(const void *item))func
{
  [self subclassResponsibility: _cmd];
}

- (void) setUsesStrongWriteBarrier: (BOOL)flag
{
  [self subclassResponsibility: _cmd];
}

- (void) setUsesWeakReadAndWriteBarriers: (BOOL)flag
{
  [self subclassResponsibility: _cmd];
}

- (NSUInteger (*)(const void *item)) sizeFunction
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (BOOL) usesStrongWriteBarrier
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (BOOL) usesWeakReadAndWriteBarriers
{
  [self subclassResponsibility: _cmd];
  return 0;
}

@end

