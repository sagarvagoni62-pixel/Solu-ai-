/**
 * Solu AI proxy - Reference to Video only.
 *
 * Why a proxy:
 *  - the provider key never ships inside the APK
 *  - prompts stay server-side, so they can be tuned without an app update
 *  - the app talks to one stable contract, providers can be swapped freely
 *
 * Routes
 *   GET  /v1/health
 *   GET  /v1/scenes                 -> catalogue (no prompts leaked)
 *   POST /v1/upload                 -> multipart photo -> public R2 URL
 *   POST /v1/generate               -> { sceneId, imageUrl, imageUrl2? }
 *   GET  /v1/jobs/:id/status
 *   GET  /v1/jobs/:id
 *   PUT  /v1/jobs/:id/cancel
 *
 * Motion Control is intentionally NOT here. When that separate API arrives,
 * add an adapter in PROVIDERS and a second scene list - nothing else changes.
 */

import { DEFAULT_POOL_CONFIG, KeyPool, classifyFailure } from "./keys"

export interface Env {
	/** One or many provider keys, comma / newline separated. Rotated automatically. */
	GENPRESSO_API_KEYS: string
	/** Legacy single-key name, still honoured. */
	GENPRESSO_API_KEY?: string
	APP_SHARED_SECRET: string
	MEDIA?: R2Bucket
	/** KV for key health + job->key mapping. Strongly recommended. */
	STATE?: KVNamespace
	PUBLIC_BASE?: string // e.g. https://solu-ai-proxy.you.workers.dev
	/** Override the video model id without touching code. */
	VIDEO_MODEL?: string
	/** Credits loaded on each key (default 230). */
	KEY_CREDITS?: string
	/** Credits one video costs on the chosen model (default 45). */
	CREDITS_PER_VIDEO?: string
	/** Guard route for /v1/keys?reset=1 */
	ADMIN_SECRET?: string
}

const GP_BASE = "https://genpresso.ai/api/v1"

/** Test phase: no credits, no rate limiting. Flip on before public launch. */
const FEATURES = { rateLimit: false, credits: false }

/* ------------------------------------------------------------------ models */

/**
 * Model chain. Seedance was verified to REJECT human-face stills
 * ("content policy violation") across several providers, so it is not the
 * primary. Each candidate is tried in order until one accepts the job.
 */
/**
 * Model candidates, tried in order until one accepts the job.
 *
 * Primary is Omni Flash 1.1 (Sagar's account: 45 credits for one 9:16 1080p
 * clip). The exact provider id is confirmed from GET /v1/models - several
 * spellings are listed so the first deploy works even before that check, and
 * VIDEO_MODEL in wrangler.toml overrides everything.
 *
 * Seedance stays LAST: it was verified to reject human-face stills with
 * "content policy violation" across several providers.
 */
const VIDEO_CHAIN = [
	{ id: "gp/omni-flash-1.1/image-to-video", durationParam: true },
	{ id: "gp/omni-flash/1.1/image-to-video", durationParam: true },
	{ id: "omni-flash-1.1/image-to-video", durationParam: true },
	{ id: "gp/omni-flash-1.1", durationParam: true },
	{ id: "gp/minimax/hailuo-2.3/pro/image-to-video", durationParam: false },
	{ id: "gp/veo3.1", durationParam: true },
	{ id: "bytedance/seedance-2.5/image-to-video", durationParam: true },
]

/* ------------------------------------------------------------------ scenes */

type Scene = {
	id: string
	title: string
	subtitle: string
	category: string
	seconds: number
	photos: 1 | 2
	featured?: boolean
	sensitive?: boolean
	prompt: string
}

/** Applied to every scene: the single biggest quality lever. */
const IDENTITY_LOCK =
	"Preserve the exact facial identity, age, skin tone, facial structure, hair and " +
	"visible clothing details of the person in the reference photo. Do not beautify, " +
	"do not slim the face, do not change age, do not replace the person. " +
	"Photorealistic, cinematic, 9:16 vertical, soft film grain, 24fps motion."

const NEGATIVE =
	"distorted face, warped features, extra fingers, extra limbs, multiple people, " +
	"different person, face swap, horror, scary, creepy, demonic, zombie, blood, " +
	"nudity, text, captions, watermark, logo, glitch, low quality, oversaturated"

const SCENES: Scene[] = [
	{
		id: "swarg_darwaza",
		title: "Swarg Ka Darwaza",
		subtitle: "Alvida kehkar sone ke darwaze se swarg mein",
		category: "Shraddhanjali",
		seconds: 10,
		photos: 1,
		featured: true,
		sensitive: true,
		prompt:
			"The person from the photo stands in soft heavenly clouds wearing clean white " +
			"traditional Indian clothes. Behind them, at the top of a short flight of white " +
			"marble steps, stand tall glowing golden gates of heaven, slightly open, warm " +
			"divine light pouring through. " +
			"0-3s: they turn towards the camera and wave goodbye with a gentle peaceful smile. " +
			"3-7s: they turn away and slowly walk up the marble steps, back to camera. " +
			"7-10s: they walk through the open golden gate as the divine light gently fills " +
			"the frame. Volumetric god rays, floating light particles, white doves flying, " +
			"slow respectful camera push-in. Serene, dignified memorial film. No text.",
	},
	{
		id: "swarg_pushpak",
		title: "Pushpak Viman",
		subtitle: "Divya viman mein baadalon ke paar",
		category: "Shraddhanjali",
		seconds: 10,
		photos: 1,
		featured: true,
		sensitive: true,
		prompt:
			"The person from the photo sits calmly with folded hands inside a divine golden " +
			"pushpak viman decorated with marigold garlands. The viman slowly rises through " +
			"golden sunrise clouds towards a glowing light above. They look down towards the " +
			"camera once with a peaceful smile and fold their hands in namaste. Floating " +
			"flower petals, warm golden light, slow upward camera movement. Devotional, " +
			"respectful, no text.",
	},
	{
		id: "swarg_seedhi",
		title: "Prakash Ki Seedhi",
		subtitle: "Roshni ki seedhiyon par shaanti se",
		category: "Shraddhanjali",
		seconds: 10,
		photos: 1,
		sensitive: true,
		prompt:
			"The person from the photo stands at the bottom of a wide staircase made of soft " +
			"glowing light rising into bright clouds. They look back at the camera, smile " +
			"gently, touch their heart, then slowly climb the luminous steps and fade into " +
			"the warm light at the top. Gentle mist, floating sparkles, calm slow motion, " +
			"reverent tone, no text.",
	},
	{
		id: "shraddhanjali_frame",
		title: "Shraddhanjali",
		subtitle: "Haar chadhi tasveer, diya aur shraddha",
		category: "Shraddhanjali",
		seconds: 8,
		photos: 1,
		sensitive: true,
		prompt:
			"A dignified memorial portrait of the person from the photo, framed in a garlanded " +
			"wooden frame with fresh white and marigold flowers. A brass diya burns beside it, " +
			"incense smoke drifts slowly, white flower petals fall gently through the frame. " +
			"Very slow respectful camera push-in, warm candlelight. The portrait stays a " +
			"still photograph; only smoke, flame, petals and light move. No text.",
	},
	{
		id: "ashirwad_haath",
		title: "Ashirwad",
		subtitle: "Sar par pyaar bhara haath, ashirwad",
		category: "Blessing",
		seconds: 8,
		photos: 1,
		featured: true,
		sensitive: true,
		prompt:
			"The person from the photo appears in soft warm heavenly light, smiles lovingly at " +
			"the camera, then slowly raises their right hand in a blessing gesture towards the " +
			"viewer, as if placing it on the viewer's head. Gentle glow around the hand, warm " +
			"golden particles, tears of love in the eyes, very slow camera. Emotional, " +
			"comforting, no text.",
	},
	{
		id: "heaven_hug",
		title: "Aakhri Mulaqat",
		subtitle: "Do apne swarg mein phir milte hain",
		category: "Reunion",
		seconds: 10,
		photos: 2,
		sensitive: true,
		prompt:
			"The two people from the reference photos meet each other in soft heavenly clouds " +
			"wearing clean white traditional clothes. They walk towards each other, faces " +
			"lighting up with recognition, and share a warm long embrace with tears of joy. " +
			"Slow emotional camera orbit around them, golden divine light, floating petals. " +
			"Both faces must stay exactly as in their reference photos. No text.",
	},
	{
		id: "yaad_pyari",
		title: "Pyari Yaadein",
		subtitle: "Purani tasveer mein jaan, halki muskaan",
		category: "Memory",
		seconds: 8,
		photos: 1,
		featured: true,
		prompt:
			"Bring the old photograph gently to life: the person blinks naturally, breathes, " +
			"and a soft warm smile slowly appears. Very subtle head movement only, background " +
			"stays exactly the same, restored colours, gentle light bloom, slow parallax " +
			"camera push-in. Natural and believable, not exaggerated. No text.",
	},
]

const sceneById = (id: string) => SCENES.find((s) => s.id === id)

/* -------------------------------------------------------------------- utils */

const json = (body: unknown, status = 200) =>
	new Response(JSON.stringify(body), {
		status,
		headers: { "content-type": "application/json", "access-control-allow-origin": "*" },
	})

const fail = (code: string, message: string, status = 400) =>
	json({ error: { code, message } }, status)

function authed(req: Request, env: Env): boolean {
	if (!env.APP_SHARED_SECRET) return true // not configured yet
	return req.headers.get("x-solu-key") === env.APP_SHARED_SECRET
}

/** One upstream call with an explicit key from the pool. */
async function gp(path: string, key: string, init: RequestInit = {}) {
	return fetch(`${GP_BASE}${path}`, {
		...init,
		headers: {
			"content-type": "application/json",
			authorization: `Bearer ${key}`,
			...(init.headers as Record<string, string> | undefined),
		},
	})
}

const jobKeyMemory = new Map<string, string>()

async function buildPool(env: Env): Promise<KeyPool> {
	const raw = [env.GENPRESSO_API_KEYS, env.GENPRESSO_API_KEY].filter(Boolean).join(",")
	const pool = new KeyPool(raw, env.STATE, {
		keyCredits: Number(env.KEY_CREDITS ?? "") || DEFAULT_POOL_CONFIG.keyCredits,
		creditsPerVideo:
			Number(env.CREDITS_PER_VIDEO ?? "") || DEFAULT_POOL_CONFIG.creditsPerVideo,
	})
	await pool.load()
	return pool
}

/** VIDEO_MODEL env wins; otherwise walk the built-in candidate chain. */
function modelChain(env: Env) {
	if (env.VIDEO_MODEL) {
		return [{ id: env.VIDEO_MODEL, durationParam: true }, ...VIDEO_CHAIN]
	}
	return VIDEO_CHAIN
}

/**
 * Remember which key created a job, so status/result polling uses the same key
 * (a request id is only visible to the account that created it).
 */
async function rememberJobKey(env: Env, jobId: string, fp: string) {
	jobKeyMemory.set(jobId, fp)
	if (env.STATE) {
		await env.STATE.put(`job:${jobId}`, fp, { expirationTtl: 60 * 60 * 24 })
	}
}

async function recallJobKey(env: Env, jobId: string): Promise<string | undefined> {
	const local = jobKeyMemory.get(jobId)
	if (local) return local
	if (env.STATE) return (await env.STATE.get(`job:${jobId}`)) ?? undefined
	return undefined
}

/** Keys to try for a job lookup: the creator key first, then everyone else. */
function lookupOrder(pool: KeyPool, fp?: string): string[] {
	const all = pool.order()
	const owner = fp ? pool.keyByFingerprint(fp) : undefined
	return owner ? [owner, ...all.filter((k) => k !== owner)] : all
}

/** Walks any JSON shape and collects media URLs. */
function extractAssets(node: unknown, out: { type: string; url: string }[] = []) {
	if (typeof node === "string") {
		if (/^https?:\/\/\S+\.(mp4|webm|mov)(\?|$)/i.test(node)) out.push({ type: "video", url: node })
		else if (/^https?:\/\/\S+\.(png|jpe?g|webp|gif)(\?|$)/i.test(node))
			out.push({ type: "image", url: node })
	} else if (Array.isArray(node)) {
		for (const v of node) extractAssets(v, out)
	} else if (node && typeof node === "object") {
		for (const v of Object.values(node as Record<string, unknown>)) extractAssets(v, out)
	}
	return out
}

/* ------------------------------------------------------------------- routes */

export default {
	async fetch(req: Request, env: Env): Promise<Response> {
		const url = new URL(req.url)
		const path = url.pathname

		if (req.method === "OPTIONS") {
			return new Response(null, {
				headers: {
					"access-control-allow-origin": "*",
					"access-control-allow-methods": "GET,POST,PUT,OPTIONS",
					"access-control-allow-headers": "content-type,x-solu-key,x-solu-device",
				},
			})
		}

		// public: serve uploaded photos (R2 when the account has it, else KV)
		if (req.method === "GET" && path.startsWith("/f/")) {
			const fileKey = path.slice(3)

			if (env.MEDIA) {
				const obj = await env.MEDIA.get(fileKey)
				if (!obj) return fail("not_found", "file not found", 404)
				return new Response(obj.body, {
					headers: {
						"content-type": obj.httpMetadata?.contentType ?? "image/jpeg",
						"cache-control": "public, max-age=86400",
					},
				})
			}

			if (env.STATE) {
				const hit = await env.STATE.getWithMetadata(`f:${fileKey}`, "arrayBuffer")
				if (!hit.value) return fail("not_found", "file not found or expired", 404)
				const meta = (hit.metadata ?? {}) as { contentType?: string }
				return new Response(hit.value, {
					headers: {
						"content-type": meta.contentType ?? "image/jpeg",
						"cache-control": "public, max-age=86400",
					},
				})
			}

			return fail("no_storage", "no storage binding", 500)
		}

		if (path === "/v1/health") {
			return json({
				ok: true,
				mode: "reference-to-video",
				scenes: SCENES.length,
				storage: env.MEDIA ? "r2" : env.STATE ? "kv" : false,
				...(await (async () => {
					const p = await buildPool(env)
					return {
						keys: p.size,
						videosLeft: p.videosLeft(),
						videosPerKey: p.videosPerKey,
						model: env.VIDEO_MODEL ?? VIDEO_CHAIN[0].id,
					}
				})()),
				keyState: Boolean(env.STATE),
				testMode: !FEATURES.credits,
			})
		}

		if (!authed(req, env)) return fail("unauthorized", "bad app key", 401)

		// key pool dashboard - secrets are never returned, only labels
		if (req.method === "GET" && path === "/v1/keys") {
			const pool = await buildPool(env)

			// ?reset=1 after topping keys up (needs ADMIN_SECRET when configured)
			if (url.searchParams.get("reset") === "1") {
				const given = url.searchParams.get("admin")
				if (env.ADMIN_SECRET && given !== env.ADMIN_SECRET) {
					return fail("unauthorized", "admin secret required", 401)
				}
				pool.resetAll()
				await pool.flush()
			}

			if (url.searchParams.get("refresh") === "1") {
				await Promise.all(pool.order().map((k) => pool.refreshCredits(k, GP_BASE)))
				await pool.flush()
			}

			const report = pool.report()
			return json({
				totalKeys: report.length,
				usableKeys: report.filter((r) => r.status === "ok").length,
				videosLeft: pool.videosLeft(),
				creditsPerVideo: pool.cfg.creditsPerVideo,
				videosPerKey: pool.videosPerKey,
				keys: report,
			})
		}

		// which model ids does this account actually have? (run once, then set
		// VIDEO_MODEL in wrangler.toml to the exact Omni Flash 1.1 id)
		if (req.method === "GET" && path === "/v1/models") {
			const pool = await buildPool(env)
			for (const key of pool.order()) {
				const r = await gp("/models", key)
				if (!r.ok) continue
				const body = await r.text()
				return new Response(body, {
					headers: {
						"content-type": "application/json",
						"access-control-allow-origin": "*",
					},
				})
			}
			return fail("upstream_error", "no key could list models", 502)
		}

		// catalogue - prompts are stripped
		if (req.method === "GET" && path === "/v1/scenes") {
			return json({
				scenes: SCENES.map(({ prompt, ...rest }) => rest),
			})
		}

		// photo upload -> public URL
		if (req.method === "POST" && path === "/v1/upload") {
			if (!env.MEDIA && !env.STATE) return fail("no_storage", "no storage binding", 500)
			const form = await req.formData().catch(() => null)
			const file = form?.get("file")
			if (!(file instanceof File)) return fail("photo_required", "no file field", 400)
			if (file.size > 12 * 1024 * 1024) return fail("too_large", "max 12MB", 413)

			const ext = (file.type.split("/")[1] || "jpg").replace("jpeg", "jpg")
			const key = `u/${Date.now()}-${crypto.randomUUID()}.${ext}`
			const contentType = file.type || "image/jpeg"
			if (env.MEDIA) {
				await env.MEDIA.put(key, file.stream(), { httpMetadata: { contentType } })
			} else {
				// No R2 on this account: keep the photo in KV for 24h. The provider
				// only needs the URL long enough to fetch the reference image.
				await env.STATE!.put(`f:${key}`, await file.arrayBuffer(), {
					expirationTtl: 60 * 60 * 24,
					metadata: { contentType },
				})
			}
			const base = env.PUBLIC_BASE || `${url.protocol}//${url.host}`
			return json({ url: `${base}/f/${key}`, key })
		}

		// submit a scene
		if (req.method === "POST" && path === "/v1/generate") {
			const body = (await req.json().catch(() => null)) as
				| { sceneId?: string; imageUrl?: string; imageUrl2?: string }
				| null
			if (!body) return fail("bad_json", "invalid body")

			const scene = sceneById(body.sceneId ?? "")
			if (!scene) return fail("unknown_scene", `unknown scene ${body.sceneId}`)
			if (!body.imageUrl) return fail("photo_required", "imageUrl is required")
			if (scene.photos === 2 && !body.imageUrl2)
				return fail("second_photo_required", "this scene needs 2 photos")

			const prompt = `${scene.prompt}\n\n${IDENTITY_LOCK}`
			const needCredits = DEFAULT_POOL_CONFIG.creditsPerVideo

			const pool = await buildPool(env)
			if (pool.size === 0) return fail("not_configured", "no provider keys set", 500)

			const candidates = pool.order(
				Number(env.CREDITS_PER_VIDEO ?? "") || needCredits,
			)
			const tried: string[] = []
			let lastError = ""

			// key loop x model loop: the user only sees a failure if EVERY
			// key/model combination refuses the job.
			for (const key of candidates) {
				let keyBurned = false

				for (const model of modelChain(env)) {
					const payload: Record<string, unknown> = {
						prompt,
						negative_prompt: NEGATIVE,
						image_url: body.imageUrl,
						aspect_ratio: "9:16",
						resolution: "1080p",
					}
					if (model.durationParam) payload.duration = scene.seconds
					if (body.imageUrl2) payload.image_urls = [body.imageUrl, body.imageUrl2]

					const res = await gp(`/media/${model.id}`, key, {
						method: "POST",
						body: JSON.stringify(payload),
					})
					const text = await res.text()
					const data = (() => {
						try {
							return JSON.parse(text) as Record<string, unknown>
						} catch {
							return {} as Record<string, unknown>
						}
					})()

					if (res.ok) {
						const jobId = (data.request_id ?? data.id) as string | undefined
						if (!jobId) {
							lastError = "provider returned no request id"
							continue
						}
						pool.markOk(key)
						pool.charge(key, pool.cfg.creditsPerVideo)
						await pool.flush()
						await rememberJobKey(env, jobId, pool.fingerprintOf(key))
						return json({
							jobId,
							sceneId: scene.id,
							seconds: scene.seconds,
							model: model.id,
							key: `key-${candidates.indexOf(key) + 1}`,
							creditsLeft: pool.creditsLeft(key),
							videosLeftOnPool: pool.videosLeft(),
							attempts: tried.length + 1,
						})
					}

					lastError = `${res.status} ${text.slice(0, 200)}`
					tried.push(`${model.id}:${res.status}`)
					const kind = classifyFailure(res.status, text)

					if (kind === "exhausted") {
						// no balance -> this key is done, jump straight to the next key
						pool.markExhausted(key, lastError)
						keyBurned = true
						break
					}
					if (kind === "invalid") {
						pool.markInvalid(key, lastError)
						keyBurned = true
						break
					}
					if (kind === "rate_limited") {
						const ra = Number(res.headers.get("retry-after") ?? "")
						pool.markRateLimited(key, Number.isFinite(ra) ? ra : undefined)
						keyBurned = true
						break
					}
					// "model" / "other" -> same key, next model (e.g. face policy reject)
				}

				if (keyBurned) continue
			}

			await pool.flush()
			const everyKeyDry = pool.report().every((r) => r.status !== "ok")
			if (everyKeyDry) {
				return fail(
					"insufficient_credits",
					"all provider keys are out of credits or blocked",
					402,
				)
			}
			return fail("upstream_error", `all keys/models failed: ${lastError}`, 502)
		}

		const jobMatch = path.match(/^\/v1\/jobs\/([^/]+)(\/status|\/cancel)?$/)
		if (jobMatch) {
			const id = jobMatch[1]
			const suffix = jobMatch[2]

			const pool = await buildPool(env)
			const order = lookupOrder(pool, await recallJobKey(env, id))
			if (order.length === 0) return fail("not_configured", "no provider keys set", 500)

			if (suffix === "/cancel" && req.method === "PUT") {
				for (const key of order) {
					const r = await gp(`/media/requests/${id}/cancel`, key, { method: "PUT" })
					if (r.ok) return json({ ok: true })
				}
				return json({ ok: false })
			}

			if (suffix === "/status" && req.method === "GET") {
				for (const key of order) {
					const r = await gp(`/media/requests/${id}/status`, key)
					if (!r.ok) continue
					const d = (await r.json().catch(() => ({}))) as Record<string, unknown>
					if (d.status) return json({ status: d.status as string })
				}
				return json({ status: "IN_PROGRESS" })
			}

			if (!suffix && req.method === "GET") {
				for (const key of order) {
					const r = await gp(`/media/requests/${id}`, key)
					if (!r.ok) continue
					const d = (await r.json().catch(() => ({}))) as Record<string, unknown>
					const assets = extractAssets(d)
					if (assets.length || d.status) {
						return json({
							status: assets.length ? "COMPLETED" : (d.status as string),
							assets,
						})
					}
				}
				return json({ status: "IN_PROGRESS", assets: [] })
			}
		}

		return fail("not_found", `no route for ${req.method} ${path}`, 404)
	},
}
