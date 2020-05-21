#ifndef _GNUstep_H_NSControl
#define _GNUstep_H_NSControl
#import <GNUstepBase/GSVersionMacros.h>

// for NSWritingDirection
#import <AppKit/NSParagraphStyle.h>
#import <AppKit/NSView.h>

@class NSString;
@class NSNotification;
@class NSFormatter;

@class NSCell;
@class NSFont;
@class NSEvent;
@class NSTextView;

@interface NSControl : NSView
{
    // Attributes
    NSInteger _tag;
    id _cell; // id so compiler wont complain too much for subclasses
    BOOL _ignoresMultiClick;
}

//
// Setting the Control's Cell 
//
+ (Class)cellClass;
+ (void)setCellClass:(Class)factoryId;
- (id)cell;
- (void)setCell:(NSCell *)aCell;

//
// Enabling and Disabling the Control 
//
- (BOOL)isEnabled;
- (void)setEnabled:(BOOL)flag;

//
// Identifying the Selected Cell 
//
- (id)selectedCell;
- (NSInteger)selectedTag;

//
// Setting the Control's Value 
//
- (void) setDoubleValue: (double)aDouble;
- (double) doubleValue;

- (void) setFloatValue: (float)aFloat;
- (float) floatValue;

- (void) setIntValue: (int)anInt;
- (int) intValue;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)
- (NSInteger) integerValue;
- (void) setIntegerValue: (NSInteger)anInt;
- (void) takeIntegerValueFrom: (id)sender;
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_10, GS_API_LATEST)
- (NSSize) sizeThatFits: (NSSize)size;
#endif

- (void) setStringValue: (NSString *)aString;
- (NSString *) stringValue;

- (void) setObjectValue: (id)anObject;
- (id) objectValue;

- (void) setNeedsDisplay;

//
// Interacting with Other Controls 
//
- (void) takeDoubleValueFrom: (id)sender;
- (void) takeFloatValueFrom: (id)sender;
- (void) takeIntValueFrom: (id)sender;
- (void) takeStringValueFrom: (id)sender;
- (void) takeObjectValueFrom: (id)sender;

//
// Formatting Text 
//
- (NSTextAlignment)alignment;
- (NSFont *)font;
- (void)setAlignment:(NSTextAlignment)mode;
- (void)setFont:(NSFont *)fontObject;
- (void)setFloatingPointFormat:(BOOL)autoRange
                          left:(NSUInteger)leftDigits
                         right:(NSUInteger)rightDigits;
#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (void)setFormatter:(NSFormatter*)newFormatter;
- (id)formatter;
#endif
#if OS_API_VERSION(MAC_OS_X_VERSION_10_4, GS_API_LATEST)
- (NSWritingDirection)baseWritingDirection;
- (void)setBaseWritingDirection:(NSWritingDirection)direction;
#endif

//
// Managing the Field Editor 
//
- (BOOL)abortEditing;
- (NSText *)currentEditor;
- (void)validateEditing;

//
// Resizing the Control 
//
- (void)calcSize;
- (void)sizeToFit;

//
// Displaying the Control and Cell 
//
- (void)drawCell:(NSCell *)aCell;
- (void)drawCellInside:(NSCell *)aCell;
- (void)selectCell:(NSCell *)aCell;
- (void)updateCell:(NSCell *)aCell;
- (void)updateCellInside:(NSCell *)aCell;

//
// Target and Action 
//
- (SEL)action;
- (BOOL)isContinuous;
- (BOOL)sendAction:(SEL)theAction
                to:(id)theTarget;
- (NSInteger)sendActionOn:(NSInteger)mask;
- (void)setAction:(SEL)aSelector;
- (void)setContinuous:(BOOL)flag;
- (void)setTarget:(id)anObject;
- (id)target;

//
// Attributed string handling
//
#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (NSAttributedString *)attributedStringValue;
- (void)setAttributedStringValue:(NSAttributedString *)attribStr;
#endif 

//
// Assigning a Tag 
//
- (void)setTag:(NSInteger)anInt;
- (NSInteger)tag;

//
// Activation
//
- (void)performClick:(id)sender;
#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (BOOL)refusesFirstResponder;
- (void)setRefusesFirstResponder:(BOOL)flag;
#endif

//
// Tracking the Mouse 
//
- (void)mouseDown:(NSEvent *)theEvent;
- (BOOL)ignoresMultiClick;
- (void)setIgnoresMultiClick:(BOOL)flag;

@end

APPKIT_EXPORT NSString *NSControlTextDidBeginEditingNotification;
APPKIT_EXPORT NSString *NSControlTextDidEndEditingNotification;
APPKIT_EXPORT NSString *NSControlTextDidChangeNotification;

//
// Methods Implemented by the Delegate
//
@protocol NSControlTextEditingDelegate <NSObject>
#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST) && GS_PROTOCOLS_HAVE_OPTIONAL
@optional
#else
@end
@interface NSObject (NSControlTextEditingDelegate)
#endif
- (BOOL) control: (NSControl *)control  isValidObject:(id)object;

- (BOOL) control: (NSControl *)control
textShouldBeginEditing: (NSText *)fieldEditor;

- (BOOL) control: (NSControl *)control
textShouldEndEditing: (NSText *)fieldEditor;

- (BOOL) control: (NSControl *)control 
didFailToFormatString: (NSString *)string
errorDescription: (NSString *)error;

- (void) control: (NSControl *)control 
didFailToValidatePartialString: (NSString *)string
errorDescription: (NSString *)error;

#if OS_API_VERSION(GS_API_MACOSX, GS_API_LATEST)
- (BOOL) control: (NSControl *)control 
        textView: (NSTextView *)textView
doCommandBySelector: (SEL)command;

- (NSArray *) control: (NSControl *)control 
             textView: (NSTextView *)textView
          completions: (NSArray *)words
  forPartialWordRange: (NSRange)charRange
  indexOfSelectedItem: (int *)index;
#endif

@end

@interface NSObject (NSControlDelegate)
- (void) controlTextDidBeginEditing: (NSNotification *)aNotification;
- (void) controlTextDidEndEditing: (NSNotification *)aNotification;
- (void) controlTextDidChange: (NSNotification *)aNotification;
@end

#endif // _GNUstep_H_NSControl
