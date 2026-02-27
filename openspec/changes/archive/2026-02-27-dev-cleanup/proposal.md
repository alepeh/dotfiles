## Why

Orphaned dev processes (wrangler dev servers, workerd runtimes, esbuild services) accumulate during development and consume memory. EXITED Zellij sessions also pile up. There's no quick way to identify and kill these without manually grepping `ps aux`.

## What Changes

- Add `make cleanup-dry` target that shows orphaned processes and EXITED Zellij sessions without killing anything
- Add `make cleanup` target that kills orphaned wrangler, workerd, esbuild, and pywrangler processes, and deletes EXITED Zellij sessions

## Capabilities

### New Capabilities
- `dev-cleanup`: Makefile targets for previewing and killing orphaned dev processes and stale Zellij sessions

### Modified Capabilities
_(none)_

## Impact

- **Modified files**: `Makefile` (two new targets under existing `##@ Cleanup` section)
- **No breaking changes**: Existing `clean` target is untouched
