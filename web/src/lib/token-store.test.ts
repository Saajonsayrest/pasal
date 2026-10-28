import { afterEach, describe, expect, it, vi } from 'vitest'
import { forgetToken, isDesktop, loadToken, saveToken } from './token-store'

function fakeMac(invoke: (command: string, args?: Record<string, unknown>) => Promise<unknown>): void {
  ;(window as unknown as { __TAURI__: unknown }).__TAURI__ = { core: { invoke } }
}

afterEach(() => {
  delete (window as unknown as { __TAURI__?: unknown }).__TAURI__
  sessionStorage.clear()
})

describe('token store in a browser', () => {
  it('keeps the token in sessionStorage', async () => {
    expect(isDesktop()).toBe(false)
    expect(await loadToken()).toBeNull()
    await saveToken('abc')
    expect(sessionStorage.getItem('pasal-token')).toBe('abc')
    expect(await loadToken()).toBe('abc')
    await forgetToken()
    expect(await loadToken()).toBeNull()
  })
})

describe('token store in the Mac app', () => {
  it('uses the Keychain commands and never sessionStorage', async () => {
    const invoke = vi.fn(async (command: string) => (command === 'token_get' ? 'from-keychain' : undefined))
    fakeMac(invoke)

    expect(isDesktop()).toBe(true)
    expect(await loadToken()).toBe('from-keychain')
    await saveToken('abc')
    await forgetToken()

    expect(invoke).toHaveBeenCalledWith('token_set', { token: 'abc' })
    expect(invoke).toHaveBeenCalledWith('token_clear')
    expect(sessionStorage.length).toBe(0)
  })

  it('treats a denied Keychain as signed out, not a crash', async () => {
    fakeMac(async () => {
      throw new Error('denied')
    })
    expect(await loadToken()).toBeNull()
    await expect(saveToken('abc')).resolves.toBeUndefined()
    await expect(forgetToken()).resolves.toBeUndefined()
  })
})
