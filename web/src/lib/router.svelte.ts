// A small hash router: the address is /#/items/12?x=1. It works on any plain file server,
// and the server never sees the path, so nothing needs configuring for deep links.

export interface RouteState {
  path: string
  query: Record<string, string>
}

function parse(): RouteState {
  const raw = location.hash.replace(/^#/, '') || '/'
  const [path, search = ''] = raw.split('?')
  const query: Record<string, string> = {}
  new URLSearchParams(search).forEach((v, k) => {
    query[k] = v
  })
  return { path: path || '/', query }
}

export const route = $state<RouteState>(parse())

window.addEventListener('hashchange', () => {
  const next = parse()
  route.path = next.path
  route.query = next.query
})

/** Go to a path: navigate('/items/12'). Pass `replace` to skip the back button history. */
export function navigate(path: string, replace = false): void {
  const url = `#${path}`
  if (replace) location.replace(url)
  else location.hash = url
}

export function back(fallback = '/'): void {
  if (history.length > 1) history.back()
  else navigate(fallback)
}

/** Change only the query part of this page, without adding history. */
export function setQuery(patch: Record<string, string | null | undefined>): void {
  const q = new URLSearchParams(route.query)
  for (const [k, v] of Object.entries(patch)) {
    if (v === null || v === undefined || v === '') q.delete(k)
    else q.set(k, v)
  }
  const s = q.toString()
  navigate(s ? `${route.path}?${s}` : route.path, true)
}

/** Match "/items/:id" against "/items/12". Returns the params or null. */
export function match(pattern: string, path: string): Record<string, string> | null {
  const a = pattern.split('/').filter(Boolean)
  const b = path.split('/').filter(Boolean)
  if (a.length !== b.length) return null
  const params: Record<string, string> = {}
  for (let i = 0; i < a.length; i++) {
    if (a[i].startsWith(':')) params[a[i].slice(1)] = decodeURIComponent(b[i])
    else if (a[i] !== b[i]) return null
  }
  return params
}
