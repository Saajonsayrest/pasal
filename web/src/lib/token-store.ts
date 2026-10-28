// Where the login token is kept.
//
// In a browser it lives in sessionStorage: it survives a refresh and is gone when the tab closes.
// In the Mac app it lives in the macOS Keychain, through the Rust commands in `src-tauri/src/lib.rs`,
// so the shop stays signed in after the app is closed. Never localStorage, a URL or a log.

const KEY = 'pasal-token'

interface TauriCore {
  invoke<T>(command: string, args?: Record<string, unknown>): Promise<T>
}

function tauri(): TauriCore | null {
  const w = window as unknown as { __TAURI__?: { core?: TauriCore } }
  return w.__TAURI__?.core ?? null
}

/** True inside the Mac app. */
export function isDesktop(): boolean {
  return tauri() !== null
}

export async function loadToken(): Promise<string | null> {
  const core = tauri()
  if (core) {
    try {
      return await core.invoke<string | null>('token_get')
    } catch {
      return null // A locked or denied Keychain means signing in again, not a crash.
    }
  }
  return sessionStorage.getItem(KEY)
}

export async function saveToken(token: string): Promise<void> {
  const core = tauri()
  if (core) {
    try {
      await core.invoke('token_set', { token })
    } catch {
      // Signed in for this run only; the next start asks for the password again.
    }
    return
  }
  sessionStorage.setItem(KEY, token)
}

export async function forgetToken(): Promise<void> {
  const core = tauri()
  if (core) {
    try {
      await core.invoke('token_clear')
    } catch {
      // Nothing more to do. The server side token is revoked on logout.
    }
    return
  }
  sessionStorage.removeItem(KEY)
}
