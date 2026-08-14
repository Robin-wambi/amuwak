# amuwak

Monorepo for the Amuwak laundry business:

- `apps/amuwak_staff` — the staff/rider app (Flutter; also a PWA on GitHub Pages).
- `apps/amuwak_customer` — the customer app (Flutter; a PWA on Cloudflare Pages).
- `packages/amuwak_core` — code both apps share: design system, domain models,
  pricing, auth, and the Supabase repositories.
- `supabase/` — the single migration history and pgTAP tests both apps depend on.

One pub workspace, one lockfile, one backend — see `docs/` for deployment and
hardening notes.

## Toolchain

The Flutter version is pinned in **`.fvmrc`**, and that file is the only place
it is written down: CI and both deploy workflows read it via
`flutter-version-file`, so the test run and the two live PWAs are always built
with the same SDK.

Match it locally with [FVM](https://fvm.app):

```sh
dart pub global activate fvm
fvm use            # installs the pinned version and links .fvm/
fvm flutter test   # run flutter/dart through fvm from here on
```

Why it is pinned rather than floating on `stable`: a newer Flutter flags
deprecations for APIs these apps do not target yet (e.g. `FormField.value` →
`initialValue`, deprecated after 3.33.0), which fails `melos run analyze`.

Resolving dependencies on a *different* Flutter than the pin rewrites
`pubspec.lock` — including its `sdks:` floor and the SDK-bundled test packages.
`pub get` recovers by re-resolving rather than failing, so this is silent: CI
quietly tests different dependency versions than you ran. Run `pub get` through
`fvm` so the one committed lockfile keeps meaning what it says.

Bumping the version is a deliberate change: edit `.fvmrc`, clear any
deprecations the new SDK reports, and regenerate `pubspec.lock` under it.
