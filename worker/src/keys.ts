/**
 * Key pool with credit accounting and automatic failover.
 *
 * Sagar's setup: 9 provider keys, each loaded with a fixed credit pack.
 * One 9:16 1080p / 10s video on the configured model costs a known number of
 * credits, so the pool can count locally and switch keys BEFORE a key dies
 * mid-render - no need to trust a balance API that may not exist.
 *
 * Defaults (override with env vars):
 *   KEY_CREDITS        = 230   credits loaded per key
 *   CREDITS_PER_VIDEO  = 45    credits one video costs
 *   -> 5 videos per key, then the next key is used automatically.
 *
 * State lives in KV (binding: STATE) so the count is shared across all Worker
 * isolates and survives deploys. Without KV it falls back to isolate memory.
 */

export type KeyHealth = {
	index: number
	label: string // "key-1" ... never the secret itself
	status: "ok" | "exhausted" | "invalid" | "cooldown"
	creditsUsed: number
	creditsLeft: number
	videosLeft: number
	lastError?: string
	coldUntil?: number // epoch ms
	usedAt?: number
}

type Entry = {
	status: "ok" | "exhausted" | "invalid" | "cooldown"
	used: number // credits consumed by us
	reported: number | null // credits reported by the provider, if ever
	lastError?: string
	coldUntil?: number
	usedAt?: number
}

type PoolState = Record<string, Entry>

const STATE_KEY = "keypool:v2"

/** A key that reported "no balance" is parked this long (top-ups come back). */
const EXHAUSTED_COOLDOWN_MS = 6 * 60 * 60 * 1000
/** Rate limited -> short park. */
const RATELIMIT_COOLDOWN_MS = 60 * 1000
/** Revoked / bad key -> long park. */
const INVALID_COOLDOWN_MS = 24 * 60 * 60 * 1000

export type PoolConfig = {
	keyCredits: number
	creditsPerVideo: number
}

export const DEFAULT_POOL_CONFIG: PoolConfig = {
	keyCredits: 230,
	creditsPerVideo: 45,
}

/** Only ever shown in logs/admin output - never the raw key. */
function fingerprint(key: string): string {
	return `${key.slice(0, 6)}...${key.slice(-4)}`
}

let memoryState: PoolState = {}

export class KeyPool {
	private keys: string[]
	private state: PoolState = {}
	private kv?: KVNamespace
	private dirty = false
	readonly cfg: PoolConfig

	constructor(rawKeys: string, kv?: KVNamespace, cfg: PoolConfig = DEFAULT_POOL_CONFIG) {
		this.keys = rawKeys
			.split(/[\s,;\r\n]+/)
			.map((k) => k.trim())
			.filter((k) => k.length > 8)
		this.kv = kv
		this.cfg = cfg
	}

	get size(): number {
		return this.keys.length
	}

	/** Videos one full key can produce. */
	get videosPerKey(): number {
		return Math.floor(this.cfg.keyCredits / this.cfg.creditsPerVideo)
	}

	async load(): Promise<void> {
		if (this.kv) {
			const raw = await this.kv.get(STATE_KEY)
			this.state = raw ? (JSON.parse(raw) as PoolState) : {}
		} else {
			this.state = memoryState
		}
	}

	async flush(): Promise<void> {
		if (!this.dirty) return
		memoryState = this.state
		if (this.kv) await this.kv.put(STATE_KEY, JSON.stringify(this.state))
		this.dirty = false
	}

	private entry(key: string): Entry {
		const id = fingerprint(key)
		this.state[id] ??= { status: "ok", used: 0, reported: null }
		return this.state[id]
	}

	/** Credits we believe are left: provider number wins, else our own count. */
	creditsLeft(key: string): number {
		const e = this.entry(key)
		if (e.reported !== null) return Math.max(0, e.reported)
		return Math.max(0, this.cfg.keyCredits - e.used)
	}

	private isCold(key: string, now: number): boolean {
		const e = this.entry(key)
		return Boolean(e.coldUntil && e.coldUntil > now)
	}

	/**
	 * Order in which keys should be tried:
	 *   1. keys that still have enough credits for this job (fullest first, so a
	 *      key is drained predictably 5 videos at a time)
	 *   2. keys below the threshold
	 *   3. parked keys, as a last resort - a local guess must never permanently
	 *      block a real user
	 */
	order(needCredits = 0): string[] {
		const now = Date.now()
		const hot: string[] = []
		const low: string[] = []
		const cold: string[] = []

		for (const k of this.keys) {
			if (this.isCold(k, now)) cold.push(k)
			else if (needCredits > 0 && this.creditsLeft(k) < needCredits) low.push(k)
			else hot.push(k)
		}
		// Use one key until it is nearly empty, then move on: fullest first.
		hot.sort((a, b) => this.creditsLeft(b) - this.creditsLeft(a))
		low.sort((a, b) => this.creditsLeft(b) - this.creditsLeft(a))
		return [...hot, ...low, ...cold]
	}

	/** Charge a successful job and park the key once it can't fund one more. */
	charge(key: string, credits: number) {
		const e = this.entry(key)
		e.used += credits
		if (e.reported !== null) e.reported = Math.max(0, e.reported - credits)
		e.usedAt = Date.now()
		if (this.creditsLeft(key) < this.cfg.creditsPerVideo) {
			e.status = "exhausted"
			e.lastError = "credit pack finished"
			e.coldUntil = Date.now() + EXHAUSTED_COOLDOWN_MS
		}
		this.dirty = true
	}

	markExhausted(key: string, error: string) {
		const e = this.entry(key)
		e.status = "exhausted"
		e.reported = 0
		e.lastError = error.slice(0, 160)
		e.coldUntil = Date.now() + EXHAUSTED_COOLDOWN_MS
		this.dirty = true
	}

	markInvalid(key: string, error: string) {
		const e = this.entry(key)
		e.status = "invalid"
		e.lastError = error.slice(0, 160)
		e.coldUntil = Date.now() + INVALID_COOLDOWN_MS
		this.dirty = true
	}

	markRateLimited(key: string, retryAfterSec?: number) {
		const e = this.entry(key)
		e.status = "cooldown"
		e.lastError = "rate limited"
		e.coldUntil = Date.now() + (retryAfterSec ? retryAfterSec * 1000 : RATELIMIT_COOLDOWN_MS)
		this.dirty = true
	}

	markOk(key: string) {
		const e = this.entry(key)
		e.status = "ok"
		e.lastError = undefined
		e.coldUntil = undefined
		this.dirty = true
	}

	/** Manual reset after topping a key up (admin route). */
	resetAll() {
		for (const k of this.keys) {
			this.state[fingerprint(k)] = { status: "ok", used: 0, reported: null }
		}
		this.dirty = true
	}

	keyByFingerprint(fp: string): string | undefined {
		return this.keys.find((k) => fingerprint(k) === fp)
	}

	fingerprintOf(key: string): string {
		return fingerprint(key)
	}

	report(): KeyHealth[] {
		const now = Date.now()
		return this.keys.map((k, i) => {
			const e = this.entry(k)
			const left = this.creditsLeft(k)
			const cold = Boolean(e.coldUntil && e.coldUntil > now)
			return {
				index: i,
				label: `key-${i + 1}`,
				status: cold ? (e.status === "ok" ? "cooldown" : e.status) : "ok",
				creditsUsed: e.used,
				creditsLeft: left,
				videosLeft: cold ? 0 : Math.floor(left / this.cfg.creditsPerVideo),
				lastError: e.lastError,
				coldUntil: e.coldUntil,
				usedAt: e.usedAt,
			}
		})
	}

	/** Total videos the whole pool can still make. */
	videosLeft(): number {
		return this.report().reduce((sum, r) => sum + r.videosLeft, 0)
	}

	/**
	 * Optional live credit read. Providers disagree on this endpoint, so every
	 * candidate path is tried and any plausible number is accepted. Unknown is
	 * fine - local counting plus the 402 path already protects us.
	 */
	async refreshCredits(key: string, base: string): Promise<number | null> {
		for (const path of ["/balance", "/me", "/credits", "/account/balance", "/user/balance"]) {
			try {
				const r = await fetch(`${base}${path}`, {
					headers: { authorization: `Bearer ${key}` },
				})
				if (r.status === 401 || r.status === 403) {
					this.markInvalid(key, `auth failed on ${path}`)
					return 0
				}
				if (!r.ok) continue
				const n = findNumber(await r.json().catch(() => null))
				if (n !== null) {
					const e = this.entry(key)
					e.reported = n
					this.dirty = true
					if (n < this.cfg.creditsPerVideo) this.markExhausted(key, "low credits")
					else this.markOk(key)
					return n
				}
			} catch {
				/* try next path */
			}
		}
		return null
	}
}

/** Digs a credit-looking number out of any provider response shape. */
function findNumber(node: unknown, depth = 0): number | null {
	if (depth > 4 || !node || typeof node !== "object") return null
	const obj = node as Record<string, unknown>
	for (const f of ["credits", "credit", "balance", "remaining", "available", "amount"]) {
		const v = obj[f]
		if (typeof v === "number") return v
		if (typeof v === "string" && v.trim() !== "" && !Number.isNaN(Number(v))) return Number(v)
	}
	for (const v of Object.values(obj)) {
		const n = findNumber(v, depth + 1)
		if (n !== null) return n
	}
	return null
}

/** Classify an upstream failure so the pool reacts correctly. */
export function classifyFailure(
	status: number,
	bodyText: string,
): "exhausted" | "invalid" | "rate_limited" | "model" | "other" {
	const t = bodyText.toLowerCase()
	if (status === 402) return "exhausted"
	if (status === 401 || status === 403) {
		return /balance|credit|fund|quota/.test(t) ? "exhausted" : "invalid"
	}
	if (status === 429) return "rate_limited"
	if (/insufficient|not enough|out of credit|low balance|quota exceeded|no credit/.test(t))
		return "exhausted"
	if (/content policy|policy violation|moderation|unsupported|model_price_error|invalid model|not found/.test(t))
		return "model"
	return "other"
}
