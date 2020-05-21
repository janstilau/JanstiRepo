//
//  NSDictionary+BlocksKit.m
//  BlocksKit
//

#import "NSDictionary+BlocksKit.h"

@implementation NSDictionary (BlocksKit)

- (void)bk_each:(void (^)(id key, id obj))block
{
	NSParameterAssert(block != nil);
	[self enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		block(key, obj);
	}];
}

- (void)bk_apply:(void (^)(id key, id obj))block
{
	NSParameterAssert(block != nil);

	[self enumerateKeysAndObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(id key, id obj, BOOL *stop) {
		block(key, obj);
	}];
}

/*
 这个函数的内部, 会有剪枝的操作.
 */
- (id)bk_match:(BOOL (^)(id key, id obj))block
{
	NSParameterAssert(block != nil);
    /*
     由于哈希表无法进行顺序的限制, 这里使用的 anyObject 进行取值. 猜测, anyObject 是根据哈希表数组的第一个链表的第一个元素进行的取值.
     */
	return self[[[self keysOfEntriesPassingTest:^(id key, id obj, BOOL *stop) {
		if (block(key, obj)) {
			*stop = YES;
			return YES;
		}
		return NO;
	}] anyObject]];
}

- (NSDictionary *)bk_select:(BOOL (^)(id key, id obj))block
{
	NSParameterAssert(block != nil);

	NSArray *keys = [[self keysOfEntriesPassingTest:^(id key, id obj, BOOL *stop) {
		return block(key, obj);
	}] allObjects];
	NSArray *objects = [self objectsForKeys:keys notFoundMarker:[NSNull null]];
    /*
     [NSDictionary dictionaryWithObjects: keys:]
     这个函数里面, 所传入的数据是和顺序相关的.
     */
	return [NSDictionary dictionaryWithObjects:objects forKeys:keys];
}

- (NSDictionary *)bk_reject:(BOOL (^)(id key, id obj))block
{
	NSParameterAssert(block != nil);
	return [self bk_select:^BOOL(id key, id obj) {
		return !block(key, obj);
	}];
}

- (NSDictionary *)bk_map:(id (^)(id key, id obj))block
{
	NSParameterAssert(block != nil);
    /*
     提前进行 capacity 的指定, 提前进行空间的分配工作.
     */
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:self.count];
	[self bk_each:^(id key, id obj) {
		id value = block(key, obj) ?: [NSNull null];
		result[key] = value;
	}];

	return result;
}

- (BOOL)bk_any:(BOOL (^)(id key, id obj))block
{
	return [self bk_match:block] != nil;
}

- (BOOL)bk_none:(BOOL (^)(id key, id obj))block
{
	return [self bk_match:block] == nil;
}

- (BOOL)bk_all:(BOOL (^)(id key, id obj))block
{
	NSParameterAssert(block != nil);
	__block BOOL result = YES;
	[self enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		if (!block(key, obj)) {
			result = NO;
			*stop = YES;
		}
	}];
	return result;
}

@end
