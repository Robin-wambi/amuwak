// _shared/cors.ts
// -----------------------------------------------------------------------------
// One CORS policy for every Edge Function. It lives here rather than being
// copied per function because two copies is how the two drift apart — the
// second function already inherited the first one's default without its
// reasoning.
//
// CONFIGURATION
//
// `ALLOWED_ORIGINS` is a comma-separated list. The older singular
// `ALLOWED_ORIGIN` is still read, so a deployment that already set it keeps the
// lock-down it asked for. With neither set the policy is '*' — exactly what
// these functions shipped with, which means deploying this change without
// touching any function's config alters nothing. That default is deliberate:
// this is the recovery path for locked-out staff, and it must fail toward
// working.
//
// WHY '*' IS DEFENSIBLE, NOT JUST CONVENIENT
//
// '*' cannot be combined with credentials, and no browser attaches an
// `Authorization` header on its own. A cross-origin page cannot read another
// origin's stored session to forge one. So CORS is not the authorisation
// boundary on these endpoints — the bearer token is. An allowlist here is
// defence in depth, not the lock.
//
// WHY A LIST, AND NOT JUST A VALUE
//
// The response header carries ONE origin or '*', never several. A single
// hardcoded value would therefore shut out localhost during development, which
// is why nobody ever set the old singular var. Hence: echo the caller's origin
// when it is on the list, and omit the header entirely when it is not. A
// browser blocks the response in that case; curl and the native app are
// unaffected, because CORS is enforced only by browsers.

const BASE_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// The policy, with its configuration handed in rather than read from the
// environment. This is the seam `cors_test.ts` uses: reading env at module
// scope means one frozen config per import, so testing the precedence rules
// below would otherwise need a fresh module per case. Everything that can be
// got wrong lives in here; the only thing outside it is the one line that
// binds this to `Deno.env`.
export function corsPolicy(
  env: (key: string) => string | undefined,
): (req: Request) => Record<string, string> {
  const configured = (env('ALLOWED_ORIGINS') ?? env('ALLOWED_ORIGIN') ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter((origin) => origin !== '');

  // Unset, or an explicit '*' anywhere in the list, means wildcard. Without the
  // second half, setting ALLOWED_ORIGINS='*' would look like a wildcard and
  // behave like an allowlist containing one origin literally named '*',
  // matching nothing and blocking every browser.
  const wildcard = configured.length === 0 || configured.includes('*');

  return (req: Request): Record<string, string> => {
    if (wildcard) {
      return { ...BASE_HEADERS, 'Access-Control-Allow-Origin': '*' };
    }

    // `Vary: Origin` only matters once the answer varies by origin — without it
    // a shared cache can hand one origin's allow header to a different origin.
    const headers: Record<string, string> = { ...BASE_HEADERS, Vary: 'Origin' };

    // Exact match only. Prefix or substring matching is the classic hole here:
    // `https://app.example.com.evil.test` starts with an allowed origin.
    const origin = req.headers.get('Origin');
    if (origin !== null && configured.includes(origin)) {
      headers['Access-Control-Allow-Origin'] = origin;
    }
    return headers;
  };
}

// Headers for ONE request. Call this per request rather than building a
// constant at module scope: once an allowlist is configured, the answer depends
// on who asked.
export const corsHeadersFor = corsPolicy((key) => Deno.env.get(key));
