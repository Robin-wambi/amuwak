// _shared/cors_test.ts
// -----------------------------------------------------------------------------
// Run: deno test --allow-env supabase/functions/_shared/
//
// `--allow-env` is needed because importing cors.ts binds `corsHeadersFor` to
// `Deno.env` at module load — not because these cases read the environment.
// They hand their configuration to `corsPolicy` instead, which is the only
// reason they can all share one module instance.
//
// What these are guarding: this policy decides which origins a browser may read
// a response from on the staff MFA recovery path. The failure that matters most
// is not "a stranger got in" — it is "the allowlist got stricter than intended
// and locked out the app", so the wildcard and singular-variable defaults are
// pinned here just as hard as the denials.

import { assert, assertEquals, assertFalse } from 'jsr:@std/assert@^1.0.0';
import { corsHeadersFor, corsPolicy } from './cors.ts';

const STAFF = 'https://ray007-xp.github.io';
const LOCAL = 'http://localhost:5000';

function policy(env: Record<string, string>) {
  return corsPolicy((key) => env[key]);
}

function request(origin: string | null): Request {
  return new Request('https://example.test/', {
    headers: origin === null ? {} : { Origin: origin },
  });
}

Deno.test('unconfigured stays wildcard, exactly as the functions already shipped', () => {
  const headers = policy({})(request(STAFF));
  assertEquals(headers['Access-Control-Allow-Origin'], '*');
  // No Vary: nothing varies, so nothing to tell a cache about.
  assertEquals(headers['Vary'], undefined);
});

Deno.test('the singular ALLOWED_ORIGIN is still read, so an existing lock-down survives', () => {
  const headers = policy({ ALLOWED_ORIGIN: STAFF })(request(STAFF));
  assertEquals(headers['Access-Control-Allow-Origin'], STAFF);
  assertEquals(headers['Vary'], 'Origin');
});

Deno.test('an origin that is not on the list gets no allow header at all', () => {
  const headers = policy({ ALLOWED_ORIGIN: STAFF })(request('https://evil.test'));
  assertFalse('Access-Control-Allow-Origin' in headers);
  assertEquals(headers['Vary'], 'Origin');
});

Deno.test('a list allows every member, which is the entire point of the change', () => {
  const allow = policy({ ALLOWED_ORIGINS: `${STAFF},${LOCAL}` });
  assertEquals(allow(request(STAFF))['Access-Control-Allow-Origin'], STAFF);
  assertEquals(allow(request(LOCAL))['Access-Control-Allow-Origin'], LOCAL);
});

Deno.test('the plural list wins over the singular value', () => {
  const allow = policy({ ALLOWED_ORIGINS: LOCAL, ALLOWED_ORIGIN: STAFF });
  assertEquals(allow(request(LOCAL))['Access-Control-Allow-Origin'], LOCAL);
  assertFalse('Access-Control-Allow-Origin' in allow(request(STAFF)));
});

Deno.test('spaces and empty entries in the list are tolerated', () => {
  const allow = policy({ ALLOWED_ORIGINS: `  ${STAFF} , , ${LOCAL} ,` });
  assertEquals(allow(request(STAFF))['Access-Control-Allow-Origin'], STAFF);
  assertEquals(allow(request(LOCAL))['Access-Control-Allow-Origin'], LOCAL);
});

Deno.test("an explicit '*' means wildcard, not an origin literally named '*'", () => {
  // Without this, ALLOWED_ORIGINS='*' would read as a lock-down that matches
  // nothing and blocks every browser — the exact opposite of what it says.
  const headers = policy({ ALLOWED_ORIGINS: '*' })(request(STAFF));
  assertEquals(headers['Access-Control-Allow-Origin'], '*');
  assertEquals(headers['Vary'], undefined);
});

Deno.test('a request with no Origin header is not handed one', () => {
  const headers = policy({ ALLOWED_ORIGINS: STAFF })(request(null));
  assertFalse('Access-Control-Allow-Origin' in headers);
});

Deno.test('matching is exact — no prefix, suffix or substring', () => {
  const allow = policy({ ALLOWED_ORIGINS: STAFF });
  for (
    const bad of [
      `${STAFF}.evil.test`,
      `${STAFF}/path`,
      `${STAFF}:8080`,
      'https://ray007-xp.github.io.evil.test',
      'https://evil.test?x=https://ray007-xp.github.io',
    ]
  ) {
    assertFalse(
      'Access-Control-Allow-Origin' in allow(request(bad)),
      `should not allow ${bad}`,
    );
  }
});

Deno.test('the preflight headers survive every mode', () => {
  // Dropping these breaks the OPTIONS preflight, which fails the request just
  // as thoroughly as a wrong origin does.
  for (const env of [{}, { ALLOWED_ORIGINS: STAFF }]) {
    for (const origin of [STAFF, 'https://evil.test', null]) {
      const headers = policy(env)(request(origin));
      assert(headers['Access-Control-Allow-Headers'].includes('authorization'));
      assertEquals(headers['Access-Control-Allow-Methods'], 'POST, OPTIONS');
    }
  }
});

Deno.test('corsHeadersFor is bound to the environment and answers requests', () => {
  // Deliberately does not assert the origin: that depends on how whoever runs
  // this has configured their environment. What is being checked is that the
  // one line outside `corsPolicy` — the `Deno.env` binding — evaluates and
  // yields a usable set of headers.
  const headers = corsHeadersFor(request(STAFF));
  assertEquals(headers['Access-Control-Allow-Methods'], 'POST, OPTIONS');
  assert(headers['Access-Control-Allow-Headers'].includes('authorization'));
});
