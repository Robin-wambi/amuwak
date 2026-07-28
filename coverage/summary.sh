#!/usr/bin/env bash
# Reproducible coverage summary for hand-written, unit-testable Dart.
#
# `flutter test --coverage` writes coverage/lcov.info over ALL of lib/, which
# includes code that is not meaningfully unit-testable. We report coverage over
# the *testable surface* by excluding the categories below. Each exclusion is a
# deliberate policy decision, not metric-gaming:
#
#   * Generated code            *.g.dart (Drift) — authored by the generator.
#   * Declarative schema        lib/src/data/tables/* — Drift table DSL, no logic.
#   * Platform / hardware / IO   Bluetooth printer, GPS, camera, file IO — need
#                                real device/platform channels, not unit tests.
#   * App / DB / DI wiring       main, bootstrap, app_database, *_providers.
#   * Dormant offline engine     sync_puller / outbox_worker / sync_orchestrator
#                                — preserved-but-disconnected in online-only mode
#                                (their tests are intentionally skip-stubbed).
#   * Data-access repositories   thin Supabase SDK wrappers; their real logic
#                                (payload building, row mapping) lives in
#                                supabase_payloads.dart / supabase_mappers.dart,
#                                which ARE unit-tested to >=98%. The repos' own
#                                uncovered lines are live .from()/.stream()/.rpc()
#                                calls that require integration infra.
#
# Usage:  (cd apps/amuwak_staff && flutter test --coverage)
#         bash coverage/summary.sh [--list]
set -euo pipefail
cd "$(dirname "$0")/.."

# Merge staff-app + amuwak_core coverage. A file like order_code.dart is only
# partly exercised by app tests but fully by amuwak_core's own suite; the inline
# awk (below) takes the max hit per line, so concatenating both lcov files merges
# them. Each lcov records package-relative paths (lib/...), so both are prefixed
# with their package directory — that also keeps the EXCLUDE patterns below,
# which match on path substrings, working unchanged.
LCOV="$(mktemp)"
trap 'rm -f "$LCOV"' EXIT
sed 's#^SF:#SF:apps/amuwak_staff/#' apps/amuwak_staff/coverage/lcov.info > "$LCOV"
if [ -f packages/amuwak_core/coverage/lcov.info ]; then
  sed 's#^SF:#SF:packages/amuwak_core/#' packages/amuwak_core/coverage/lcov.info >> "$LCOV"
fi

EXCLUDE='(\.g\.dart$)|(data/tables/)|(bluetooth_label_printer|barcode_reader|geo_services|proof_photo_storage_io)|(app_database\.dart|app_bootstrap\.dart|main\.dart|_providers\.dart)|(sync_puller|outbox_worker|sync_orchestrator)|(sync/(customers|orders|proof_events|staff|status_events|expenses|outbox|pull_dead_letter)_repository)|((pricing_catalog|pricing_settings)_repository|expenses/expenses_repository|auth_service|connectivity_watcher)'

awk -v EX="$EXCLUDE" '
  /^SF:/ { f=substr($0,4); gsub("\\\\","/",f); skip=(f ~ EX); next }
  /^DA:/ { if(skip)next; split(substr($0,4),a,","); k=f"|"a[1]; h=a[2]+0;
           if(!(k in s)){s[k]=1; tot++} if(h>c[k])c[k]=h }
  END { for(k in c) if(c[k]>0) hit++;
        printf "Testable-surface line coverage: %.2f%%  (%d/%d)\n", hit*100.0/tot, hit, tot }
' "$LCOV"

if [ "${1:-}" = "--list" ]; then
  echo "--- included files below 98% (merged per file) ---"
  awk -v EX="$EXCLUDE" '
    /^SF:/ { f=substr($0,4); gsub("\\\\","/",f); skip=(f ~ EX); next }
    /^DA:/ { if(skip)next; split(substr($0,4),a,","); line=a[1]; h=a[2]+0; key=f"|"line;
             if(!(key in seen)){seen[key]=1; lf[f]++} if(h>cov[key])cov[key]=h }
    END { for(k in cov) if(cov[k]>0){split(k,p,"|"); lh[p[1]]++}
          for(file in lf){ pct=lh[file]*100.0/lf[file];
            if(pct < 98) printf "%6.1f%%  %4d/%-4d  %s\n", pct, lh[file]+0, lf[file], file } }
  ' "$LCOV" | sort -n
fi
