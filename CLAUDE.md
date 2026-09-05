# Repository Instructions

## Running Flutter tests and analyze

This host runs `flutter test` / `flutter analyze` slowly — a single test
file can take a couple of minutes to finish loading. Two rules follow from
that, both learned from repeated agent stalls:

1. **Always run `flutter test` / `flutter analyze` as a plain, blocking,
   foreground shell call.** Never dispatch one as a background/async
   command and then end your turn "waiting" for the result — a run
   invoked that way has repeatedly caused agents to stall indefinitely
   instead of resuming when it completes. A foreground call is slower
   per-call but always returns; just wait for it.
2. **Run one test file at a time.** `flutter test path1 path2` (multiple
   paths in one invocation) is known to hang at the `loading` step on this
   host — invoke the command once per file instead.

Use `scripts/flutter_test.sh <app-dir> <test-file>` as the standard way to
run a single test file — it wraps the correct foreground, `--timeout=none`
invocation so there's one obvious command to reach for instead of composing
one ad hoc:

```
scripts/flutter_test.sh apps/amuwak_staff test/dashboard/staff_dashboard_screen_test.dart
```

`flutter analyze` has no equivalent wrapper because it takes no per-file
arguments — run it directly, just keep it in the foreground per rule 1.
