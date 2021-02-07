#ifndef __DISPATCH_ONCE__
#define __DISPATCH_ONCE__

#ifndef __DISPATCH_INDIRECT__
#error "Please #include <dispatch/dispatch.h> instead of this file directly."
#include <dispatch/base.h> // for HeaderDoc
#endif

DISPATCH_ASSUME_NONNULL_BEGIN

__BEGIN_DECLS

/*!
 * @typedef dispatch_once_t
 *
 * @abstract
 * A predicate for use with dispatch_once(). It must be initialized to zero.
 * Note: static and global variables default to zero.
 *
 */
DISPATCH_SWIFT3_UNAVAILABLE("Use lazily initialized globals instead")
typedef intptr_t dispatch_once_t;

#if defined(__x86_64__) || defined(__i386__) || defined(__s390x__)
#define DISPATCH_ONCE_INLINE_FASTPATH 1
#elif defined(__APPLE__)
#define DISPATCH_ONCE_INLINE_FASTPATH 1
#else
#define DISPATCH_ONCE_INLINE_FASTPATH 0
#endif

/*!
 * @function dispatch_once
 *
 * @abstract
 * Execute a block once and only once.
 *
 * @param predicate
 * A pointer to a dispatch_once_t that is used to test whether the block has
 * completed or not.
 *
 * @param block
 * The block to execute once.
 *
 * @discussion
 * Always call dispatch_once() before using or testing any variables that are
 * initialized by the block.
 *
 *  所以, 其实这就是一个全局的 Bool 值, 然后每次都判断一下这个值, 如果没有执行过, 就执行 block 的代码. 和我们平时写的代码没有太大的区别.
 */
#ifdef __BLOCKS__
API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_NONNULL_ALL DISPATCH_NOTHROW
DISPATCH_SWIFT3_UNAVAILABLE("Use lazily initialized globals instead")
void
dispatch_once(dispatch_once_t *predicate,
			  DISPATCH_NOESCAPE dispatch_block_t block);

#if DISPATCH_ONCE_INLINE_FASTPATH
DISPATCH_INLINE DISPATCH_ALWAYS_INLINE DISPATCH_NONNULL_ALL DISPATCH_NOTHROW
DISPATCH_SWIFT3_UNAVAILABLE("Use lazily initialized globals instead")
void
_dispatch_once(dispatch_once_t *predicate,
			   DISPATCH_NOESCAPE dispatch_block_t block)
{
	if (DISPATCH_EXPECT(*predicate, ~0l) != ~0l) {
		dispatch_once(predicate, block);
	} else {
		dispatch_compiler_barrier();
	}
	DISPATCH_COMPILER_CAN_ASSUME(*predicate == ~0l);
}
#undef dispatch_once
#define dispatch_once _dispatch_once
#endif
#endif // DISPATCH_ONCE_INLINE_FASTPATH

API_AVAILABLE(macos(10.6), ios(4.0))
DISPATCH_EXPORT DISPATCH_NONNULL1 DISPATCH_NONNULL3 DISPATCH_NOTHROW
DISPATCH_SWIFT3_UNAVAILABLE("Use lazily initialized globals instead")
void
dispatch_once_f(dispatch_once_t *predicate, void *_Nullable context,
				dispatch_function_t function);

#if DISPATCH_ONCE_INLINE_FASTPATH
DISPATCH_INLINE DISPATCH_ALWAYS_INLINE DISPATCH_NONNULL1 DISPATCH_NONNULL3
DISPATCH_NOTHROW
DISPATCH_SWIFT3_UNAVAILABLE("Use lazily initialized globals instead")
void
_dispatch_once_f(dispatch_once_t *predicate, void *_Nullable context,
				 dispatch_function_t function)
{
	if (DISPATCH_EXPECT(*predicate, ~0l) != ~0l) {
		dispatch_once_f(predicate, context, function);
	} else {
		dispatch_compiler_barrier();
	}
	DISPATCH_COMPILER_CAN_ASSUME(*predicate == ~0l);
}
#undef dispatch_once_f
#define dispatch_once_f _dispatch_once_f
#endif // DISPATCH_ONCE_INLINE_FASTPATH

__END_DECLS

DISPATCH_ASSUME_NONNULL_END

#endif
