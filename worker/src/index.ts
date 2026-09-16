/**
 * Solu AI proxy — BlitzReels two-stage pipeline.
 *
 * Stage 1 (hidden from the user): generate a full-body character sheet of the
 * uploaded person wearing white "swarg" clothes, using an image model with the
 * user's photo as a reference asset.
 * Stage 2: feed that character sheet back as the reference asset for a
 * reference-to-video generation (10s, 9:16, 720p, no dialogue).
 *
 * The app only ever polls one flow id and only ever sees the final video.
 */

export interface Env {
	BLITZREELS_API_KEYS?: string
	BLITZREELS_API_KEY?: string
	GENPRESSO_API_KEYS?: string
	APP_SHARED_SECRET: string
	STATE?: KVNamespace
	PUBLIC_BASE?: string
	IMAGE_MODEL?: string
	VIDEO_MODEL?: string
	ADMIN_SECRET?: string
}

const BR_BASE = "https://blitzreels.com/api/v1"
const DEFAULT_IMAGE_MODEL = "fal-ai/gpt-image-2"

/** Tried in order until the upstream accepts one. */
const VIDEO_MODEL_CHAIN = [
	"bytedance/seedance-2.0/pro/reference-to-video",
	"fal-ai/bytedance/seedance-2.0/reference-to-video",
	"bytedance/seedance-2.5/reference-to-video",
	"fal-ai/bytedance/seedance-2.0/pro/image-to-video",
	"fal-ai/bytedance/seedance/v2/pro/reference-to-video",
]

const IDENTITY_LOCK =
	"The person must stay exactly the same as the reference: identical face, facial structure, eyes, nose, lips, skin tone, hair and body type. Do not beautify, do not change age, do not change gender, do not swap the face."

const CHARACTER_SHEET_PROMPT = [
	"Full body photorealistic character reference sheet of the SAME person as in the reference photo, standing straight and facing the camera, head to toe fully visible.",
	"They wear clean pure-white traditional Indian clothing (white kurta-pyjama or white saree with a light white shawl), simple and dignified.",
	"Soft even studio lighting, plain soft white cloud-like background, calm peaceful expression, sharp focus on the face.",
	IDENTITY_LOCK,
	"No text, no watermark, no logo, no extra people, no collage, no frames.",
].join(" ")

type Scene = {
	id: string
	title: string
	durationSeconds: number
	videoPrompt: string
	sheetPrompt?: string
}

const SCENES: Scene[] = [
	{
		id: "swarg_darwaza",
		title: "Swarg ka Darwaza",
		durationSeconds: 10,
		videoPrompt: [
			"The same person from the reference image stands on white marble steps in front of the tall golden gates of heaven, surrounded by soft glowing clouds and warm god rays.",
			"First they turn towards the camera and join their hands in a gentle namaste with a happy peaceful smile.",
			"Then they raise one hand and wave goodbye warmly.",
			"Finally they turn around, walk up the steps and pass through the open golden gate into soft divine light.",
			"Slow cinematic camera push-in, white doves flying, floating light particles, serene heavenly atmosphere.",
			"No dialogue, no speech, no lip movement, no on-screen text, no subtitles, no watermark.",
			IDENTITY_LOCK,
		].join(" "),
	},
	{
		id: "swarg_seedhi",
		title: "Swarg ki Seedhi",
		durationSeconds: 10,
		videoPrompt: [
			"The same person from the reference image climbs a glowing white stairway rising through the clouds towards a bright divine light.",
			"They pause, look back at the camera, do a gentle namaste and wave goodbye with a calm happy smile, then continue upward into the light.",
			"Soft golden god rays, drifting clouds, white doves, slow cinematic camera.",
			"No dialogue, no on-screen text, no watermark.",
			IDENTITY_LOCK,
		].join(" "),
	},
	{
		id: "ashirwad_haath",
		title: "Ashirwad",
		durationSeconds: 10,
		videoPrompt: [
			"The same person from the reference image stands among soft heavenly clouds in white traditional clothes, smiles warmly at the camera, raises their right hand to give a blessing, then folds both hands in namaste.",
			"Warm golden light, floating particles, gentle cinematic camera.",
			"No dialogue, no on-screen text, no watermark.",
			IDENTITY_LOCK,
		].join(" "),
	},
]

function sceneById(id: string): Scene | undefined {
	return SCENES.find((s) => s.id === id)
}

const CORS: Record<string, string> = {
	"access-control-allow-origin": "*",
	"access-control-allow-headers": "content-type,x-solu-key,x-solu-device",
	"access-control-allow-methods": "GET,POST,PUT,OPTIONS",
}

function json(data: unknown, status = 200): Response {
	return new Response(JSON.stringify(data), {
		status,
		headers: { "content-type": "application/json; charset=utf-8", ...CORS },
	})
}

function fail(code: string, message: string, status = 400, extra: Record<string, unknown> = {}) {
	return json({ error: { code, message, ...extra } }, status)
}

function authed(req: Request, env: Env): boolean {
	if (!env.APP_SHARED_SECRET) return false
	return req.headers.get("x-solu-key") === env.APP_SHARED_SECRET
}

/* ---------------------------------------------------------------- key pool */

type KeyState = { cooldownUntil?: number; invalid?: boolean; lastError?: string }
type PoolState = Record<string, KeyState>

const POOL_STATE_KEY = "brkeys:v1"
const COOLDOWN_NO_CREDITS = 6 * 60 * 60 * 1000
const COOLDOWN_RATE_LIMIT = 60 * 1000

function rawKeys(env: Env): string[] {
	const blob = [env.BLITZREELS_API_KEYS, env.BLITZREELS_API_KEY, env.GENPRESSO_API_KEYS]
		.filter(Boolean)
		.join(",")
	const seen = new Set<string>()
	const out: string[] = []
	for (const part of blob.split(/[,\s\n]+/)) {
		const k = part.trim()
		if (!k || seen.has(k)) continue
		seen.add(k)
		out.push(k)
	}
	return out
}

function fpOf(key: string): string {
	return `${key.slice(0, 11)}…${key.slice(-4)}`
}

async function loadPool(env: Env): Promise<PoolState> {
	if (!env.STATE) return {}
	try {
		return ((await env.STATE.get(POOL_STATE_KEY, "json")) as PoolState) || {}
	} catch {
		return {}
	}
}

async function savePool(env: Env, pool: PoolState): Promise<void> {
	if (!env.STATE) return
	try {
		await env.STATE.put(POOL_STATE_KEY, JSON.stringify(pool))
	} catch {
		/* ignore */
	}
}

async function orderedKeys(env: Env): Promise<string[]> {
	const pool = await loadPool(env)
	const now = Date.now()
	const all = rawKeys(env)
	const ready = all.filter((k) => {
		const st = pool[fpOf(k)]
		if (!st) return true
		if (st.invalid) return false
		return !st.cooldownUntil || st.cooldownUntil <= now
	})
	// If every key is cooling down, still try them rather than hard-failing.
	return ready.length ? ready : all.filter((k) => !pool[fpOf(k)]?.invalid)
}

async function markKey(env: Env, key: string, patch: KeyState): Promise<void> {
	const pool = await loadPool(env)
	pool[fpOf(key)] = { ...(pool[fpOf(key)] || {}), ...patch }
	await savePool(env, pool)
}

type BrResult<T> = { ok: true; data: T; key: string } | { ok: false; status: number; body: string }

async function br(path: string, key: string, init: RequestInit = {}): Promise<Response> {
	const headers: Record<string, string> = {
		authorization: `Bearer ${key}`,
		...((init.headers as Record<string, string>) || {}),
	}
	if (init.body && !headers["content-type"]) headers["content-type"] = "application/json"
	return fetch(`${BR_BASE}${path}`, { ...init, headers })
}

/** Runs `attempt` against each healthy key, rotating on auth/credit/rate errors. */
async function withKeys<T>(
	env: Env,
	attempt: (key: string) => Promise<Response>,
): Promise<BrResult<T>> {
	const keys = await orderedKeys(env)
	if (!keys.length) return { ok: false, status: 500, body: "no api keys configured" }
	let last: { status: number; body: string } = { status: 500, body: "no attempt made" }
	for (const key of keys) {
		let res: Response
		try {
			res = await attempt(key)
		} catch (err) {
			last = { status: 502, body: String(err) }
			continue
		}
		const text = await res.text()
		if (res.ok) {
			let data: unknown = null
			try {
				data = text ? JSON.parse(text) : {}
			} catch {
				data = {}
			}
			return { ok: true, data: data as T, key }
		}
		last = { status: res.status, body: text.slice(0, 600) }
		if (res.status === 401 || res.status === 403) {
			await markKey(env, key, { invalid: true, lastError: "unauthorized" })
			continue
		}
		if (res.status === 402 || /credit|balance|quota/i.test(text)) {
			await markKey(env, key, {
				cooldownUntil: Date.now() + COOLDOWN_NO_CREDITS,
				lastError: "out of credits",
			})
			continue
		}
		if (res.status === 429) {
			await markKey(env, key, {
				cooldownUntil: Date.now() + COOLDOWN_RATE_LIMIT,
				lastError: "rate limited",
			})
			continue
		}
		// 4xx/5xx that is not key-specific: no point trying other keys.
		return { ok: false, status: res.status, body: last.body }
	}
	return { ok: false, status: last.status, body: last.body }
}

/* ------------------------------------------------------------ media upload */

type UploadInit = { upload_url: string; storage_key: string; expires_in?: number }

const FINALIZE_PATHS = [
	"/workspace/media/upload/complete",
	"/workspace/media/upload/finalize",
]

async function uploadToBlitz(
	env: Env,
	bytes: ArrayBuffer,
	fileName: string,
	contentType: string,
): Promise<{ assetId: string; key: string } | { error: string; status: number }> {
	const init = await withKeys<UploadInit>(env, (key) =>
		br("/workspace/media/upload/init", key, {
			method: "POST",
			body: JSON.stringify({ file_name: fileName, content_type: contentType }),
		}),
	)
	if (!init.ok) return { error: `upload_init_failed: ${init.body}`, status: init.status }

	const put = await fetch(init.data.upload_url, {
		method: "PUT",
		headers: { "content-type": contentType },
		body: bytes,
	})
	if (!put.ok) {
		return { error: `presigned_put_failed: ${put.status}`, status: 502 }
	}

	const payload = JSON.stringify({
		storage_key: init.data.storage_key,
		file_name: fileName,
		content_type: contentType,
		size_bytes: bytes.byteLength,
	})
	for (const path of FINALIZE_PATHS) {
		const done = await withKeys<Record<string, any>>(env, (key) =>
			br(path, key, { method: "POST", body: payload }),
		)
		if (done.ok) {
			const d = done.data as Record<string, any>
			const assetId =
				d.asset_id || d.assetId || d.id || d.asset?.id || d.media?.id || d.media_id
			if (assetId) return { assetId: String(assetId), key: done.key }
			return { error: `finalize_missing_asset_id: ${JSON.stringify(d).slice(0, 300)}`, status: 502 }
		}
		if (done.status !== 404) {
			return { error: `finalize_failed: ${done.body}`, status: done.status }
		}
	}
	return { error: "finalize_route_not_found", status: 502 }
}

/* ------------------------------------------------------------------- flows */

type Flow = {
	id: string
	sceneId: string
	sourceAssetId: string
	stage: "image" | "video" | "done" | "error"
	imageJobId?: string
	sheetAssetId?: string
	videoJobId?: string
	videoModel?: string
	videoUrl?: string
	thumbUrl?: string
	error?: string
	credits?: number
	createdAt: number
	updatedAt: number
}

async function saveFlow(env: Env, flow: Flow): Promise<void> {
	flow.updatedAt = Date.now()
	if (!env.STATE) return
	await env.STATE.put(`flow:${flow.id}`, JSON.stringify(flow), {
		expirationTtl: 60 * 60 * 24 * 7,
	})
}

async function loadFlow(env: Env, id: string): Promise<Flow | null> {
	if (!env.STATE) return null
	return ((await env.STATE.get(`flow:${id}`, "json")) as Flow) || null
}

type JobResponse = {
	job_id?: string
	status?: string
	kind?: string
	media_id?: string
	progress?: number
	error?: unknown
	estimated_credits?: number
	credits?: number
	asset?: Record<string, any>
	media?: Record<string, any>
	result?: Record<string, any>
	output?: Record<string, any>
	download_url?: string
	url?: string
}

function jobStatus(job: JobResponse): "queued" | "running" | "done" | "failed" {
	const s = String(job.status || "").toLowerCase()
	if (["completed", "complete", "succeeded", "success", "done", "ready"].includes(s)) return "done"
	if (["failed", "error", "canceled", "cancelled", "expired"].includes(s)) return "failed"
	if (["queued", "pending", "created", "waiting"].includes(s)) return "queued"
	return "running"
}

function pickUrl(job: JobResponse): string | undefined {
	const candidates = [
		job.download_url,
		job.url,
		job.asset?.url,
		job.asset?.download_url,
		job.media?.url,
		job.media?.download_url,
		job.result?.url,
		job.result?.download_url,
		job.result?.video_url,
		job.result?.image_url,
		job.output?.url,
		job.output?.video_url,
		job.output?.image_url,
	]
	return candidates.find((u) => typeof u === "string" && u.startsWith("http")) as string | undefined
}

function pickAssetId(job: JobResponse): string | undefined {
	const candidates = [
		job.media_id,
		job.asset?.id,
		job.media?.id,
		job.result?.asset_id,
		job.result?.media_id,
		(job as any).asset_id,
	]
	return candidates.find((v) => typeof v === "string" && v.length > 0) as string | undefined
}

async function getJob(env: Env, jobId: string): Promise<BrResult<JobResponse>> {
	return withKeys<JobResponse>(env, (key) => br(`/generation-jobs/${jobId}`, key))
}

async function submitCharacterSheet(
	env: Env,
	scene: Scene,
	sourceAssetId: string,
): Promise<BrResult<JobResponse>> {
	const body = {
		prompt: scene.sheetPrompt || CHARACTER_SHEET_PROMPT,
		model: env.IMAGE_MODEL || DEFAULT_IMAGE_MODEL,
		aspect_ratio: "9:16",
		reference_asset_ids: [sourceAssetId],
		enhance_prompt: false,
	}
	return withKeys<JobResponse>(env, (key) =>
		br("/generate-image", key, { method: "POST", body: JSON.stringify(body) }),
	)
}

/**
 * Submits the reference-to-video job. Model ids and optional parameters differ
 * between upstream providers, so we walk a chain of payload shapes and stop at
 * the first one the API accepts.
 */
async function submitVideo(
	env: Env,
	scene: Scene,
	sheetAssetId: string,
): Promise<{ result: BrResult<JobResponse>; model?: string }> {
	const models = [env.VIDEO_MODEL, ...VIDEO_MODEL_CHAIN].filter(
		(m): m is string => typeof m === "string" && m.trim().length > 0,
	)
	const base = {
		prompt: scene.videoPrompt,
		reference_asset_ids: [sheetAssetId],
		aspect_ratio: "9:16",
	}
	let last: BrResult<JobResponse> = { ok: false, status: 500, body: "no attempt made" }
	for (const model of models) {
		const variants: Record<string, unknown>[] = [
			{ ...base, model, resolution: "720p", duration_seconds: scene.durationSeconds },
			{ ...base, model, resolution: "720p", duration: scene.durationSeconds },
			{ ...base, model, duration_seconds: scene.durationSeconds },
			{ ...base, model },
		]
		for (const body of variants) {
			const res = await withKeys<JobResponse>(env, (key) =>
				br("/generate-video", key, { method: "POST", body: JSON.stringify(body) }),
			)
			if (res.ok) return { result: res, model }
			last = res
			// Only keep probing when the upstream rejected the shape or the model id.
			if (res.status !== 400 && res.status !== 404 && res.status !== 422) {
				return { result: res, model }
			}
		}
	}
	return { result: last }
}

/** Advances a flow: image done -> submit video; video done -> expose url. */
async function advance(env: Env, flow: Flow): Promise<Flow> {
	if (flow.stage === "done" || flow.stage === "error") return flow

	if (flow.stage === "image" && flow.imageJobId) {
		const job = await getJob(env, flow.imageJobId)
		if (!job.ok) {
			if (job.status >= 500) return flow // transient, keep polling
			flow.stage = "error"
			flow.error = `character_sheet_failed: ${job.body}`
			await saveFlow(env, flow)
			return flow
		}
		const state = jobStatus(job.data)
		if (state === "failed") {
			flow.stage = "error"
			flow.error = "character_sheet_rejected"
			await saveFlow(env, flow)
			return flow
		}
		if (state !== "done") return flow

		const sheetAssetId = pickAssetId(job.data)
		if (!sheetAssetId) {
			flow.stage = "error"
			flow.error = "character_sheet_asset_missing"
			await saveFlow(env, flow)
			return flow
		}
		flow.sheetAssetId = sheetAssetId

		const scene = sceneById(flow.sceneId) || SCENES[0]
		const { result, model } = await submitVideo(env, scene, sheetAssetId)
		if (!result.ok) {
			flow.stage = "error"
			flow.error = `video_submit_failed: ${result.body}`
			await saveFlow(env, flow)
			return flow
		}
		flow.stage = "video"
		flow.videoModel = model
		flow.videoJobId = result.data.job_id
		flow.credits = (flow.credits || 0) + (result.data.estimated_credits || 0)
		await saveFlow(env, flow)
		return flow
	}

	if (flow.stage === "video" && flow.videoJobId) {
		const job = await getJob(env, flow.videoJobId)
		if (!job.ok) {
			if (job.status >= 500) return flow
			flow.stage = "error"
			flow.error = `video_failed: ${job.body}`
			await saveFlow(env, flow)
			return flow
		}
		const state = jobStatus(job.data)
		if (state === "failed") {
			flow.stage = "error"
			flow.error = "video_rejected"
			await saveFlow(env, flow)
			return flow
		}
		if (state !== "done") return flow

		const url = pickUrl(job.data)
		if (!url) {
			flow.stage = "error"
			flow.error = "video_url_missing"
			await saveFlow(env, flow)
			return flow
		}
		flow.stage = "done"
		flow.videoUrl = url
		await saveFlow(env, flow)
		return flow
	}

	return flow
}

function flowView(flow: Flow) {
	const progress =
		flow.stage === "done"
			? 100
			: flow.stage === "error"
				? 0
				: flow.stage === "image"
					? 25
					: 65
	return {
		id: flow.id,
		sceneId: flow.sceneId,
		// The app deliberately never learns about the hidden character sheet step.
		state: flow.stage === "done" ? "done" : flow.stage === "error" ? "error" : "rendering",
		progress,
		videoUrl: flow.videoUrl || null,
		error: flow.error || null,
		createdAt: flow.createdAt,
	}
}

/* ------------------------------------------------------------------ router */

export default {
	async fetch(req: Request, env: Env): Promise<Response> {
		const url = new URL(req.url)
		const path = url.pathname.replace(/\/+$/, "") || "/"

		if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS })

		if (path === "/" || path === "/v1/health") {
			const pool = await loadPool(env)
			const keys = rawKeys(env)
			return json({
				ok: true,
				service: "solu-ai-proxy",
				provider: "blitzreels",
				pipeline: ["character_sheet(image)", "reference_to_video"],
				imageModel: env.IMAGE_MODEL || DEFAULT_IMAGE_MODEL,
				videoModel: env.VIDEO_MODEL || VIDEO_MODEL_CHAIN[0],
				videoModelChain: VIDEO_MODEL_CHAIN,
				storage: env.STATE ? "kv" : "none",
				keys: keys.length,
				keyState: Object.fromEntries(
					keys.map((k) => [fpOf(k), pool[fpOf(k)] || { ok: true }]),
				),
				scenes: SCENES.map((s) => s.id),
				configured: keys.length > 0 && Boolean(env.APP_SHARED_SECRET),
			})
		}

		if (path === "/v1/scenes") {
			return json({
				scenes: SCENES.map((s) => ({
					id: s.id,
					title: s.title,
					durationSeconds: s.durationSeconds,
					photos: 1,
				})),
			})
		}

		if (!authed(req, env)) return fail("unauthorized", "Missing or invalid x-solu-key", 401)

		/** Diagnostics: shows the upstream's real model ids and credit pricing. */
		if (path === "/v1/upstream" && req.method === "GET") {
			const target = url.searchParams.get("path") || "/generation-options"
			const res = await withKeys<unknown>(env, (key) => br(target, key))
			return res.ok
				? json({ path: target, data: res.data })
				: fail("upstream_error", res.body, res.status)
		}

		if (path === "/v1/keys" && req.method === "GET") {
			if (url.searchParams.get("reset") === "1") {
				if (!env.ADMIN_SECRET || url.searchParams.get("admin") !== env.ADMIN_SECRET) {
					return fail("unauthorized", "admin secret required", 401)
				}
				await savePool(env, {})
			}
			const pool = await loadPool(env)
			return json({
				keys: rawKeys(env).map((k) => ({ fingerprint: fpOf(k), ...(pool[fpOf(k)] || {}) })),
			})
		}

		/** Uploads the user's photo straight into the BlitzReels media library. */
		if (path === "/v1/upload" && req.method === "POST") {
			let form: FormData
			try {
				form = await req.formData()
			} catch {
				return fail("bad_request", "multipart/form-data with a 'file' field is required")
			}
			const file = form.get("file")
			if (!(file instanceof File)) return fail("photo_required", "No file provided")
			if (file.size > 12 * 1024 * 1024) return fail("too_large", "Max photo size is 12 MB", 413)

			const bytes = await file.arrayBuffer()
			const contentType = file.type || "image/jpeg"
			const ext = contentType.includes("png") ? "png" : "jpg"
			const res = await uploadToBlitz(env, bytes, `solu-${crypto.randomUUID()}.${ext}`, contentType)
			if ("error" in res) return fail("upstream_error", res.error, res.status)
			return json({ assetId: res.assetId })
		}

		/** Starts the hidden character sheet, then the video, as one flow. */
		if (path === "/v1/generate" && req.method === "POST") {
			let body: { sceneId?: string; assetId?: string }
			try {
				body = (await req.json()) as typeof body
			} catch {
				return fail("bad_json", "Body must be JSON")
			}
			const scene = sceneById(body.sceneId || "swarg_darwaza")
			if (!scene) return fail("unknown_scene", `Unknown sceneId ${body.sceneId}`)
			if (!body.assetId) return fail("photo_required", "assetId from /v1/upload is required")
			if (!env.STATE) return fail("no_storage", "KV namespace STATE is not bound", 500)

			const sheet = await submitCharacterSheet(env, scene, body.assetId)
			if (!sheet.ok) return fail("upstream_error", sheet.body, sheet.status)

			const flow: Flow = {
				id: crypto.randomUUID(),
				sceneId: scene.id,
				sourceAssetId: body.assetId,
				stage: "image",
				imageJobId: sheet.data.job_id,
				credits: sheet.data.estimated_credits || 1,
				createdAt: Date.now(),
				updatedAt: Date.now(),
			}
			await saveFlow(env, flow)
			return json(flowView(flow), 202)
		}

		const jobMatch = path.match(/^\/v1\/jobs\/([^/]+)(\/status)?$/)
		if (jobMatch && req.method === "GET") {
			const flow = await loadFlow(env, jobMatch[1])
			if (!flow) return fail("not_found", "Unknown job id", 404)
			return json(flowView(await advance(env, flow)))
		}

		return fail("not_found", `No route for ${req.method} ${path}`, 404)
	},
}
