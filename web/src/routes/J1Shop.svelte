<script lang="ts">
  import { api } from '../lib/api'
  import { resource, action } from '../lib/resource.svelte'
  import { session } from '../lib/session.svelte'
  import { tr } from '../lib/i18n'
  import { toast } from '../lib/toast.svelte'
  import type { Business } from '../lib/types'
  import Field from '../components/Field.svelte'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'

  const FOOTER_KEY = 'pasal-bill-footer'
  const DEFAULT_FOOTER = 'Thank you. Please visit again.'

  const shop = resource(() => api.get<{ data: Business }>('/business'))

  let name = $state('')
  let pan = $state('')
  let phone = $state('')
  let address = $state('')
  let vat = $state('')
  let footer = $state(readFooter())
  let vatError = $state<string | null>(null)
  let filled = false
  const save = action()

  $effect(() => {
    const b = shop.data?.data
    if (!b || filled) return
    filled = true
    name = b.name
    pan = b.pan ?? ''
    phone = b.phone ?? ''
    address = b.address ?? ''
    vat = String(b.vat_rate)
  })

  function readFooter(): string {
    try {
      return localStorage.getItem(FOOTER_KEY) ?? DEFAULT_FOOTER
    } catch {
      return DEFAULT_FOOTER
    }
  }

  function writeFooter(text: string): void {
    try {
      localStorage.setItem(FOOTER_KEY, text)
    } catch {
      // Storage can be blocked. The footer then uses the bill default.
    }
  }

  function parseVat(text: string): number | null {
    const t = text.trim()
    if (!/^\d{1,3}(\.\d{1,2})?$/.test(t)) return null
    const v = Number(t)
    return v <= 100 ? v : null
  }

  async function submit(e: Event): Promise<void> {
    e.preventDefault()
    const rate = parseVat(vat)
    if (rate === null) {
      vatError = tr('Type a rate from 0 to 100', 'दर ० देखि १०० सम्म लेख्नुहोस्')
      return
    }
    vatError = null
    const ok = await save.run(async () => {
      await api.patch('/business', {
        name: name.trim(),
        pan: pan.trim() || null,
        phone: phone.trim() || null,
        address: address.trim() || null,
        vat_rate: rate,
      })
      await session.refresh()
      return true
    })
    if (ok) {
      writeFooter(footer.trim() || DEFAULT_FOOTER)
      toast('Shop details saved', 'पसलको विवरण सेभ भयो')
    }
  }
</script>

<form class="page narrow" onsubmit={submit}>
  {#if shop.error}
    <ErrorCard error={shop.error} retry={shop.reload} />
  {:else if shop.loading && !shop.data}
    <Skeleton card />
    <Skeleton rows={3} />
  {:else}
    <p class="small muted">{tr('Shop logo upload is not available yet.', 'पसलको लोगो अपलोड अहिले उपलब्ध छैन।')}</p>

    <div class="form-grid two">
      <Field label={tr('Shop name', 'पसलको नाम')} error={save.field('name')} full>
        <input bind:value={name} required maxlength="150" />
      </Field>
      <Field label={tr('PAN number', 'PAN नम्बर')} error={save.field('pan')}>
        <input bind:value={pan} inputmode="numeric" maxlength="20" />
      </Field>
      <Field label={tr('Phone', 'फोन')} error={save.field('phone')}>
        <input type="tel" bind:value={phone} maxlength="30" />
      </Field>
      <Field label={tr('Address', 'ठेगाना')} error={save.field('address')} full>
        <input bind:value={address} maxlength="255" />
      </Field>
      <Field label={tr('VAT rate %', 'भ्याट दर %')} error={vatError ?? save.field('vat_rate')} hint={tr('Applies to new sales only.', 'नयाँ बिक्रीमा मात्र लागू हुन्छ।')}>
        <div class="input-group">
          <input bind:value={vat} inputmode="decimal" style="padding-right:44px" />
          <span class="suffix bold muted">%</span>
        </div>
      </Field>
      <Field label={tr('Bill footer text', 'बिलको तलको लेख')} hint={tr('Saved on this device only. Shown at the bottom of each bill.', 'यो उपकरणमा मात्र सेभ हुन्छ। हरेक बिलको तलमा देखिन्छ।')} full>
        <textarea bind:value={footer} rows="2" maxlength="300"></textarea>
      </Field>
    </div>

    {#if save.message}
      <div class="alert bad"><span class="ms">error</span><div>{save.message}</div></div>
    {/if}

    <div class="bottom-bar">
      <button class="btn btn-primary btn-lg btn-block" type="submit" disabled={save.busy}>
        <span class="ms">check</span><span>{save.busy ? tr('Saving…', 'सेभ हुँदैछ…') : tr('Save', 'सेभ गर्ने')}</span>
      </button>
    </div>
  {/if}
</form>
