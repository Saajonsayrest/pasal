import { api, setToken, setUnauthorizedHandler } from './api'
import { cart } from './cart.svelte'
import type { Business, User } from './types'

// The token is kept in sessionStorage: it survives a refresh, and is gone when the tab closes.
// This is the middle choice from docs/api-reference.md (memory only would log out on every refresh).
// Never put the token in localStorage, a URL or a log.
const KEY = 'pasal-token'

class Session {
  user = $state<User | null>(null)
  /** True while the saved token is being checked at start. */
  checking = $state(false)

  get loggedIn(): boolean {
    return this.user !== null
  }
  get isOwner(): boolean {
    return this.user?.role === 'owner'
  }
  get business(): Business | null {
    return this.user?.business ?? null
  }

  async restore(): Promise<void> {
    const saved = sessionStorage.getItem(KEY)
    if (!saved) return
    this.checking = true
    setToken(saved)
    try {
      this.user = await api.get<User>('/me')
    } catch {
      this.clear()
    } finally {
      this.checking = false
    }
  }

  async login(email: string, password: string): Promise<void> {
    const res = await api.post<{ token: string; user: User }>('/login', { email, password, device_name: 'Website' })
    setToken(res.token)
    sessionStorage.setItem(KEY, res.token)
    this.user = res.user
  }

  async logout(everywhere = false): Promise<void> {
    try {
      await api.post(everywhere ? '/logout-all' : '/logout')
    } catch {
      // The token may already be dead. Either way this browser forgets it.
    }
    this.clear()
  }

  /** Forget the token and the user. Used on logout and on any 401. */
  clear(): void {
    setToken(null)
    sessionStorage.removeItem(KEY)
    this.user = null
    // Work left on this browser belongs to the shop that just signed out.
    cart.reset()
    try {
      localStorage.removeItem('pasal-count-draft')
    } catch {
      // Storage can be blocked. Nothing to clean then.
    }
  }

  /** Reload the user (after the shop details change). */
  async refresh(): Promise<void> {
    this.user = await api.get<User>('/me')
  }
}

export const session = new Session()

setUnauthorizedHandler(() => {
  session.clear()
  if (location.hash !== '#/login') location.hash = '#/login'
})
