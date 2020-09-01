#if	!GS_NONFRAGILE

/* Code for when we don't have non-fragile instance variables
 */

/* Start declaration of internal ivars.
 */
#define	GS_PRIVATE_INTERNAL(name) \
@interface	name ## Internal : NSObject \
{ \
@public \
GS_##name##_IVARS; \
} \
@end \
@implementation	name ## Internal \
@end

/* Create holder for internal ivars.
 */
#define	GS_CREATE_INTERNAL(name) \
if (nil == _internal) { _internal = [name ## Internal new]; }

/* Destroy holder for internal ivars.
 */
#define	GS_DESTROY_INTERNAL(name) \
if (nil != _internal) { [_internal release]; _internal = nil; }

/* Create a new copy of the current object's internal class and place
 * it in the destination instance.  This produces a bitwise copy, and you
 * may wish to perform further action to deepen the copy after using this
 * macro.
 * Use this only where D is a new copy of the current instance.
 */
#define	GS_COPY_INTERNAL(D,Z) (D)->_internal = NSCopyObject(_internal, 0, (Z));

/* Checks to see if internal instance variables exist ... use in -dealloc if
 * there is any chance that the instance is being deallocated before they
 * were created.
 */
#define	GS_EXISTS_INTERNAL	(nil == _internal ? NO : YES)

#undef	internal
#define	internal	((GSInternal*)_internal)
#undef	GSIVar
#define	GSIVar(X,Y)	(((GSInternal*)((X)->_internal))->Y)

#else	/* GS_NONFRAGILE */

/* We have support for non-fragile ivars
 */

#define	GS_PRIVATE_INTERNAL(name) 

#define	GS_CREATE_INTERNAL(name)

#define	GS_DESTROY_INTERNAL(name)

#define	GS_COPY_INTERNAL(D,Z)

#define	GS_EXISTS_INTERNAL	YES

/* Define constant to reference internal ivars.
 */
#undef	internal
#define	internal	self
#undef	GSIVar
#define	GSIVar(X,Y)	((X)->Y)

#endif	/* GS_NONFRAGILE */


