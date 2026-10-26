/** Move an element to another place in the page (a sheet to the app frame, buttons to the top bar). */
export function portal(node: HTMLElement, selector: string): { destroy(): void } {
  document.querySelector(selector)?.appendChild(node)
  return {
    destroy() {
      node.remove()
    },
  }
}
