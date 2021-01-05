#import "FMDatabase.h"
#import <unistd.h>
#import <objc/runtime.h>

#if FMDB_SQLITE_STANDALONE
#import <sqlite3/sqlite3.h>
#else
#import <sqlite3.h>
#endif

// MARK: - FMDatabase Private Extension

NS_ASSUME_NONNULL_BEGIN

@interface FMDatabase () {
    void*               _db; // 数据库指针
    BOOL                _isExecutingStatement; // 标识是否正在进行查询.
    NSTimeInterval      _startBusyRetryTime;
    
    NSMutableSet        *_openResultSets;
    NSMutableSet        *_openFunctions;
    
    NSDateFormatter     *_dateFormat;
}

- (FMResultSet * _Nullable)executeQuery:(NSString *)sql withArgumentsInArray:(NSArray * _Nullable)arrayArgs orDictionary:(NSDictionary * _Nullable)dictionaryArgs orVAList:(va_list)args shouldBind:(BOOL)shouldBind;
- (BOOL)executeUpdate:(NSString *)sql error:(NSError * _Nullable __autoreleasing *)outErr withArgumentsInArray:(NSArray * _Nullable)arrayArgs orDictionary:(NSDictionary * _Nullable)dictionaryArgs orVAList:(va_list)args;

@end

// MARK: - FMResultSet Private Extension

@interface FMResultSet ()

- (int)internalStepWithError:(NSError * _Nullable __autoreleasing *)outErr;
+ (instancetype)resultSetWithStatement:(FMStatement *)statement usingParentDatabase:(FMDatabase*)aDB shouldAutoClose:(BOOL)shouldAutoClose;

@end

NS_ASSUME_NONNULL_END

// MARK: - FMDatabase

@implementation FMDatabase

// Because these two properties have all of their accessor methods implemented,
// we have to synthesize them to get the corresponding ivars. The rest of the
// properties have their ivars synthesized automatically for us.

@synthesize shouldCacheStatements = _shouldCacheStatements;
@synthesize maxBusyRetryTimeInterval = _maxBusyRetryTimeInterval;

#pragma mark FMDatabase instantiation and deallocation

+ (instancetype)databaseWithPath:(NSString *)aPath {
    return FMDBReturnAutoreleased([[self alloc] initWithPath:aPath]);
}

+ (instancetype)databaseWithURL:(NSURL *)url {
    return FMDBReturnAutoreleased([[self alloc] initWithURL:url]);
}

- (instancetype)init {
    return [self initWithPath:nil];
}

- (instancetype)initWithURL:(NSURL *)url {
    return [self initWithPath:url.path];
}

- (instancetype)initWithPath:(NSString *)path {
    
    assert(sqlite3_threadsafe()); // whoa there big boy- gotta make sure sqlite it happy with what we're going to do.
    
    self = [super init];
    
    if (self) {
        // FMDB 里面的数据部分, 就算是默认是 0 的数据, 在这里都有一份显式地定义.
        _databasePath               = [path copy];
        _openResultSets             = [[NSMutableSet alloc] init];
        _db                         = nil;
        _logsErrors                 = YES;
        _crashOnErrors              = NO;
        _maxBusyRetryTimeInterval   = 2;
        _isOpen                     = NO;
    }
    
    return self;
}

#if ! __has_feature(objc_arc)
- (void)finalize {
    [self close];
    [super finalize];
}
#endif

- (void)dealloc {
    [self close];
    FMDBRelease(_openResultSets);
    FMDBRelease(_cachedStatements);
    FMDBRelease(_dateFormat);
    FMDBRelease(_databasePath);
    FMDBRelease(_openFunctions);
    
#if ! __has_feature(objc_arc)
    [super dealloc];
#endif
}

- (NSURL *)databaseURL {
    return _databasePath ? [NSURL fileURLWithPath:_databasePath] : nil;
}

// 作为一个对外的 lib, 应该有这样一个, 让外界可以知道当前版本号的操作.
+ (NSString*)FMDBUserVersion {
    return @"2.7.7";
}

+ (SInt32)FMDBVersion {
    
    // we go through these hoops so that we only have to change the version number in a single spot.
    static dispatch_once_t once;
    static SInt32 FMDBVersionVal = 0;
    
    dispatch_once(&once, ^{
        NSString *prodVersion = [self FMDBUserVersion];
        
        while ([[prodVersion componentsSeparatedByString:@"."] count] < 3) {
            prodVersion = [prodVersion stringByAppendingString:@".0"];
        }

        NSArray *components = [prodVersion componentsSeparatedByString:@"."];
        for (NSUInteger i = 0; i < 3; i++) {
            SInt32 component = [components[i] intValue];
            if (component > 15) {
                NSLog(@"FMDBVersion is invalid: Please use FMDBUserVersion instead.");
                component = 15;
            }
            FMDBVersionVal = FMDBVersionVal << 4 | component;
        }
    });
    
    return FMDBVersionVal;
}

#pragma mark SQLite information

+ (NSString*)sqliteLibVersion {
    return [NSString stringWithFormat:@"%s", sqlite3_libversion()];
}

+ (BOOL)isSQLiteThreadSafe {
    // make sure to read the sqlite headers on this guy!
    return sqlite3_threadsafe() != 0;
}

- (void*)sqliteHandle {
    return _db;
}

- (const char*)sqlitePath {
    
    if (!_databasePath) {
        return ":memory:"; // 这是数据库的惯例写法.
    }
    
    if ([_databasePath length] == 0) {
        return ""; // this creates a temporary database (it's an sqlite thing).
    }
    
    return [_databasePath fileSystemRepresentation];
    
}

- (int)limitFor:(int)type value:(int)newLimit {
    return sqlite3_limit(_db, type, newLimit);
}

#pragma mark Open and close database

- (BOOL)open {
    // GuardCheck
    if (_isOpen) {
        return YES;
    }
    
    // if we previously tried to open and it failed, make sure to close it before we try again
    
    if (_db) {
        [self close];
    }
    
    // now open database
    // 最主要的就是这一步, 使用 sqlite3_open 打开数据库.
    // 在这个函数内部, 应该会有链接数据库的底层操作.
    int err = sqlite3_open([self sqlitePath], (sqlite3**)&_db );
    if(err != SQLITE_OK) {
        NSLog(@"error opening!: %d", err);
        return NO;
    }
    
    if (_maxBusyRetryTimeInterval > 0.0) {
        // set the handler
        [self setMaxBusyRetryTimeInterval:_maxBusyRetryTimeInterval];
    }
    
    _isOpen = YES;
    
    return YES;
}

- (BOOL)openWithFlags:(int)flags {
    return [self openWithFlags:flags vfs:nil];
}

- (BOOL)openWithFlags:(int)flags vfs:(NSString *)vfsName {
#if SQLITE_VERSION_NUMBER >= 3005000
    if (_isOpen) {
        return YES;
    }
    
    // if we previously tried to open and it failed, make sure to close it before we try again
    
    if (_db) {
        [self close];
    }
    
    // now open database
    
    // 使用了 sqlite3_open_v2 来应对带参的情况.
    int err = sqlite3_open_v2([self sqlitePath], (sqlite3**)&_db, flags, [vfsName UTF8String]);
    if(err != SQLITE_OK) {
        NSLog(@"error opening!: %d", err);
        return NO;
    }
    
    if (_maxBusyRetryTimeInterval > 0.0) {
        // set the handler
        [self setMaxBusyRetryTimeInterval:_maxBusyRetryTimeInterval];
    }
    
    _isOpen = YES;
    
    return YES;
#else
    NSLog(@"openWithFlags requires SQLite 3.5");
    return NO;
#endif
}

- (BOOL)close {
    
    [self clearCachedStatements];
    [self closeOpenResultSets];
    
    if (!_db) {
        return YES;
    }
    
    int  rc;
    BOOL retry;
    BOOL triedFinalizingOpenStatements = NO;
    
    do {
        retry   = NO;
        rc      = sqlite3_close(_db);
        if (SQLITE_BUSY == rc || SQLITE_LOCKED == rc) {
            if (!triedFinalizingOpenStatements) {
                triedFinalizingOpenStatements = YES;
                sqlite3_stmt *pStmt;
                while ((pStmt = sqlite3_next_stmt(_db, nil)) !=0) {
                    NSLog(@"Closing leaked statement");
                    sqlite3_finalize(pStmt);
                    pStmt = 0x00;
                    retry = YES;
                }
            }
        }
        else if (SQLITE_OK != rc) {
            NSLog(@"error closing!: %d", rc);
        }
    }
    while (retry);
    
    _db = nil;
    _isOpen = false;
    
    return YES;
}

#pragma mark Busy handler routines

// NOTE: appledoc seems to choke on this function for some reason;
//       so when generating documentation, you might want to ignore the
//       .m files so that it only documents the public interfaces outlined
//       in the .h files.
//
//       This is a known appledoc bug that it has problems with C functions
//       within a class implementation, but for some reason, only this
//       C function causes problems; the rest don't. Anyway, ignoring the .m
//       files with appledoc will prevent this problem from occurring.

static int FMDBDatabaseBusyHandler(void *f, int count) {
    FMDatabase *self = (__bridge FMDatabase*)f;
    
    if (count == 0) {
        self->_startBusyRetryTime = [NSDate timeIntervalSinceReferenceDate];
        return 1;
    }
    
    NSTimeInterval delta = [NSDate timeIntervalSinceReferenceDate] - (self->_startBusyRetryTime);
    
    if (delta < [self maxBusyRetryTimeInterval]) {
        int requestedSleepInMillseconds = (int) arc4random_uniform(50) + 50;
        int actualSleepInMilliseconds = sqlite3_sleep(requestedSleepInMillseconds);
        if (actualSleepInMilliseconds != requestedSleepInMillseconds) {
            NSLog(@"WARNING: Requested sleep of %i milliseconds, but SQLite returned %i. Maybe SQLite wasn't built with HAVE_USLEEP=1?", requestedSleepInMillseconds, actualSleepInMilliseconds);
        }
        return 1;
    }
    
    return 0;
}

- (void)setMaxBusyRetryTimeInterval:(NSTimeInterval)timeout {
    
    _maxBusyRetryTimeInterval = timeout;
    
    if (!_db) {
        return;
    }
    
    if (timeout > 0) {
        sqlite3_busy_handler(_db, &FMDBDatabaseBusyHandler, (__bridge void *)(self));
    }
    else {
        // turn it off otherwise
        sqlite3_busy_handler(_db, nil, nil);
    }
}

- (NSTimeInterval)maxBusyRetryTimeInterval {
    return _maxBusyRetryTimeInterval;
}


// we no longer make busyRetryTimeout public
// but for folks who don't bother noticing that the interface to FMDatabase changed,
// we'll still implement the method so they don't get suprise crashes
- (int)busyRetryTimeout {
    NSLog(@"%s:%d", __FUNCTION__, __LINE__);
    NSLog(@"FMDB: busyRetryTimeout no longer works, please use maxBusyRetryTimeInterval");
    return -1;
}

- (void)setBusyRetryTimeout:(int)i {
#pragma unused(i)
    NSLog(@"%s:%d", __FUNCTION__, __LINE__);
    NSLog(@"FMDB: setBusyRetryTimeout does nothing, please use setMaxBusyRetryTimeInterval:");
}

#pragma mark Result set functions

- (BOOL)hasOpenResultSets {
    return [_openResultSets count] > 0;
}

- (void)closeOpenResultSets {
    
    //Copy the set so we don't get mutation errors
    NSSet *openSetCopy = FMDBReturnAutoreleased([_openResultSets copy]);
    for (NSValue *rsInWrappedInATastyValueMeal in openSetCopy) {
        FMResultSet *rs = (FMResultSet *)[rsInWrappedInATastyValueMeal pointerValue];
        
        [rs setParentDB:nil];
        [rs close];
        
        [_openResultSets removeObject:rsInWrappedInATastyValueMeal];
    }
}

- (void)resultSetDidClose:(FMResultSet *)resultSet {
    NSValue *setValue = [NSValue valueWithNonretainedObject:resultSet];
    
    [_openResultSets removeObject:setValue];
}

#pragma mark Cached statements

- (void)clearCachedStatements {
    
    for (NSMutableSet *statements in [_cachedStatements objectEnumerator]) {
        for (FMStatement *statement in [statements allObjects]) {
            [statement close];
        }
    }
    
    [_cachedStatements removeAllObjects];
}

// 这里, 是直接根据 query 作为 key 进行了检索.
// 一个 Sql 语句, 在 _cachedStatements 存档一个 NSMutableSet, 里面是 FMStatement 的对象.
- (FMStatement*)cachedStatementForQuery:(NSString*)query {
    
    NSMutableSet* statements = [_cachedStatements objectForKey:query];
    
    return [[statements objectsPassingTest:^BOOL(FMStatement* statement, BOOL *stop) {
        *stop = ![statement inUse];
        return *stop;
    }] anyObject];
}


- (void)setCachedStatement:(FMStatement*)statement forQuery:(NSString*)query {
    NSParameterAssert(query);
    if (!query) {
        NSLog(@"API misuse, -[FMDatabase setCachedStatement:forQuery:] query must not be nil");
        return;
    }
    
    query = [query copy]; // in case we got handed in a mutable string...
    [statement setQuery:query];
    
    NSMutableSet* statements = [_cachedStatements objectForKey:query];
    if (!statements) {
        statements = [NSMutableSet set];
    }
    
    [statements addObject:statement];
    
    [_cachedStatements setObject:statements forKey:query];
    
    FMDBRelease(query);
}

#pragma mark Key routines

- (BOOL)rekey:(NSString*)key {
    NSData *keyData = [NSData dataWithBytes:(void *)[key UTF8String] length:(NSUInteger)strlen([key UTF8String])];
    
    return [self rekeyWithData:keyData];
}

- (BOOL)rekeyWithData:(NSData *)keyData {
#ifdef SQLITE_HAS_CODEC
    if (!keyData) {
        return NO;
    }
    
    int rc = sqlite3_rekey(_db, [keyData bytes], (int)[keyData length]);
    
    if (rc != SQLITE_OK) {
        NSLog(@"error on rekey: %d", rc);
        NSLog(@"%@", [self lastErrorMessage]);
    }
    
    return (rc == SQLITE_OK);
#else
#pragma unused(keyData)
    return NO;
#endif
}

- (BOOL)setKey:(NSString*)key {
    NSData *keyData = [NSData dataWithBytes:[key UTF8String] length:(NSUInteger)strlen([key UTF8String])];
    
    return [self setKeyWithData:keyData];
}

- (BOOL)setKeyWithData:(NSData *)keyData {
#ifdef SQLITE_HAS_CODEC
    if (!keyData) {
        return NO;
    }
    
    int rc = sqlite3_key(_db, [keyData bytes], (int)[keyData length]);
    
    return (rc == SQLITE_OK);
#else
#pragma unused(keyData)
    return NO;
#endif
}

#pragma mark Date routines

+ (NSDateFormatter *)storeableDateFormat:(NSString *)format {
    
    NSDateFormatter *result = FMDBReturnAutoreleased([[NSDateFormatter alloc] init]);
    result.dateFormat = format;
    result.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    result.locale = FMDBReturnAutoreleased([[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]);
    return result;
}


- (BOOL)hasDateFormatter {
    return _dateFormat != nil;
}

- (void)setDateFormat:(NSDateFormatter *)format {
    FMDBAutorelease(_dateFormat);
    _dateFormat = FMDBReturnRetained(format);
}

- (NSDate *)dateFromString:(NSString *)s {
    return [_dateFormat dateFromString:s];
}

- (NSString *)stringFromDate:(NSDate *)date {
    return [_dateFormat stringFromDate:date];
}

#pragma mark State of database

- (BOOL)goodConnection {
    
    if (!_isOpen) {
        return NO;
    }
    
#ifdef SQLCIPHER_CRYPTO
    // Starting with Xcode8 / iOS 10 we check to make sure we really are linked with
    // SQLCipher because there is no longer a linker error if we accidently link
    // with unencrypted sqlite library.
    //
    // https://discuss.zetetic.net/t/important-advisory-sqlcipher-with-xcode-8-and-new-sdks/1688
    
    FMResultSet *rs = [self executeQuery:@"PRAGMA cipher_version"];

    if ([rs next]) {
        NSLog(@"SQLCipher version: %@", rs.resultDictionary[@"cipher_version"]);
        
        [rs close];
        return YES;
    }
#else
    FMResultSet *rs = [self executeQuery:@"select name from sqlite_master where type='table'"];
    
    if (rs) {
        [rs close];
        return YES;
    }
#endif
    
    return NO;
}

// 其实就是判断, 数据库有没有打开, 输出 Log
- (BOOL)databaseExists {
    
    if (!_isOpen) {
        
        NSLog(@"The FMDatabase %@ is not open.", self);
        
#ifndef NS_BLOCK_ASSERTIONS
        // _crashOnErrors 默认是 No
        if (_crashOnErrors) {
            NSAssert(false, @"The FMDatabase %@ is not open.", self);
            abort();
        }
#endif
        
        return NO;
    }
    
    return YES;
}

#pragma mark Error routines

- (NSString *)lastErrorMessage {
    return [NSString stringWithUTF8String:sqlite3_errmsg(_db)];
}

- (BOOL)hadError {
    int lastErrCode = [self lastErrorCode];
    
    return (lastErrCode > SQLITE_OK && lastErrCode < SQLITE_ROW);
}

- (int)lastErrorCode {
    return sqlite3_errcode(_db);
}

- (int)lastExtendedErrorCode {
    return sqlite3_extended_errcode(_db);
}

- (NSError*)errorWithMessage:(NSString *)message {
    NSDictionary* errorMessage = [NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey];
    
    return [NSError errorWithDomain:@"FMDatabase" code:sqlite3_errcode(_db) userInfo:errorMessage];
}

- (NSError*)lastError {
    return [self errorWithMessage:[self lastErrorMessage]];
}

#pragma mark Update information routines

- (sqlite_int64)lastInsertRowId {
    
    if (_isExecutingStatement) {
        return NO;
    }
    
    _isExecutingStatement = YES;
    
    sqlite_int64 ret = sqlite3_last_insert_rowid(_db);
    
    _isExecutingStatement = NO;
    
    return ret;
}

- (int)changes {
    if (_isExecutingStatement) {
        return 0;
    }
    
    _isExecutingStatement = YES;
    
    int ret = sqlite3_changes(_db);
    
    _isExecutingStatement = NO;
    
    return ret;
}

#pragma mark SQL manipulation

// 实际的 value binding 的过程.
- (int)bindObject:(id)valueObj toColumn:(int)idx inStatement:(sqlite3_stmt*)pStmt {
    
    // 实际上, 这个 Bind 的过程, 就是根据 valueObj 的类型, 调用不同的 sqlite 的绑定函数.
    if ((!valueObj) || ((NSNull *)valueObj == [NSNull null])) {
        return sqlite3_bind_null(pStmt, idx);
    }
    
    // FIXME - someday check the return codes on these binds.
    else if ([valueObj isKindOfClass:[NSData class]]) {
        const void *bytes = [valueObj bytes];
        if (!bytes) {
            // it's an empty NSData object, aka [NSData data].
            // Don't pass a NULL pointer, or sqlite will bind a SQL null instead of a blob.
            bytes = "";
        }
        return sqlite3_bind_blob(pStmt, idx, bytes, (int)[valueObj length], SQLITE_TRANSIENT);
    }
    else if ([valueObj isKindOfClass:[NSDate class]]) {
        if (self.hasDateFormatter) // 如果, 有日期的格式化器, 就输出为文本, 否则, 直接存储时间戳.
            return sqlite3_bind_text(pStmt, idx, [[self stringFromDate:valueObj] UTF8String], -1, SQLITE_TRANSIENT);
        else
            return sqlite3_bind_double(pStmt, idx, [valueObj timeIntervalSince1970]);
    }
    else if ([valueObj isKindOfClass:[NSNumber class]]) {
        // 按照数字的不同类型, 存储值.
        if (strcmp([valueObj objCType], @encode(char)) == 0) {
            return sqlite3_bind_int(pStmt, idx, [valueObj charValue]);
        }
        else if (strcmp([valueObj objCType], @encode(unsigned char)) == 0) {
            return sqlite3_bind_int(pStmt, idx, [valueObj unsignedCharValue]);
        }
        else if (strcmp([valueObj objCType], @encode(short)) == 0) {
            return sqlite3_bind_int(pStmt, idx, [valueObj shortValue]);
        }
        else if (strcmp([valueObj objCType], @encode(unsigned short)) == 0) {
            return sqlite3_bind_int(pStmt, idx, [valueObj unsignedShortValue]);
        }
        else if (strcmp([valueObj objCType], @encode(int)) == 0) {
            return sqlite3_bind_int(pStmt, idx, [valueObj intValue]);
        }
        else if (strcmp([valueObj objCType], @encode(unsigned int)) == 0) {
            return sqlite3_bind_int64(pStmt, idx, (long long)[valueObj unsignedIntValue]);
        }
        else if (strcmp([valueObj objCType], @encode(long)) == 0) {
            return sqlite3_bind_int64(pStmt, idx, [valueObj longValue]);
        }
        else if (strcmp([valueObj objCType], @encode(unsigned long)) == 0) {
            return sqlite3_bind_int64(pStmt, idx, (long long)[valueObj unsignedLongValue]);
        }
        else if (strcmp([valueObj objCType], @encode(long long)) == 0) {
            return sqlite3_bind_int64(pStmt, idx, [valueObj longLongValue]);
        }
        else if (strcmp([valueObj objCType], @encode(unsigned long long)) == 0) {
            return sqlite3_bind_int64(pStmt, idx, (long long)[valueObj unsignedLongLongValue]);
        }
        else if (strcmp([valueObj objCType], @encode(float)) == 0) {
            return sqlite3_bind_double(pStmt, idx, [valueObj floatValue]);
        }
        else if (strcmp([valueObj objCType], @encode(double)) == 0) {
            return sqlite3_bind_double(pStmt, idx, [valueObj doubleValue]);
        }
        else if (strcmp([valueObj objCType], @encode(BOOL)) == 0) {
            return sqlite3_bind_int(pStmt, idx, ([valueObj boolValue] ? 1 : 0));
        }
        else {
            return sqlite3_bind_text(pStmt, idx, [[valueObj description] UTF8String], -1, SQLITE_TRANSIENT);
        }
    }

    return sqlite3_bind_text(pStmt, idx, [[valueObj description] UTF8String], -1, SQLITE_TRANSIENT);
}

- (void)extractSQL:(NSString *)sql argumentsList:(va_list)args intoString:(NSMutableString *)cleanedSQL arguments:(NSMutableArray *)arguments {
    
    NSUInteger length = [sql length];
    unichar last = '\0';
    for (NSUInteger i = 0; i < length; ++i) {
        id arg = nil;
        unichar current = [sql characterAtIndex:i];
        unichar add = current;
        if (last == '%') {
            switch (current) {
                case '@':
                    arg = va_arg(args, id);
                    break;
                case 'c':
                    // warning: second argument to 'va_arg' is of promotable type 'char'; this va_arg has undefined behavior because arguments will be promoted to 'int'
                    arg = [NSString stringWithFormat:@"%c", va_arg(args, int)];
                    break;
                case 's':
                    arg = [NSString stringWithUTF8String:va_arg(args, char*)];
                    break;
                case 'd':
                case 'D':
                case 'i':
                    arg = [NSNumber numberWithInt:va_arg(args, int)];
                    break;
                case 'u':
                case 'U':
                    arg = [NSNumber numberWithUnsignedInt:va_arg(args, unsigned int)];
                    break;
                case 'h':
                    i++;
                    if (i < length && [sql characterAtIndex:i] == 'i') {
                        //  warning: second argument to 'va_arg' is of promotable type 'short'; this va_arg has undefined behavior because arguments will be promoted to 'int'
                        arg = [NSNumber numberWithShort:(short)(va_arg(args, int))];
                    }
                    else if (i < length && [sql characterAtIndex:i] == 'u') {
                        // warning: second argument to 'va_arg' is of promotable type 'unsigned short'; this va_arg has undefined behavior because arguments will be promoted to 'int'
                        arg = [NSNumber numberWithUnsignedShort:(unsigned short)(va_arg(args, uint))];
                    }
                    else {
                        i--;
                    }
                    break;
                case 'q':
                    i++;
                    if (i < length && [sql characterAtIndex:i] == 'i') {
                        arg = [NSNumber numberWithLongLong:va_arg(args, long long)];
                    }
                    else if (i < length && [sql characterAtIndex:i] == 'u') {
                        arg = [NSNumber numberWithUnsignedLongLong:va_arg(args, unsigned long long)];
                    }
                    else {
                        i--;
                    }
                    break;
                case 'f':
                    arg = [NSNumber numberWithDouble:va_arg(args, double)];
                    break;
                case 'g':
                    // warning: second argument to 'va_arg' is of promotable type 'float'; this va_arg has undefined behavior because arguments will be promoted to 'double'
                    arg = [NSNumber numberWithFloat:(float)(va_arg(args, double))];
                    break;
                case 'l':
                    i++;
                    if (i < length) {
                        unichar next = [sql characterAtIndex:i];
                        if (next == 'l') {
                            i++;
                            if (i < length && [sql characterAtIndex:i] == 'd') {
                                //%lld
                                arg = [NSNumber numberWithLongLong:va_arg(args, long long)];
                            }
                            else if (i < length && [sql characterAtIndex:i] == 'u') {
                                //%llu
                                arg = [NSNumber numberWithUnsignedLongLong:va_arg(args, unsigned long long)];
                            }
                            else {
                                i--;
                            }
                        }
                        else if (next == 'd') {
                            //%ld
                            arg = [NSNumber numberWithLong:va_arg(args, long)];
                        }
                        else if (next == 'u') {
                            //%lu
                            arg = [NSNumber numberWithUnsignedLong:va_arg(args, unsigned long)];
                        }
                        else {
                            i--;
                        }
                    }
                    else {
                        i--;
                    }
                    break;
                default:
                    // something else that we can't interpret. just pass it on through like normal
                    break;
            }
        }
        else if (current == '%') {
            // percent sign; skip this character
            add = '\0';
        }
        
        if (arg != nil) {
            [cleanedSQL appendString:@"?"];
            [arguments addObject:arg];
        }
        else if (add == (unichar)'@' && last == (unichar) '%') {
            [cleanedSQL appendFormat:@"NULL"];
        }
        else if (add != '\0') {
            [cleanedSQL appendFormat:@"%C", add];
        }
        last = current;
    }
}

#pragma mark Execute queries

- (FMResultSet *)executeQuery:(NSString *)sql withParameterDictionary:(NSDictionary *)arguments {
    return [self executeQuery:sql withArgumentsInArray:nil orDictionary:arguments orVAList:nil shouldBind:true];
}

// executeQuery 的终点函数.
- (FMResultSet *)executeQuery:(NSString *)sqlCmd withArgumentsInArray:(NSArray*)arrayArgs orDictionary:(NSDictionary *)dictionaryArgs orVAList:(va_list)args shouldBind:(BOOL)shouldBind {
    if (![self databaseExists]) {
        return 0x00;
    }
    
    if (_isExecutingStatement) {
        return 0x00;
    }
    
    _isExecutingStatement = YES;
    
    int rc                  = 0x00;
    sqlite3_stmt *pStmt     = 0x00;
    FMStatement *statement  = 0x00;
    FMResultSet *rs         = 0x00;
    
    if (_shouldCacheStatements) {
        statement = [self cachedStatementForQuery:sqlCmd];
        pStmt = statement ? [statement statement] : 0x00;
        [statement reset];
    }
    
    // 这个时候 pStmt 为空, 就是缓存里面没有该信息.
    if (!pStmt) {
        // 第一个参数, db, 第二个参数, SQL char*, 第三个参数 SQL 的长度, 第四个参数, 输出参数, 第五个无用.
        // 返回值, error code 值.
        rc = sqlite3_prepare_v2(_db, [sqlCmd UTF8String], -1, &pStmt, 0);
        
        if (SQLITE_OK != rc) {
            if (_logsErrors) {
                // 打印出错信息.
                NSLog(@"DB Error: %d \"%@\"", [self lastErrorCode], [self lastErrorMessage]);
                NSLog(@"DB Query: %@", sqlCmd);
                NSLog(@"DB Path: %@", _databasePath);
            }
            
            if (_crashOnErrors) {
                NSAssert(false, @"DB Error: %d \"%@\"", [self lastErrorCode], [self lastErrorMessage]);
                abort();
            }
            
            // 提前退出.
            // sqlite3_finalize函数释放所有的内部资源和sqlite3_stmt数据结构，有效删除prepared语句
            sqlite3_finalize(pStmt);
            pStmt = 0x00;
            _isExecutingStatement = NO;
            return nil;
        }
    }

    if (shouldBind) {
        // 这里就是 Sql 里面, 根据 ?, 或者 :key 进行绑定的机制.
        BOOL success = [self bindStatement:pStmt WithArgumentsInArray:arrayArgs orDictionary:dictionaryArgs orVAList:args];
        if (!success) {
            return nil;
        }
    }

    // 下面的这些操作, 真正的数据库查询, 并没有发生. 
    if (!statement) {
        statement = [[FMStatement alloc] init];
        [statement setStatement:pStmt];
        if (_shouldCacheStatements && sqlCmd) {
            [self setCachedStatement:statement forQuery:sqlCmd];
        }
    }
    
    // the statement gets closed in rs's dealloc or [rs close];
    // we should only autoclose if we're binding automatically when the statement is prepared
    rs = [FMResultSet resultSetWithStatement:statement usingParentDatabase:self shouldAutoClose:shouldBind];
    [rs setQuery:sqlCmd];
    
    NSValue *openResultSet = [NSValue valueWithNonretainedObject:rs];
    [_openResultSets addObject:openResultSet];
    
    [statement setUseCount:[statement useCount] + 1];
    
    FMDBRelease(statement);
    
    _isExecutingStatement = NO;
    
    return rs;
}

// arrayArgs, dictionaryArgs, cArgs 是分开使用的.
- (BOOL)bindStatement:(sqlite3_stmt *)pStmt WithArgumentsInArray:(NSArray*)arrayArgs orDictionary:(NSDictionary *)dictionaryArgs orVAList:(va_list)cArgs {
    id obj;
    int idx = 0;
    // 这个时候, pStmt 已经包含了 SQLCmd 的格式了, 所以能够知道需要绑定的数量.
    int queryCount = sqlite3_bind_parameter_count(pStmt); // pointed out by Dominic Yu (thanks!)

    // 优先使用 dictionaryArgs, 也就是优先使用命名的绑定方式.
    if (dictionaryArgs) {

        for (NSString *dictionaryKey in [dictionaryArgs allKeys]) {

            // Prefix the key with a colon.
            NSString *parameterName = [[NSString alloc] initWithFormat:@":%@", dictionaryKey];

            // Get the index for the parameter name.
            // 最终, 还是使用的 idx 进行的绑定, key 主要用作了获取合法 idx 的途径
            int namedIdx = sqlite3_bind_parameter_index(pStmt, [parameterName UTF8String]);
            
            if (namedIdx > 0) {
                // Standard binding from here.
                int rc = [self bindObject:[dictionaryArgs objectForKey:dictionaryKey] toColumn:namedIdx inStatement:pStmt];
                if (rc != SQLITE_OK) {
                    // 在 binding 的过程中出错了, 提前退出.
                    NSLog(@"Error: unable to bind (%d, %s", rc, sqlite3_errmsg(_db));
                    sqlite3_finalize(pStmt);
                    pStmt = 0x00;
                    _isExecutingStatement = NO;
                    return false;
                }
                // increment the binding count, so our check below works out
                idx++;
            }
            else {
                NSLog(@"Could not find index for %@", dictionaryKey);
            }
        }
    } else {
        while (idx < queryCount) {
            // 如果, 数组有值, 就用数组的
            if (arrayArgs && idx < (int)[arrayArgs count]) {
                obj = [arrayArgs objectAtIndex:(NSUInteger)idx];
            }
            // 如果 C 可变数组有值, 就用 C 函数的.
            else if (cArgs) {
                obj = va_arg(cArgs, id);
            }
            else {
                //We ran out of arguments
                break;
            }

            idx++;

            // 同样的逻辑, 不过直接按照数组的 idx 当做了 tobind 的 idx
            int rc = [self bindObject:obj toColumn:idx inStatement:pStmt];
            if (rc != SQLITE_OK) {
                NSLog(@"Error: unable to bind (%d, %s", rc, sqlite3_errmsg(_db));
                sqlite3_finalize(pStmt);
                pStmt = 0x00;
                _isExecutingStatement = NO;
                return false;
            }
        }
    }

    if (idx != queryCount) {
        NSLog(@"Error: the bind count is not correct for the # of variables (executeQuery)");
        sqlite3_finalize(pStmt);
        pStmt = 0x00;
        _isExecutingStatement = NO;
        return false;
    }

    return true;
}

- (FMResultSet *)executeQuery:(NSString*)sql, ... {
    va_list args;
    va_start(args, sql);
    
    id result = [self executeQuery:sql withArgumentsInArray:nil orDictionary:nil orVAList:args shouldBind:true];
    
    va_end(args);
    return result;
}

- (FMResultSet *)executeQueryWithFormat:(NSString*)format, ... {
    va_list args;
    va_start(args, format);
    
    NSMutableString *sql = [NSMutableString stringWithCapacity:[format length]];
    NSMutableArray *arguments = [NSMutableArray array];
    [self extractSQL:format argumentsList:args intoString:sql arguments:arguments];
    
    va_end(args);
    
    return [self executeQuery:sql withArgumentsInArray:arguments];
}

- (FMResultSet *)executeQuery:(NSString *)sql withArgumentsInArray:(NSArray *)arguments {
    return [self executeQuery:sql withArgumentsInArray:arguments orDictionary:nil orVAList:nil shouldBind:true];
}

- (FMResultSet *)executeQuery:(NSString *)sql values:(NSArray *)values error:(NSError * __autoreleasing *)error {
    FMResultSet *rs = [self executeQuery:sql withArgumentsInArray:values orDictionary:nil orVAList:nil shouldBind:true];
    if (!rs && error) {
        *error = [self lastError];
    }
    return rs;
}

- (FMResultSet *)executeQuery:(NSString*)sql withVAList:(va_list)args {
    return [self executeQuery:sql withArgumentsInArray:nil orDictionary:nil orVAList:args shouldBind:true];
}

#pragma mark Execute updates

// 最终的 executeUpdate 的终点函数,.
- (BOOL)executeUpdate:(NSString*)sql error:(NSError * _Nullable __autoreleasing *)outErr withArgumentsInArray:(NSArray*)arrayArgs orDictionary:(NSDictionary *)dictionaryArgs orVAList:(va_list)args {
    FMResultSet *rs = [self executeQuery:sql withArgumentsInArray:arrayArgs orDictionary:dictionaryArgs orVAList:args shouldBind:true];
    if (!rs) {
        if (outErr) {
            *outErr = [self lastError];
        }
        return false;
    }

    return [rs internalStepWithError:outErr] == SQLITE_DONE;
}

- (BOOL)executeUpdate:(NSString*)sql, ... {
    va_list args;
    va_start(args, sql);
    
    BOOL result = [self executeUpdate:sql error:nil withArgumentsInArray:nil orDictionary:nil orVAList:args];
    
    va_end(args);
    return result;
}

- (BOOL)executeUpdate:(NSString*)sql withArgumentsInArray:(NSArray *)arguments {
    return [self executeUpdate:sql error:nil withArgumentsInArray:arguments orDictionary:nil orVAList:nil];
}

- (BOOL)executeUpdate:(NSString*)sql values:(NSArray *)values error:(NSError * __autoreleasing *)error {
    return [self executeUpdate:sql error:error withArgumentsInArray:values orDictionary:nil orVAList:nil];
}

- (BOOL)executeUpdate:(NSString*)sql withParameterDictionary:(NSDictionary *)arguments {
    return [self executeUpdate:sql error:nil withArgumentsInArray:nil orDictionary:arguments orVAList:nil];
}

- (BOOL)executeUpdate:(NSString*)sql withVAList:(va_list)args {
    return [self executeUpdate:sql error:nil withArgumentsInArray:nil orDictionary:nil orVAList:args];
}

- (BOOL)executeUpdateWithFormat:(NSString*)format, ... {
    va_list args;
    va_start(args, format);
    
    NSMutableString *sql      = [NSMutableString stringWithCapacity:[format length]];
    NSMutableArray *arguments = [NSMutableArray array];
    
    [self extractSQL:format argumentsList:args intoString:sql arguments:arguments];
    
    va_end(args);
    
    return [self executeUpdate:sql withArgumentsInArray:arguments];
}


int FMDBExecuteBulkSQLCallback(void *theBlockAsVoid, int columns, char **values, char **names); // shhh clang.
int FMDBExecuteBulkSQLCallback(void *theBlockAsVoid, int columns, char **values, char **names) {
    
    if (!theBlockAsVoid) {
        return SQLITE_OK;
    }
    
    int (^execCallbackBlock)(NSDictionary *resultsDictionary) = (__bridge int (^)(NSDictionary *__strong))(theBlockAsVoid);
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:(NSUInteger)columns];
    
    for (NSInteger i = 0; i < columns; i++) {
        NSString *key = [NSString stringWithUTF8String:names[i]];
        id value = values[i] ? [NSString stringWithUTF8String:values[i]] : [NSNull null];
        value = value ? value : [NSNull null];
        [dictionary setObject:value forKey:key];
    }
    
    return execCallbackBlock(dictionary);
}

- (BOOL)executeStatements:(NSString *)sql {
    return [self executeStatements:sql withResultBlock:nil];
}

- (BOOL)executeStatements:(NSString *)sql withResultBlock:(__attribute__((noescape)) FMDBExecuteStatementsCallbackBlock)block {
    
    int rc;
    char *errmsg = nil;
    
    rc = sqlite3_exec([self sqliteHandle], [sql UTF8String], block ? FMDBExecuteBulkSQLCallback : nil, (__bridge void *)(block), &errmsg);
    
    if (errmsg && [self logsErrors]) {
        NSLog(@"Error inserting batch: %s", errmsg);
    }
    if (errmsg) {
        sqlite3_free(errmsg);
    }
    
    return (rc == SQLITE_OK);
}

- (BOOL)executeUpdate:(NSString*)sql withErrorAndBindings:(NSError * _Nullable __autoreleasing *)outErr, ... {
    
    va_list args;
    va_start(args, outErr);
    
    BOOL result = [self executeUpdate:sql error:outErr withArgumentsInArray:nil orDictionary:nil orVAList:args];
    
    va_end(args);
    return result;
}


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (BOOL)update:(NSString*)sql withErrorAndBindings:(NSError * _Nullable __autoreleasing *)outErr, ... {
    va_list args;
    va_start(args, outErr);
    
    BOOL result = [self executeUpdate:sql error:outErr withArgumentsInArray:nil orDictionary:nil orVAList:args];
    
    va_end(args);
    return result;
}

#pragma clang diagnostic pop

#pragma mark Prepare

- (FMResultSet *)prepare:(NSString *)sql {
    return [self executeQuery:sql withArgumentsInArray:nil orDictionary:nil orVAList:nil shouldBind:false];
}

#pragma mark Transactions

// 回滚, 就是执行一下回滚的语句.
- (BOOL)rollback {
    BOOL b = [self executeUpdate:@"rollback transaction"];
    
    if (b) {
        _isInTransaction = NO;
    }
    
    return b;
}

// commit 就是执行一下, commit 的语句.
- (BOOL)commit {
    BOOL b =  [self executeUpdate:@"commit transaction"];
    
    if (b) {
        _isInTransaction = NO;
    }
    
    return b;
}

// 开始一个事务, 就是执行一下开启事务的语句.
- (BOOL)beginTransaction {
    
    BOOL b = [self executeUpdate:@"begin exclusive transaction"];
    if (b) {
        _isInTransaction = YES;
    }
    
    return b;
}

- (BOOL)beginDeferredTransaction {
    
    BOOL b = [self executeUpdate:@"begin deferred transaction"];
    if (b) {
        _isInTransaction = YES;
    }
    
    return b;
}

- (BOOL)beginImmediateTransaction {
    
    BOOL b = [self executeUpdate:@"begin immediate transaction"];
    if (b) {
        _isInTransaction = YES;
    }
    
    return b;
}

- (BOOL)beginExclusiveTransaction {
    
    BOOL b = [self executeUpdate:@"begin exclusive transaction"];
    if (b) {
        _isInTransaction = YES;
    }
    
    return b;
}

- (BOOL)inTransaction {
    return _isInTransaction;
}

- (BOOL)interrupt
{
    if (_db) {
        sqlite3_interrupt([self sqliteHandle]);
        return YES;
    }
    return NO;
}

static NSString *FMDBEscapeSavePointName(NSString *savepointName) {
    return [savepointName stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
}

- (BOOL)startSavePointWithName:(NSString*)name error:(NSError * _Nullable __autoreleasing *)outErr {
#if SQLITE_VERSION_NUMBER >= 3007000
    NSParameterAssert(name);
    
    NSString *sql = [NSString stringWithFormat:@"savepoint '%@';", FMDBEscapeSavePointName(name)];
    
    return [self executeUpdate:sql error:outErr withArgumentsInArray:nil orDictionary:nil orVAList:nil];
#else
    NSString *errorMessage = NSLocalizedStringFromTable(@"Save point functions require SQLite 3.7", @"FMDB", nil);
    if (self.logsErrors) NSLog(@"%@", errorMessage);
    return NO;
#endif
}

- (BOOL)releaseSavePointWithName:(NSString*)name error:(NSError * _Nullable __autoreleasing *)outErr {
#if SQLITE_VERSION_NUMBER >= 3007000
    NSParameterAssert(name);
    
    NSString *sql = [NSString stringWithFormat:@"release savepoint '%@';", FMDBEscapeSavePointName(name)];

    return [self executeUpdate:sql error:outErr withArgumentsInArray:nil orDictionary:nil orVAList:nil];
#else
    NSString *errorMessage = NSLocalizedStringFromTable(@"Save point functions require SQLite 3.7", @"FMDB", nil);
    if (self.logsErrors) NSLog(@"%@", errorMessage);
    return NO;
#endif
}

- (BOOL)rollbackToSavePointWithName:(NSString*)name error:(NSError * _Nullable __autoreleasing *)outErr {
#if SQLITE_VERSION_NUMBER >= 3007000
    NSParameterAssert(name);
    
    NSString *sql = [NSString stringWithFormat:@"rollback transaction to savepoint '%@';", FMDBEscapeSavePointName(name)];

    return [self executeUpdate:sql error:outErr withArgumentsInArray:nil orDictionary:nil orVAList:nil];
#else
    NSString *errorMessage = NSLocalizedStringFromTable(@"Save point functions require SQLite 3.7", @"FMDB", nil);
    if (self.logsErrors) NSLog(@"%@", errorMessage);
    return NO;
#endif
}

- (NSError*)inSavePoint:(__attribute__((noescape)) void (^)(BOOL *rollback))block {
#if SQLITE_VERSION_NUMBER >= 3007000
    static unsigned long savePointIdx = 0;
    
    NSString *name = [NSString stringWithFormat:@"dbSavePoint%ld", savePointIdx++];
    
    BOOL shouldRollback = NO;
    
    NSError *err = 0x00;
    
    if (![self startSavePointWithName:name error:&err]) {
        return err;
    }
    
    if (block) {
        block(&shouldRollback);
    }
    
    if (shouldRollback) {
        // We need to rollback and release this savepoint to remove it
        [self rollbackToSavePointWithName:name error:&err];
    }
    [self releaseSavePointWithName:name error:&err];
    
    return err;
#else
    NSString *errorMessage = NSLocalizedStringFromTable(@"Save point functions require SQLite 3.7", @"FMDB", nil);
    if (self.logsErrors) NSLog(@"%@", errorMessage);
    return [NSError errorWithDomain:@"FMDatabase" code:0 userInfo:@{NSLocalizedDescriptionKey : errorMessage}];
#endif
}

- (BOOL)checkpoint:(FMDBCheckpointMode)checkpointMode error:(NSError * __autoreleasing *)error {
    return [self checkpoint:checkpointMode name:nil logFrameCount:NULL checkpointCount:NULL error:error];
}

- (BOOL)checkpoint:(FMDBCheckpointMode)checkpointMode name:(NSString *)name error:(NSError * __autoreleasing *)error {
    return [self checkpoint:checkpointMode name:name logFrameCount:NULL checkpointCount:NULL error:error];
}

- (BOOL)checkpoint:(FMDBCheckpointMode)checkpointMode name:(NSString *)name logFrameCount:(int *)logFrameCount checkpointCount:(int *)checkpointCount error:(NSError * __autoreleasing *)error
{
    const char* dbName = [name UTF8String];
#if SQLITE_VERSION_NUMBER >= 3007006
    int err = sqlite3_wal_checkpoint_v2(_db, dbName, checkpointMode, logFrameCount, checkpointCount);
#else
    NSLog(@"sqlite3_wal_checkpoint_v2 unavailable before sqlite 3.7.6. Ignoring checkpoint mode: %d", mode);
    int err = sqlite3_wal_checkpoint(_db, dbName);
#endif
    if(err != SQLITE_OK) {
        if (error) {
            *error = [self lastError];
        }
        if (self.logsErrors) NSLog(@"%@", [self lastErrorMessage]);
        if (self.crashOnErrors) {
            NSAssert(false, @"%@", [self lastErrorMessage]);
            abort();
        }
        return NO;
    } else {
        return YES;
    }
}

#pragma mark Cache statements

- (BOOL)shouldCacheStatements {
    return _shouldCacheStatements;
}

// 设置是否要缓存命令.
- (void)setShouldCacheStatements:(BOOL)value {
    
    _shouldCacheStatements = value;
    
    if (_shouldCacheStatements && !_cachedStatements) {
        [self setCachedStatements:[NSMutableDictionary dictionary]];
    }
    
    if (!_shouldCacheStatements) {
        [self setCachedStatements:nil];
    }
}

#pragma mark Callback function

void FMDBBlockSQLiteCallBackFunction(sqlite3_context *context, int argc, sqlite3_value **argv); // -Wmissing-prototypes
void FMDBBlockSQLiteCallBackFunction(sqlite3_context *context, int argc, sqlite3_value **argv) {
#if ! __has_feature(objc_arc)
    void (^block)(sqlite3_context *context, int argc, sqlite3_value **argv) = (id)sqlite3_user_data(context);
#else
    void (^block)(sqlite3_context *context, int argc, sqlite3_value **argv) = (__bridge id)sqlite3_user_data(context);
#endif
    if (block) {
        @autoreleasepool {
            block(context, argc, argv);
        }
    }
}

// deprecated because "arguments" parameter is not maximum argument count, but actual argument count.

- (void)makeFunctionNamed:(NSString *)name maximumArguments:(int)arguments withBlock:(void (^)(void *context, int argc, void **argv))block {
    [self makeFunctionNamed:name arguments:arguments block:block];
}

- (void)makeFunctionNamed:(NSString *)name arguments:(int)arguments block:(void (^)(void *context, int argc, void **argv))block {
    
    if (!_openFunctions) {
        _openFunctions = [NSMutableSet new];
    }
    
    id b = FMDBReturnAutoreleased([block copy]);
    
    [_openFunctions addObject:b];
    
    /* I tried adding custom functions to release the block when the connection is destroyed- but they seemed to never be called, so we use _openFunctions to store the values instead. */
#if ! __has_feature(objc_arc)
    sqlite3_create_function([self sqliteHandle], [name UTF8String], arguments, SQLITE_UTF8, (void*)b, &FMDBBlockSQLiteCallBackFunction, 0x00, 0x00);
#else
    sqlite3_create_function([self sqliteHandle], [name UTF8String], arguments, SQLITE_UTF8, (__bridge void*)b, &FMDBBlockSQLiteCallBackFunction, 0x00, 0x00);
#endif
}

- (SqliteValueType)valueType:(void *)value {
    return sqlite3_value_type(value);
}

- (int)valueInt:(void *)value {
    return sqlite3_value_int(value);
}

- (long long)valueLong:(void *)value {
    return sqlite3_value_int64(value);
}

- (double)valueDouble:(void *)value {
    return sqlite3_value_double(value);
}

- (NSData *)valueData:(void *)value {
    const void *bytes = sqlite3_value_blob(value);
    int length = sqlite3_value_bytes(value);
    return bytes ? [NSData dataWithBytes:bytes length:(NSUInteger)length] : nil;
}

- (NSString *)valueString:(void *)value {
    const char *cString = (const char *)sqlite3_value_text(value);
    return cString ? [NSString stringWithUTF8String:cString] : nil;
}

- (void)resultNullInContext:(void *)context {
    sqlite3_result_null(context);
}

- (void)resultInt:(int) value context:(void *)context {
    sqlite3_result_int(context, value);
}

- (void)resultLong:(long long)value context:(void *)context {
    sqlite3_result_int64(context, value);
}

- (void)resultDouble:(double)value context:(void *)context {
    sqlite3_result_double(context, value);
}

- (void)resultData:(NSData *)data context:(void *)context {
    sqlite3_result_blob(context, data.bytes, (int)data.length, SQLITE_TRANSIENT);
}

- (void)resultString:(NSString *)value context:(void *)context {
    sqlite3_result_text(context, [value UTF8String], -1, SQLITE_TRANSIENT);
}

- (void)resultError:(NSString *)error context:(void *)context {
    sqlite3_result_error(context, [error UTF8String], -1);
}

- (void)resultErrorCode:(int)errorCode context:(void *)context {
    sqlite3_result_error_code(context, errorCode);
}

- (void)resultErrorNoMemoryInContext:(void *)context {
    sqlite3_result_error_nomem(context);
}

- (void)resultErrorTooBigInContext:(void *)context {
    sqlite3_result_error_toobig(context);
}

@end

// MARK: - FMStatement

@implementation FMStatement

#if ! __has_feature(objc_arc)
- (void)finalize {
    [self close];
    [super finalize];
}
#endif

- (void)dealloc {
    [self close];
    FMDBRelease(_query);
#if ! __has_feature(objc_arc)
    [super dealloc];
#endif
}

- (void)close {
    if (_statement) {
        sqlite3_finalize(_statement);
        _statement = 0x00;
    }
    _inUse = NO;
}

// reset 会在新的查询开始的时候设置.
- (void)reset {
    if (_statement) {
        sqlite3_reset(_statement);
    }
    _inUse = NO;
}

- (NSString*)description {
    return [NSString stringWithFormat:@"%@ %ld hit(s) for query %@", [super description], _useCount, _query];
}

@end

