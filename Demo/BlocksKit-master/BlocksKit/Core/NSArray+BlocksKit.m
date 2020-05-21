//
//  NSArray+BlocksKit.m
//  BlocksKit
//

#import "NSArray+BlocksKit.h"

@implementation NSArray (BlocksKit)

- (void)bk_each:(void (^)(id obj))block
{
	NSParameterAssert(block != nil);
    
    /*
     enumerateObjectsUsingBlock 是 NSArray 提供的功能.
     分类直接利用了该功能, 而不是自己去实现 Array 的遍历的过程. 这样, 如果源代码修改, 分类可以享受到重用的福利.
     */
    
    /*
     enumerateObjectsUsingBlock 的实现, 在 Gnu Founation 是根据 dispatch_group 实现的.
     如果是逆序, 那么遍历的时候, 就获取 reverseEnumerator.
     如果是 NSEnumerationConcurrent, 那就创建一个 dispatch_group. 然后将任务提交到一个并行
     */
	 [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		block(obj);
	}];
}

- (void)bk_apply:(void (^)(id obj))block
{
	NSParameterAssert(block != nil);

	[self enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		block(obj);
	}];
}

- (id)bk_match:(BOOL (^)(id obj))block
{
	NSParameterAssert(block != nil);

    /*
     indexOfObjectPassingTest 是除了 isEqual, identiticalTo 之外的, 提供的另外的一个可以自定义遍历条件的筛选规则.
     */
	NSUInteger index = [self indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
		return block(obj);
	}];

	if (index == NSNotFound)
		return nil;

	return self[index];
}

- (NSArray *)bk_select:(BOOL (^)(id obj))block
{
	NSParameterAssert(block != nil);
	return [self objectsAtIndexes:[self indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
		return block(obj);
	}]];
}

/*
 所以, bk_reject 的逻辑, 完全和 bk_select 一样, 不过是逻辑相反. 实现的时候, 也是用的 bk_select 的实现.
 */

- (NSArray *)bk_reject:(BOOL (^)(id obj))block
{
	NSParameterAssert(block != nil);
	return [self bk_select:^BOOL(id obj) {
		return !block(obj);
	}];
}

/*
 最经典的 map 的使用方式.
 生成一个新的数组.
 不过, 这里还是使用 enumerateObjectsUsingBlock 的方式, enumerateObjectsUsingBlock 里面, 封装了 for 循环.
 */
- (NSArray *)bk_map:(id (^)(id obj))block
{
	NSParameterAssert(block != nil);

	NSMutableArray *result = [NSMutableArray arrayWithCapacity:self.count];

	[self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		id value = block(obj) ?: [NSNull null];
		[result addObject:value];
	}];

	return result;
}

/*
 bk_compact, 会进行 nil 的排除工作.
 */
- (NSArray *)bk_compact:(id (^)(id obj))block
{
	NSParameterAssert(block != nil);
	
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:self.count];
	
	[self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		id value = block(obj);
		if(value)
		{
			[result addObject:value];
		}
	}];
	
	return result;
}

/*
 还是进行遍历操作, 结果是根据 Block 进行操作. 所有的数据, 都是 id 进行表示, 没有很好地类型保护.
 */
- (id)bk_reduce:(id)initial withBlock:(id (^)(id sum, id obj))block
{
	NSParameterAssert(block != nil);

	__block id result = initial;

	[self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		result = block(result, obj);
	}];

	return result;
}

- (NSInteger)bk_reduceInteger:(NSInteger)initial withBlock:(NSInteger (^)(NSInteger, id))block
{
	NSParameterAssert(block != nil);

	__block NSInteger result = initial;
    
	[self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		result = block(result, obj);
	}];
    
	return result;
}

/*
 专门为 Interger, 和 Float 生成了相关的 reduce 版本.
 */
- (CGFloat)bk_reduceFloat:(CGFloat)inital withBlock:(CGFloat (^)(CGFloat, id))block
{
	NSParameterAssert(block != nil);
    
	__block CGFloat result = inital;
    
	[self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		result = block(result, obj);
    }];
    
	return result;
}

/*
 根据 bk_match 的结果, 来实现这个新的逻辑函数.
 */
- (BOOL)bk_any:(BOOL (^)(id obj))block
{
	return [self bk_match:block] != nil;
}

/*
 根据 bk_match 的结果, 来实现这个新的逻辑函数.
*/
- (BOOL)bk_none:(BOOL (^)(id obj))block
{
	return [self bk_match:block] == nil;
}

/*
 为了效率, 这里要进行剪枝的操作.
 */
- (BOOL)bk_all:(BOOL (^)(id obj))block
{
	NSParameterAssert(block != nil);

	__block BOOL result = YES;

	[self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		if (!block(obj)) {
			result = NO;
			*stop = YES;
		}
	}];

	return result;
}

/*
 这里, 不应该先检查 count, 做一次剪枝操作要好一点的吗.
 */
- (BOOL)bk_corresponds:(NSArray *)list withBlock:(BOOL (^)(id obj1, id obj2))block
{
	NSParameterAssert(block != nil);

	__block BOOL result = NO;

	[self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		if (idx < list.count) {
			id obj2 = list[idx];
			result = block(obj, obj2);
		} else {
			result = NO;
		}
		*stop = !result;
	}];

	return result;
}

@end
