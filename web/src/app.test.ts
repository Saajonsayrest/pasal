// The frame around the screens: the login guard, the owner lock, the menus and the language switch.
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushSync, mount, unmount } from 'svelte'
import App from './App.svelte'
import { session } from './lib/session.svelte'
import { settings } from './lib/settings.svelte'
import { setToken } from './lib/api'

const wait = (ms = 30) => new Promise((r) => setTimeout(r, ms))

const business = { id: 1, name: 'Himal Kirana Pasal', pan: '600000001', phone: null, address: null, vat_rate: 13 }
const emptyList = { data: [], meta: { current_page: 1, last_page: 1, per_page: 50, total: 0 }, summary: { owed_total: 0, owing_customers: 0 } }

let app: ReturnType<typeof mount> | undefined

async function open(hash: string): Promise<HTMLElement> {
  location.hash = hash
  // jsdom sends hashchange a moment later. Send it now so the router state matches the address before mounting.
  window.dispatchEvent(new HashChangeEvent('hashchange'))
  document.body.innerHTML = '<div id="root"></div>'
  app = mount(App, { target: document.getElementById('root')! })
  flushSync()
  await wait()
  // The screen file loads on demand. A slow machine needs longer than one short wait, so wait for the placeholder to go.
  for (let i = 0; i < 100 && document.querySelector('#root .skeleton'); i++) await wait(30)
  flushSync()
  return document.getElementById('root')!
}

beforeEach(() => {
  vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify(emptyList), { status: 200, headers: { 'Content-Type': 'application/json' } })))
  setToken(null)
  session.user = null
  settings.set({ lang: 'en', theme: 'light' })
})

afterEach(() => {
  if (app) unmount(app)
  app = undefined
  vi.unstubAllGlobals()
})

describe('the app frame', () => {
  it('sends a person who is not logged in to the login screen', async () => {
    const root = await open('#/customers')
    expect(location.hash).toBe('#/login')
    expect(root.textContent).toContain('PASAL')
    expect(root.querySelector('input[type="email"]')).not.toBeNull()
    expect(root.querySelector('.bottom-nav')).toBeNull()
  })

  it('shows the owner menus and the page', async () => {
    session.user = { id: 1, name: 'Asha Shrestha', email: 'a@example.com', role: 'owner', business }
    const root = await open('#/customers')
    expect(root.querySelector('.topbar .title')?.textContent).toBe('Customers')
    expect(root.querySelector('.side-nav')?.textContent).toContain('Purchases')
    expect(root.querySelectorAll('.bottom-nav a')).toHaveLength(5)
  })

  it('locks owner screens for staff and hides owner links', async () => {
    session.user = { id: 2, name: 'Bikash K.', email: 'b@example.com', role: 'staff', business }
    const root = await open('#/purchases')
    expect(root.querySelector('.locked')).not.toBeNull()
    expect(root.querySelector('.side-nav')?.textContent).not.toContain('Purchases')
    expect(root.querySelector('.side-nav')?.textContent).toContain('Customers')
  })

  it('shows a not found card for an unknown path', async () => {
    session.user = { id: 1, name: 'Asha', email: 'a@example.com', role: 'owner', business }
    const root = await open('#/nothing/here')
    expect(root.textContent).toContain('Page not found')
  })

  it('switches to Nepali with Nepali digits', async () => {
    session.user = { id: 1, name: 'Asha', email: 'a@example.com', role: 'owner', business }
    const root = await open('#/customers')
    settings.set({ lang: 'ne' })
    flushSync()
    await wait()
    expect(root.querySelector('.topbar .title')?.textContent).toBe('ग्राहकहरू')
    expect(document.documentElement.lang).toBe('ne')
  })
})
