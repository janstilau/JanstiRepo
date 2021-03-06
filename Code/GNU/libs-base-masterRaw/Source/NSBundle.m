#define	EXPOSE_NSBundle_IVARS	1
#import "common.h"
#include "objc-load.h"
#import "Foundation/NSBundle.h"
#import "Foundation/NSException.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSNull.h"
#import "Foundation/NSProcessInfo.h"
#import "Foundation/NSUserDefaults.h"
#import "Foundation/NSNotification.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSMapTable.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSFileManager.h"
#import "Foundation/NSPathUtilities.h"
#import "Foundation/NSData.h"
#import "Foundation/NSURL.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSSet.h"
#import "GNUstepBase/NSString+GNUstepBase.h"
#import "GNUstepBase/NSTask+GNUstepBase.h"

#import "GSPrivate.h"

/* Constants */
NSString * const NSBundleDidLoadNotification = @"NSBundleDidLoadNotification";
NSString * const NSShowNonLocalizedStrings = @"NSShowNonLocalizedStrings";
NSString * const NSLoadedClasses = @"NSLoadedClasses";

static NSFileManager *manager()
{
    static NSFileManager	*mgr = nil;
    
    if (mgr == nil)
    {
        mgr = RETAIN([NSFileManager defaultManager]);
    }
    return mgr;
}

static NSDictionary     *langAliases = nil;
static NSDictionary     *langCanonical = nil;

/* Map a language name to any alternative versions.   This function should
 * return an array of alternative language/localisation directory names in
 * the preferred order of precedence (ie resources in the directories named
 * earlier in the array are to be preferred to those in directories named
 * later).
 * We should support regional language specifications (such as en-GB)
 * as our first priority, and then fall back to the more general names.
 * NB. Also handle the form  like en-GB_US (English language, British dialect,
 * in the United States region).
 */
static NSArray *
altLang(NSString *full)
{
    NSMutableArray        *a = nil;
    
    if (nil != full)
    {
        NSString  *alias = nil;
        NSString  *canon = nil;
        NSString  *lang = nil;
        NSString  *dialect = nil;
        NSString  *region = nil;
        NSRange   r;
        
        alias = [langAliases objectForKey: full];
        if (nil == alias)
        {
            canon = [langCanonical objectForKey: full];
            if (nil != canon)
            {
                alias = [langAliases objectForKey: canon];
            }
            if (nil == alias)
            {
                alias = full;
            }
        }
        canon = [langCanonical objectForKey: alias];
        if (nil == canon)
        {
            canon = [langCanonical objectForKey: full];
            if (nil == canon)
            {
                canon = full;
            }
        }
        
        if ((r = [canon rangeOfString: @"-"]).length > 1)
        {
            dialect = [canon substringFromIndex: NSMaxRange(r)];
            lang = [canon substringToIndex: r.location];
            if ((r = [dialect rangeOfString: @"_"]).length > 1)
            {
                region = [dialect substringFromIndex: NSMaxRange(r)];
                dialect = [dialect substringToIndex: r.location];
            }
        }
        else if ((r = [canon rangeOfString: @"_"]).length > 1)
        {
            region = [canon substringFromIndex: NSMaxRange(r)];
            lang = [canon substringToIndex: r.location];
        }
        else
        {
            lang = canon;
        }
        
        a = [NSMutableArray arrayWithCapacity: 5];
        if (nil != dialect && nil != region)
        {
            [a addObject: [NSString stringWithFormat: @"%@-%@_%@",
                           lang, dialect, region]];
        }
        if (nil != dialect)
        {
            [a addObject: [NSString stringWithFormat: @"%@-%@",
                           lang, dialect]];
        }
        if (nil != region)
        {
            [a addObject: [NSString stringWithFormat: @"%@_%@",
                           lang, region]];
        }
        [a addObject: lang];
        if (NO == [a containsObject: alias])
        {
            [a addObject: alias];
        }
    }
    return a;
}

static NSLock *pathCacheLock = nil;
static NSMutableDictionary *pathCache = nil;

@interface NSObject (PrivateFrameworks)

+ (NSString*) frameworkVersion;
+ (NSString**) frameworkClasses;

@end

typedef enum {
    NSBUNDLE_BUNDLE = 1,
    NSBUNDLE_APPLICATION,
    NSBUNDLE_FRAMEWORK,
    NSBUNDLE_LIBRARY // 静态库, 应该嵌入到主可执行文件里面了.
} bundle_t;

/* Class variables - We keep track of all the bundles */
static NSBundle		*_mainBundle = nil;
static NSMapTable	*_pathBundleMap = NULL;
static NSMapTable	*_classFrameworkMap = NULL; // key 是 class, value 是 framework, 通过类来查找 Bundle.
static NSMapTable	*_IdentifierBundleMap = NULL;

/* Store the working directory at startup */
static NSString		*_launchDirectory = nil;

static NSString		*_base_version = @"1";

/*
 * An empty strings file table for use when localization files can't be found.
 */
static NSDictionary	*_emptyTable = nil;

/* When we are linking in an object file, GSPrivateLoadModule calls our
 callback routine for every Class and Category loaded.  The following
 variable stores the bundle that is currently doing the loading so we know
 where to store the class names.
 */
static NSBundle		*_loadingBundle = nil;
static NSBundle		*_gnustep_bundle = nil;
static NSRecursiveLock	*load_lock = nil; // 在访问全局资源的时候, 使用这个 load_lock
static BOOL		_strip_after_loading = NO;

/* List of framework linked in the _loadingBundle */
static NSMutableArray	*_loadingFrameworks = nil;
static NSString         *_currentFrameworkName = nil;

static NSString	*gnustep_target_dir =
#ifdef GNUSTEP_TARGET_DIR
@GNUSTEP_TARGET_DIR;
#else
nil;
#endif
static NSString	*gnustep_target_cpu =
#ifdef GNUSTEP_TARGET_CPU
@GNUSTEP_TARGET_CPU;
#else
nil;
#endif
static NSString	*gnustep_target_os =
#ifdef GNUSTEP_TARGET_OS
@GNUSTEP_TARGET_OS;
#else
nil;
#endif
static NSString	*library_combo =
#ifdef LIBRARY_COMBO
@LIBRARY_COMBO;
#else
nil;
#endif


/*
 * Try to find the absolute path of an executable.
 * Search all the directoried in the PATH.
 * The atLaunch flag determines whether '.' is considered to be
 * the  current working directory or the working directory at the
 * time when the program was launched (technically the directory
 * at the point when NSBundle was first used ... so programs must
 * use NSBundle *before* changing their working directories).
 */
static NSString*
AbsolutePathOfExecutable(NSString *path, BOOL atLaunch)
{
    if (NO == [path isAbsolutePath])
    {
        NSFileManager	*mgr = manager();
        NSDictionary	*env;
        NSString		*pathlist;
        NSString		*prefix;
        id		patharr;
        NSString		*result = nil;
        
        env = [[NSProcessInfo processInfo] environment];
        pathlist = [env objectForKey: @"PATH"];
        
        /* Windows 2000 and perhaps others have "Path" not "PATH" */
        if (pathlist == nil)
        {
            pathlist = [env objectForKey: @"Path"];
        }
        patharr = [pathlist componentsSeparatedByString: @":"];
        /* Add . if not already in path */
        if ([patharr indexOfObject: @"."] == NSNotFound)
        {
            patharr = AUTORELEASE([patharr mutableCopy]);
            [patharr addObject: @"."];
        }
        patharr = [patharr objectEnumerator];
        while (nil != (prefix = [patharr nextObject]))
        {
            if ([prefix isEqual: @"."])
            {
                if (atLaunch == YES)
                {
                    prefix = _launchDirectory;
                }
                else
                {
                    prefix = [mgr currentDirectoryPath];
                }
            }
            prefix = [prefix stringByAppendingPathComponent: path];
            if ([mgr isExecutableFileAtPath: prefix])
            {
                result = [prefix stringByStandardizingPath];
                break;
            }
        }
        path = result;
    }
    path = [path stringByResolvingSymlinksInPath];
    path = [path stringByStandardizingPath];
    return path;
}

/*
 * Return the path to this executable.
 */
NSString *
GSPrivateExecutablePath()
{
    static NSString	*executablePath = nil;
    static BOOL		beenHere = NO;
    
    if (beenHere == NO)
    {
        [load_lock lock];
        if (beenHere == NO)
        {
            if (executablePath == nil || [executablePath length] == 0)
            {
                executablePath
                = [[[NSProcessInfo processInfo] arguments] objectAtIndex: 0];
            }
            if (NO == [executablePath isAbsolutePath])
            {
                executablePath = AbsolutePathOfExecutable(executablePath, YES);
            }
            else
            {
                executablePath = [executablePath stringByResolvingSymlinksInPath];
                executablePath = [executablePath stringByStandardizingPath];
            }
            IF_NO_GC([executablePath retain];)
            beenHere = YES;
        }
        [load_lock unlock];
    }
    return executablePath;
}

// 通过 path, 读取里面的文件列表.
// 内设缓存机制.
// 因为内设缓存机制, 所有的读取资源的行为, 都应该由该函数触发.
static NSArray *
bundle_directory_readable(NSString *path)
{
    NSArray	*found;
    
    [pathCacheLock lock];
    found = [[[pathCache objectForKey: path] retain] autorelease];
    [pathCacheLock unlock];
    if (nil == found)
    {
        NSFileManager	*mgr = manager();
        
        found = [mgr directoryContentsAtPath: path];
        if (nil == found)
        {
            found = [NSNull null];
        }
        [pathCacheLock lock];
        [pathCache setObject: found forKey: path];
        [pathCacheLock unlock];
    }
    if ((id)[NSNull null] == found)
    {
        found = nil;
    }
    return (NSArray*)found;
}

/* Get the object file that should be located in the bundle of the same name */
// 从 Bundle 路径下, 寻找 executable 指定的可执行文件名.
static NSString *
bundle_object_name(NSString *bundlePath, NSString* executable)
{
    NSString *path = bundlePath;
    NSFileManager	*mgr = manager();
    NSString	*name, *path0, *path1, *path2;
    
    if (executable)
    {
        NSString	*exepath;
        
        name = [executable lastPathComponent];
        exepath = [executable stringByDeletingLastPathComponent];
        if ([exepath isEqualToString: @""] == NO)
        {
            if ([exepath isAbsolutePath] == YES)
                path = exepath;
            else
                path = [path stringByAppendingPathComponent: exepath];
        }
    }
    else
    {
        name = [[path lastPathComponent] stringByDeletingPathExtension];
        path = [path stringByDeletingLastPathComponent];
    }
    path0 = [path stringByAppendingPathComponent: name];
    path = [path stringByAppendingPathComponent: gnustep_target_dir];
    path1 = [path stringByAppendingPathComponent: name];
    path = [path stringByAppendingPathComponent: library_combo];
    path2 = [path stringByAppendingPathComponent: name];
    
    if ([mgr isReadableFileAtPath: path2] == YES)
        return path2;
    else if ([mgr isReadableFileAtPath: path1] == YES)
        return path1;
    else if ([mgr isReadableFileAtPath: path0] == YES)
        return path0;
    return path0;
}

/* Construct a path from components */
// 最终, inoutlist 里面, 是 path, subdir, lang 这三者组合出来的绝对路径.
static void
addBundlePath(NSMutableArray *inoutList,
              NSArray *contents,
              NSString *path,
              NSString *subdir,
              NSString *lang)
{
    // contents 目前是 path 目录下所有的文件信息.
    if (nil == contents) { return; }
    if (nil != subdir)
    {
        //        NSString *path = @"tmp/scratch";
        //        NSArray *pathComponents = [path pathComponents];
        //        结果是 tmp, scratch. pathComponents 会按照分隔符, 进行路径分段.
        NSEnumerator      *e = [[subdir pathComponents] objectEnumerator];
        NSString          *subdirComponent;
        
        // 这里, 这个循环, 就是将 content 变化为 path/subdir 目录下的文件列表信息.
        // 如果这个过程中, subdir 指定的资源没有找到, 就退出. inoutList 里面就不会填入信息.
        // 结束后, path 就是最终 subdir 指定的绝对路径, content 就是最终路径下的文件列表.
        while ((subdirComponent = [e nextObject]) != nil)
        {
            if (NO == [contents containsObject: subdirComponent])
            { // 如果 contents 没有 subdirComponent, 那就是 subdir 指定的子路径, 没有在父目录下.
                return;
            }
            path = [path stringByAppendingPathComponent: subdirComponent];
            if (nil == (contents = bundle_directory_readable(path)))
            {
                return;
            }
        }
    }
    
    if (nil == lang)
    {
        // 如果, 没有语言设置, 直接将最终的绝对路径, 填入到输出参数中.
        [inoutList addObject: path];
    }
    else
    {
        NSEnumerator      *enumerator = [altLang(lang) objectEnumerator];
        NSString          *alt;
        
        /* Add each language specific subdirectory in order.
         */
        // 这里和 subdir 的行为类似, lang 可能对应好几个版本资源. 所以, altLang(lang) 会返回所有可能的子目录.
        while (nil != (alt = [enumerator nextObject]))
        {
            alt = [alt stringByAppendingPathExtension: @"lproj"];
            if (YES == [contents containsObject: alt])
            {
                alt = [path stringByAppendingPathComponent: alt];
                if (nil != (contents = bundle_directory_readable(alt)))
                {
                    [inoutList addObject: alt];
                }
            }
        }
    }
}

/* Try to locate name framework in standard places
 which are like /Library/Frameworks/(name).framework */
static inline NSString *
_find_framework(NSString *name)
{
    NSArray	*paths;
    NSFileManager *file_mgr = manager();
    NSString	*file_name;
    NSString	*file_path;
    NSString	*path;
    NSEnumerator	*enumerator;
    
    NSCParameterAssert(name != nil);
    
    file_name = [name stringByAppendingPathExtension: @"framework"];
    paths = NSSearchPathForDirectoriesInDomains(GSFrameworksDirectory,
                                                NSAllDomainsMask,YES);
    
    enumerator = [paths objectEnumerator];
    while ((path = [enumerator nextObject]))
    {
        file_path = [path stringByAppendingPathComponent: file_name];
        
        if ([file_mgr fileExistsAtPath: file_path] == YES)
        {
            return file_path; // Found it!
        }
    }
    return nil;
}


/* Try to locate resources for tool name (which is this tool) in
 * standard places like xxx/Library/Tools/Resources/name */
/* This could be converted into a public +bundleForTool:
 * method.  At the moment it's only used privately
 * to locate the main bundle for this tool.
 */
static inline NSString *
_find_main_bundle_for_tool(NSString *toolName)
{
    NSArray *paths;
    NSEnumerator *enumerator;
    NSString *path;
    NSString *tail;
    NSFileManager *fm = manager();
    
    /*
     * Eliminate any base path or extensions.
     */
    toolName = [toolName lastPathComponent];
    do
    {
        toolName = [toolName stringByDeletingPathExtension];
    }
    while ([[toolName pathExtension] length] > 0);
    
    if ([toolName length] == 0)
    {
        return nil;
    }
    
    tail = [@"Tools" stringByAppendingPathComponent:
            [@"Resources" stringByAppendingPathComponent:
             toolName]];
    
    paths = NSSearchPathForDirectoriesInDomains (NSLibraryDirectory,
                                                 NSAllDomainsMask, YES);
    
    enumerator = [paths objectEnumerator];
    while ((path = [enumerator nextObject]))
    {
        BOOL isDir;
        path = [path stringByAppendingPathComponent: tail];
        
        if ([fm fileExistsAtPath: path  isDirectory: &isDir]  &&  isDir)
        {
            return path;
        }
    }
    
    return nil;
}


@implementation NSBundle (Private)

+ (NSString *) _absolutePathOfExecutable: (NSString *)path
{
    return AbsolutePathOfExecutable(path, NO);
}

/* Nicola & Mirko:
 
 Frameworks can be used in an application in two different ways:
 
 () the framework is dynamically/manually loaded, as if it were a
 bundle.  This is the easier case, because we already have the
 bundle setup with the correct path (it's the programmer's
 responsibility to find the framework bundle on disk); we get all
 information from the bundle dictionary, such as the version; we
 also create the class list when loading the bundle, as for any
 other bundle.
 
 () the framework was linked into the application.  This is much
 more difficult, because without using tricks, we have no way of
 knowing where the framework bundle (needed eg for resources) is on
 disk, and we have no way of knowing what the class list is, or the
 version.  So the trick we use in this case to work around those
 problems is that gnustep-make generates a 'NSFramework_xxx' class
 and compiles it into each framework.  By asking to the class, we
 can get the version information and the list of classes which were
 compiled into the framework.  To get the location of the framework
 on disk, we try using advanced dynamic linker features to get the
 shared object file on disk from which the NSFramework_xxx class was
 loaded.  If that doesn't work, because the dynamic linker can't
 provide this information on this platform (or maybe because the
 framework was statically linked into the application), we have a
 fallback trick :-) We look for the framework in the standard
 locations and in the main bundle.  This might fail if the framework
 is not in a standard location or there is more than one installed
 framework of the same name (and different versions?).
 
 So at startup, we scan all classes which were compiled into the
 application.  For each NSFramework_ class, we call the following
 function, which records the name of the framework, the version,
 the classes belonging to it, and tries to determine the path
 on disk to the framework bundle.
 
 Bundles (and frameworks if dynamically loaded as bundles) could
 depend on other frameworks (linked togheter on platform that
 supports this behaviour) so whenever we dynamically load a bundle,
 we need to spot out any additional NSFramework_* classes which are
 loaded, and call this method (exactly as for frameworks linked into
 the main application) to record them, and try finding the path on
 disk to those framework bundles.
 
 */
+ (NSBundle*) _addFrameworkFromClass: (Class)frameworkClass
{
    NSBundle	*bundle = nil;
    NSString	**fmClasses;
    NSString	*bundlePath = nil;
    unsigned int	len;
    const char    *frameworkClassName;
    
    if (frameworkClass == Nil)
    {
        return nil;
    }
    
    frameworkClassName = class_getName(frameworkClass);
    
    len = strlen (frameworkClassName);
    
    if (len > 12 * sizeof(char)
        && !strncmp ("NSFramework_", frameworkClassName, 12))
    {
        /* The name of the framework.  */
        NSString *name;
        
        // 缓存机制, 返回已经注册的 Bundle.
        bundle = (id)NSMapGet(_classFrameworkMap, frameworkClass);
        if (nil != bundle)
        {
            if ((id)bundle == (id)[NSNull null])
            {
                bundle = nil;
            }
            return bundle;
        }
        
        name = [NSString stringWithUTF8String: &frameworkClassName[12]];
        /* Important - gnustep-make mangles framework names to encode
         * them as ObjC class names.  Here we need to demangle them.  We
         * apply the reverse transformations in the reverse order.
         */
        name = [name stringByReplacingString: @"_1"  withString: @"+"];
        name = [name stringByReplacingString: @"_0"  withString: @"-"];
        name = [name stringByReplacingString: @"__"  withString: @"_"];
        
        /* Try getting the path to the framework using the dynamic
         * linker.  When it works it's really cool :-) This is the only
         * really universal way of getting the framework path ... we can
         * locate the framework no matter where it is on disk!
         */
        // 在这里, 就可以定位到了 Bundle 的路径了.
        bundlePath = GSPrivateSymbolPath(frameworkClass);
        
        if ([bundlePath isEqualToString: GSPrivateExecutablePath()])
        {
            /* Oops ... the NSFramework_xxx class is linked in the main
             * executable.  Maybe the framework was statically linked
             * into the application ... resort to searching the
             * framework bundle on the filesystem manually.
             */
            bundlePath = nil;
        }
        
        if (bundlePath != nil)
        {
            NSString *pathComponent;
            
            /* bundlePath should really be an absolute path; we
             * recommend you use only absolute paths in LD_LIBRARY_PATH.
             *
             * If it isn't, we try to survive the situation; we assume
             * it's relative to the launch directory.  That's how the
             * dynamic linker would have found it after all.  This is
             * fragile though, so please use absolute paths.
             */
            if ([bundlePath isAbsolutePath] == NO)
            {
                bundlePath = [_launchDirectory
                              stringByAppendingPathComponent: bundlePath];
                
            }
            
            /* Dereference symlinks, and standardize path.  This will
             * only work properly if the original bundlePath is
             * absolute.
             */
            bundlePath = [bundlePath stringByStandardizingPath];
            
            /* We now have the location of the shared library object
             * file inside the framework directory.  We need to walk up
             * the directory tree up to the top of the framework.  To do
             * so, we need to chop off the extra subdirectories, the
             * library combo and the target cpu/os if they exist.  The
             * framework and this library should match so we can use the
             * compiled-in settings.
             */
            /* library name */
            bundlePath = [bundlePath stringByDeletingLastPathComponent];
            /* library combo */
            pathComponent = [bundlePath lastPathComponent];
            if ([pathComponent isEqual: library_combo])
            {
                bundlePath = [bundlePath stringByDeletingLastPathComponent];
            }
            /* target directory */
            pathComponent = [bundlePath lastPathComponent];
            if ([pathComponent isEqual: gnustep_target_dir])
            {
                bundlePath = [bundlePath stringByDeletingLastPathComponent];
            }
            /* There are no Versions on MinGW.  So the version check is only
             * done on non-MinGW.  */
            /* version name */
            bundlePath = [bundlePath stringByDeletingLastPathComponent];
            
            pathComponent = [bundlePath lastPathComponent];
            if ([pathComponent isEqual: @"Versions"])
            {
                bundlePath = [bundlePath stringByDeletingLastPathComponent];
                pathComponent = [bundlePath lastPathComponent];
                
                if ([pathComponent isEqualToString:
                     [NSString stringWithFormat: @"%@%@",
                      name, @".framework"]])
                {
                    /* Try creating the bundle.  */
                    if (bundlePath)
                        bundle = [[self alloc] initWithPath: bundlePath];
                }
#if !defined(_WIN32)
            }
#endif
            
            /* Failed - buu - try the fallback trick.  */
            if (bundle == nil)
            {
                bundlePath = nil;
            }
        }
        
        if (bundlePath == nil)
        {
            /* NICOLA: In an ideal world, the following is just a hack
             * for when GSPrivateSymbolPath() fails!  But in real life
             * GSPrivateSymbolPath() is risky (some platforms don't
             * have it at all!), so this hack might be used a lot!  It
             * must be quite robust.  We try to look for the framework
             * in the standard GNUstep installation dirs and in the main
             * bundle.  This should be reasonably safe if the user is
             * not being too clever ... :-)
             */
            bundlePath = _find_framework(name);
            if (bundlePath == nil)
            {
                bundlePath = [[NSBundle mainBundle] pathForResource: name
                                                             ofType: @"framework"
                                                        inDirectory: @"Frameworks"];
            }
            
            /* Try creating the bundle.  */
            if (bundlePath != nil)
            {
                bundle = [[self alloc] initWithPath: bundlePath];
            }
        }
        
        [load_lock lock];
        if (bundle == nil)
        {
            NSMapInsert(_classFrameworkMap, frameworkClass, [NSNull null]);
            [load_lock unlock];
            NSWarnMLog (@"Could not find framework %@ in any standard location",
                        name);
            return nil;
        }
        else
        {
            bundle->_principalClass = frameworkClass;
            NSMapInsert(_classFrameworkMap, frameworkClass, bundle);
            [load_lock unlock];
        }
        
        bundle->_bundleType = NSBUNDLE_FRAMEWORK;
        bundle->_codeLoaded = YES;
        /* frameworkVersion is something like 'A'.  */
        bundle->_frameworkVersion = RETAIN([frameworkClass frameworkVersion]);
        bundle->_bundleClasses = RETAIN([NSMutableArray arrayWithCapacity: 2]);
        
        /* A NULL terminated list of class names - the classes contained
         in the framework.  */
        fmClasses = [frameworkClass frameworkClasses];
        
        // 这里, 将 Bundle 里面的所有的 Class 添加到 Bundle 的 _bundleClasses 数组里面.
        while (*fmClasses != NULL)
        {
            NSValue *value;
            Class    class = NSClassFromString(*fmClasses);
            
            NSMapInsert(_classFrameworkMap, class, bundle);
            value = [NSValue valueWithPointer: (void*)class];
            [bundle->_bundleClasses addObject: value];
            
            fmClasses++;
        }
        
        /* If _loadingBundle is not nil, it means we reached this point
         * while loading a bundle.  This can happen if the framework is
         * linked into the bundle (then, the dynamic linker
         * automatically drags in the framework when the bundle is
         * loaded).  But then, the classes in the framework should be
         * removed from the list of classes in the bundle. Check that
         * _loadingBundle != bundle which happens on Windows machines when
         * loading in Frameworks.
         */
        if (_loadingBundle != nil && _loadingBundle != bundle)
        {
            int i, j;
            id b = bundle->_bundleClasses;
            id l = _loadingBundle->_bundleClasses;
            
            /* The following essentially does:
             *
             * [_loadingBundle->_bundleClasses
             *  removeObjectsInArray: bundle->_bundleClasses];
             *
             * The problem with that code is isEqual: gets
             * sent to the classes, which will cause them to be
             * initialized (which should not happen.)
             */
            for (i = 0; i < [b count]; i++)
            {
                for (j = 0; j < [l count]; j++)
                {
                    if ([[l objectAtIndex: j] pointerValue]
                        == [[b objectAtIndex: i] pointerValue])
                    {
                        [l removeObjectAtIndex: j];
                    }
                }
            }
        }
    }
    return bundle;
}

+ (NSMutableArray*) _addFrameworks
{
    int                   i;
    int                   numClasses = 0;
    int                   newNumClasses;
    Class                 *classes = NULL;
    NSMutableArray        *added = [NSMutableArray arrayWithCapacity: 100];
    
    newNumClasses = objc_getClassList(NULL, 0);
    while (numClasses < newNumClasses)
    {
        numClasses = newNumClasses;
        classes = realloc(classes, sizeof(Class) * numClasses);
        newNumClasses = objc_getClassList(classes, numClasses);
    }
    
    // 这里给人的感觉是, 把 classes[i] 当做了 principle class 看待了.
    for (i = 0; i < numClasses; i++)
    {
        NSBundle  *bundle = [self _addFrameworkFromClass: classes[i]];
        if (nil != bundle)
        {
            [added addObject: bundle];
        }
    }
    free(classes);
    return added;
}

+ (NSString*) _gnustep_target_cpu
{
    return gnustep_target_cpu;
}

+ (NSString*) _gnustep_target_dir
{
    return gnustep_target_dir;
}

+ (NSString*) _gnustep_target_os
{
    return gnustep_target_os;
}

+ (NSString*) _library_combo
{
    return library_combo;
}

@end

/*
 Mirko:
 
 The gnu-runtime calls the +load method of each class before the
 _bundle_load_callback() is called and we can't provide the list of classes
 ready for this method.
 
 */

static void
_bundle_load_callback(Class theClass, struct objc_category *theCategory)
{
    const char *className;
    
    /* We never record categories - if this is a category, just do nothing.  */
    if (theCategory != 0)
    {
        return;
    }
    className = class_getName(theClass);
    
    /* Don't store the internal NSFramework_xxx class into the list of
     bundle classes, but store the linked frameworks in _loadingFrameworks  */
    if (strlen (className) > 12
        &&  !strncmp ("NSFramework_", className, 12))
    {
        if (_currentFrameworkName)
        {
            const char *frameworkName;
            
            frameworkName = [_currentFrameworkName cString];
            
            if (!strcmp(className, frameworkName))
                return;
        }
        
        [_loadingFrameworks
         addObject: [NSValue valueWithPointer: (void*)theClass]];
        return;
    }
    
    /* Store classes (but don't store categories) */
    // 这里有点全局变量的使用. 因为这是一个 C 函数.
    [(_loadingBundle)->_bundleClasses addObject:
     [NSValue valueWithPointer: (void*)theClass]];
}


@implementation NSBundle

// 初始化一些全局量

+ (void) initialize
{
    if (self == [NSBundle class])
    {
        extern const char	*GSPathHandling(const char *);
        NSAutoreleasePool *pool = [NSAutoreleasePool new];
        NSString          *file;
        const char	*mode;
        NSDictionary	*env;
        NSString		*str;
        
        /* Ensure we do 'right' path handling while initializing core paths.
         */
        mode = GSPathHandling("right");
        _emptyTable = [NSDictionary new];
        
        /* Create basic mapping dictionaries for bootstrapping and
         * for use if the full dictionaries can't be loaded from the
         * gnustep-base library resource bundle.
         */
        langAliases = [[NSDictionary alloc] initWithObjectsAndKeys:
                       @"Dutch", @"nl",
                       @"English", @"en",
                       @"Esperanto", @"eo",
                       @"French", @"fr",
                       @"German", @"de",
                       @"Hungarian", @"hu",
                       @"Italian", @"it",
                       @"Korean", @"ko",
                       @"Russian", @"ru",
                       @"Slovak", @"sk",
                       @"Spanish", @"es",
                       @"TraditionalChinese", @"zh",
                       @"Ukrainian", @"uk",
                       nil];
        langCanonical = [[NSDictionary alloc] initWithObjectsAndKeys:
                         @"de", @"German",
                         @"de", @"ger",
                         @"de", @"deu",
                         @"en", @"English",
                         @"en", @"eng",
                         @"ep", @"Esperanto",
                         @"ep", @"epo",
                         @"ep", @"epo",
                         @"fr", @"French",
                         @"fr", @"fra",
                         @"fr", @"fre",
                         @"hu", @"Hungarian",
                         @"hu", @"hun",
                         @"it", @"Italian",
                         @"it", @"ita",
                         @"ko", @"Korean",
                         @"ko", @"kir",
                         @"nl", @"Dutch",
                         @"nl", @"dut",
                         @"nl", @"nld",
                         @"ru", @"Russian",
                         @"ru", @"rus",
                         @"sk", @"Slovak",
                         @"sk", @"slo",
                         @"sk", @"slk",
                         @"sp", @"Spanish",
                         @"sp", @"spa",
                         @"uk", @"Ukrainian",
                         @"uk", @"ukr",
                         @"zh", @"TraditionalChinese",
                         @"zh", @"chi",
                         @"zh", @"zho",
                         nil];
        
        _pathBundleMap = NSCreateMapTable(NSObjectMapKeyCallBacks,
                                    NSNonOwnedPointerMapValueCallBacks, 0);
        _classFrameworkMap = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                                              NSNonOwnedPointerMapValueCallBacks, 0);
        _IdentifierBundleMap = NSCreateMapTable(NSObjectMapKeyCallBacks,
                                         NSNonOwnedPointerMapValueCallBacks, 0);
        
        pathCacheLock = [NSLock new];
        [pathCacheLock setName: @"pathCacheLock"];
        pathCache = [NSMutableDictionary new];
        
        /* Need to make this recursive since both mainBundle and
         * initWithPath: want to lock the thread.
         */
        load_lock = [NSRecursiveLock new];
        [load_lock setName: @"load_lock"];
        env = [[NSProcessInfo processInfo] environment];
        _launchDirectory = RETAIN([manager() currentDirectoryPath]);
        _gnustep_bundle = RETAIN([self bundleForLibrary: @"gnustep-base"
                                                version: _base_version]);
        
        /* The Locale aliases map converts canonical names to old-style names
         */
        file = [_gnustep_bundle pathForResource: @"Locale"
                                         ofType: @"aliases"
                                    inDirectory: @"Languages"];
        if (file != nil)
        {
            NSDictionary  *d;
            
            d = [[NSDictionary alloc] initWithContentsOfFile: file];
            if ([d count] > 0)
            {
                ASSIGN(langAliases, d);
            }
            [d release];
        }
        
        /* The Locale canonical map converts old-style names to ISO 639 names
         * and converts ISO 639-2 names to the preferred ISO 639-1 names where
         * an ISO 639-1 name exists.
         */
        file = [_gnustep_bundle pathForResource: @"Locale"
                                         ofType: @"canonical"
                                    inDirectory: @"Languages"];
        if (file != nil)
        {
            NSDictionary  *d;
            
            d = [[NSDictionary alloc] initWithContentsOfFile: file];
            if ([d count] > 0)
            {
                ASSIGN(langCanonical, d);
            }
            [d release];
        }
        
        
        // 前面都是一些全局值的设置. 这里会调用 Frame 的注册工作.
        // 真正的 Frame, 是加载器完成的, 这里是把 frame 里面的信息抽取出来, 放到 Bundle 的概念模型下.
        [self _addFrameworks];
        GSPathHandling(mode);
        [pool release];
        [self registerAtExit];
    }
}

/*
 就是遍历 _pathBundleMap 里面的数据, 将不是 framework 类型的 buncle 提取出来返回.
 */
+ (NSArray *) allBundles
{
    /*
     就是遍历 _pathBundleMap, 找到所有的类型不是 Framework 的 Bundle
     */
    return [NSArray array];
}

+ (NSArray *) allFrameworks
{
    /*
     就是遍历 _pathBundleMap, 找到所有的类型是 Framework 的 Bundle
     */
    return [NSArray array];
}

/*
 * The NSBundle object corresponding to the bundle directory that contains the current executable. This method may return a valid bundle object even for unbundled apps. It may also return nil if the bundle object could not be created, so always check the return value.
 * The main bundle lets you access the resources in the same directory as the currently running executable. For a running app, the main bundle offers access to the app’s bundle directory. For code running in a framework, the main bundle offers access to the framework’s bundle directory.
 * 简单的来说, mainBundle 返回的是, 可执行文件所在目录的 Bundle, 有了这个 Bundle, 就可以访问 App 主要的资源文件了.
 */
+ (NSBundle *) mainBundle
{
    [load_lock lock];
    if (_mainBundle) {
        [load_lock unlock];
        return _mainBundle;
    }
    // 中间很多的代码, 最终效果就是找到可执行文件所在的路径, 然后生成对应的 Bundle , 存储到一个全局量里面.
    NSString *path = @"";
    _mainBundle = [self alloc];
    _mainBundle = [_mainBundle initWithPath: path];
    [load_lock unlock];
    return _mainBundle;
}

// 通过 aClass 到 _classFrameworkMap 找到对应的 Bundle.
// 如果, 没有找到, 那么找到 aClass 对应的路径, 生成对应的 Bundle.
+ (NSBundle *) bundleForClass: (Class)aClass
{
    if (!aClass) { return nil; }
    void		*key;
    NSBundle	*bundle;
    NSMapEnumerator enumerate;
    
    [load_lock lock];
    
    // 首先, 通过 缓存哈希表, 查找一些 Class 对应的 Bundle 对象.
    bundle = (NSBundle *)NSMapGet(_classFrameworkMap, aClass);
    if ((id)bundle == (id)[NSNull null])
    {
        [load_lock unlock];
        return nil;
    }
    
    // 如果还找不到, 直接通过 GSPrivateSymbolPath 查找一下类定义所在的路径, 然后通过这个路径找到 Bundle.
    if (nil == bundle)
    {
        /* Is it in the main bundle or a library? */
        if (!class_isMetaClass(aClass))
        {
            NSString	*lib;
            
            /*
             * Take the path to the binary containing the class and
             * convert it to the format for a library name as used for
             * obtaining a library resource bundle.
             */
            lib = GSPrivateSymbolPath(aClass);
            if ([lib isEqual: GSPrivateExecutablePath()] == YES)
            {
                lib = nil;	// In program, not library.
            }
            
            /*
             * Get the library bundle ... if there wasn't one then we
             * will check to see if it's in a newly loaded framework
             * and if not, assume the class was in the program executable
             * and return the mainBundle instead.
             */
            bundle = [NSBundle bundleForLibrary: lib];
            if (nil == bundle && [[self _addFrameworks] count] > 0)
            {
                bundle = (NSBundle *)NSMapGet(_classFrameworkMap, aClass);
                if ((id)bundle == (id)[NSNull null])
                {
                    [load_lock unlock];
                    return nil;
                }
            }
            if (nil == bundle)
            {
                bundle = [self mainBundle];
            }
            
            /*
             * Add the class to the list of classes known to be in the
             * library or executable.  We didn't find it there to start
             * with, so we know it's safe to add now.
             */
            if (bundle->_bundleClasses == nil)
            {
                bundle->_bundleClasses
                = [[NSMutableArray alloc] initWithCapacity: 2];
            }
            [bundle->_bundleClasses addObject:
             [NSValue valueWithPointer: (void*)aClass]];
        }
    }
    [load_lock unlock];
    
    return bundle;
}

// 其实, 就是按照 identifier 去全局表里面找 Bundle
+ (NSBundle*) bundleWithIdentifier: (NSString*)identifier
{
    NSBundle	*bundle = nil;
    
    [load_lock lock];
    if (_IdentifierBundleMap)
    {
        bundle = (NSBundle *)NSMapGet(_IdentifierBundleMap, identifier);
    }
    [load_lock unlock];
    return AUTORELEASE(bundle);
}

/*
    Bundle 的初始化操作.
    可以看到, Bundle 是和路径关联的, 这也体现了, Bundle 就是一个目录而已.
 */
- (id) initWithPath: (NSString*)path
{
    NSString	*identifier;
    NSBundle	*bundle;
    
    self = [super init];
    
    if (!path || [path length] == 0)
    {
        NSDebugMLog(@"No path specified for bundle");
        [self dealloc];
        return nil;
    }
    
    /*
     * Make sure we have an absolute and fully expanded path,
     * so we can manipulate it without having to worry about
     * details like that throughout the code.
     */
    
    /*
     1. make path absolute.
     */
    if ([path isAbsolutePath] == NO)
    {
        // The path to the program’s current directory.
        path = [[manager() currentDirectoryPath]
                stringByAppendingPathComponent: path];
    }
    
    /* 2. Expand any symbolic links.
     */
    path = [path stringByResolvingSymlinksInPath];
    
    /* 3. Standardize so we can be sure that cache lookup is consistent.
     */
    path = [path stringByStandardizingPath];
    
    // 经过上面的操作, path 就是一个绝对路径, 标准化的路径了.
    
    // 下面是操作全局资源, 进行加锁处理.
    [load_lock lock];
    
    // 缓存查询.
    // 这里, 体现了 OC 的好处. 可以在 构造函数里面, 更改返回的对象.
    bundle = (NSBundle *)NSMapGet(_pathBundleMap, path);
    if (bundle != nil)
    {
        IF_NO_GC([bundle retain];)
        [load_lock unlock];
        [self dealloc];
        return bundle;
    }
    [load_lock unlock];
    
    if (bundle_directory_readable(path) == nil)
    {
        if (self != _mainBundle)
        {
            [self dealloc];
            return nil;
        }
    }
    
    /* OK ... this is a new bundle ... need to insert it in the global map
     * to be found by this path so that a leter call to -bundleIdentifier
     * can work.
     */
    _path = [path copy];
    [load_lock lock];
    NSMapInsert(_pathBundleMap, _path, self);
    [load_lock unlock];
    
    // 这里, 是直接根据文件名进行的 type 的决定.
    // 应该实际的 Apple 代码里, 有更好的策略.
    if ([[[_path lastPathComponent] pathExtension] isEqual: @"framework"] == YES)
    {
        _bundleType = (unsigned int)NSBUNDLE_FRAMEWORK;
    } else {
        if (self == _mainBundle)
            _bundleType = (unsigned int)NSBUNDLE_APPLICATION;
        else
            _bundleType = (unsigned int)NSBUNDLE_BUNDLE;
    }
        
    // 如果, Bundle 的 info plist 文件里面, 设置了 identifier, 那么就缓存下来.
    identifier = [self bundleIdentifier];
    [load_lock lock];
    if (identifier != nil)
    {
        NSBundle	*bundle = (NSBundle *)NSMapGet(_IdentifierBundleMap, identifier);
        
        if (bundle != self)
        {
            if (bundle != nil)
            {
                IF_NO_GC([bundle retain];)
                [load_lock unlock];
                [self dealloc];
                return bundle;
            }
            NSMapInsert(_IdentifierBundleMap, identifier, self);
        }
    }
    [load_lock unlock];
    
    return self;
}

- (NSString*) bundlePath
{
    return _path;
}

- (NSURL*) bundleURL
{
    return [NSURL fileURLWithPath: [self bundlePath]];
}

- (Class) classNamed: (NSString *)className
{
    int     i, j;
    Class   theClass = Nil;
    
    if (!_codeLoaded)
    {
        if (self != _mainBundle && ![self load])
        {
            NSLog(@"No classes in bundle");
            return Nil;
        }
    }
    
    if (self == _mainBundle || self == _gnustep_bundle)
    {
        theClass = NSClassFromString(className);
        if (theClass && [[self class] bundleForClass: theClass] != self)
        {
            theClass = Nil;
        }
    }
    else
    {
        BOOL found = NO;
        
        theClass = NSClassFromString(className);
        [load_lock lock];
        j = [_bundleClasses count];
        
        for (i = 0; i < j  &&  found == NO; i++)
        {
            Class c = (Class)[[_bundleClasses objectAtIndex: i] pointerValue];
            
            if (c == theClass)
            {
                found = YES;
            }
        }
        [load_lock unlock];
        
        if (found == NO)
        {
            theClass = Nil;
        }
    }
    
    return theClass;
}

- (Class) principalClass
{
    NSString	*class_name;
    
    if (_principalClass)
    {
        return _principalClass;
    }
    
    if ([self load] == NO)
    {
        return Nil;
    }
    
    class_name = [[self infoDictionary] objectForKey: @"NSPrincipalClass"];
    
    if (class_name)
    {
        _principalClass = NSClassFromString(class_name);
    }
    else if (self == _gnustep_bundle)
    {
        _principalClass = [NSObject class];
    }
    // 如果, 没有该类, 那么就用第一个加载的类.
    if (_principalClass == nil)
    {
        [load_lock lock];
        if (_principalClass == nil && [_bundleClasses count] > 0)
        {
            _principalClass = (Class)[[_bundleClasses objectAtIndex: 0]
                                      pointerValue];
        }
        [load_lock unlock];
    }
    return _principalClass;
}

/**
 * Returns YES if the receiver's code is loaded, otherwise, returns NO.
 */
- (BOOL) isLoaded
{
    return _codeLoaded;
}

/*
 Dynamically loads the bundle’s executable code into a running program,
 if the code has not already been loaded.
 真正的动态库的加载, 是在 GSPrivateLoadModule 里面做的.
 Bundle 里面, 做的更多的是信息记录的事情.
 */
- (BOOL)load
{
    if (self == _mainBundle ||
        self ->_bundleType == NSBUNDLE_LIBRARY)
    {
        _codeLoaded = YES;
        return YES;
    }
    
    [load_lock lock];
    
    if (_codeLoaded == NO)
    {
        NSString       *executedFile;
        NSEnumerator   *classEnumerator;
        NSMutableArray *classNames;
        NSValue        *class;
        NSBundle       *savedLoadingBundle;
        
        /* Get the binary and set up fraework name if it is a framework.
         */
        executedFile = [self executablePath]; // 首先, 查找可执行文件路径.
        if (executedFile == nil || [executedFile length] == 0)
        {
            [load_lock unlock];
            return NO;
        }
        
        savedLoadingBundle = _loadingBundle;
        _loadingBundle = self;
        _bundleClasses = [[NSMutableArray alloc] initWithCapacity: 2];
        
        if (nil == savedLoadingBundle)
        {
            _loadingFrameworks = [[NSMutableArray alloc] initWithCapacity: 2];
        }
        
        /* This code is executed twice if a class linked in the bundle calls a
         NSBundle method inside +load (-principalClass). To avoid this we set
         _codeLoaded before loading the bundle. */
        _codeLoaded = YES;
        
        // _bundle_load_callback 里面, 会做一些填充数据的事情, 所以, 在这之前, 会修改一些全局变量.
        if (GSPrivateLoadModule(executedFile, stderr, _bundle_load_callback, 0, 0))
        {
            _codeLoaded = NO;
            _loadingBundle = savedLoadingBundle;
            if (nil == _loadingBundle)
            {
                DESTROY(_loadingFrameworks);
                DESTROY(_currentFrameworkName);
            }
            [load_lock unlock];
            return NO;
        }
        
        /* We now construct the list of bundles from frameworks linked with
         this one */
        classEnumerator = [_loadingFrameworks objectEnumerator];
        while ((class = [classEnumerator nextObject]) != nil)
        {
            [NSBundle _addFrameworkFromClass: (Class)[class pointerValue]];
        }
        
        /* After we load code from a bundle, we retain the bundle until
         we unload it (because we never unload bundles, that is
         forever).  The reason why we retain it is that we need it!
         We need it to answer calls like bundleForClass:; also, users
         normally want all loaded bundles to appear when they call
         +allBundles.  */
        IF_NO_GC([self retain];)
        
        classNames = [NSMutableArray arrayWithCapacity: [_bundleClasses count]];
        classEnumerator = [_bundleClasses objectEnumerator];
        while ((class = [classEnumerator nextObject]) != nil)
        {
            // 这里, 把 Class 和 Bundle 绑定在了一起. 使用了一个外部存储 map.
            NSMapInsert(_classFrameworkMap, class, self);
            [classNames addObject: NSStringFromClass((Class)[class pointerValue])];
        }
        
        _loadingBundle = savedLoadingBundle;
        if (nil == _loadingBundle)
        {
            DESTROY(_loadingFrameworks);
            DESTROY(_currentFrameworkName);
        }
        [load_lock unlock];
        
        [[NSNotificationCenter defaultCenter]
         postNotificationName: NSBundleDidLoadNotification
         object: self
         userInfo: [NSDictionary dictionaryWithObject: classNames
                                               forKey: NSLoadedClasses]];
        
        return YES;
    }
    [load_lock unlock];
    return YES;
}

- (oneway void) release
{
    /* We lock during release so that other threads can't grab the
     * object between us checking the reference count and deallocating.
     */
    [load_lock lock];
    if (NSDecrementExtraRefCountWasZero(self))
    {
        [self dealloc];
    }
    [load_lock unlock];
}


#pragma mark - ResourceSearch

/* This method is the backbone of the resource searching for NSBundle. It
 constructs an array of paths, where each path is a possible location
 for a resource in the bundle.  The current algorithm for searching goes:
 
 <rootPath>/Resources/<bundlePath>
 <rootPath>/Resources/<bundlePath>/<language.lproj>
 <rootPath>/<bundlePath>
 <rootPath>/<bundlePath>/<language.lproj>
 */
// 所以, Bundle 其实就是按照特定的文件结构, 进行资源的读取.
// 返回的, 是一个目录的绝对地址的列表.
+ (NSArray *) _bundleResourcePathsWithRootPath: (NSString*)rootPath
                                       subPath: (NSString*)subPath
                                  localization: (NSString*)localization
{
    NSEnumerator		*enumerate;
    NSMutableArray    *result = [NSMutableArray arrayWithCapacity: 8];
    NSString        *language = [[NSUserDefaults standardUserDefaults]
                                 stringArrayForKey: @"NSLanguages"];
    NSString        *resourcePath = [rootPath stringByAppendingPathComponent: @"Resources"];
    NSArray        *contents = bundle_directory_readable(resourcePath);
    // contents 里面, 目前存放的是 root 下 Resources 目录下的文件列表.
    addBundlePath(result, contents, resourcePath, subPath, nil);
    if (localization != nil)
    {
        addBundlePath(result, contents, resourcePath, subPath, localization);
    }
    else
    {
        /* This matches OS X behavior, which only searches languages that
         * are in the user's preference. Don't use -preferredLocalizations -
         * that would cause a recursive loop.
         */
        enumerate = [languages objectEnumerator];
        while ((language = [enumerate nextObject]))
        {
            addBundlePath(result, contents, resourcePath, subPath, language);
        }
    }
    // 下面就是读取 这两个路径下的资源了.
    //  <rootPath>/<bundlePath>
    //  <rootPath>/<bundlePath>/<language.lproj>
    resourcePath = rootPath;
    contents = bundle_directory_readable(resourcePath);
    addBundlePath(result, contents, resourcePath, subPath, nil);
    if (localization != nil)
    {
        addBundlePath(result, contents, resourcePath, subPath, localization);
    }
    else
    {
        enumerate = [languages objectEnumerator];
        while ((language = [enumerate nextObject]))
        {
            addBundlePath(result, contents, resourcePath, subPath, language);
        }
    }
    return result;
}

+ (NSString *) _pathForResource: (NSString *)name
                         ofType: (NSString *)extension
                     inRootPath: (NSString *)rootPath
                    inDirectory: (NSString *)subPath
{
    NSFileManager	*mgr = manager();
    NSString	*path;
    NSString	*file = [name copy];
    NSEnumerator	*pathlist;
    
    if ([extension length] ) {
        file = [name stringByAppendingPathExtension: extension];
    }
    
    pathlist = [[self _bundleResourcePathsWithRootPath: rootPath
                                               subPath: subPath
                                          localization: nil] objectEnumerator];
    // pathlist 是所有可能的目录的绝对地址列表.
    while ((path = [pathlist nextObject]) != nil)
    {
        // 从目录里面读取出文件信息来.
        // 如果, 文件信息里面, 有 name, extension 组合而成的资源, 并且可读. 那么就返回该路径了.
        NSArray	*paths = bundle_directory_readable(path);
        if (YES == [paths containsObject: file])
        {
            path = [path stringByAppendingPathComponent: file];
            if (YES == [mgr isReadableFileAtPath: path])
            {
                return path;
            }
        }
    }
    return nil;
}


+ (NSString *) pathForResource: (NSString *)name
                        ofType: (NSString *)extension
                   inDirectory: (NSString *)bundlePath
                   withVersion: (int)version
{
    return [self _pathForResource: name
                           ofType: extension
                       inRootPath: bundlePath
                      inDirectory: nil];
}

+ (NSString *) pathForResource: (NSString *)name
                        ofType: (NSString *)extension
                   inDirectory: (NSString *)bundlePath
{
    return [self _pathForResource: name
                           ofType: extension
                       inRootPath: bundlePath
                      inDirectory: nil];
}

+ (NSURL*) URLForResource: (NSString*)name
            withExtension: (NSString*)extension
             subdirectory: (NSString*)subpath
          inBundleWithURL: (NSURL*)bundleURL
{
    NSBundle *root = [self bundleWithURL: bundleURL];
    
    return [root URLForResource: name
                  withExtension: extension
                   subdirectory: subpath];
}

- (NSString *) pathForResource: (NSString *)name
                        ofType: (NSString *)extension
{
    return [self pathForResource: name
                          ofType: extension
                     inDirectory: nil];
}

- (NSString *) pathForResource: (NSString *)name
                        ofType: (NSString *)extension
                   inDirectory: (NSString *)subPath
{
    // 首先, 获取到自己 Bundle 的路径, 然后调用类方法, 进行统一的资源搜索
    NSString *rootPath = [self bundlePath];
    return [NSBundle _pathForResource: name
                               ofType: extension
                           inRootPath: rootPath
                          inDirectory: subPath];
}

- (NSURL *) URLForResource: (NSString *)name
             withExtension: (NSString *)extension
{
    return [self URLForResource: name
                  withExtension: extension
                   subdirectory: nil
                   localization: nil];
}

- (NSURL *) URLForResource: (NSString *)name
             withExtension: (NSString *)extension
              subdirectory: (NSString *)subpath
{
    return [self URLForResource: name
                  withExtension: extension
                   subdirectory: subpath
                   localization: nil];
}

// Url, 就是先通过 Path 搜索到信息, 然后 fileUrl 进行组建
- (NSURL *) URLForResource: (NSString *)name
             withExtension: (NSString *)extension
              subdirectory: (NSString *)subpath
              localization: (NSString *)localizationName
{
    NSString	*path;
    path = [self pathForResource: name
                          ofType: extension
                     inDirectory: subpath
                 forLocalization: localizationName];
    if (nil == path)
    {
        return nil;
    }
    return [NSURL fileURLWithPath: path];
}

// 前面的 Path, 是找到了就不找后面的了. 这里, 是所有资源, 都查找一遍, 将匹配的结果放到了数组里面返回.
+ (NSArray*) _pathsForResourcesOfType: (NSString*)extension // 扩展名限制.
                      inRootDirectory: (NSString*)bundlePath // 根据 BundlePath
                       inSubDirectory: (NSString*)subPath // SubPath 去寻找
                         localization: (NSString*)localization // 本地化限制.
{
    NSString *path;
    NSEnumerator *pathlist = [[NSBundle _bundleResourcePathsWithRootPath: bundlePath
                                                                 subPath: subPath localization: localization] objectEnumerator];
    NSMutableArray *resources = [NSMutableArray arrayWithCapacity: 2];
    BOOL allfiles = (extension == nil || [extension length] == 0);
    
    while ((path = [pathlist nextObject]))
    {
        NSEnumerator *filelist;
        NSString	*match;
        
        filelist = [bundle_directory_readable(path) objectEnumerator];
        while ((match = [filelist nextObject]))
        {
            if (allfiles || [extension isEqual: [match pathExtension]])
                [resources addObject: [path stringByAppendingPathComponent: match]];
        }
    }
    
    return resources;
}

+ (NSArray*) pathsForResourcesOfType: (NSString*)extension
                         inDirectory: (NSString*)bundlePath
{
    return [self _pathsForResourcesOfType: extension
                          inRootDirectory: bundlePath
                           inSubDirectory: nil
                             localization: nil];
}

- (NSArray *) pathsForResourcesOfType: (NSString *)extension
                          inDirectory: (NSString *)subPath
{
    return [[self class] _pathsForResourcesOfType: extension
                                  inRootDirectory: [self bundlePath]
                                   inSubDirectory: subPath
                                     localization: nil];
}

- (NSArray*) pathsForResourcesOfType: (NSString*)extension
                         inDirectory: (NSString*)subPath
                     forLocalization: (NSString*)localizationName
{
    NSArray         *paths = nil;
    NSMutableArray  *result = nil;
    NSEnumerator    *enumerator = nil;
    NSString        *path = nil;
    
    result = [NSMutableArray array];
    paths = [[self class] _pathsForResourcesOfType: extension
                                   inRootDirectory: [self bundlePath]
                                    inSubDirectory: subPath
                                      localization: localizationName];
    
    enumerator = [paths objectEnumerator];
    while ((path = [enumerator nextObject]) != nil)
    {
        /* Add all non-localized paths, plus ones in the particular localization
         (if there is one). */
        NSString  *theDir = [path stringByDeletingLastPathComponent];
        NSString  *last = [theDir lastPathComponent];
        
        if ([[last pathExtension] isEqual: @"lproj"] == NO)
        {
            [result addObject: path];
        }
        else
        {
            NSString      *lang = [last stringByDeletingPathExtension];
            NSArray       *alternatives = altLang(lang);
            
            if ([alternatives count] > 0)
            {
                [result addObject: path];
            }
        }
    }
    
    return result;
}

// 通过一个 Bundle 对象, 寻找资源.
- (NSString*) pathForResource: (NSString*)name // 名称
                       ofType: (NSString*)extension // 扩展名
                  inDirectory: (NSString*)subPath // Bundle 下的目录路径
              forLocalization: (NSString*)localizationName // 本地化.
{
    NSAutoreleasePool	*arp = [NSAutoreleasePool new];
    NSString		*result = nil;
    NSArray		*array;
    
    if ([extension length] == 0)
    {
        extension = [name pathExtension];
        if (extension != nil)
        {
            name = [name stringByDeletingPathExtension];
        }
    }
    // array 里面存的, 就是对应的文件资源了.
    array = [self pathsForResourcesOfType: extension
                              inDirectory: subPath
                          forLocalization: localizationName];
    
    if (array != nil)
    {
        NSEnumerator	*enumerator = [array objectEnumerator];
        NSString		*path;
        
        name = [name stringByAppendingPathExtension: extension];
        while ((path = [enumerator nextObject]) != nil)
        {
            NSString	*found = [path lastPathComponent];
            
            if ([found isEqualToString: name] == YES)
            {
                result = path;
                break;		// localised paths occur before non-localised
            }
        }
    }
    [result retain];
    [arp drain];
    return [result autorelease];
}

+ (NSArray *) preferredLocalizationsFromArray: (NSArray *)localizationsArray
{
    return [self preferredLocalizationsFromArray: localizationsArray
                                  forPreferences: [[NSUserDefaults standardUserDefaults]
                                                   stringArrayForKey: @"NSLanguages"]];
}

+ (NSArray *) preferredLocalizationsFromArray: (NSArray *)localizationsArray
                               forPreferences: (NSArray *)preferencesArray
{
    NSString	*locale;
    NSMutableArray	*array;
    NSEnumerator	*enumerate;
    
    array = [NSMutableArray arrayWithCapacity: 2];
    enumerate = [preferencesArray objectEnumerator];
    while ((locale = [enumerate nextObject]))
    {
        if ([localizationsArray indexOfObject: locale] != NSNotFound)
            [array addObject: locale];
    }
    /* I guess this is arbitrary if we can't find a match? */
    if ([array count] == 0 && [localizationsArray count] > 0)
        [array addObject: [localizationsArray objectAtIndex: 0]];
    return GS_IMMUTABLE(array);
}

- (NSDictionary*) localizedInfoDictionary
{
    NSString  *path;
    NSArray   *locales;
    NSString  *locale = nil;
    NSDictionary *dict = nil;
    
    locales = [self preferredLocalizations];
    if ([locales count] > 0)
        locale = [locales objectAtIndex: 0];
    path = [self pathForResource: @"Info-gnustep"
                          ofType: @"plist"
                     inDirectory: nil
                 forLocalization: locale];
    if (path)
    {
        dict = [[NSDictionary alloc] initWithContentsOfFile: path];
    }
    else
    {
        path = [self pathForResource: @"Info"
                              ofType: @"plist"
                         inDirectory: nil
                     forLocalization: locale];
        if (path)
        {
            dict = [[NSDictionary alloc] initWithContentsOfFile: path];
        }
    }
    if (nil == [dict autorelease])
    {
        dict = [self infoDictionary];
    }
    return dict;
}

- (id) objectForInfoDictionaryKey: (NSString *)key
{
    return [[self infoDictionary] objectForKey: key];
}

- (NSString*) developmentLocalization
{
    return nil;
}

// 先找到所有的语言包, 然后去除后面的扩展名后返回.
- (NSArray *) localizations
{
    NSString *locale;
    NSArray *localizations;
    NSEnumerator* enumerate;
    NSMutableArray *array = [NSMutableArray arrayWithCapacity: 2];
    
    localizations = [self pathsForResourcesOfType: @"lproj"
                                      inDirectory: nil];
    enumerate = [localizations objectEnumerator];
    while ((locale = [enumerate nextObject]))
    {
        locale = [[locale lastPathComponent] stringByDeletingPathExtension];
        [array addObject: locale];
    }
    
    return GS_IMMUTABLE(array);
}

- (NSArray *) preferredLocalizations
{
    return [NSBundle preferredLocalizationsFromArray: [self localizations]];
}

- (NSString *) localizedStringForKey: (NSString *)key
                               value: (NSString *)value
                               table: (NSString *)tableName
{
    NSDictionary	*table;
    NSString	*newString = nil;
    
    if (_localizations == nil)
        _localizations = [[NSMutableDictionary alloc] initWithCapacity: 1];
    
    if (tableName == nil || [tableName isEqualToString: @""] == YES)
    {
        tableName = @"Localizable";
        table = [_localizations objectForKey: tableName];
    }
    else if ((table = [_localizations objectForKey: tableName]) == nil
             && [@"strings" isEqual: [tableName pathExtension]] == YES)
    {
        tableName = [tableName stringByDeletingPathExtension];
        table = [_localizations objectForKey: tableName];
    }
    
    if (table == nil)
    {
        NSString	*tablePath;
        
        /*
         * Make sure we have an empty table in place in case anything
         * we do somehow causes recursion.  The recursive call will look
         * up the string in the empty table.
         */
        [_localizations setObject: _emptyTable forKey: tableName];
        
        tablePath = [self pathForResource: tableName ofType: @"strings"];
        if (tablePath != nil)
        {
            NSStringEncoding	encoding;
            NSString		*tableContent;
            NSData		*tableData;
            const unsigned char	*bytes;
            unsigned		length;
            
            tableData = [[NSData alloc] initWithContentsOfFile: tablePath];
            bytes = [tableData bytes];
            length = [tableData length];
            /*
             * A localisation file can be ...
             * UTF16 with a leading BOM,
             * UTF8 with a leading BOM,
             * or ASCII (the original standard) with \U escapes.
             */
            if (length > 2
                && ((bytes[0] == 0xFF && bytes[1] == 0xFE)
                    || (bytes[0] == 0xFE && bytes[1] == 0xFF)))
            {
                encoding = NSUnicodeStringEncoding;
            }
            else if (length > 2
                     && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF)
            {
                encoding = NSUTF8StringEncoding;
            }
            else
            {
                encoding = NSASCIIStringEncoding;
            }
            tableContent = [[NSString alloc] initWithData: tableData
                                                 encoding: encoding];
            if (tableContent == nil && encoding == NSASCIIStringEncoding)
            {
                encoding = [NSString defaultCStringEncoding];
                tableContent = [[NSString alloc] initWithData: tableData
                                                     encoding: encoding];
                if (tableContent != nil)
                {
                    NSWarnMLog (@"Localisation file %@ not in portable encoding"
                                @" so I'm using the default encoding for the current"
                                @" system, which may not display messages correctly.\n"
                                @"The file should be ASCII (using \\U escapes for unicode"
                                @" characters) or Unicode (UTF16 or UTF8) with a leading "
                                @"byte-order-marker.\n", tablePath);
                }
            }
            if (tableContent == nil)
            {
                NSWarnMLog(@"Failed to load strings file %@ - bad character"
                           @" encoding", tablePath);
            }
            else
            {
                NS_DURING
                {
                    table = [tableContent propertyListFromStringsFileFormat];
                }
                NS_HANDLER
                {
                    NSWarnMLog(@"Failed to parse strings file %@ - %@",
                               tablePath, localException);
                }
                NS_ENDHANDLER
            }
            RELEASE(tableData);
            RELEASE(tableContent);
        }
        else
        {
            NSDebugMLLog(@"NSBundle", @"Failed to locate strings file %@",
                         tableName);
        }
        /*
         * If we couldn't found and parsed the strings table, we put it in
         * the cache of strings tables in this bundle, otherwise we will just
         * be keeping the empty table in the cache so we don't keep retrying.
         */
        if (table != nil)
            [_localizations setObject: table forKey: tableName];
    }
    
    if (key == nil || (newString = [table objectForKey: key]) == nil)
    {
        NSString	*show = [[NSUserDefaults standardUserDefaults]
                             objectForKey: NSShowNonLocalizedStrings];
        if (show && [show isEqual: @"YES"])
        {
            /* It would be bad to localize this string! */
            NSLog(@"Non-localized string: %@\n", key);
            newString = [key uppercaseString];
        }
        else
        {
            newString = value;
            if (newString == nil || [newString isEqualToString: @""] == YES)
                newString = key;
        }
        if (newString == nil)
            newString = @"";
    }
    
    return newString;
}

- (NSString *) executablePath
{
    NSString *result;
    
    if (!_mainBundle)
    {
        [NSBundle mainBundle];
    }
    if (self == _mainBundle)
    {
        // 如果, 是主 Bundle, 直接找可执行路径
        return GSPrivateExecutablePath();
    }
    if (self->_bundleType == NSBUNDLE_LIBRARY)
    {
        return GSPrivateSymbolPath([self principalClass]);
    }
    
    result = [[self infoDictionary] objectForKey: @"NSExecutable"];
    if (result == nil || [result length] == 0)
    {
        result = [[self infoDictionary] objectForKey: @"CFBundleExecutable"];
        if (result == nil || [result length] == 0)
        {
            return nil;
        }
    }
    if (_bundleType == NSBUNDLE_FRAMEWORK)
    {
        /* Mangle the name before building the _currentFrameworkName,
         * which really is a class name.
         */
        NSString *mangledName = result;
        mangledName = [mangledName stringByReplacingString: @"_"
                                                withString: @"__"];
        mangledName = [mangledName stringByReplacingString: @"-"
                                                withString: @"_0"];
        mangledName = [mangledName stringByReplacingString: @"+"
                                                withString: @"_1"];
        _currentFrameworkName = RETAIN(([NSString stringWithFormat:
                                         @"NSFramework_%@",
                                         mangledName]));
    }
    else
    {
    }
    NSString *path = _path;
    // 通过 Info 里面的 executate key 找到可执行文件.
    result = bundle_object_name(path, result);
    return result;
}

- (NSURL *) executableURL
{
    return [NSURL fileURLWithPath: [self executablePath]];
}

- (NSString *) pathForAuxiliaryExecutable: (NSString *) executableName
{
    NSString  *version = _frameworkVersion;
    
    if (!version)
        version = @"Current";
    
    if (_bundleType == NSBUNDLE_FRAMEWORK)
    {
#if !defined(_WIN32)
        return [_path stringByAppendingPathComponent:
                [NSString stringWithFormat: @"Versions/%@/%@",
                 version, executableName]];
#else
        return [_path stringByAppendingPathComponent: executableName];
#endif
    }
    else
    {
        return [_path stringByAppendingPathComponent: executableName];
    }
}

- (NSURL *) URLForAuxiliaryExecutable: (NSString *) executableName
{
    return [NSURL fileURLWithPath: [self pathForAuxiliaryExecutable:
                                    executableName]];
}

- (NSString *) resourcePath
{
    if (_bundleType == NSBUNDLE_FRAMEWORK)
    {
        return [_path stringByAppendingPathComponent: @"Resources"];
    }
    else
    {
        return [_path stringByAppendingPathComponent: @"Resources"];
    }
}

- (NSURL *) resourceURL
{
    return [NSURL fileURLWithPath: [self resourcePath]];
}

- (NSDictionary *) infoDictionary
{
    NSString* path;
    
    if (_infoDict)
        return _infoDict;
    
    path = [self pathForResource: @"Info-gnustep" ofType: @"plist"];
    if (path)
    {
        _infoDict = [[NSDictionary alloc] initWithContentsOfFile: path];
    }
    else
    {
        path = [self pathForResource: @"Info" ofType: @"plist"];
        if (path)
        {
            _infoDict = [[NSDictionary alloc] initWithContentsOfFile: path];
        }
        else
        {
            _infoDict = RETAIN([NSDictionary dictionary]);
        }
    }
    return _infoDict;
}

- (NSString *) builtInPlugInsPath
{
    NSString  *version = _frameworkVersion;
    
    if (!version)
        version = @"Current";
    
    if (_bundleType == NSBUNDLE_FRAMEWORK)
    {
#if !defined(_WIN32)
        return [_path stringByAppendingPathComponent:
                [NSString stringWithFormat: @"Versions/%@/PlugIns",
                 version]];
#else
        return [_path stringByAppendingPathComponent: @"PlugIns"];
#endif
    }
    else
    {
        return [_path stringByAppendingPathComponent: @"PlugIns"];
    }
}

- (NSURL *) builtInPlugInsURL
{
    return [NSURL fileURLWithPath: [self builtInPlugInsPath]];
}

- (NSString *) privateFrameworksPath
{
    NSString  *version = _frameworkVersion;
    
    if (!version)
        version = @"Current";
    
    if (_bundleType == NSBUNDLE_FRAMEWORK)
    {
#if !defined(_WIN32)
        return [_path stringByAppendingPathComponent:
                [NSString stringWithFormat: @"Versions/%@/PrivateFrameworks",
                 version]];
#else
        return [_path stringByAppendingPathComponent: @"PrivateFrameworks"];
#endif
    }
    else
    {
        return [_path stringByAppendingPathComponent: @"PrivateFrameworks"];
    }
}

- (NSURL *) privateFrameworksURL
{
    return [NSURL fileURLWithPath: [self privateFrameworksPath]];
}

- (NSString*) bundleIdentifier
{
    return [[self infoDictionary] objectForKey: @"CFBundleIdentifier"];
}

- (unsigned) bundleVersion
{
    return _version;
}

- (void) setBundleVersion: (unsigned)version
{
    _version = version;
}

- (BOOL) unload
{
    return NO;
}
@end







@implementation NSBundle (GNUstep)

+ (NSBundle *) bundleForLibrary: (NSString *)libraryName
{
    return [self bundleForLibrary: libraryName  version: nil];
}

+ (NSBundle *) bundleForLibrary: (NSString *)libraryName
                        version: (NSString *)interfaceVersion
{
    /* Important: if you change this code, make sure to also
     * change NSUserDefault's manual gnustep-base resource
     * lookup to match.
     */
    NSArray *paths;
    NSEnumerator *enumerator;
    NSString *path;
    NSFileManager *fm = manager();
    NSRange	r;
    
    if ([libraryName length] == 0)
    {
        return nil;
    }
    /*
     * Eliminate any base path or extensions.
     */
    libraryName = [libraryName lastPathComponent];
    
#if defined(_WIN32)
    /* A dll is usually of the form 'xxx-maj_min.dll'
     * so we can extract the version info and use it.
     */
    if ([[libraryName pathExtension] isEqual: @"dll"])
    {
        libraryName = [libraryName stringByDeletingPathExtension];
        r = [libraryName rangeOfString: @"-" options: NSBackwardsSearch];
        if (r.length > 0)
        {
            NSString	*ver;
            
            ver = [[libraryName substringFromIndex: NSMaxRange(r)]
                   stringByReplacingString: @"_" withString: @"."];
            libraryName = [libraryName substringToIndex: r.location];
            if (interfaceVersion == nil)
            {
                interfaceVersion = ver;
            }
        }
    }
#elif defined(__APPLE__)
    /* A .dylib is usually of the form 'libxxx.maj.min.sub.dylib',
     * but GNUstep-make installs them with 'libxxx.dylib.maj.min.sub'.
     * For maximum compatibility with support both forms here.
     */
    if ([[libraryName pathExtension] isEqual: @"dylib"])
    {
        NSString	*s = [libraryName stringByDeletingPathExtension];
        NSArray	*a = [s componentsSeparatedByString: @"."];
        
        if ([a count] > 1)
        {
            libraryName = [a objectAtIndex: 0];
            if (interfaceVersion == nil && [a count] >= 3)
            {
                interfaceVersion = [NSString stringWithFormat: @"%@.%@",
                                    [a objectAtIndex: 1], [a objectAtIndex: 2]];
            }
        }
    }
    else
    {
        r = [libraryName rangeOfString: @".dylib."];
        if (r.length > 0)
        {
            NSString *s = [libraryName substringFromIndex: NSMaxRange(r)];
            NSArray  *a = [s componentsSeparatedByString: @"."];
            
            libraryName = [libraryName substringToIndex: r.location];
            if (interfaceVersion == nil && [a count] >= 2)
            {
                interfaceVersion = [NSString stringWithFormat: @"%@.%@",
                                    [a objectAtIndex: 0], [a objectAtIndex: 1]];
            }
        }
    }
#else
    /* A .so is usually of the form 'libxxx.so.maj.min.sub'
     * so we can extract the version info and use it.
     */
    r = [libraryName rangeOfString: @".so."];
    if (r.length > 0)
    {
        NSString	*s = [libraryName substringFromIndex: NSMaxRange(r)];
        NSArray	*a = [s componentsSeparatedByString: @"."];
        
        libraryName = [libraryName substringToIndex: r.location];
        if (interfaceVersion == nil && [a count] >= 2)
        {
            interfaceVersion = [NSString stringWithFormat: @"%@.%@",
                                [a objectAtIndex: 0], [a objectAtIndex: 1]];
        }
    }
#endif
    
    while ([[libraryName pathExtension] length] > 0)
    {
        libraryName = [libraryName stringByDeletingPathExtension];
    }
    
    /*
     * Discard leading 'lib'
     */
    if ([libraryName hasPrefix: @"lib"] == YES)
    {
        libraryName = [libraryName substringFromIndex: 3];
    }
    
    if ([libraryName length] == 0)
    {
        return nil;
    }
    
    /*
     * We expect to find the library resources in the GNUSTEP_LIBRARY domain in:
     *
     * Libraries/<libraryName>/Versions/<interfaceVersion>/Resources/
     *
     * if no <interfaceVersion> is specified, and if can't find any versioned
     * resources in those directories, we'll also accept the old unversioned
     * subdirectory:
     *
     * Libraries/Resources/<libraryName>/
     *
     */
    paths = NSSearchPathForDirectoriesInDomains (NSLibraryDirectory,
                                                 NSAllDomainsMask, YES);
    
    enumerator = [paths objectEnumerator];
    while ((path = [enumerator nextObject]) != nil)
    {
        NSBundle	*b;
        BOOL isDir;
        path = [path stringByAppendingPathComponent: @"Libraries"];
        
        if ([fm fileExistsAtPath: path  isDirectory: &isDir]  &&  isDir)
        {
            /* As a special case, if we have been asked to get the base
             * library bundle without a version, we check to see if the
             * bundle for the current version is available and use that
             * in preference to all others.
             * This lets older code (using the non-versioned api) work
             * on systems where multiple versions are installed.
             */
            if (interfaceVersion == nil
                && [libraryName isEqualToString: @"gnustep-base"])
            {
                NSString	*p;
                
                p = [[[[path stringByAppendingPathComponent: libraryName]
                       stringByAppendingPathComponent: @"Versions"]
                      stringByAppendingPathComponent: _base_version]
                     stringByAppendingPathComponent: @"Resources"];
                if ([fm fileExistsAtPath: p  isDirectory: &isDir]  &&  isDir)
                {
                    interfaceVersion = _base_version;
                }
            }
            
            if (interfaceVersion != nil)
            {
                /* We're looking for a specific version.  */
                path = [[[[path stringByAppendingPathComponent: libraryName]
                          stringByAppendingPathComponent: @"Versions"]
                         stringByAppendingPathComponent: interfaceVersion]
                        stringByAppendingPathComponent: @"Resources"];
                if ([fm fileExistsAtPath: path  isDirectory: &isDir]  &&  isDir)
                {
                    b = [self bundleWithPath: path];
                    
                    if (b != nil && b->_bundleType == NSBUNDLE_BUNDLE)
                    {
                        b->_bundleType = NSBUNDLE_LIBRARY;
                    }
                    return b;
                }
            }
            else
            {
                /* Any version will do.  */
                NSString *versionsPath;
                
                versionsPath
                = [[path stringByAppendingPathComponent: libraryName]
                   stringByAppendingPathComponent: @"Versions"];
                
                if ([fm fileExistsAtPath: versionsPath  isDirectory: &isDir]
                    && isDir)
                {
                    /* TODO: Ignore subdirectories.  */
                    NSEnumerator *fileEnumerator;
                    NSString *potentialPath;
                    
                    fileEnumerator = [fm enumeratorAtPath: versionsPath];
                    while ((potentialPath = [fileEnumerator nextObject]) != nil)
                    {
                        potentialPath = [potentialPath
                                         stringByAppendingPathComponent: @"Resources"];
                        potentialPath = [versionsPath
                                         stringByAppendingPathComponent: potentialPath];
                        if ([fm fileExistsAtPath: potentialPath
                                     isDirectory: &isDir]  &&  isDir)
                        {
                            b = [self bundleWithPath: potentialPath];
                            
                            if (b != nil && b->_bundleType == NSBUNDLE_BUNDLE)
                            {
                                b->_bundleType = NSBUNDLE_LIBRARY;
                            }
                            return b;
                        }
                    }
                }
                
                /* We didn't find anything!  For backwards
                 * compatibility, try the unversioned directory itself:
                 * we used to put library resources directly in
                 * unversioned directories such as
                 * GNUSTEP_LIBRARY/Libraries/Resources/gnustep-base/{resources
                 * here}.  This was deprecated/obsoleted on 9 March 2007
                 * when we added library resource versioning.
                 */
                {
                    NSString *oldResourcesPath;
                    
                    oldResourcesPath = [path
                                        stringByAppendingPathComponent: @"Resources"];
                    oldResourcesPath = [oldResourcesPath
                                        stringByAppendingPathComponent: libraryName];
                    if ([fm fileExistsAtPath: oldResourcesPath
                                 isDirectory: &isDir]  &&  isDir)
                    {
                        b = [self bundleWithPath: oldResourcesPath];
                        if (b != nil && b->_bundleType == NSBUNDLE_BUNDLE)
                        {
                            b->_bundleType = NSBUNDLE_LIBRARY;
                        }
                        return b;
                    }
                }
            }
        }
    }
    
    return nil;
}

+ (NSString *) pathForLibraryResource: (NSString *)name
                               ofType: (NSString *)extension
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
                                ofType: extension
                           inDirectory: bundlePath];
    }
    
    return path;
}

- (void)cleanPathCache
{
    NSUInteger	plen = [_path length];
    NSEnumerator	*enumerator;
    NSString		*path;
    
    [pathCacheLock lock];
    enumerator = [pathCache keyEnumerator];
    while (nil != (path = [enumerator nextObject]))
    {
        if (YES == [path hasPrefix: _path])
        {
            if ([path length] == plen)
            {
                /* Remove the bundle directory path from the cache.
                 */
                [pathCache removeObjectForKey: path];
            }
            else
            {
                unichar	c = [path characterAtIndex: plen];
                
                /* if the directory is inside the bundle, remove from cache.
                 */
                if ('/' == c)
                {
                    [pathCache removeObjectForKey: path];
                }
            }
        }
    }
    [pathCacheLock unlock];
    
    /* also destroy cached variables depending on bundle paths */
    DESTROY(_infoDict);
    DESTROY(_localizations);
}

@end

