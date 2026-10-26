import type { Paged } from './types'

const BASE = (import.meta.env.VITE_API_URL as string | undefined) ?? '/api/v1'

export class ApiError extends Error {
  status: number
  errors: Record<string, string[]>
  body: Record<string, unknown>

  constructor(status: number, message: string, errors: Record<string, string[]> = {}, body: Record<string, unknown> = {}) {
    super(message)
    this.status = status
    this.errors = errors
    this.body = body
  }

  /** First message for one field, or null. */
  field(name: string): string | null {
    return this.errors[name]?.[0] ?? null
  }
}

let token: string | null = null
let onUnauthorized: () => void = () => {}

export function setToken(value: string | null): void {
  token = value
}
export function setUnauthorizedHandler(fn: () => void): void {
  onUnauthorized = fn
}

/** A new random key for one tap of a save button. Reuse it for every retry of that same tap. */
export function newKey(): string {
  return crypto.randomUUID()
}

type Query = Record<string, string | number | boolean | null | undefined>

export interface RequestOptions {
  query?: Query
  body?: unknown
  /** Idempotency-Key header. Pass newKey() made when the user taps save. */
  key?: string
  signal?: AbortSignal
}

function qs(query?: Query): string {
  if (!query) return ''
  const p = new URLSearchParams()
  for (const [k, v] of Object.entries(query)) {
    if (v === undefined || v === null || v === '') continue
    p.set(k, typeof v === 'boolean' ? (v ? '1' : '0') : String(v))
  }
  const s = p.toString()
  return s ? `?${s}` : ''
}

export async function request<T>(method: string, path: string, opts: RequestOptions = {}): Promise<T> {
  const headers: Record<string, string> = { Accept: 'application/json' }
  if (token) headers.Authorization = `Bearer ${token}`
  if (opts.key) headers['Idempotency-Key'] = opts.key

  let body: BodyInit | undefined
  if (opts.body instanceof FormData) {
    body = opts.body // the browser sets the multipart boundary
  } else if (opts.body !== undefined) {
    headers['Content-Type'] = 'application/json'
    body = JSON.stringify(opts.body)
  }

  let res: Response
  try {
    res = await fetch(`${BASE}${path}${qs(opts.query)}`, { method, headers, body, signal: opts.signal })
  } catch (e) {
    if ((e as Error).name === 'AbortError') throw e
    throw new ApiError(0, 'Cannot reach the server. Check the connection and try again.')
  }

  const text = await res.text()
  let json: Record<string, unknown> = {}
  try {
    json = text ? (JSON.parse(text) as Record<string, unknown>) : {}
  } catch {
    json = {}
  }

  if (!res.ok) {
    if (res.status === 401 && token) onUnauthorized()
    const message = (json.message as string | undefined) ?? (res.status === 429 ? 'Too many tries. Wait a moment.' : 'Something went wrong.')
    throw new ApiError(res.status, message, (json.errors as Record<string, string[]>) ?? {}, json)
  }
  return json as T
}

export const api = {
  get: <T>(path: string, query?: Query, signal?: AbortSignal) => request<T>('GET', path, { query, signal }),
  post: <T>(path: string, body?: unknown, key?: string) => request<T>('POST', path, { body: body ?? {}, key }),
  put: <T>(path: string, body?: unknown) => request<T>('PUT', path, { body: body ?? {} }),
  patch: <T>(path: string, body?: unknown) => request<T>('PATCH', path, { body: body ?? {} }),
  delete: <T>(path: string) => request<T>('DELETE', path),
  /** One page of a list. */
  page: <T>(path: string, query?: Query) => request<Paged<T>>('GET', path, { query }),
  /** Every page of a list (use for small lists such as categories). */
  async all<T>(path: string, query: Query = {}, perPage = 50): Promise<T[]> {
    const out: T[] = []
    for (let page = 1; page <= 200; page++) {
      const res = await request<Paged<T>>('GET', path, { query: { ...query, per_page: perPage, page } })
      out.push(...res.data)
      if (res.meta.current_page >= (res.meta.last_page ?? 1)) break
    }
    return out
  },
}
