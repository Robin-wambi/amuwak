# Amuwak Staff + Customer — why we're not done, and a timeline to finish

Written 2026-08-07. Evidence is from git history, the GitHub PR/issue API, CI runs,
and the plan docs in `docs/superpowers/`.

---

## Part 1 — Where we actually are

### Both apps are built. Neither is finished.

| | Staff app | Customer app |
|---|---|---|
| Started | 2026-05-09 | 2026-06-30 (Phase A) |
| Feature scope | Effectively complete | Effectively complete (50 source files, all 10 plan tasks) |
| Deployed | GitHub Pages PWA | Cloudflare Pages PWA (`amuwak-customer.pages.dev`) |
| CI | Green, ~8 min | Green |
| Coverage | ~99% | included in the same target |
| Releases cut | **0** | **0** |
| Verified against a live environment | Partially | **Never** |
| Real users | 0 | 0 |

The build is not the problem. The **last mile** is the problem.

### Velocity, measured

Merged PRs per month:

```
May   ~16 PRs   (plus 271 direct commits — pre-PR era)
Jun    40 PRs
Jul    15 PRs   (but includes #100, +28k lines — the whole customer app)
Aug     1 PR    (7 days in)
```

Since **2026-07-29** — nine days — the project has produced **6 open PRs,
~9,700 added lines, and 1 merge**. Every one of those PRs is CI-green.
Every one of them is auth/identity work.

---

## Part 2 — What is holding us back

Ranked by how much time each is actually costing.

### 1. Work is finished but not merged (biggest single cost)

Eight PRs are open right now. All the recent ones pass CI.

| PR | Open since | Days | Size | State |
|---|---|---|---|---|
| #80 | 2026-06-26 | 42 | +1458 | Staff training guide + pricing plan. Forgotten. |
| #93 | 2026-07-05 | 33 | +23 | **Dead** — #99 shipped the same fix on 2026-07-17. |
| #105 | 2026-07-31 | 7 | +2116 | TOTP MFA. Green. |
| #106 | 2026-08-03 | 4 | +4818 | Manager-mediated MFA recovery. Green. |
| #107 | 2026-08-04 | 3 | +98 | Green. |
| #108 | 2026-08-04 | 3 | +384 | Green. |
| #109 | 2026-08-04 | 3 | +2088 | Docs only. |
| #110 | 2026-08-05 | 2 | +189 | Green. |

And they are **stacked**: #104 → #107 → #108 → #109, and #105 → #106.
A stack that deep means nothing lands until the bottom lands, rebases cascade
on every merge, and #109 already had to write down "retarget as those merge"
as a known chore.

Best practice this violates: *green, trunk-ready work merges the same day.*
Batching is the classic cycle-time killer, and it is the dominant one here.

### 2. v1 scope kept growing after the product was built

The customer app was feature-complete on 2026-07-27 (#100). Everything since
has been auth and identity: password reset, cross-device reset, a recovery
latch, TOTP MFA, manager-mediated MFA recovery, recovery codes, role-claim
cold start, breach notification, Turnstile.

That is a genuinely good roadmap. It is not a v1 gate for an app that
**no customer has ever opened**. NIST/OWASP hardening is being applied ahead of
the much cheaper question: does the thing work in the field?

### 3. The verification that actually gates launch has never been run

`docs/customer-app-hardening.md` has four unchecked boxes, all needing only a
live Supabase project and two phones:

- [ ] RLS pen-test with a real customer JWT
- [ ] Signup round-trip (role claim lands, app routes to `/`)
- [ ] Estimate ↔ final-weight reconciliation live-updating on the customer side
- [ ] Two-way chat between a customer and staff

These are the highest-information, lowest-cost tasks on the board and they have
been open since 2026-07-27 while 9,700 lines of auth code went in around them.

### 4. A vendor blocker sat unowned for weeks — and it broke something silently

Auth-hardening Phase A was written as one blocking blob waiting on a domain
nobody had bought. It stayed that way until **2026-08-04**, when #109 split it
and discovered most of it was never domain-blocked at all.

The cost of that delay is not just schedule: `invite-staff` sends via an
implicit-flow client while both apps run PKCE, so **staff invite links are very
likely dead in production right now — with no error, no event, nothing.** The
fix (flip the email template to a token hash) was available the whole time and
needs no code change.

Best practice this violates: *a blocker gets a named owner and a date, or it
gets designed around.* This one had neither for ~5 weeks.

### 5. Outstanding credential hygiene

Specifics are deliberately left out of this document, which lives in a public
repository. The auth-hardening plan carries this as its own blocking
prerequisite and is where the detail belongs.

It is the one item on this list that is a live risk rather than a schedule
cost, which is why it leads Week 1 below.

### 6. The local feedback loop is minutes, not seconds

On this Windows host `flutter test <a> <b>` deadlocks; tests must be run one
file at a time, and a big file can hang 12 minutes on `loading`. CI is the real
source of truth at ~8 minutes a run.

So the inner loop for "did I break anything" is 8–12 minutes instead of ~10
seconds. That multiplies into every single task and it is almost certainly the
largest invisible tax in the project.

### 7. No human review capacity

Across 100+ merged PRs: `reviews = 0` on every one. Review is Claude bot
comments only — up to 15 per PR, which drives real rework loops. The author is
the only human gate. That is workable for a solo project, but it means large
PRs (#84 at 35 files, #100 at 206 files) get no second pair of eyes on exactly
the changes where one matters most.

### 8. WIP and workspace sprawl

- 53 remote branches, 58 local branches
- 9 git worktrees — four abandoned under `C:/tmp` since July, one already `prunable`
- The primary working directory sits on `main` at **784de7b (#55, 2026-06-11)** —
  about 50 commits and two months stale — with 40+ modified/deleted files dirty

There is no trustworthy workspace to do a quick check in, which pushes even
trivial verification into a new worktree.

### 9. The issue tracker doesn't describe reality

16 open issues. Twelve are `M1-*` tasks from 2026-05-09/10 (staff dashboard,
daily report, status transitions) that demonstrably shipped months ago.
Issues #37 and #39 (offline order creation) appear resolved by #92/#94.

Only #71 and #72 look like genuine open staff work. There is no single place
that answers "what is left," which is why scope keeps being re-derived from
plan docs instead of read off a list.

### 10. Rework from avoidable errors

Migration 0026 collision (two PRs claiming the same prefix, silently skipping
columns), stale test fixtures reddening main after #94, #91 abandoned and
re-landed as #92, #93 duplicated by #99. Each cost a PR-cycle. The dup-prefix CI
guard from #85 was the right response — that class is now closed.

---

## What is *not* the problem

Worth saying, because it rules out the usual suspects:

- **CI** — green, ~8 minutes, reliable.
- **Test coverage** — ~99% on the testable surface.
- **Architecture** — the `amuwak_core` extraction, the offline-first outbox, and
  the RLS/RPC model are sound and are not being fought.
- **Effort** — 100+ PRs in three months is not a throughput problem.

This is a **finishing** problem, not a building problem.

---

## Part 3 — Timeline to done

**Assumptions** (change these and the dates move):
- ~1 developer working with Claude, ~4 focused days/week
- A domain is purchased in Week 0 — this is ~$12 and unblocks the entire email path
- MFA (#105/#106) is deferred out of v1 and lands post-launch

**Target: v1 launch the week of 2026-09-07. Five weeks from today.**

### Week 0 — now, Aug 7–8 (2 days): drain the queue

Nothing new gets written until the pipe is empty.

- Merge in this order — **#107 → #108 → #110 → #109**. Ordering matters: the
  deployed apps must understand `?code=` links *before* the email template flips.
- Close #93 (superseded by #99). Salvage the training guide out of #80 and close
  the rest.
- Close the 12 stale `M1-*` issues plus #37/#39. Re-file what's genuinely left
  (#71, #72) into one v1 list.
- **Decide MFA is post-launch.** Park #105 and #106 as-is; do not rebase them
  weekly. Write the decision down.
- Buy the domain.
- Prune the four dead `C:/tmp` worktrees; reset the primary working directory to
  `origin/main`.

*Exit: 0 open PRs except the two parked MFA ones. A clean workspace on current main.*

### Week 1 — Aug 10–14: security debt + the config that was never blocked

- **Rotate the Supabase keys and purge git history.** First, before anything
  else. This is overdue and it is the only genuine risk on the list.
- Phase A1 (no domain needed): recovery template → token hash; add
  `https://amuwak-customer.pages.dev/**` to Redirect URLs; min length 8; leaked-
  password protection on; confirm recovery-link expiry.
- **Verify staff invites end-to-end.** This is the payoff for the template flip
  and it confirms or kills the #109 diagnosis.
- Ship the interim recovery from #109: `SELF_SERVICE_RESET` flag (default off)
  and the manager-issued temporary-password Edge Function.

*Exit: keys rotated. Staff can be invited and can recover. Managers can reset anyone.*

### Week 2 — Aug 17–21: prove the product works

The highest-value week in this plan. No new features.

- The four hardening checks: RLS pen-test with a real JWT, signup round-trip,
  estimate ↔ final reconciliation, two-way chat.
- Customer proof-photo viewing — the one deferred code item, needs a Storage
  read path for a customer's own orders.
- Real-device pass: two rider Androids and two customer phones, on actual
  Ugandan mobile data, not wifi.

*Exit: whatever this week finds **is** the v1 bug list. Whatever it doesn't find
is out of scope. This is the scope freeze.*

### Week 3 — Aug 24–28: email pipeline + first release

- Domain DNS: SPF, DKIM, DMARC verified on Postmark. Send Email Hook wired.
  Supabase Pro. Turnstile on auth endpoints. (This is Phase A2 — now unblocked.)
- Phase D: password-changed notification (trigger on `auth.users` → Edge
  Function → Postmark). This is how a victim learns about a takeover.
- Flip `SELF_SERVICE_RESET` on. The customer app stops telling people a lie.
- **Tag `v1.0.0` on both apps.** The first release this project has ever cut.

*Exit: real email is delivering. Two tagged, deployed builds.*

### Week 4 — Aug 31–Sep 4: pilot

- One branch, two riders, ~10 real orders/day, five days.
- Staff training guide from #80, actually handed to the riders.
- Daily triage with one rule: **only field-blocking bugs get fixed this week.**
  Everything else goes to a post-pilot list, unargued.

*Exit: five days of real orders through both apps.*

### Week 5 — Sep 7–11: fix and launch

- Fix the pilot's field-blocking findings.
- Open customer signups.
- Tag `v1.1.0`. **Launched.**

### Post-launch — Sep 14 onward

In this order, because enforcement before enrolment locks staff out of production:

1. Merge #105 (optional TOTP enrolment, no enforcement) — enrol everyone first.
2. Merge #106 (manager-mediated MFA recovery).
3. Only then the `aal2` RLS migration that actually enforces it.
4. Recovery codes, breach notification, the rest of the enterprise roadmap.

---

## Part 4 — Four changes that stop this recurring

1. **Merge green work the same day. Never stack more than two PRs.**
   This is the single highest-leverage change available. Eight open PRs is not a
   review backlog — there are no reviewers — it is a habit.

2. **Fix the local test loop, or stop pretending it exists.**
   Either get a Linux/WSL or CI-runner path where the full suite runs in one
   command, or formally adopt "push and let CI judge" and stop paying the
   12-minute hang. Right now it's the worst of both.

3. **Every blocker gets a named owner and a date, or gets designed around within
   48 hours.** The domain sat unowned for five weeks and hid a broken invite
   flow. #109 proved the design-around was cheap and available all along.

4. **Define done before building. Ship, then harden.**
   v1 = a rider can run a day's orders and a customer can place and track one.
   Everything else — MFA, breach screening, Turnstile, recovery codes — is v1.x.
   Write that line down and defend it, or the next five weeks look like the last five.
