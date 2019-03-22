#import "common.h"

#define	EXPOSE_NSValueTransformer_IVARS	1
#import "Foundation/NSData.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSException.h"
#import "Foundation/NSArchiver.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSValueTransformer.h"
#import "GNUstepBase/GSLock.h"

@interface NSNegateBooleanTransformer : NSValueTransformer
@end

@interface NSIsNilTransformer : NSValueTransformer
@end

@interface NSIsNotNilTransformer : NSValueTransformer
@end

@interface NSUnarchiveFromDataTransformer : NSValueTransformer
@end


@implementation NSValueTransformer

// non-abstract methods

static NSMutableDictionary *registry = nil;
static GSLazyLock *lock = nil;

+ (void) initialize
{
  if (lock == nil)
    {
      NSValueTransformer	*t;

      lock = [GSLazyLock new];
      [[NSObject leakAt: &lock] release];
      registry = [[NSMutableDictionary alloc] init];
      [[NSObject leakAt: &registry] release];

      t = [NSNegateBooleanTransformer new];
      [self setValueTransformer: t
		        forName: NSNegateBooleanTransformerName];
      RELEASE(t);

      t = [NSIsNilTransformer new];
      [self setValueTransformer: t
		        forName: NSIsNilTransformerName];
      RELEASE(t);

      t = [NSIsNotNilTransformer new];
      [self setValueTransformer: t
		        forName: NSIsNotNilTransformerName];
      RELEASE(t);

      t = [NSUnarchiveFromDataTransformer new];
      [self setValueTransformer: t
		        forName: NSUnarchiveFromDataTransformerName];
      RELEASE(t);
    }
}

+ (void) setValueTransformer: (NSValueTransformer *)transformer
		     forName: (NSString *)name
{
  [lock lock];
  [registry setObject: transformer forKey: name];
  [lock unlock];
}

+ (NSValueTransformer *) valueTransformerForName: (NSString *)name
{
  NSValueTransformer	*transformer;

  [lock lock];
  transformer = [registry objectForKey: name];
  IF_NO_GC([transformer retain];)

  if (transformer == nil)
    {
      Class transformerClass = NSClassFromString(name);

      if (transformerClass != Nil 
        && [transformerClass isSubclassOfClass: [NSValueTransformer class]])
        {
          transformer = [[transformerClass alloc] init];

          [registry setObject: transformer forKey: name];
        }
    }

  [lock unlock];
  return AUTORELEASE(transformer);
}

+ (NSArray *) valueTransformerNames
{
  NSArray	*names;

  [lock lock];
  names = [registry allKeys];
  [lock unlock];
  return names;
}

+ (BOOL) allowsReverseTransformation
{
  [self subclassResponsibility: _cmd];
  return NO;
}

+ (Class) transformedValueClass
{
  return [self subclassResponsibility: _cmd];
}

- (id) reverseTransformedValue: (id)value
{
  if ([[self class] allowsReverseTransformation] == NO)
    {
      [NSException raise: NSGenericException
      		  format: @"[%@] is not reversible",
	NSStringFromClass([self class])];
    }
  return [self transformedValue: value];
}

- (id) transformedValue: (id)value
{
  return [self subclassResponsibility: _cmd];
}

@end

// builtin transformers

@implementation NSNegateBooleanTransformer

+ (BOOL) allowsReverseTransformation
{
  return YES;
}

+ (Class) transformedValueClass
{
  return [NSNumber class];
}

- (id) reverseTransformedValue: (id) value
{
  return [NSNumber numberWithBool: [value boolValue] ? NO : YES];
}

- (id) transformedValue: (id)value
{
  return [NSNumber numberWithBool: [value boolValue] ? NO : YES];
}

@end

@implementation NSIsNilTransformer

+ (BOOL) allowsReverseTransformation
{
  return NO;
}

+ (Class) transformedValueClass
{
  return [NSNumber class];
}

- (id) transformedValue: (id)value
{
  return [NSNumber numberWithBool: (value == nil) ? YES : NO];
}

@end

@implementation NSIsNotNilTransformer

+ (BOOL) allowsReverseTransformation
{
  return NO;
}

+ (Class) transformedValueClass
{
  return [NSNumber class];
}

- (id) transformedValue: (id)value
{
  return [NSNumber numberWithBool: (value != nil) ? YES : NO];
}

@end

@implementation NSUnarchiveFromDataTransformer

+ (BOOL) allowsReverseTransformation
{
  return YES;
}

+ (Class) transformedValueClass
{
  return [NSData class];
}

- (id) reverseTransformedValue: (id)value
{
  return [NSArchiver archivedDataWithRootObject: value];
}

- (id) transformedValue: (id)value
{
  return [NSUnarchiver unarchiveObjectWithData: value];
}

@end
