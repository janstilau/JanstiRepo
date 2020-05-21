#ifndef __NSAffineTransform_h_GNUSTEP_BASE_INCLUDE
#define __NSAffineTransform_h_GNUSTEP_BASE_INCLUDE
#import <GNUstepBase/GSVersionMacros.h>

#import <Foundation/NSObject.h>
#import <Foundation/NSGeometry.h>

typedef	struct {
  CGFloat	m11;
  CGFloat	m12;
  CGFloat	m21;
  CGFloat	m22;
  CGFloat	tX;
  CGFloat	tY;
} NSAffineTransformStruct;

@interface NSAffineTransform : NSObject <NSCopying, NSCoding>
{
#if GS_EXPOSE(NSAffineTransform)
@private
  NSAffineTransformStruct	_matrix;
  BOOL _isIdentity;	// special case: A=D=1 and B=C=0
  BOOL _isFlipY;	// special case: A=1 D=-1 and B=C=0
  BOOL _pad1 GS_UNUSED_IVAR;
  BOOL _pad2 GS_UNUSED_IVAR;
#endif
}

+ (NSAffineTransform*) transform;
- (void) appendTransform: (NSAffineTransform*)aTransform;
- (id) initWithTransform: (NSAffineTransform*)aTransform;
- (void) invert;
- (void) prependTransform: (NSAffineTransform*)aTransform;
- (void) rotateByDegrees: (CGFloat)angle;
- (void) rotateByRadians: (CGFloat)angleRad;
- (void) scaleBy: (CGFloat)scale;
- (void) scaleXBy: (CGFloat)scaleX yBy: (CGFloat)scaleY;
- (void) setTransformStruct: (NSAffineTransformStruct)val;
- (NSPoint) transformPoint: (NSPoint)aPoint;
- (NSSize) transformSize: (NSSize)aSize;
- (NSAffineTransformStruct) transformStruct;
- (void) translateXBy: (CGFloat)tranX yBy: (CGFloat)tranY;
@end

#endif /* __NSAffineTransform_h_GNUSTEP_BASE_INCLUDE */
