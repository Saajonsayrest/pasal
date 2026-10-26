import { ApiError } from './api'

export interface Resource<T> {
  readonly data: T | undefined
  readonly loading: boolean
  readonly error: ApiError | null
  reload(): Promise<void>
}

/**
 * Load data for a screen. The fetcher runs when the component starts and again whenever a $state
 * value it reads (before its first await) changes, so a search box or a filter chip can drive it.
 * A slow old answer never replaces a newer one.
 *
 *   const items = resource(() => api.page<Item>('/items', { search: q }))
 *   {#if items.loading} ... {:else if items.error} ... {:else} {items.data.data} {/if}
 */
export function resource<T>(fetcher: () => Promise<T>): Resource<T> {
  let data = $state<T | undefined>(undefined)
  let loading = $state(true)
  let error = $state<ApiError | null>(null)
  let run = 0

  async function load(): Promise<void> {
    const id = ++run
    loading = true
    try {
      const result = await fetcher()
      if (id === run) {
        data = result
        error = null
      }
    } catch (e) {
      if (id === run) error = e instanceof ApiError ? e : new ApiError(0, (e as Error).message)
    } finally {
      if (id === run) loading = false
    }
  }

  $effect(() => {
    void load()
  })

  return {
    get data() {
      return data
    },
    get loading() {
      return loading
    },
    get error() {
      return error
    },
    reload: load,
  }
}

/** Run an async save with a busy flag and field errors. */
export function action() {
  let busy = $state(false)
  let error = $state<ApiError | null>(null)
  return {
    get busy() {
      return busy
    },
    get error() {
      return error
    },
    /** Message for one field, or null. */
    field(name: string): string | null {
      return error?.field(name) ?? null
    },
    /** The general message when no single field has it. */
    get message(): string | null {
      if (!error) return null
      return Object.keys(error.errors).length ? null : error.message
    },
    clear() {
      error = null
    },
    async run<T>(fn: () => Promise<T>): Promise<T | undefined> {
      busy = true
      error = null
      try {
        return await fn()
      } catch (e) {
        error = e instanceof ApiError ? e : new ApiError(0, (e as Error).message)
        return undefined
      } finally {
        busy = false
      }
    },
  }
}

/** Wait until typing stops. Use inside $effect: debounce(() => q, 250, (v) => (term = v)). */
export function debounce<T>(read: () => T, ms: number, write: (value: T) => void): () => void {
  const value = read()
  const t = setTimeout(() => write(value), ms)
  return () => clearTimeout(t)
}
