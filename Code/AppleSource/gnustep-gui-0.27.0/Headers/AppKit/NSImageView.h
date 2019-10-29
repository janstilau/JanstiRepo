#ifndef _GNUstep_H_NSImageView
#define _GNUstep_H_NSImageView
#import <GNUstepBase/GSVersionMacros.h>

#import <AppKit/NSControl.h>
#import <AppKit/NSImageCell.h>

@interface NSImageView : NSControl
{
    id _target;
    SEL _action;
    struct GSImageViewFlagsType {
        // total 32 bits.  30 bits left.
        unsigned allowsCutCopyPaste: 1;
        unsigned initiatesDrag: 1;
    } _ivflags;
}

- (NSImage *)image;
- (void)setImage:(NSImage *)image;

- (NSImageAlignment)imageAlignment;
- (void)setImageAlignment:(NSImageAlignment)align;
- (NSImageScaling)imageScaling;
- (void)setImageScaling:(NSImageScaling)scaling;
- (NSImageFrameStyle)imageFrameStyle;
- (void)setImageFrameStyle:(NSImageFrameStyle)style;
- (void)setEditable:(BOOL)flag;
- (BOOL)isEditable;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_3, GS_API_LATEST)
- (BOOL)animates;
- (void)setAnimates:(BOOL)flag;
#endif
#if OS_API_VERSION(MAC_OS_X_VERSION_10_4, GS_API_LATEST)
- (BOOL)allowsCutCopyPaste;
- (void)setAllowsCutCopyPaste:(BOOL)flag;
#endif

@end

#if OS_API_VERSION(GS_API_NONE, GS_API_NONE)
// 
// Methods that are GNUstep extensions
//
@interface NSImageView (GNUstep)
- (BOOL)initiatesDrag;
- (void)setInitiatesDrag: (BOOL)flag;
@end
#endif
#endif /* _GNUstep_H_NSImageView */
