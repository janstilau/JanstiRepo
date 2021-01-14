#import "common.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSPathUtilities.h"
#import "Foundation/NSSet.h"
#import "GNUstepBase/NSBundle+GNUstepBase.h"

@implementation NSBundle(GNUstepBase)

// In NSBundle.m
+ (NSString *) pathForLibraryResource: (NSString *)name
                               ofType: (NSString *)ext
                          inDirectory: (NSString *)bundlePath
{
    NSString	*path = nil;
    NSString	*bundle_path = nil;
    NSArray	*paths;
    NSBundle	*bundle;
    NSEnumerator	*enumerator;
    
    /* Gather up the paths */
    paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                NSAllDomainsMask, YES);
    
    enumerator = [paths objectEnumerator];
    while ((path == nil) && (bundle_path = [enumerator nextObject]))
    {
        bundle = [self bundleWithPath: bundle_path];
        path = [bundle pathForResource: name
                                ofType: ext
                           inDirectory: bundlePath];
    }
    
    return path;
}

@end


