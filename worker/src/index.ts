/**
 * Solu AI proxy — BlitzReels two-stage pipeline, single API key.
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
	BLITZREELS_API_KEY?: string
	/** Legacy name, still accepted; only the first key is used. */
	BLITZREELS_API_KEYS?: string
	APP_SHARED_SECRET: string
	STATE?: KVNamespace
	IMAGE_MODEL?: string
	VIDEO_MODEL?: string
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

function fail(code: string, message: string, status = 400) {
	return json({ error: { code, message } }, status)
}

function authed(req: Request, env: Env): boolean {
	if (!env.APP_SHARED_SECRET) return false
	return req.headers.get("x-solu-key") === env.APP_SHARED_SECRET
}

function sleep(ms: number): Promise<void> {
	return new Promise((resolve) => setTimeout(resolve, ms))
}

/* -------------------------------------------------------------- single key */

/** The one BlitzReels key used for both image and video generation. */
function apiKey(env: Env): string {
	const raw = (env.BLITZREELS_API_KEY || env.BLITZREELS_API_KEYS || "").trim()
	// Tolerate a legacy comma/newline separated value by taking the first entry.
	return raw.split(/[,\s\n]+/).filter(Boolean)[0] || ""
}

type BrResult<T> = { ok: true; data: T } | { ok: false; status: number; body: string }

/** Calls BlitzReels with the single key and normalises the result. */
async function br<T>(env: Env, path: string, init: RequestInit = {}): Promise<BrResult<T>> {
	const key = apiKey(env)
	if (!key) return { ok: false, status: 500, body: "BLITZREELS_API_KEY is not set" }

	const headers: Record<string, string> = {
		authorization: `Bearer ${key}`,
		...((init.headers as Record<string, string>) || {}),
	}
	if (init.body && !headers["content-type"]) headers["content-type"] = "application/json"

	let res: Response
	try {
		res = await fetch(`${BR_BASE}${path}`, { ...init, headers })
	} catch (err) {
		return { ok: false, status: 502, body: String(err) }
	}

	const text = await res.text()
	if (!res.ok) return { ok: false, status: res.status, body: text.slice(0, 600) }

	let data: unknown = {}
	try {
		data = text ? JSON.parse(text) : {}
	} catch {
		data = {}
	}
	return { ok: true, data: data as T }
}

/* ------------------------------------------------------------ media upload */

type UploadInit = { upload_url?: string; storage_key?: string; expires_in?: number }

const UPLOAD_INIT_PATHS = ["/workspace/media/upload/init", "/media/upload/init"]
const FINALIZE_PATHS = ["/workspace/media/upload/complete", "/workspace/media/upload/finalize"]
const IMPORT_PATHS = [
	"/workspace/media/import-url",
	"/workspace/media/import",
	"/media/import-url",
]

function assetIdOf(d: Record<string, any>): string | undefined {
	const v = d.asset_id || d.assetId || d.id || d.asset?.id || d.media?.id || d.media_id
	return v ? String(v) : undefined
}

/** Presigned flow: init -> PUT -> finalize. Retries the flaky init step. */
async function presignedUpload(
	env: Env,
	bytes: ArrayBuffer,
	fileName: string,
	contentType: string,
	log: string[],
): Promise<string | null> {
	const bodies: Record<string, unknown>[] = [
		{ file_name: fileName, content_type: contentType, size_bytes: bytes.byteLength },
		{ file_name: fileName, content_type: contentType },
		{ file_name: fileName, mime_type: contentType, size_bytes: bytes.byteLength },
		{ file_name: fileName, content_type: contentType, folder_id: "root" },
	]

	for (const path of UPLOAD_INIT_PATHS) {
		for (const body of bodies) {
			for (let attempt = 1; attempt <= 3; attempt++) {
				const init = await br<UploadInit>(env, path, {
					method: "POST",
					body: JSON.stringify(body),
				})

				if (init.ok && init.data.upload_url) {
					const put = await fetch(init.data.upload_url, {
						method: "PUT",
						headers: { "content-type": contentType },
						body: bytes,
					})
					if (!put.ok) {
						log.push(`put ${put.status}`)
						break
					}
					const payload = JSON.stringify({
						storage_key: init.data.storage_key,
						file_name: fileName,
						content_type: contentType,
						size_bytes: bytes.byteLength,
					})
					for (const finalizePath of FINALIZE_PATHS) {
						const done = await br<Record<string, any>>(env, finalizePath, {
							method: "POST",
							body: payload,
						})
						if (done.ok) {
							const id = assetIdOf(done.data)
							if (id) return id
							log.push(`finalize ok but no asset id: ${JSON.stringify(done.data).slice(0, 160)}`)
						} else {
							log.push(`finalize ${finalizePath} ${done.status}`)
						}
					}
					break
				}

				const status = init.ok ? 200 : init.status
				log.push(`init ${path} [${Object.keys(body).join(",")}] -> ${status}`)

				// Their init handler returns a retryable 500 fairly often.
				if (!init.ok && init.status >= 500 && attempt < 3) {
					await sleep(700 * attempt)
					continue
				}
				break
			}
		}
	}
	return null
}

/**
 * Fallback: park the bytes on this Worker, expose them at a short-lived public
 * URL and ask BlitzReels to import that URL instead.
 */
async function importUpload(
	env: Env,
	bytes: ArrayBuffer,
	fileName: string,
	contentType: string,
	origin: string,
	log: string[],
): Promise<string | null> {
	if (!env.STATE) {
		log.push("import skipped: no KV")
		return null
	}

	const id = crypto.randomUUID()
	await env.STATE.put(`f:${id}`, bytes, {
		metadata: { ct: contentType },
		expirationTtl: 60 * 60 * 24,
	})
	const publicUrl = `${origin}/v1/f/${id}`

	const bodies: Record<string, unknown>[] = [
		{ url: publicUrl, file_name: fileName },
		{ source_url: publicUrl, file_name: fileName },
		{ media_url: publicUrl, file_name: fileName },
	]

	for (const path of IMPORT_PATHS) {
		for (const body of bodies) {
			const res = await br<Record<string, any>>(env, path, {
				method: "POST",
				body: JSON.stringify(body),
			})
			if (res.ok) {
				const assetId = assetIdOf(res.data)
				if (assetId) return assetId
				log.push(`import ok but no asset id: ${JSON.stringify(res.data).slice(0, 160)}`)
				continue
			}
			log.push(`import ${path} [${Object.keys(body).join(",")}] -> ${res.status}`)
			if (res.status === 404) break // path does not exist, try the next one
		}
	}
	return null
}

async function uploadToBlitz(
	env: Env,
	bytes: ArrayBuffer,
	fileName: string,
	contentType: string,
	origin: string,
): Promise<{ assetId: string } | { error: string; status: number }> {
	const log: string[] = []

	const direct = await presignedUpload(env, bytes, fileName, contentType, log)
	if (direct) return { assetId: direct }

	const imported = await importUpload(env, bytes, fileName, contentType, origin, log)
	if (imported) return { assetId: imported }

	return { error: `upload_failed_all_routes: ${log.join(" | ").slice(0, 500)}`, status: 502 }
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
	return br<JobResponse>(env, `/generation-jobs/${jobId}`)
}

async function submitCharacterSheet(
	env: Env,
	scene: Scene,
	sourceAssetId: string,
): Promise<BrResult<JobResponse>> {
	return br<JobResponse>(env, "/generate-image", {
		method: "POST",
		body: JSON.stringify({
			prompt: scene.sheetPrompt || CHARACTER_SHEET_PROMPT,
			model: env.IMAGE_MODEL || DEFAULT_IMAGE_MODEL,
			aspect_ratio: "9:16",
			reference_asset_ids: [sourceAssetId],
			enhance_prompt: false,
		}),
	})
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
			const res = await br<JobResponse>(env, "/generate-video", {
				method: "POST",
				body: JSON.stringify(body),
			})
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
			const key = apiKey(env)
			return json({
				ok: true,
				service: "solu-ai-proxy",
				provider: "blitzreels",
				pipeline: ["character_sheet(image)", "reference_to_video"],
				imageModel: env.IMAGE_MODEL || DEFAULT_IMAGE_MODEL,
				videoModel: env.VIDEO_MODEL || VIDEO_MODEL_CHAIN[0],
				videoModelChain: VIDEO_MODEL_CHAIN,
				storage: env.STATE ? "kv" : "none",
				apiKey: key ? `${key.slice(0, 11)}\u2026${key.slice(-4)}` : null,
				scenes: SCENES.map((s) => s.id),
				configured: Boolean(key) && Boolean(env.APP_SHARED_SECRET),
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

		/** Short-lived public file used by the URL-import upload fallback. */
		const fileMatch = path.match(/^\/v1\/f\/([A-Za-z0-9-]+)$/)
		if (fileMatch && req.method === "GET") {
			if (!env.STATE) return fail("no_storage", "KV namespace STATE is not bound", 500)
			const found = await env.STATE.getWithMetadata(`f:${fileMatch[1]}`, "arrayBuffer")
			if (!found.value) return fail("not_found", "File expired", 404)
			const ct = (found.metadata as { ct?: string } | null)?.ct || "image/jpeg"
			return new Response(found.value, {
				headers: { "content-type": ct, "cache-control": "public, max-age=3600", ...CORS },
			})
		}

		if (!authed(req, env)) return fail("unauthorized", "Missing or invalid x-solu-key", 401)

		/** Diagnostics: shows the upstream's real model ids and credit pricing. */
		if (path === "/v1/upstream" && req.method === "GET") {
			const target = url.searchParams.get("path") || "/generation-options"
			const res = await br<unknown>(env, target)
			return res.ok
				? json({ path: target, data: res.data })
				: fail("upstream_error", res.body, res.status)
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
			const res = await uploadToBlitz(
				env,
				bytes,
				`solu-${crypto.randomUUID()}.${ext}`,
				contentType,
				url.origin,
			)
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
