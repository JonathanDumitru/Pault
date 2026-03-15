# Deferred Items - Phase 01

## Compilation Cache Bug (discovered during 01-02 Task 3)

**File:** `Pault/BlockEditor/Services/CompilationCache.swift`
**Issue:** `generateCacheKey()` only includes blocks and blockInputs but NOT blockModifiers or modifierInputs. This means when a modifier is added/removed/changed, the cache returns stale compiled output that doesn't reflect the modifier changes.
**Impact:** Modifier changes aren't reflected in compiled output until something else (block input change, add/remove block) invalidates the cache.
**Workaround:** Tests call `CompilationCache.shared.clear()` before `compileNow()` when testing modifier effects.
**Fix:** Add blockModifiers and modifierInputs to the cache key generation.
