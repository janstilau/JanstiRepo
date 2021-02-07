#include "internal.h"

#undef dispatch_once
#undef dispatch_once_f

// Dispatchonce 的实现.
#ifdef __BLOCKS__
void
dispatch_once(dispatch_once_t *val, dispatch_block_t block)
{
	dispatch_once_f(val, block, _dispatch_Block_invoke(block));
}
#endif

#if DISPATCH_ONCE_INLINE_FASTPATH
#define DISPATCH_ONCE_SLOW_INLINE inline DISPATCH_ALWAYS_INLINE
#else
#define DISPATCH_ONCE_SLOW_INLINE DISPATCH_NOINLINE
#endif // DISPATCH_ONCE_INLINE_FASTPATH

DISPATCH_NOINLINE
static void
_dispatch_once_callout(dispatch_once_gate_t l, void *ctxt,
		dispatch_function_t func)
{
	_dispatch_client_callout(ctxt, func);
	_dispatch_once_gate_broadcast(l);
}

DISPATCH_NOINLINE
void
dispatch_once_f(dispatch_once_t *val, void *ctxt, dispatch_function_t func)
{
	dispatch_once_gate_t l = (dispatch_once_gate_t)val;

#if !DISPATCH_ONCE_INLINE_FASTPATH || DISPATCH_ONCE_USE_QUIESCENT_COUNTER
	uintptr_t v = os_atomic_load(&l->dgo_once, acquire);
	if (likely(v == DLOCK_ONCE_DONE)) {
		return;
	}
#if DISPATCH_ONCE_USE_QUIESCENT_COUNTER
	if (likely(DISPATCH_ONCE_IS_GEN(v))) {
		return _dispatch_once_mark_done_if_quiesced(l, v);
	}
#endif
#endif
	if (_dispatch_once_gate_tryenter(l)) {
		return _dispatch_once_callout(l, ctxt, func);
	}
	return _dispatch_once_wait(l);
}
