//
//  YYKVStorage.m
//  YYKit <https://github.com/ibireme/YYKit>
//
//  Created by ibireme on 15/4/22.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "YYKVStorage.h"
#import "UIApplication+YYAdd.h"
#import <UIKit/UIKit.h>
#import <time.h>

#if __has_include(<sqlite3.h>)
#import <sqlite3.h>
#else
#import "sqlite3.h"
#endif


static const NSUInteger kMaxErrorRetryCount = 8;
static const NSTimeInterval kMinRetryTimeInterval = 2.0;
static const int kPathLengthMax = PATH_MAX - 64;
static NSString *const kDBFileName = @"manifest.sqlite";
static NSString *const kDBShmFileName = @"manifest.sqlite-shm";
static NSString *const kDBWalFileName = @"manifest.sqlite-wal";
static NSString *const kDataDirectoryName = @"data";
static NSString *const kTrashDirectoryName = @"trash";

/*
 File:
 /path/
 /manifest.sqlite
 /manifest.sqlite-shm
 /manifest.sqlite-wal
 /data/
 /e10adc3949ba59abbe56e057f20f883e
 /e10adc3949ba59abbe56e057f20f883e
 /trash/
 /unused_file_or_folder
 
 SQL:
 create table if not exists manifest (
 key                 text,
 filename            text,
 size                integer,
 inline_data         blob,
 modification_time   integer,
 last_access_time    integer,
 extended_data       blob,
 primary key(key)
 ); 
 create index if not exists last_access_time_idx on manifest(last_access_time);
 */

@implementation YYKVStorageItem
@end

@implementation YYKVStorage {
    dispatch_queue_t _trashQueue;
    
    NSString *_path;
    NSString *_dbPath;
    NSString *_dataPath;
    NSString *_trashPath;
    
    sqlite3 *_db;
    CFMutableDictionaryRef _dbStmtCache;
    NSTimeInterval _dbLastOpenErrorTime;
    NSUInteger _dbOpenErrorCount;
}


#pragma mark - db

- (BOOL)_dbOpen {
    if (_db) return YES;
    int result = sqlite3_open(_dbPath.UTF8String, &_db);
    if (result == SQLITE_OK) {
        CFDictionaryKeyCallBacks keyCallbacks = kCFCopyStringDictionaryKeyCallBacks;
        CFDictionaryValueCallBacks valueCallbacks = {0};
        _dbStmtCache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &keyCallbacks, &valueCallbacks);
        _dbLastOpenErrorTime = 0;
        _dbOpenErrorCount = 0;
        return YES;
    } else {
        _db = NULL;
        if (_dbStmtCache) CFRelease(_dbStmtCache);
        _dbStmtCache = NULL;
        _dbLastOpenErrorTime = CACurrentMediaTime();
        _dbOpenErrorCount++;
        
        if (_errorLogsEnabled) {
            NSLog(@"%s line:%d sqlite open failed (%d).", __FUNCTION__, __LINE__, result);
        }
        return NO;
    }
}

- (BOOL)_dbClose {
    if (!_db) return YES;
    
    int  result = 0;
    BOOL retry = NO;
    BOOL stmtFinalized = NO;
    
    if (_dbStmtCache) CFRelease(_dbStmtCache);
    _dbStmtCache = NULL;
    
    do {
        retry = NO;
        result = sqlite3_close(_db);
        if (result == SQLITE_BUSY || result == SQLITE_LOCKED) {
            if (!stmtFinalized) {
                stmtFinalized = YES;
                sqlite3_stmt *stmt;
                while ((stmt = sqlite3_next_stmt(_db, nil)) != 0) {
                    sqlite3_finalize(stmt);
                    retry = YES;
                }
            }
        } else if (result != SQLITE_OK) {
            if (_errorLogsEnabled) {
                NSLog(@"%s line:%d sqlite close failed (%d).", __FUNCTION__, __LINE__, result);
            }
        }
    } while (retry);
    _db = NULL;
    return YES;
}

- (BOOL)_dbCheck {
    if (!_db) {
        if (_dbOpenErrorCount < kMaxErrorRetryCount &&
            CACurrentMediaTime() - _dbLastOpenErrorTime > kMinRetryTimeInterval) {
            return [self _dbOpen] && [self _dbInitialize];
        } else {
            return NO;
        }
    }
    return YES;
}

- (BOOL)_dbInitialize {
    NSString *sql = @"pragma journal_mode = wal; pragma synchronous = normal;\
    create table if not exists manifest (\
    key text,\
    filename text,\
    size integer,\
    inline_data blob,\
    modification_time integer,\
    last_access_time integer,\
    extended_data blob,\
    primary key(key)); \
    create index if not exists last_access_time_idx on manifest(last_access_time);";
    return [self _dbExecute:sql];
}

- (void)_dbCheckpoint {
    if (![self _dbCheck]) return;
    // Cause a checkpoint to occur, merge `sqlite-wal` file to `sqlite` file.
    sqlite3_wal_checkpoint(_db, NULL);
}

- (BOOL)_dbExecute:(NSString *)sql {
    if (sql.length == 0) return NO;
    if (![self _dbCheck]) return NO;
    
    char *error = NULL;
    int result = sqlite3_exec(_db, sql.UTF8String, NULL, NULL, &error);
    if (error) {
        if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite exec error (%d): %s", __FUNCTION__, __LINE__, result, error);
        sqlite3_free(error);
    }
    
    return result == SQLITE_OK;
}

// 这里没有太明白为了什么, 难道是 sqlite 必须要进行 prepare 才能进行执行吗
- (sqlite3_stmt *)_dbPrepareStmt:(NSString *)sql {
    if (![self _dbCheck] || sql.length == 0 || !_dbStmtCache) return NULL;
    sqlite3_stmt *stmt = (sqlite3_stmt *)CFDictionaryGetValue(_dbStmtCache, (__bridge const void *)(sql));
    if (!stmt) {
        int result = sqlite3_prepare_v2(_db, sql.UTF8String, -1, &stmt, NULL);
        if (result != SQLITE_OK) {
            if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite stmt prepare error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
            return NULL;
        }
        CFDictionarySetValue(_dbStmtCache, (__bridge const void *)(sql), stmt);
    } else {
        sqlite3_reset(stmt);
    }
    return stmt;
}

// 简简单单的进行字符串的拼接.
- (NSString *)_dbJoinedKeys:(NSArray *)keys {
    NSMutableString *string = [NSMutableString new];
    for (NSUInteger i = 0,max = keys.count; i < max; i++) {
        [string appendString:@"?"];
        if (i + 1 != max) {
            [string appendString:@","];
        }
    }
    return string;
}

- (void)_dbBindJoinedKeys:(NSArray *)keys stmt:(sqlite3_stmt *)stmt fromIndex:(int)index{
    for (int i = 0, max = (int)keys.count; i < max; i++) {
        NSString *key = keys[i];
        sqlite3_bind_text(stmt, index + i, key.UTF8String, -1, NULL);
    }
}

- (BOOL)_dbSaveWithKey:(NSString *)key value:(NSData *)value fileName:(NSString *)fileName extendedData:(NSData *)extendedData {
    NSString *sql = @"insert or replace into manifest (key, filename, size, inline_data, modification_time, last_access_time, extended_data) values (?1, ?2, ?3, ?4, ?5, ?6, ?7);";
    sqlite3_stmt *stmt = [self _dbPrepareStmt:sql];
    if (!stmt) return NO;
    
    // 对于 insert SQL 的各个参数, 进行绑定.
    int timestamp = (int)time(NULL);
    sqlite3_bind_text(stmt, 1, key.UTF8String, -1, NULL);
    sqlite3_bind_text(stmt, 2, fileName.UTF8String, -1, NULL);
    sqlite3_bind_int(stmt, 3, (int)value.length);
    // 如果没有外部存储, 那么就是 value 的值就存到数据库中.
    if (fileName.length == 0) {
        sqlite3_bind_blob(stmt, 4, value.bytes, (int)value.length, 0);
    } else {
        // 如果有了外部存储, 那么久不会存储二进制的值到数据库总.
        sqlite3_bind_blob(stmt, 4, NULL, 0, 0);
    }
    // 对于保存操作, 创建时间, 和最后的修改时间是一样的.
    sqlite3_bind_int(stmt, 5, timestamp);
    sqlite3_bind_int(stmt, 6, timestamp);
    sqlite3_bind_blob(stmt, 7, extendedData.bytes, (int)extendedData.length, 0);
    
    // 执行 SQL 语句.
    int result = sqlite3_step(stmt);
    if (result != SQLITE_DONE) {
        if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite insert error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        return NO;
    }
    return YES;
}

- (BOOL)_dbUpdateAccessTimeWithKey:(NSString *)key {
    NSString *sql = @"update manifest set last_access_time = ?1 where key = ?2;";
    sqlite3_stmt *stmt = [self _dbPrepareStmt:sql];
    if (!stmt) return NO;
    sqlite3_bind_int(stmt, 1, (int)time(NULL));
    sqlite3_bind_text(stmt, 2, key.UTF8String, -1, NULL);
    int result = sqlite3_step(stmt);
    if (result != SQLITE_DONE) {
        if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite update error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        return NO;
    }
    return YES;
}

- (BOOL)_dbUpdateAccessTimeWithKeys:(NSArray *)keys {
    if (![self _dbCheck]) return NO;
    int t = (int)time(NULL);
    NSString *sql = [NSString stringWithFormat:@"update manifest set last_access_time = %d where key in (%@);", t, [self _dbJoinedKeys:keys]];
    
    sqlite3_stmt *stmt = NULL;
    int result = sqlite3_prepare_v2(_db, sql.UTF8String, -1, &stmt, NULL);
    if (result != SQLITE_OK) {
        if (_errorLogsEnabled)  NSLog(@"%s line:%d sqlite stmt prepare error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        return NO;
    }
    
    [self _dbBindJoinedKeys:keys stmt:stmt fromIndex:1];
    result = sqlite3_step(stmt);
    sqlite3_finalize(stmt);
    if (result != SQLITE_DONE) {
        if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite update error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        return NO;
    }
    return YES;
}

- (BOOL)_dbDeleteItemWithKey:(NSString *)key {
    NSString *sql = @"delete from manifest where key = ?1;";
    sqlite3_stmt *stmt = [self _dbPrepareStmt:sql];
    if (!stmt) return NO;
    sqlite3_bind_text(stmt, 1, key.UTF8String, -1, NULL);
    
    int result = sqlite3_step(stmt);
    if (result != SQLITE_DONE) {
        if (_errorLogsEnabled) NSLog(@"%s line:%d db delete error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        return NO;
    }
    return YES;
}

// 这里, 直接调用了 where key in (%@) 这样的方式.
- (BOOL)_dbDeleteItemWithKeys:(NSArray *)keys {
    if (![self _dbCheck]) return NO;
    NSString *sql =  [NSString stringWithFormat:@"delete from manifest where key in (%@);", [self _dbJoinedKeys:keys]];
    sqlite3_stmt *stmt = NULL;
    int result = sqlite3_prepare_v2(_db, sql.UTF8String, -1, &stmt, NULL);
    if (result != SQLITE_OK) {
        if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite stmt prepare error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        return NO;
    }
    
    [self _dbBindJoinedKeys:keys stmt:stmt fromIndex:1];
    result = sqlite3_step(stmt);
    sqlite3_finalize(stmt);
    if (result == SQLITE_ERROR) {
        if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite delete error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        return NO;
    }
    return YES;
}

- (BOOL)_dbDeleteItemsWithSizeLargerThan:(int)size {
    // 直接就是根据数据库里面的数据进行删除, 数据的意义就在于, 可以加快算法的结构, 当然可以通过读取整个数据获取到数据的大小, 但是, 进行存储了之后, 才能让整个容器工具类变为可用的工具类.
    NSString *sql = @"delete from manifest where size > ?1;";
    sqlite3_stmt *stmt = [self _dbPrepareStmt:sql];
    if (!stmt) return NO;
    sqlite3_bind_int(stmt, 1, size);
    int result = sqlite3_step(stmt);
    if (result != SQLITE_DONE) {
        if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite delete error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        return NO;
    }
    return YES;
}

- (BOOL)_dbDeleteItemsWithTimeEarlierThan:(int)time {
    // 根据数据库里面的 time 进行筛选.
    NSString *sql = @"delete from manifest where last_access_time < ?1;";
    sqlite3_stmt *stmt = [self _dbPrepareStmt:sql];
    if (!stmt) return NO;
    sqlite3_bind_int(stmt, 1, time);
    int result = sqlite3_step(stmt);
    if (result != SQLITE_DONE) {
        if (_errorLogsEnabled)  NSLog(@"%s line:%d sqlite delete error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        return NO;
    }
    return YES;
}

- (YYKVStorageItem *)_dbGetItemFromStmt:(sqlite3_stmt *)stmt excludeInlineData:(BOOL)excludeInlineData {
    int i = 0;
    char *key = (char *)sqlite3_column_text(stmt, i++);
    char *filename = (char *)sqlite3_column_text(stmt, i++);
    int size = sqlite3_column_int(stmt, i++);
    const void *inline_data = excludeInlineData ? NULL : sqlite3_column_blob(stmt, i);
    int inline_data_bytes = excludeInlineData ? 0 : sqlite3_column_bytes(stmt, i++);
    int modification_time = sqlite3_column_int(stmt, i++);
    int last_access_time = sqlite3_column_int(stmt, i++);
    const void *extended_data = sqlite3_column_blob(stmt, i);
    int extended_data_bytes = sqlite3_column_bytes(stmt, i++);
    
    YYKVStorageItem *item = [YYKVStorageItem new];
    if (key) item.key = [NSString stringWithUTF8String:key];
    if (filename && *filename != 0) item.filename = [NSString stringWithUTF8String:filename];
    item.size = size;
    if (inline_data_bytes > 0 && inline_data) item.value = [NSData dataWithBytes:inline_data length:inline_data_bytes];
    item.modTime = modification_time;
    item.accessTime = last_access_time;
    if (extended_data_bytes > 0 && extended_data) item.extendedData = [NSData dataWithBytes:extended_data length:extended_data_bytes];
    return item;
}

- (YYKVStorageItem *)_dbGetItemWithKey:(NSString *)key excludeInlineData:(BOOL)excludeInlineData {
    NSString *sql = excludeInlineData ? @"select key, filename, size, modification_time, last_access_time, extended_data from manifest where key = ?1;" : @"select key, filename, size, inline_data, modification_time, last_access_time, extended_data from manifest where key = ?1;";
    sqlite3_stmt *stmt = [self _dbPrepareStmt:sql];
    if (!stmt) return nil;
    sqlite3_bind_text(stmt, 1, key.UTF8String, -1, NULL);
    
    YYKVStorageItem *item = nil;
    int result = sqlite3_step(stmt);
    if (result == SQLITE_ROW) {
        item = [self _dbGetItemFromStmt:stmt excludeInlineData:excludeInlineData];
    } else {
        if (result != SQLITE_DONE) {
            if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite query error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        }
    }
    return item;
}

- (NSMutableArray *)_dbGetItemWithKeys:(NSArray *)keys excludeInlineData:(BOOL)excludeInlineData {
    if (![self _dbCheck]) return nil;
    NSString *sql;
    if (excludeInlineData) {
        sql = [NSString stringWithFormat:@"select key, filename, size, modification_time, last_access_time, extended_data from manifest where key in (%@);", [self _dbJoinedKeys:keys]];
    } else {
        sql = [NSString stringWithFormat:@"select key, filename, size, inline_data, modification_time, last_access_time, extended_data from manifest where key in (%@)", [self _dbJoinedKeys:keys]];
    }
    
    sqlite3_stmt *stmt = NULL;
    int result = sqlite3_prepare_v2(_db, sql.UTF8String, -1, &stmt, NULL);
    if (result != SQLITE_OK) {
        if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite stmt prepare error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        return nil;
    }
    
    [self _dbBindJoinedKeys:keys stmt:stmt fromIndex:1];
    NSMutableArray *items = [NSMutableArray new];
    do {
        result = sqlite3_step(stmt);
        if (result == SQLITE_ROW) {
            YYKVStorageItem *item = [self _dbGetItemFromStmt:stmt excludeInlineData:excludeInlineData];
            if (item) [items addObject:item];
        } else if (result == SQLITE_DONE) {
            break;
        } else {
            if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite query error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
            items = nil;
            break;
        }
    } while (1);
    sqlite3_finalize(stmt);
    return items;
}

- (NSData *)_dbGetValueWithKey:(NSString *)key {
    NSString *sql = @"select inline_data from manifest where key = ?1;";
    sqlite3_stmt *stmt = [self _dbPrepareStmt:sql];
    if (!stmt) return nil;
    sqlite3_bind_text(stmt, 1, key.UTF8String, -1, NULL);
    
    int result = sqlite3_step(stmt);
    if (result == SQLITE_ROW) {
        const void *inline_data = sqlite3_column_blob(stmt, 0);
        int inline_data_bytes = sqlite3_column_bytes(stmt, 0);
        if (!inline_data || inline_data_bytes <= 0) return nil;
        return [NSData dataWithBytes:inline_data length:inline_data_bytes];
    } else {
        if (result != SQLITE_DONE) {
            if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite query error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        }
        return nil;
    }
}

- (NSString *)_dbGetFilenameWithKey:(NSString *)key {
    NSString *sql = @"select filename from manifest where key = ?1;";
    sqlite3_stmt *stmt = [self _dbPrepareStmt:sql];
    if (!stmt) return nil;
    sqlite3_bind_text(stmt, 1, key.UTF8String, -1, NULL);
    int result = sqlite3_step(stmt);
    if (result == SQLITE_ROW) {
        char *filename = (char *)sqlite3_column_text(stmt, 0);
        if (filename && *filename != 0) {
            return [NSString stringWithUTF8String:filename];
        }
    } else {
        if (result != SQLITE_DONE) {
            if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite query error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        }
    }
    return nil;
}

- (NSMutableArray *)_dbGetFilenameWithKeys:(NSArray *)keys {
    if (![self _dbCheck]) return nil;
    NSString *sql = [NSString stringWithFormat:@"select filename from manifest where key in (%@);", [self _dbJoinedKeys:keys]];
    sqlite3_stmt *stmt = NULL;
    int result = sqlite3_prepare_v2(_db, sql.UTF8String, -1, &stmt, NULL);
    if (result != SQLITE_OK) {
        if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite stmt prepare error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        return nil;
    }
    
    [self _dbBindJoinedKeys:keys stmt:stmt fromIndex:1];
    NSMutableArray *filenames = [NSMutableArray new];
    do {
        result = sqlite3_step(stmt);
        if (result == SQLITE_ROW) {
            char *filename = (char *)sqlite3_column_text(stmt, 0);
            if (filename && *filename != 0) {
                NSString *name = [NSString stringWithUTF8String:filename];
                if (name) [filenames addObject:name];
            }
        } else if (result == SQLITE_DONE) {
            break;
        } else {
            if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite query error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
            filenames = nil;
            break;
        }
    } while (1);
    sqlite3_finalize(stmt);
    return filenames;
}

- (NSMutableArray *)_dbGetFilenamesWithSizeLargerThan:(int)size {
    // 还是通过数据库的 size, 来获取所有的文件.
    NSString *sql = @"select filename from manifest where size > ?1 and filename is not null;";
    sqlite3_stmt *stmt = [self _dbPrepareStmt:sql];
    if (!stmt) return nil;
    sqlite3_bind_int(stmt, 1, size);
    
    NSMutableArray *filenames = [NSMutableArray new];
    do {
        // 一个查询操作, 怎么变成 OC 中的数据呢, 这里给出了答案.
        int result = sqlite3_step(stmt);
        if (result == SQLITE_ROW) {
            char *filename = (char *)sqlite3_column_text(stmt, 0);
            if (filename && *filename != 0) {
                NSString *name = [NSString stringWithUTF8String:filename];
                if (name) [filenames addObject:name];
            }
        } else if (result == SQLITE_DONE) {
            break;
        } else {
            if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite query error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
            filenames = nil;
            break;
        }
    } while (1);
    return filenames;
}

- (NSMutableArray *)_dbGetFilenamesWithTimeEarlierThan:(int)time {
    NSString *sql = @"select filename from manifest where last_access_time < ?1 and filename is not null;";
    sqlite3_stmt *stmt = [self _dbPrepareStmt:sql];
    if (!stmt) return nil;
    sqlite3_bind_int(stmt, 1, time);
    
    NSMutableArray *filenames = [NSMutableArray new];
    do {
        int result = sqlite3_step(stmt);
        if (result == SQLITE_ROW) {
            char *filename = (char *)sqlite3_column_text(stmt, 0);
            if (filename && *filename != 0) {
                NSString *name = [NSString stringWithUTF8String:filename];
                if (name) [filenames addObject:name];
            }
        } else if (result == SQLITE_DONE) {
            break;
        } else {
            if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite query error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
            filenames = nil;
            break;
        }
    } while (1);
    return filenames;
}

- (NSMutableArray *)_dbGetItemSizeInfoOrderByTimeAscWithLimit:(int)count {
    // 这里, 根据最后的访问时间, 从数据库里面读取数据. 并且最后生成 item 对象.
    NSString *sql = @"select key, filename, size from manifest order by last_access_time asc limit ?1;";
    sqlite3_stmt *stmt = [self _dbPrepareStmt:sql];
    if (!stmt) return nil;
    sqlite3_bind_int(stmt, 1, count);
    
    NSMutableArray *items = [NSMutableArray new];
    do {
        int result = sqlite3_step(stmt);
        if (result == SQLITE_ROW) {
            char *key = (char *)sqlite3_column_text(stmt, 0);
            char *filename = (char *)sqlite3_column_text(stmt, 1);
            int size = sqlite3_column_int(stmt, 2);
            NSString *keyStr = key ? [NSString stringWithUTF8String:key] : nil;
            if (keyStr) {
                YYKVStorageItem *item = [YYKVStorageItem new];
                item.key = key ? [NSString stringWithUTF8String:key] : nil;
                item.filename = filename ? [NSString stringWithUTF8String:filename] : nil;
                item.size = size;
                [items addObject:item];
            }
        } else if (result == SQLITE_DONE) {
            break;
        } else {
            if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite query error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
            items = nil;
            break;
        }
    } while (1);
    return items;
}

- (int)_dbGetItemCountWithKey:(NSString *)key {
    NSString *sql = @"select count(key) from manifest where key = ?1;";
    sqlite3_stmt *stmt = [self _dbPrepareStmt:sql];
    if (!stmt) return -1;
    sqlite3_bind_text(stmt, 1, key.UTF8String, -1, NULL);
    int result = sqlite3_step(stmt);
    if (result != SQLITE_ROW) {
        if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite query error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        return -1;
    }
    return sqlite3_column_int(stmt, 0);
}

- (int)_dbGetTotalItemSize {
    // 根据数据库中的 size sum, 返回最后的和.
    NSString *sql = @"select sum(size) from manifest;";
    sqlite3_stmt *stmt = [self _dbPrepareStmt:sql];
    if (!stmt) return -1;
    int result = sqlite3_step(stmt);
    if (result != SQLITE_ROW) {
        if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite query error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        return -1;
    }
    return sqlite3_column_int(stmt, 0);
}

- (int)_dbGetTotalItemCount {
    NSString *sql = @"select count(*) from manifest;";
    sqlite3_stmt *stmt = [self _dbPrepareStmt:sql];
    if (!stmt) return -1;
    int result = sqlite3_step(stmt);
    if (result != SQLITE_ROW) {
        if (_errorLogsEnabled) NSLog(@"%s line:%d sqlite query error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_db));
        return -1;
    }
    return sqlite3_column_int(stmt, 0);
}


#pragma mark - file

// 简单的二进制文件的存储.
- (BOOL)_fileWriteWithName:(NSString *)filename data:(NSData *)data {
    // 根据 filename 进行存储.
    NSString *path = [_dataPath stringByAppendingPathComponent:filename];
    return [data writeToFile:path atomically:NO];
}

// 简单的分局 fileName 进行读取的操作.
- (NSData *)_fileReadWithName:(NSString *)filename {
    NSString *path = [_dataPath stringByAppendingPathComponent:filename];
    NSData *data = [NSData dataWithContentsOfFile:path];
    return data;
}

// 简单的删除操作.
- (BOOL)_fileDeleteWithName:(NSString *)filename {
    NSString *path = [_dataPath stringByAppendingPathComponent:filename];
    return [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
}

- (BOOL)_fileMoveAllToTrash {
    CFUUIDRef uuidRef = CFUUIDCreate(NULL);
    CFStringRef uuid = CFUUIDCreateString(NULL, uuidRef);
    CFRelease(uuidRef);
    NSString *tmpPath = [_trashPath stringByAppendingPathComponent:(__bridge NSString *)(uuid)];
    BOOL suc = [[NSFileManager defaultManager] moveItemAtPath:_dataPath toPath:tmpPath error:nil];
    if (suc) {
        suc = [[NSFileManager defaultManager] createDirectoryAtPath:_dataPath withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    CFRelease(uuid);
    return suc;
}

- (void)_fileEmptyTrashInBackground {
    NSString *trashPath = _trashPath;
    dispatch_queue_t queue = _trashQueue;
    dispatch_async(queue, ^{
        NSFileManager *manager = [NSFileManager new];
        NSArray *directoryContents = [manager contentsOfDirectoryAtPath:trashPath error:NULL];
        for (NSString *path in directoryContents) {
            NSString *fullPath = [trashPath stringByAppendingPathComponent:path];
            [manager removeItemAtPath:fullPath error:NULL];
        }
    });
}


#pragma mark - private

/**
 Delete all files and empty in background.
 Make sure the db is closed.
 */
- (void)_reset {
    [[NSFileManager defaultManager] removeItemAtPath:[_path stringByAppendingPathComponent:kDBFileName] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[_path stringByAppendingPathComponent:kDBShmFileName] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[_path stringByAppendingPathComponent:kDBWalFileName] error:nil];
    [self _fileMoveAllToTrash];
    [self _fileEmptyTrashInBackground];
}

#pragma mark - public

- (instancetype)init {
    @throw [NSException exceptionWithName:@"YYKVStorage init error" reason:@"Please use the designated initializer and pass the 'path' and 'type'." userInfo:nil];
    return [self initWithPath:@"" type:YYKVStorageTypeFile];
}

// 在 init 方法里面, 封装所有的初始化操作.
- (instancetype)initWithPath:(NSString *)path type:(YYKVStorageType)type {
    // 首先是两个防卫式的判断语句.
    if (path.length == 0 || path.length > kPathLengthMax) {
        NSLog(@"YYKVStorage init error: invalid path: [%@].", path);
        return nil;
    }
    if (type > YYKVStorageTypeMixed) {
        NSLog(@"YYKVStorage init error: invalid type: %lu.", (unsigned long)type);
        return nil;
    }
    
    self = [super init];
    _path = path.copy;
    _type = type;
    // 所有的文件, 都是在一个固定的路径下面, 这个路径, 应该由类内部进行管理.
    // 所有的文件, 都建立在 path 的基础上. 所以, path 不会是最终的各个数据文件的路径, 而是他们的前缀
    _dataPath = [path stringByAppendingPathComponent:kDataDirectoryName];
    _trashPath = [path stringByAppendingPathComponent:kTrashDirectoryName];
    _trashQueue = dispatch_queue_create("com.ibireme.cache.disk.trash", DISPATCH_QUEUE_SERIAL);
    _dbPath = [path stringByAppendingPathComponent:kDBFileName];
    _errorLogsEnabled = YES;
    NSError *error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:path
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:&error] ||
        ![[NSFileManager defaultManager] createDirectoryAtPath:[path stringByAppendingPathComponent:kDataDirectoryName]
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:&error] ||
        ![[NSFileManager defaultManager] createDirectoryAtPath:[path stringByAppendingPathComponent:kTrashDirectoryName]
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:&error]) {
        NSLog(@"YYKVStorage init error:%@", error);
        return nil;
    }
    
    if (![self _dbOpen] || ![self _dbInitialize]) {
        // db file may broken...
        [self _dbClose];
        [self _reset]; // rebuild
        if (![self _dbOpen] || ![self _dbInitialize]) {
            [self _dbClose];
            NSLog(@"YYKVStorage init error: fail to open sqlite db.");
            return nil;
        }
    }
    [self _fileEmptyTrashInBackground]; // empty the trash if failed at last time
    return self;
}

- (void)dealloc {
    UIBackgroundTaskIdentifier taskID = [[UIApplication sharedExtensionApplication] beginBackgroundTaskWithExpirationHandler:^{}];
    [self _dbClose];
    if (taskID != UIBackgroundTaskInvalid) {
        [[UIApplication sharedExtensionApplication] endBackgroundTask:taskID];
    }
}

#pragma mark - Save

- (BOOL)saveItem:(YYKVStorageItem *)item {
    return [self saveItemWithKey:item.key value:item.value filename:item.filename extendedData:item.extendedData];
}

- (BOOL)saveItemWithKey:(NSString *)key value:(NSData *)value {
    return [self saveItemWithKey:key value:value filename:nil extendedData:nil];
}

- (BOOL)saveItemWithKey:(NSString *)key value:(NSData *)value filename:(NSString *)filename extendedData:(NSData *)extendedData {
    if (key.length == 0 || value.length == 0) return NO;
    if (_type == YYKVStorageTypeFile && filename.length == 0) {
        return NO;
    }
    
    if (filename.length) {
        // 如果是文件存储, 那么首先进行文件的存储工作, 然后进行数据库的存储.
        if (![self _fileWriteWithName:filename data:value]) {
            return NO;
        }
        if (![self _dbSaveWithKey:key value:value fileName:filename extendedData:extendedData]) {
            [self _fileDeleteWithName:filename];
            return NO;
        }
        return YES;
    } else {
        if (_type != YYKVStorageTypeSQLite) {
            NSString *filename = [self _dbGetFilenameWithKey:key];
            if (filename) {
                [self _fileDeleteWithName:filename];
            }
        }
        return [self _dbSaveWithKey:key value:value fileName:nil extendedData:extendedData];
    }
}

#pragma mark - Remove

- (BOOL)removeItemForKey:(NSString *)key {
    if (key.length == 0) return NO;
    switch (_type) {
        case YYKVStorageTypeSQLite: {
            // 如果是数据库存储, 那么就直接进行数据库的删除操作.
            return [self _dbDeleteItemWithKey:key];
        } break;
        case YYKVStorageTypeFile:
        case YYKVStorageTypeMixed: {
            // 如果是文件存储, 那么就先删除文件, 然后删除相应的数据库数据.
            NSString *filename = [self _dbGetFilenameWithKey:key];
            if (filename) {
                [self _fileDeleteWithName:filename];
            }
            return [self _dbDeleteItemWithKey:key];
        } break;
        default: return NO;
    }
}

- (BOOL)removeItemForKeys:(NSArray *)keys {
    if (keys.count == 0) return NO;
    switch (_type) {
        case YYKVStorageTypeSQLite: {
            return [self _dbDeleteItemWithKeys:keys];
        } break;
        case YYKVStorageTypeFile:
        case YYKVStorageTypeMixed: {
            NSArray *filenames = [self _dbGetFilenameWithKeys:keys];
            for (NSString *filename in filenames) {
                [self _fileDeleteWithName:filename];
            }
            return [self _dbDeleteItemWithKeys:keys];
        } break;
        default: return NO;
    }
}

- (BOOL)removeItemsLargerThanSize:(int)size {
    if (size == INT_MAX) return YES;
    if (size <= 0) return [self removeAllItems];
    
    switch (_type) {
        case YYKVStorageTypeSQLite: {
            if ([self _dbDeleteItemsWithSizeLargerThan:size]) {
                [self _dbCheckpoint];
                return YES;
            }
        } break;
        case YYKVStorageTypeFile:
        case YYKVStorageTypeMixed: {
            NSArray *filenames = [self _dbGetFilenamesWithSizeLargerThan:size];
            for (NSString *name in filenames) {
                [self _fileDeleteWithName:name];
            }
            if ([self _dbDeleteItemsWithSizeLargerThan:size]) {
                [self _dbCheckpoint];
                return YES;
            }
        } break;
    }
    return NO;
}

// 对于内存中的 LRU, 可以根据链表的顺序进行删减. 对于数据库里面的 LRU, 可以直接通过数据库的排序进行

- (BOOL)removeItemsEarlierThanTime:(int)time {
    if (time <= 0) return YES;
    if (time == INT_MAX) return [self removeAllItems];
    
    switch (_type) {
        case YYKVStorageTypeSQLite: {
            if ([self _dbDeleteItemsWithTimeEarlierThan:time]) {
                [self _dbCheckpoint];
                return YES;
            }
        } break;
        case YYKVStorageTypeFile:
        case YYKVStorageTypeMixed: {
            NSArray *filenames = [self _dbGetFilenamesWithTimeEarlierThan:time];
            for (NSString *name in filenames) {
                [self _fileDeleteWithName:name];
            }
            if ([self _dbDeleteItemsWithTimeEarlierThan:time]) {
                [self _dbCheckpoint];
                return YES;
            }
        } break;
    }
    return NO;
}

- (BOOL)removeItemsToFitSize:(int)maxSize {
    if (maxSize == INT_MAX) return YES;
    if (maxSize <= 0) return [self removeAllItems];
    
    int total = [self _dbGetTotalItemSize];
    if (total < 0) return NO;
    if (total <= maxSize) return YES;
    
    NSArray *items = nil;
    BOOL suc = NO;
    do {
        int perCount = 16;
        // 读取 16 条数据, 逐条进行删减, 没有一次性的读取所有的数据.
        items = [self _dbGetItemSizeInfoOrderByTimeAscWithLimit:perCount];
        for (YYKVStorageItem *item in items) {
            if (total > maxSize) {
                if (item.filename) {
                    [self _fileDeleteWithName:item.filename];
                }
                suc = [self _dbDeleteItemWithKey:item.key];
                total -= item.size;
            } else {
                break;
            }
            if (!suc) break;
        }
    } while (total > maxSize && items.count > 0 && suc);
    if (suc) [self _dbCheckpoint];
    return suc;
}

// 这个和上面 removeItemsToFitSize 是完全一样的, 只不过是 while 的判断条件, 从 size 变成了 count

- (BOOL)removeItemsToFitCount:(int)maxCount {
    if (maxCount == INT_MAX) return YES;
    if (maxCount <= 0) return [self removeAllItems];
    
    int total = [self _dbGetTotalItemCount];
    if (total < 0) return NO;
    if (total <= maxCount) return YES;
    
    NSArray *items = nil;
    BOOL suc = NO;
    do {
        int perCount = 16;
        items = [self _dbGetItemSizeInfoOrderByTimeAscWithLimit:perCount];
        for (YYKVStorageItem *item in items) {
            if (total > maxCount) {
                if (item.filename) {
                    [self _fileDeleteWithName:item.filename];
                }
                suc = [self _dbDeleteItemWithKey:item.key];
                total--;
            } else {
                break;
            }
            if (!suc) break;
        }
    } while (total > maxCount && items.count > 0 && suc);
    if (suc) [self _dbCheckpoint];
    return suc;
}

- (BOOL)removeAllItems {
    if (![self _dbClose]) return NO;
    [self _reset];
    if (![self _dbOpen]) return NO;
    if (![self _dbInitialize]) return NO;
    return YES;
}

- (void)removeAllItemsWithProgressBlock:(void(^)(int removedCount, int totalCount))progress
                               endBlock:(void(^)(BOOL error))end {
    
    int total = [self _dbGetTotalItemCount];
    if (total <= 0) {
        if (end) end(total < 0);
    } else {
        int left = total;
        int perCount = 32;
        NSArray *items = nil;
        BOOL suc = NO;
        // 这种, 逐次的取一些数据, 然后进行删减的工作, 很像是设置一个 timer, 然后每次进行一部分的工作.
        do {
            items = [self _dbGetItemSizeInfoOrderByTimeAscWithLimit:perCount];
            for (YYKVStorageItem *item in items) {
                if (left > 0) {
                    if (item.filename) {
                        [self _fileDeleteWithName:item.filename];
                    }
                    suc = [self _dbDeleteItemWithKey:item.key];
                    left--;
                } else {
                    break;
                }
                if (!suc) break;
            }
            if (progress) progress(total - left, total);
        } while (left > 0 && items.count > 0 && suc);
        if (suc) [self _dbCheckpoint];
        if (end) end(!suc);
    }
}

- (YYKVStorageItem *)getItemForKey:(NSString *)key {
    if (key.length == 0) return nil;
    YYKVStorageItem *item = [self _dbGetItemWithKey:key excludeInlineData:NO];
    if (item) {
        [self _dbUpdateAccessTimeWithKey:key];
        if (item.filename) {
            item.value = [self _fileReadWithName:item.filename];
            if (!item.value) {
                [self _dbDeleteItemWithKey:key];
                item = nil;
            }
        }
    }
    return item;
}

#pragma mark - Get

- (YYKVStorageItem *)getItemInfoForKey:(NSString *)key {
    if (key.length == 0) return nil;
    YYKVStorageItem *item = [self _dbGetItemWithKey:key excludeInlineData:YES];
    return item;
}

// get 的同时, 进行数据库的更新操作
- (NSData *)getItemValueForKey:(NSString *)key {
    if (key.length == 0) return nil;
    NSData *value = nil;
    switch (_type) {
        case YYKVStorageTypeFile: {
            NSString *filename = [self _dbGetFilenameWithKey:key];
            if (filename) {
                value = [self _fileReadWithName:filename];
                if (!value) {
                    [self _dbDeleteItemWithKey:key];
                    value = nil;
                }
            }
        } break;
        case YYKVStorageTypeSQLite: {
            value = [self _dbGetValueWithKey:key];
        } break;
        case YYKVStorageTypeMixed: {
            // 如果外部存储, 那么就按照外部的值为准, 否则, 就是数据库里面的值.
            NSString *filename = [self _dbGetFilenameWithKey:key];
            if (filename) {
                value = [self _fileReadWithName:filename];
                if (!value) {
                    [self _dbDeleteItemWithKey:key];
                    value = nil;
                }
            } else {
                value = [self _dbGetValueWithKey:key];
            }
        } break;
    }
    if (value) {
        // 更新最后的访问时间.
        [self _dbUpdateAccessTimeWithKey:key];
    }
    return value;
}

- (NSArray *)getItemForKeys:(NSArray *)keys {
    if (keys.count == 0) return nil;
    NSMutableArray *items = [self _dbGetItemWithKeys:keys excludeInlineData:NO];
    if (_type != YYKVStorageTypeSQLite) {
        for (NSInteger i = 0, max = items.count; i < max; i++) {
            YYKVStorageItem *item = items[i];
            if (item.filename) {
                item.value = [self _fileReadWithName:item.filename];
                if (!item.value) {
                    if (item.key) [self _dbDeleteItemWithKey:item.key];
                    [items removeObjectAtIndex:i];
                    i--;
                    max--;
                }
            }
        }
    }
    if (items.count > 0) {
        [self _dbUpdateAccessTimeWithKeys:keys];
    }
    return items.count ? items : nil;
}

- (NSArray *)getItemInfoForKeys:(NSArray *)keys {
    if (keys.count == 0) return nil;
    return [self _dbGetItemWithKeys:keys excludeInlineData:YES];
}

- (NSDictionary *)getItemValueForKeys:(NSArray *)keys {
    NSMutableArray *items = (NSMutableArray *)[self getItemForKeys:keys];
    NSMutableDictionary *kv = [NSMutableDictionary new];
    for (YYKVStorageItem *item in items) {
        if (item.key && item.value) {
            [kv setObject:item.value forKey:item.key];
        }
    }
    return kv.count ? kv : nil;
}

- (BOOL)itemExistsForKey:(NSString *)key {
    if (key.length == 0) return NO;
    return [self _dbGetItemCountWithKey:key] > 0;
}

- (int)getItemsCount {
    return [self _dbGetTotalItemCount];
}

- (int)getItemsSize {
    return [self _dbGetTotalItemSize];
}

@end
