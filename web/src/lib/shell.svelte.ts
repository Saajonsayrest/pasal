// Things a page can tell the frame around it (top bar title).
import { route } from './router.svelte'

class ShellState {
  /** A title set by a page (for example the customer's name), and the path it was set for. */
  title = $state<string | null>(null)
  path = $state('')

  /** The page title for the current path, or null when the page did not set one. */
  get current(): string | null {
    return this.path === route.path ? this.title : null
  }
}

export const shell = new ShellState()

/** Use when the title is only known after loading: setTitle(customer.name) */
export function setTitle(title: string | null): void {
  shell.title = title
  shell.path = route.path
}
