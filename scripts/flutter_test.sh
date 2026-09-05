#!/usr/bin/env bash
# Run a single Flutter test file synchronously, in the foreground.
#
# This host runs `flutter test` slowly (a file can take a couple of
# minutes to finish loading) and has repeatedly caused agents to stall
# when the command is backgrounded and then waited on instead of run as a
# plain blocking call. Always invoke flutter test through this script (or
# an equivalent foreground, --timeout=none call) rather than composing one
# ad hoc. See CLAUDE.md for the full rationale.
#
# Usage:  scripts/flutter_test.sh <app-dir> <test-file>
#   e.g.  scripts/flutter_test.sh apps/amuwak_staff test/dashboard/staff_dashboard_screen_test.dart
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <app-dir> <test-file>" >&2
  echo "  e.g. $0 apps/amuwak_staff test/dashboard/staff_dashboard_screen_test.dart" >&2
  exit 1
fi

APP_DIR="$1"
TEST_FILE="$2"

cd "$(dirname "$0")/.."
cd "$APP_DIR"
flutter test "$TEST_FILE" --timeout=none
