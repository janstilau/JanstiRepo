#import "common.h"
#define	EXPOSE_NSDistributedLock_IVARS	1
#import "Foundation/NSDistributedLock.h"
#import "Foundation/NSException.h"
#import "Foundation/NSFileManager.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSValue.h"
#import "GSPrivate.h"


#if	defined(HAVE_SYS_FCNTL_H)
#  include	<sys/fcntl.h>
#elif	defined(HAVE_FCNTL_H)
#  include	<fcntl.h>
#endif

/*
 分布式锁的原理, 就是文件的写入.
 NSFileManager 里面, 一定做了多进程同时访问一个文件资源的管理.
 所以, 使用文件的创建时间, 当做加锁时间, 在进行 unlock 的时候, 进行对应的文件的删除操作.
 多进程之间, 通过文件系统, 完成了加锁解锁的目的;
 */

static NSFileManager	*mgr = nil;

// 这个锁, 是为了多进程之间做互斥操作的. 依赖的是可以共同访问的文件.
@implementation NSDistributedLock

+ (void) initialize
{
    if (mgr == nil)
    {
        mgr = RETAIN([NSFileManager defaultManager]);
    }
}

+ (NSDistributedLock*) lockWithPath: (NSString*)aPath
{
    return AUTORELEASE([[self alloc] initWithPath: aPath]);
}

/*
 * Forces release of the lock whether the receiver owns it or not.<br />
 * Raises an NSGenericException if unable to remove the lock.
 */
- (void) breakLock
{
    [_localLock lock];
    NS_DURING
    {
        NSDictionary	*attributes;
        
        DESTROY(_lockTime);
        attributes = [mgr fileAttributesAtPath: _lockPath traverseLink: YES];
        if (attributes != nil)
        {
            NSDate	*modDate = [attributes fileModificationDate];
            
            if ([mgr removeFileAtPath: _lockPath handler: nil] == NO)
            {
                NSString	*err = [[NSError _last] localizedDescription];
                
                attributes = [mgr fileAttributesAtPath: _lockPath
                                          traverseLink: YES];
                if ([modDate isEqual: [attributes fileModificationDate]] == YES)
                {
                    [NSException raise: NSGenericException
                                format: @"Failed to remove lock directory '%@' - %@",
                     _lockPath, err];
                }
            }
        }
    }
    NS_HANDLER
    {
        [_localLock unlock];
        [localException raise];
    }
    NS_ENDHANDLER
    [_localLock unlock];
}

- (void) dealloc
{
    if (_lockTime != nil)
    {
        NSLog(@"[%@-dealloc] still locked for %@ since %@",
              NSStringFromClass([self class]), _lockPath, _lockTime);
        [self unlock];
    }
    RELEASE(_lockPath);
    RELEASE(_lockTime);
    RELEASE(_localLock);
    [super dealloc];
}

/*
 * Initialises the receiver with the specified filesystem path.<br />
 * The location in the filesystem must be accessible for this
 * to be usable.  That is, the processes using the lock must be able
 * to access, create, and destroy files at the path.<br />
 * The directory in which the last path component resides must already
 * exist ... create it using NSFileManager if you need to.
 */
- (id) initWithPath: (NSString*)aPath
{
    // init 方法, 首先做一顿的逻辑判断. 但是这个方法, 主要还是记录一下 path.
    NSString	*lockDir;
    BOOL		isDirectory;
    
    _localLock = [NSLock new];
    _lockPath = [[aPath stringByStandardizingPath] copy];
    _lockTime = nil;
    
    lockDir = [_lockPath stringByDeletingLastPathComponent];
    if ([mgr fileExistsAtPath: lockDir isDirectory: &isDirectory] == NO)
    {
        NSLog(@"part of the path to the lock file '%@' is missing\n", aPath);
        DESTROY(self);
        return nil;
    }
    if (isDirectory == NO)
    {
        NSLog(@"part of the path to the lock file '%@' is not a directory\n",
              _lockPath);
        DESTROY(self);
        return nil;
    }
    if ([mgr isWritableFileAtPath: lockDir] == NO)
    {
        NSLog(@"parent directory of lock file '%@' is not writable\n", _lockPath);
        DESTROY(self);
        return nil;
    }
    if ([mgr isExecutableFileAtPath: lockDir] == NO)
    {
        NSLog(@"parent directory of lock file '%@' is not accessible\n",
              _lockPath);
        DESTROY(self);
        return nil;
    }
    return self;
}

/**
 * Returns the date at which the lock was acquired by <em>any</em>
 * NSDistributedLock using the same path.  If nothing has
 * the lock, this returns nil.
 */
- (NSDate*) lockDate
{
    NSDictionary	*attributes;
    
    attributes = [mgr fileAttributesAtPath: _lockPath traverseLink: YES];
    return [attributes fileModificationDate];
}

/*
 * Attempt to acquire the lock and return YES on success, NO on failure.<br />
 * May raise an NSGenericException if a problem occurs.
 */
- (BOOL) tryLock
{
    BOOL		locked = NO;
    
    [_localLock lock];
    NS_DURING
    {
        NSMutableDictionary	*attributesToSet;
        NSDictionary		*attributes;
        
        if (nil != _lockTime) // 如果, _lockTime 已经有值了, 代表现在是获取到锁的状态.
        {
            [NSException raise: NSGenericException
                        format: @"Attempt to re-lock distributed lock %@",
             _lockPath];
        }
        attributesToSet = [NSMutableDictionary dictionaryWithCapacity: 1];
        [attributesToSet setObject: [NSNumber numberWithUnsignedInt: 0755]
                            forKey: NSFilePosixPermissions];
        // -rwxr-xr-x (755)    拥有者有读、写、执行权限；而属组用户和其他用户只有读、执行权限。
        
        /* Here we depend on the fact that directory creation will fail if
         * the directory already exists.
         * We don't worry about any intermediate directories since we checked
         * those when the receiver was initialised in the -initWithPath: method.
         */
        locked = [mgr createDirectoryAtPath: _lockPath
                                 attributes: attributesToSet];
        if (NO == locked)
        {
            BOOL	dir;
            
            /* We expect the directory creation to have failed because
             * it already exists as another processes lock.
             * If the directory doesn't exist, then either the other
             * process has removed it's lock (and we can retry)
             * or we have a severe problem!
             */
            if ([mgr fileExistsAtPath: _lockPath isDirectory: &dir] == NO)
            {
                locked = [mgr createDirectoryAtPath: _lockPath
                        withIntermediateDirectories: YES
                                         attributes: attributesToSet
                                              error: NULL];
                if (NO == locked)
                {
                    NSLog(@"Failed to create lock directory '%@' - %@",
                          _lockPath, [NSError _last]);
                }
            }
        } else if (YES == locked)
        {
            attributes = [mgr fileAttributesAtPath: _lockPath
                                      traverseLink: YES];
            if (attributes == nil)
            {
                [NSException raise: NSGenericException
                            format: @"Unable to get attributes of lock file we made at %@",
                 _lockPath];
            }
            /*
             将文件的创建时间, 当做是锁上的时间.
             */
            _lockTime = [attributes fileModificationDate];
            if (nil == _lockTime)
            {
                [NSException raise: NSGenericException
                            format: @"Unable to get date of lock file we made at %@",
                 _lockPath];
            }
        }
    }
    NS_HANDLER
    {
        [_localLock unlock];
        [localException raise];
    }
    NS_ENDHANDLER
    [_localLock unlock];
    return locked;
}

/*
 * Releases the lock.  Raises an NSGenericException if unable to release
 * the lock (for instance if the receiver does not own it or another
 * process has broken it).
 */
- (void) unlock
{
    [_localLock lock];
    NS_DURING
    {
        NSDictionary	*attributes;
        
        if (_lockTime == nil)
        {
            [NSException raise: NSGenericException format: @"not locked by us"];
        }
        
        /* Don't remove the lock if it has already been broken by someone
         * else and re-created.  Unfortunately, there is a window between
         * testing and removing, but we do the bset we can.
         */
        attributes = [mgr fileAttributesAtPath: _lockPath traverseLink: YES];
        if (attributes == nil)
        {
            DESTROY(_lockTime);
            [NSException raise: NSGenericException
                        format: @"lock '%@' already broken", _lockPath];
        }
        if ([_lockTime isEqual: [attributes fileModificationDate]])
        {
            DESTROY(_lockTime);
            if ([mgr removeFileAtPath: _lockPath handler: nil] == NO)
            {
                [NSException raise: NSGenericException
                            format: @"Failed to remove lock directory '%@' - %@",
                 _lockPath, [NSError _last]];
            }
        }
        else
        {
            DESTROY(_lockTime);
            [NSException raise: NSGenericException
                        format: @"lock '%@' already broken and in use again",
             _lockPath];
        }
        DESTROY(_lockTime);
    }
    NS_HANDLER
    {
        [_localLock unlock];
        [localException raise];
    }
    NS_ENDHANDLER
    [_localLock unlock];
}

@end
