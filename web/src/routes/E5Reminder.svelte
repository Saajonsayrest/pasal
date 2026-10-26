<script lang="ts">
  import { api } from '../lib/api'
  import { resource } from '../lib/resource.svelte'
  import { session } from '../lib/session.svelte'
  import { settings } from '../lib/settings.svelte'
  import { tr } from '../lib/i18n'
  import { rs } from '../lib/money'
  import { formatDate, formatTime } from '../lib/bs'
  import { toast } from '../lib/toast.svelte'
  import { initials, smsHref, whatsappHref } from '../lib/util'
  import type { Customer } from '../lib/types'
  import Field from '../components/Field.svelte'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'

  let { params }: { params: Record<string, string> } = $props()

  type Channel = 'whatsapp' | 'sms'
  interface Sent {
    at: string
    channel: Channel
  }
  const STORE_KEY = 'pasal-reminders'

  function readSent(): Record<string, Sent> {
    try {
      return JSON.parse(localStorage.getItem(STORE_KEY) ?? '{}') as Record<string, Sent>
    } catch {
      return {}
    }
  }

  const NE_DIGITS = '०१२३४५६७८९'
  const toNepaliDigits = (text: string) => text.replace(/\d/g, (d) => NE_DIGITS[Number(d)])

  const res = resource(() => api.get<{ data: Customer }>(`/customers/${params.id}`))
  const customer = $derived(res.data?.data)
  const owes = $derived(customer?.owes ?? 0)
  const phone = $derived(customer?.phone?.trim() ?? '')
  const shop = $derived(session.business?.name ?? 'PASAL')
  const canSend = $derived(phone !== '' && owes > 0)

  let lang = $state<'en' | 'ne'>(settings.ne ? 'ne' : 'en')
  let msgEn = $state('')
  let msgNe = $state('')
  let seeded = $state(false)

  $effect(() => {
    if (customer && !seeded) {
      const name = customer.name
      msgEn = `Namaste ${name} ji. This is a reminder from ${shop}. Your balance is ${rs(owes)}. Please pay when you can.`
      msgNe = `नमस्ते ${name} जी। ${shop} बाट एउटा सम्झना। तपाईंको ${toNepaliDigits(rs(owes).replace('Rs ', 'रु '))} बाँकी छ। मिलेमा तिर्नुहोला।`
      seeded = true
    }
  })

  const text = $derived(lang === 'en' ? msgEn : msgNe)

  function setText(value: string): void {
    if (lang === 'en') msgEn = value
    else msgNe = value
  }

  let sent = $state<Sent | undefined>(undefined)
  $effect(() => {
    sent = readSent()[params.id]
  })

  function markSent(channel: Channel): void {
    const all = readSent()
    all[params.id] = { at: new Date().toISOString(), channel }
    try {
      localStorage.setItem(STORE_KEY, JSON.stringify(all))
    } catch {
      // Storage can be blocked. The tick then lasts for this visit only.
    }
    sent = all[params.id]
  }

  async function copy(): Promise<void> {
    try {
      await navigator.clipboard.writeText(text)
      toast('Message copied', 'सन्देश कपी भयो')
    } catch {
      toast('Could not copy. Select the text and copy it.', 'कपी गर्न सकिएन। लेखाइ छानेर कपी गर्नुहोस्।')
    }
  }
</script>

<div class="page narrow">
  {#if res.error}
    <ErrorCard error={res.error} retry={res.reload} />
  {:else if res.loading && !customer}
    <Skeleton card />
    <Skeleton rows={2} />
  {:else if customer}
    <section class="card">
      <div class="hstack between">
        <div class="hstack">
          <span class="avatar warn">{initials(customer.name)}</span>
          <div class="stack-sm" style="gap:0">
            <span class="bold">{customer.name}</span>
            <span class="small muted">{phone || tr('No phone saved', 'फोन छैन')}</span>
          </div>
        </div>
        <div class="row-end">
          <span class="amount warn">{rs(owes)}</span>
          <span class="tiny muted">{tr('To collect', 'उठाउन बाँकी')}</span>
        </div>
      </div>
    </section>

    {#if owes <= 0}
      <div class="alert info"><span class="ms">info</span><div>{tr('Nothing is owed now, so no reminder is needed.', 'अहिले बाँकी छैन, सम्झना चाहिँदैन।')}</div></div>
    {:else if phone === ''}
      <div class="alert warn">
        <span class="ms">phone_disabled</span>
        <div>
          {tr('Add a phone number to send by WhatsApp or SMS.', 'व्हाट्सएप वा एसएमएस पठाउन फोन नम्बर थप्नुहोस्।')}
          <a href={`#/customers/${params.id}/edit`} class="bold">{tr('Edit customer', 'ग्राहक सच्याउने')}</a>
        </div>
      </div>
    {/if}

    {#if sent}
      <div class="alert good">
        <span class="ms">done_all</span>
        <div>
          {sent.channel === 'sms' ? 'SMS' : 'WhatsApp'}:
          {tr(
            `Marked as sent on ${formatDate(sent.at)}, ${formatTime(sent.at)}`,
            `${formatDate(sent.at)}, ${formatTime(sent.at)} मा पठाएको चिनो`,
          )}
        </div>
      </div>
    {/if}

    <div class="seg block no-print">
      <button class:active={lang === 'en'} onclick={() => (lang = 'en')}>English</button>
      <button class:active={lang === 'ne'} onclick={() => (lang = 'ne')}>नेपाली</button>
    </div>

    <div class="section-title"><h3>{tr('Message preview', 'सन्देश पूर्वावलोकन')}</h3></div>
    <div class="card tonal">
      <div style="max-width:90%;padding:12px 14px;border-radius:16px 16px 16px 4px;background:var(--good-soft);white-space:pre-wrap">{text}</div>
    </div>

    <Field label={tr('Edit message', 'सन्देश सम्पादन गर्नुहोस्')}>
      <textarea rows="5" value={text} oninput={(e) => setText(e.currentTarget.value)}></textarea>
    </Field>

    <div class="bottom-bar">
      {#if canSend}
        <a class="btn btn-good btn-lg" style="flex:1" href={whatsappHref(phone, text)} target="_blank" rel="noopener" onclick={() => markSent('whatsapp')}>
          <span class="ms">chat</span><span>WhatsApp</span>
        </a>
        <a class="btn btn-outline btn-lg" style="flex:1" href={smsHref(phone, text)} onclick={() => markSent('sms')}>
          <span class="ms">sms</span><span>SMS</span>
        </a>
      {:else}
        <button class="btn btn-good btn-lg" style="flex:1" disabled><span class="ms">chat</span><span>WhatsApp</span></button>
        <button class="btn btn-outline btn-lg" style="flex:1" disabled><span class="ms">sms</span><span>SMS</span></button>
      {/if}
      <button class="btn btn-tonal btn-lg" style="flex:1" onclick={copy}><span class="ms">content_copy</span><span>{tr('Copy', 'कपी')}</span></button>
    </div>
  {/if}
</div>
