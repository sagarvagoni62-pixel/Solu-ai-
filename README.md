# Solu AI

Turn one photo of a departed loved one into a dignified 10-second remembrance
video. Built for Indian families, in Hindi and English.

Flutter app + Cloudflare Worker proxy. No AI provider key ever ships inside the
Android binary.

> Memorial content is sensitive. This project is meant for families creating
> tributes of their own relatives, with consent. Please do not use it to create
> videos of people without the family's permission.

## How it works

The user uploads one photo and picks a scene. Everything after that happens on
the server, and the app only ever polls a single job id.

```
photo  ->  /v1/upload      photo goes into the media library
       ->  /v1/generate    stage 1: character sheet image (hidden from the user)
                           stage 2: reference-to-video, 10s, 9:16, 720p
       ->  /v1/jobs/:id     one id, one progress bar, one final video
```

The hidden character-sheet stage is the important part. Going straight from a
phone photo to video drifts the person's face. Generating a clean full-body
reference first, then using that as the video reference, keeps the identity
stable.

## Architecture

| Piece | What it does |
| --- | --- |
| `lib/` | Flutter app: scene catalogue, photo upload, progress, history, diagnostics |
| `worker/` | Cloudflare Worker: holds the provider key, runs the two-stage pipeline, stores flow state in KV |
| `.github/workflows/` | Builds the debug APK and deploys the Worker, no local toolchain needed |

### Security model

- The provider API key lives only in the Worker, as a Cloudflare secret.
- The app carries a rotatable shared key (`SOLU_APP_KEY`), injected at build
  time by CI. It is not committed to this repository.
- Every generation route is authenticated; only `/v1/health` and `/v1/scenes`
  are public.

### Resilience

Upstream video APIs disagree about model ids and payload shapes, and their
upload endpoint returns retryable 500s. The Worker handles this rather than
surfacing it to the user:

- a fallback chain of video model ids, tried in order,
- several request-body shapes per model,
- retries on retryable 5xx, plus an alternate URL-import upload path,
- errors returned with a real code, surfaced in an in-app diagnostics screen.

## Running it

### Worker

```bash
cd worker
npm install
npx wrangler secret put BLITZREELS_API_KEY
npx wrangler secret put APP_SHARED_SECRET
npx wrangler deploy
```

### App

```bash
flutter pub get
flutter run \
  --dart-define=SOLU_PROXY=https://your-worker.workers.dev \
  --dart-define=SOLU_APP_KEY=<APP_SHARED_SECRET>
```

Without `SOLU_APP_KEY` the app builds but cannot reach the backend, which is
deliberate.

### CI

Push to `main` and GitHub Actions builds the APK and publishes it to the
`debug-latest` release. Required repository secrets:

| Secret | Used by |
| --- | --- |
| `SOLU_APP_KEY` | APK build |
| `APP_SHARED_SECRET` | Worker deploy |
| `BLITZREELS_API_KEY` | Worker deploy |
| `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` | Worker deploy |

## Status

Early. The memorial scenes work end to end; the wider template library, credits
and moderation are still in progress.

## License

MIT. See [LICENSE](LICENSE).
