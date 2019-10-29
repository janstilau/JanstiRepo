#ifndef _GNUstep_H_NSViewController
#define _GNUstep_H_NSViewController
#import <GNUstepBase/GSVersionMacros.h>

#import <AppKit/NSNibDeclarations.h>
#import <AppKit/NSResponder.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)

@class NSArray, NSBundle, NSPointerArray, NSView;

@interface NSViewController : NSResponder
{
@private
  NSString            *_nibName;
  NSBundle            *_nibBundle;
  id                   _representedObject;
  NSString            *_title;
  IBOutlet NSView     *view;
  NSArray             *_topLevelObjects;
  NSPointerArray      *_editors;
  id                   _autounbinder;
  NSString            *_designNibBundleIdentifier;
  struct ___vcFlags 
    {
      unsigned int nib_is_loaded:1;
      unsigned int RESERVED:31;
    } _vcFlags;
  id                   _reserved;
}

- (id)initWithNibName:(NSString *)nibNameOrNil 
               bundle:(NSBundle *)nibBundleOrNil;

- (void)setRepresentedObject:(id)representedObject;
- (id)representedObject;

- (void)setTitle:(NSString *)title;
- (NSString *)title;

- (void)setView:(NSView *)aView;
- (NSView *)view;
- (void)loadView;

- (NSString *)nibName;
- (NSBundle *)nibBundle;
@end

#endif // OS_API_VERSION
#endif /* _GNUstep_H_NSViewController */
