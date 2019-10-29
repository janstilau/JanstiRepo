#import <Foundation/NSArray.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSString.h>
#import "AppKit/NSKeyValueBinding.h"
#import "AppKit/NSNib.h"
#import "AppKit/NSView.h"
#import "AppKit/NSViewController.h"


@implementation NSViewController

- (id)initWithNibName:(NSString *)nibNameOrNil 
               bundle:(NSBundle *)nibBundleOrNil
{
    self = [super init];
    if (self == nil)
        return nil;
    
    ASSIGN(_nibName, nibNameOrNil);
    ASSIGN(_nibBundle, nibBundleOrNil);
    
    return self;
}

- (void)setRepresentedObject:(id)representedObject
{
    ASSIGN(_representedObject, representedObject);
}

- (id)representedObject
{
    return _representedObject;
}

- (void)setTitle:(NSString *)title
{
    ASSIGN(_title, title);
}

- (NSString *)title
{
    return _title;
}

- (NSView *)view
{
    if (view == nil && !_vcFlags.nib_is_loaded)
    {
        [self loadView];
    }
    return view;
}

- (void)setView:(NSView *)aView
{
    if (view != aView)
    {
        ASSIGN(view, aView);
    }
}

- (void)loadView
{
    NSNib *nib;
    
    if (_vcFlags.nib_is_loaded || ([self nibName] == nil))
    {
        return;
    }
    
    nib = [[NSNib alloc] initWithNibNamed: [self nibName]
                                   bundle: [self nibBundle]];
    if ((nib != nil) && [nib instantiateNibWithOwner: self
                                     topLevelObjects: &_topLevelObjects])
    {
        _vcFlags.nib_is_loaded = YES;
        // FIXME: Need to resolve possible retain cycles here
    }
    else
    {
        if (_nibName != nil)
        {
            NSLog(@"%@: could not load nib named %@.nib",
                  [self class], _nibName);
        }
    }
    RETAIN(_topLevelObjects);
    RELEASE(nib);
}

- (NSString *)nibName
{
    return _nibName;
}

- (NSBundle *)nibBundle
{
    return _nibBundle;
}

- (id) initWithCoder: (NSCoder *)aDecoder
{
    self = [super initWithCoder: aDecoder];
    if (!self)
    {
        return nil;
    }
    
    if ([aDecoder allowsKeyedCoding])
    {
        NSView *aView = [aDecoder decodeObjectForKey: @"NSView"];
        [self setView: aView];
    }
    else
    {
        NSView *aView;
        
        [aDecoder decodeValueOfObjCType: @encode(id) at: &aView];
        [self setView: aView];
    }
    return self;
}

- (void) encodeWithCoder: (NSCoder *)aCoder
{
    [super encodeWithCoder: aCoder];
    
    if ([aCoder allowsKeyedCoding])
    {
        [aCoder encodeObject: [self view] forKey: @"NSView"];
    }
    else
    {
        [aCoder encodeObject: [self view]];
    }
}
@end

@implementation NSViewController (NSEditorRegistration)
- (void) objectDidBeginEditing: (id)editor
{
    // Add editor to _editors
}

- (void) objectDidEndEditing: (id)editor
{
    // Remove editor from _editors
}

@end

@implementation NSViewController (NSEditor)
- (void)commitEditingWithDelegate:(id)delegate 
                didCommitSelector:(SEL)didCommitSelector
                      contextInfo:(void *)contextInfo
{
    // Loop over all elements of _editors
    id editor = nil;
    BOOL res = [self commitEditing];
    
    if (delegate && [delegate respondsToSelector: didCommitSelector])
    {
        void (*didCommit)(id, SEL, id, BOOL, void*);
        
        didCommit = (void (*)(id, SEL, id, BOOL, void*))[delegate methodForSelector:
                                                         didCommitSelector];
        didCommit(delegate, didCommitSelector, editor, res, contextInfo);
    }
    
}

- (BOOL)commitEditing
{
    // Loop over all elements of _editors
    [self notImplemented: _cmd];
    
    return NO;
}

- (void)discardEditing
{
    // Loop over all elements of _editors
    [self notImplemented: _cmd];
}

@end
