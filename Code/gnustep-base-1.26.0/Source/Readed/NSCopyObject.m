#import "common.h"

/**
 * This funcion have no memory control code. What 's its purpose.
 */

NSObject *NSCopyObject(NSObject *anObject, NSUInteger extraBytes, NSZone *zone)
{
  Class	c = object_getClass(anObject);
  id copy = NSAllocateObject(c, extraBytes, zone);

  memcpy(copy, anObject, class_getInstanceSize(c) + extraBytes);
  return copy;
}
