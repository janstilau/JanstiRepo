# line 1 "GSConcreteValueTemplate.m"	/* So gdb knows which file we are in */
/* This file should be run through a preprocessor with the macro TYPE_ORDER
   defined to a number from 0 to 4 corresponding to each value type */
#if TYPE_ORDER == 0
@interface GSNonretainedObjectValue : NSValue
{
  id data;
}
@end
#  define GSTemplateValue	GSNonretainedObjectValue
#  define TYPE_METHOD	nonretainedObjectValue
#  define TYPE_NAME	id
#elif TYPE_ORDER == 1
@interface GSPointValue : NSValue
{
  NSPoint data;
}
@end
#  define GSTemplateValue	GSPointValue
#  define TYPE_METHOD	pointValue
#  define TYPE_NAME	NSPoint
#elif TYPE_ORDER == 2
@interface GSPointerValue : NSValue
{
  void *data;
}
@end
#  define GSTemplateValue	GSPointerValue
#  define TYPE_METHOD	pointerValue
#  define TYPE_NAME	void *
#elif TYPE_ORDER == 3
#  define GSTemplateValue	GSRangeValue
@interface GSRangeValue : NSValue
{
  NSRange data;
}
@end
#  define TYPE_METHOD	rangeValue
#  define TYPE_NAME	NSRange
#elif TYPE_ORDER == 4
@interface GSRectValue : NSValue
{
  NSRect data;
}
@end
#  define GSTemplateValue	GSRectValue
#  define TYPE_METHOD	rectValue
#  define TYPE_NAME	NSRect
#elif TYPE_ORDER == 5
@interface GSSizeValue : NSValue
{
  NSSize data;
}
@end
#  define GSTemplateValue	GSSizeValue
#  define TYPE_METHOD	sizeValue
#  define TYPE_NAME	NSSize
#endif

@implementation GSTemplateValue

+ (void) initialize
{
  /*
   * Ensure that the version encoded is that used by the abstract class.
   */
  [self setVersion: [super version]];
}

// Allocating and Initializing

- (id) initWithBytes: (const void *)value
	    objCType: (const char *)type
{
  typedef __typeof__(data) _dt;
  self = [super init];
  data = *(_dt *)value;
  return self;
}

// Accessing Data
- (void) getValue: (void *)value
{
  NSUInteger	size;
  if (!value)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Cannot copy value into NULL buffer"];
	/* NOT REACHED */
    }
  NSGetSizeAndAlignment([self objCType], 0, &size);
  memcpy(value, &data, size);
}

- (BOOL) isEqual: (id)other
{
  if (other != nil && GSObjCIsInstance(other) == YES
    && GSObjCIsKindOf(object_getClass(other), object_getClass(self)))
    {
      return [self isEqualToValue: other];
    }
  return NO;
}

- (BOOL) isEqualToValue: (NSValue*)aValue
{
  typedef __typeof__(data) _dt;

  if (aValue != nil && GSObjCIsInstance(aValue) == YES
    && GSObjCIsKindOf(object_getClass(aValue), object_getClass(self)))
    {
      _dt	val = [aValue TYPE_METHOD];
#if TYPE_ORDER == 0
      return [data isEqual: val];
#elif TYPE_ORDER == 1
      if (data.x == val.x && data.y == val.y)
	return YES;
      else
	return NO;
#elif TYPE_ORDER == 2
      if (data == val)
	return YES;
      else
	return NO;
#elif TYPE_ORDER == 3
      if (data.location == val.location
	&& data.length == val.length)
	return YES;
      else
	return NO;
#elif TYPE_ORDER == 4
      if (data.origin.x == val.origin.x && data.origin.y == val.origin.y
	&& data.size.width == val.size.width
	&& data.size.height == val.size.height)
	return YES;
      else
	return NO;
#elif TYPE_ORDER == 5
      if (data.width == val.width && data.height == val.height)
	return YES;
      else
	return NO;
#endif
    }
  return NO;
}

- (NSUInteger) hash
{
#if TYPE_ORDER == 0
  return [data hash];
#elif TYPE_ORDER == 1
  union {
    double d;
    unsigned char c[sizeof(double)];
  } val;
  NSUInteger	hash = 0;
  unsigned int	i;

  val.d = data.x + data.y;
  for (i = 0; i < sizeof(double); i++)
    hash += val.c[i];
  return hash;
#elif TYPE_ORDER == 2
  return (NSUInteger)(uintptr_t)data;
#elif TYPE_ORDER == 3
  return (data.length ^ data.location);
#elif TYPE_ORDER == 4
  union {
    double d;
    unsigned char c[sizeof(double)];
  } val;
  NSUInteger	hash = 0;
  unsigned int	i;

  val.d = data.origin.x + data.origin.y + data.size.width + data.size.height;
  for (i = 0; i < sizeof(double); i++)
    hash += val.c[i];
  return hash;
#elif TYPE_ORDER == 5
  union {
    double d;
    unsigned char c[sizeof(double)];
  } val;
  NSUInteger	hash = 0;
  unsigned int	i;

  val.d = data.width + data.height;
  for (i = 0; i < sizeof(double); i++)
    hash += val.c[i];
  return hash;
#endif
}

- (const char *)objCType
{
  typedef __typeof__(data) _dt;
  return @encode(_dt);
}

- (TYPE_NAME)TYPE_METHOD
{
  return data;
}

- (NSString *) description
{
#if TYPE_ORDER == 0
  return [NSString stringWithFormat: @"{object = %p;}", data];
#elif TYPE_ORDER == 1
  return NSStringFromPoint(data);
#elif TYPE_ORDER == 2
  return [NSString stringWithFormat: @"{pointer = %p;}", data];
#elif TYPE_ORDER == 3
  return NSStringFromRange(data);
#elif TYPE_ORDER == 4
  return NSStringFromRect(data);
#elif TYPE_ORDER == 5
  return NSStringFromSize(data);
#endif
}

// NSCoding
- (void) encodeWithCoder: (NSCoder*)coder
{
#if	TYPE_ORDER == 0
  [NSException raise: NSInternalInconsistencyException
	      format: @"Attempt to encode a non-retained object"];
#elif	TYPE_ORDER == 2
  [NSException raise: NSInternalInconsistencyException
	      format: @"Attempt to encode a pointer to void object"];
#else
  [super encodeWithCoder: coder];
#endif
}

@end
#undef GSTemplateValue
#undef TYPE_METHOD
#undef TYPE_NAME
