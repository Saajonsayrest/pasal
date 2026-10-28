import { afterEach, describe, expect, it, vi } from 'vitest'
import { ApiError, api } from './api'

function answer(body: string, status = 200): void {
  vi.stubGlobal('fetch', vi.fn(async () => new Response(body, { status })))
}

afterEach(() => {
  vi.unstubAllGlobals()
  delete (window as unknown as { __TAURI__?: unknown }).__TAURI__
})

describe('api answers', () => {
  it('reads a JSON answer', async () => {
    answer('{"data":[1]}')
    expect(await api.get('/items')).toEqual({ data: [1] })
  })

  it('treats an empty answer as an empty object', async () => {
    answer('')
    expect(await api.get('/items')).toEqual({})
  })

  it('refuses a web page where JSON should be', async () => {
    answer('<!doctype html><html></html>')
    await expect(api.get('/me')).rejects.toBeInstanceOf(ApiError)
    await expect(api.get('/me')).rejects.toThrow(/did not answer like the PASAL API/)
  })
})

describe('api address', () => {
  it('uses /api/v1 in a browser', async () => {
    answer('{}')
    await api.get('/me')
    expect(vi.mocked(fetch).mock.calls[0][0]).toBe('/api/v1/me')
  })

  it('uses the API on this computer in the Mac app', async () => {
    ;(window as unknown as { __TAURI__: unknown }).__TAURI__ = { core: { invoke: async () => null } }
    answer('{}')
    await api.get('/me')
    expect(vi.mocked(fetch).mock.calls[0][0]).toBe('http://localhost:8000/api/v1/me')
  })
})
