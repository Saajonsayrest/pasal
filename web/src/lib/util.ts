/** "Hari Thapa" to "HT". */
export function initials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean)
  if (parts.length === 0) return '?'
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase()
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
}

/** Open the phone dialler or a message app. Phone numbers are cleaned first. */
export function telHref(phone: string): string {
  return `tel:${phone.replace(/[^\d+]/g, '')}`
}

/** WhatsApp link with a ready text. Numbers without a country code get Nepal's (977). */
export function whatsappHref(phone: string, text: string): string {
  let digits = phone.replace(/[^\d]/g, '')
  if (digits.length <= 10) digits = `977${digits.replace(/^0+/, '')}`
  return `https://wa.me/${digits}?text=${encodeURIComponent(text)}`
}

export function smsHref(phone: string, text: string): string {
  return `sms:${phone.replace(/[^\d+]/g, '')}?body=${encodeURIComponent(text)}`
}

/** Clean text for a CSV cell. */
export function csvCell(value: string | number | null | undefined): string {
  const s = String(value ?? '')
  // A cell that starts with = + - @ can run as a formula in a spreadsheet. Prefix it with a quote.
  const safe = /^[=+\-@\t\r]/.test(s) ? `'${s}` : s
  return /[",\n\r]/.test(safe) ? `"${safe.replace(/"/g, '""')}"` : safe
}

/** Save text as a file in the browser. */
export function downloadText(filename: string, text: string, mime = 'text/csv;charset=utf-8'): void {
  const url = URL.createObjectURL(new Blob(['﻿', text], { type: mime }))
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}

export function clamp(n: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, n))
}
