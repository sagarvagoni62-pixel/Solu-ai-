# Solu AI - v3 (clean rebuild)

AI tribute videos from a single photo. Flutter app + Cloudflare Worker proxy.
Scope of this build: **Reference to Video** (Shraddhanjali / Swarg scenes).
Motion Control will be added later behind its own provider adapter.

```
solu_app/
  lib/
    core/      config, theme tokens, hi/gu/en strings
    data/      scene catalogue (offline fallback)
    api/       proxy client (upload, submit, poll, result)
    services/  generation controller, local history
    widgets/   buttons, chips, cards, progress ring
    screens/   splash, onboarding, shell, home, explore,
               scene detail, photo upload, generating, result,
               my videos, profile
  worker/      Cloudflare Worker: prompts, model chain, R2 photo upload
  .github/     CI that builds a signed APK + AAB
```

## Architecture in one line

`photo -> Worker /v1/upload (R2, public URL) -> Worker /v1/generate (prompt + model chain)
-> poll -> mp4 downloaded to the device -> local history`

The provider API key lives **only** in the Worker. The APK ships no keys.

## 0. Zero-terminal setup (recommended)

You never need Node or wrangler on your own machine. Everything runs in GitHub
Actions.

**Step 1 - Cloudflare API token** (2 min, one time)

1. Cloudflare dashboard -> profile icon -> **My Profile** -> **API Tokens**
2. **Create Token** -> use the **Edit Cloudflare Workers** template
3. Under *Account Resources* pick your account, then **Continue** -> **Create Token**
4. Copy the token (shown only once)
5. Your **Account ID** is in the dashboard URL: `dash.cloudflare.com/<ACCOUNT_ID>`

**Step 2 - add repo secrets** (GitHub repo -> Settings -> Secrets and variables
-> Actions -> *New repository secret*)

| Secret | Value |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | token from step 1 |
| `CLOUDFLARE_ACCOUNT_ID` | account id from step 1 |
| `GENPRESSO_API_KEYS` | all your keys, comma separated, no spaces |
| `APP_SHARED_SECRET` | any long random string you invent |
| `SOLU_APP_KEY` | **same value** as `APP_SHARED_SECRET` |

**Step 3 - run it**

Actions -> **Deploy Worker** -> *Run workflow*. It creates the R2 bucket and KV
namespace, uploads the secrets, deploys, and prints the Worker URL plus a health
check in the run summary.

**Step 4** - add that URL as the `SOLU_PROXY` secret, add the 4 keystore
secrets, then Actions -> **Build Android** -> download the signed APK.

Re-running **Deploy Worker** is safe; use it whenever you change prompts,
models, or keys.

The manual wrangler steps below are only for local development.

## 1. Deploy the Worker

```bash
cd worker
npm install
npx wrangler login
npx wrangler r2 bucket create solu-media
npx wrangler kv namespace create STATE        # paste the id into wrangler.toml

# ALL your keys in one secret, comma separated:
#   gp_aaa,gp_bbb,gp_ccc,...
npx wrangler secret put GENPRESSO_API_KEYS
npx wrangler secret put APP_SHARED_SECRET     # openssl rand -hex 24
npx wrangler deploy
```

Set `PUBLIC_BASE` in `wrangler.toml` to the deployed URL, then `deploy` again.

Verify:

```bash
curl https://solu-ai-proxy.<you>.workers.dev/v1/health
# {"ok":true,"mode":"reference-to-video","scenes":7,"storage":true,"keys":10,"keyState":true,"testMode":true}
```

## 2. Test the pipeline without the app

```bash
P=https://solu-ai-proxy.<you>.workers.dev
K=<APP_SHARED_SECRET>

# upload a photo -> public URL
curl -s -X POST $P/v1/upload -H "x-solu-key: $K" -F file=@dadaji.jpg

# submit
curl -s -X POST $P/v1/generate -H "x-solu-key: $K" -H "content-type: application/json" \
  -d '{"sceneId":"swarg_darwaza","imageUrl":"<url from upload>"}'

# poll, then fetch
curl -s $P/v1/jobs/<jobId>/status -H "x-solu-key: $K"
curl -s $P/v1/jobs/<jobId>        -H "x-solu-key: $K"
```

Tune prompts in `worker/src/index.ts` and redeploy - no app rebuild needed.

## 3. Build the app

```bash
flutter pub get
flutter run \
  --dart-define=SOLU_PROXY=https://solu-ai-proxy.<you>.workers.dev \
  --dart-define=SOLU_APP_KEY=<APP_SHARED_SECRET>
```

Release:

```bash
cp android/key.properties.example android/key.properties   # then fill it in
cp /path/to/solu-release.jks android/solu-release.jks

flutter build apk --release --split-per-abi \
  --dart-define=SOLU_PROXY=... --dart-define=SOLU_APP_KEY=...
```

## 4. Build from GitHub instead (no local Flutter needed)

Push this folder to a private repo, then add these repository secrets:

| Secret | Value |
| --- | --- |
| `SOLU_PROXY` | Worker URL |
| `SOLU_APP_KEY` | `APP_SHARED_SECRET` |
| `KEYSTORE_BASE64` | `base64 -w0 solu-release.jks` |
| `KEYSTORE_PASSWORD` | store password |
| `KEY_ALIAS` | key alias |
| `KEY_PASSWORD` | key password |

Actions -> **Build Android** -> Run workflow -> download the APK/AAB artifact.

## Key pool - 9 keys, 5 videos each, automatic switching

All keys live in ONE secret, comma separated (no spaces):

```
gp_key1,gp_key2,gp_key3,...
```

Accounting is local and exact, so nothing depends on a balance API existing:

| Setting | Value | Where |
| --- | --- | --- |
| Credits per key | `230` | `KEY_CREDITS` in `wrangler.toml` |
| Credits per video | `45` | `CREDITS_PER_VIDEO` |
| Videos per key | **5** | computed |
| Videos on 9 keys | **45** | `GET /v1/keys` |

On every `POST /v1/generate`:

1. Keys are sorted fullest-first, so one key is drained 5 videos at a time -
   predictable, no half-used keys everywhere.
2. A key with fewer than 45 credits left is skipped **before** it is used, so a
   render never dies half way.
3. After a successful submit, 45 credits are debited locally. When a key drops
   below 45 it is parked automatically and the next key takes over.
4. If the provider still answers with a failure:
   - `402` / "insufficient credits" -> key parked 6h, **next key retried in the
     same request** (the user sees nothing)
   - `401/403` -> key parked 24h as invalid
   - `429` -> parked for `Retry-After` (default 60s)
   - content-policy / bad-model -> same key, **next model** in the chain
5. Only if every key x every model refuses does the app show an error.

State is stored in KV (`STATE`), shared across Worker instances and kept across
deploys.

### Check the pool anytime

```bash
curl "$P/v1/keys" -H "x-solu-key: $K"
```

```json
{ "totalKeys": 9, "usableKeys": 9, "videosLeft": 45, "creditsPerVideo": 45,
  "videosPerKey": 5, "keys": [
    { "label": "key-1", "status": "ok", "creditsUsed": 90, "creditsLeft": 140, "videosLeft": 3 },
    { "label": "key-2", "status": "ok", "creditsUsed": 0, "creditsLeft": 230, "videosLeft": 5 }
]}
```

Raw keys are never returned - only `key-1 ... key-9` labels.

After topping keys up, reset the counters (no redeploy needed):

```bash
curl "$P/v1/keys?reset=1" -H "x-solu-key: $K"
```

Job polling always uses the key that created the job (cached in KV for 24h),
with the other keys as fallback - rotation never breaks a running job.

### Confirm the exact model id (do this once)

```bash
curl "$P/v1/models" -H "x-solu-key: $K"
```

Find the Omni Flash 1.1 entry and paste its exact id into `VIDEO_MODEL` in
`worker/wrangler.toml` (or set a `VIDEO_MODEL` repo *variable*, which the deploy
workflow injects automatically). Until then the Worker tries four common
spellings, then falls back to Hailuo 2.3 Pro and Veo 3.1.

## Model chain (important)

Seedance 2.5 was verified to reject human-face stills with
`content policy violation` across multiple providers, so it is **last** in the
chain. `VIDEO_CHAIN` in the Worker tries each model in order until one accepts:

1. `gp/minimax/hailuo-2.3/pro/image-to-video`
2. `gp/veo3.1`
3. `bytedance/seedance-2.5/image-to-video`

Run `GET /models` on the provider once and reorder this list to match what your
account actually has enabled (WAN 3.0 first if available - it was verified to
accept faces with excellent identity fidelity).

## Quality levers

- `IDENTITY_LOCK` is appended to every prompt (no beautify, no age change, no
  person replacement). This is the single biggest fix for "face badal gaya".
- `NEGATIVE` blocks horror/creepy artefacts, which matter a lot for memorial
  content.
- Each scene is written as a shot-by-shot timeline, not a single sentence.

## Before Play Store

- [ ] Consent sheet is implemented; keep it, and add a visible Report action
      (already in Profile) - required for user-generated likeness content.
- [ ] Host a real privacy policy and update `SoluConfig.privacyUrl`.
- [ ] Turn `FEATURES.rateLimit` on and add per-device quotas.
- [ ] Add Crashlytics/Analytics before scaling installs.
- [ ] Revoke every API key that ever appeared in a chat, log, or old APK.
