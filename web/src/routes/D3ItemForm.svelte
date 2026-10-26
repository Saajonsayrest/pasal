<script lang="ts">
  import { onDestroy } from 'svelte'
  import { api, request } from '../lib/api'
  import { resource, action, debounce } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import { rs, toPaisa, fromPaisa } from '../lib/money'
  import { navigate } from '../lib/router.svelte'
  import { session } from '../lib/session.svelte'
  import { toast } from '../lib/toast.svelte'
  import type { Category, Item } from '../lib/types'
  import Field from '../components/Field.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Skeleton from '../components/Skeleton.svelte'

  type Existing = { id: number; name: string; deleted: boolean }

  const PHOTO_TYPES = ['image/jpeg', 'image/png', 'image/webp']
  const PHOTO_MAX = 2 * 1024 * 1024
  const UNITS: [string, string, string][] = [
    ['pcs', 'pcs', 'पिस'],
    ['kg', 'kg', 'केजी'],
    ['litre', 'litre', 'लिटर'],
    ['packet', 'packet', 'प्याकेट'],
    ['dozen', 'dozen', 'दर्जन'],
  ]

  let { params }: { params: Record<string, string> } = $props()
  const editId = $derived(params.id ? Number(params.id) : null)

  const current = resource(() =>
    editId !== null ? api.get<{ data: Item }>(`/items/${editId}`).then((r) => r.data) : Promise.resolve<Item | null>(null),
  )
  const cats = resource(() => api.all<Category>('/categories'))

  let name = $state('')
  let sku = $state('')
  let unit = $state('pcs')
  let vatApplies = $state(true)
  let buy = $state('')
  let sell = $state('')
  let lowStock = $state(5)
  let categoryId = $state('')
  let filled = $state(false)
  let existingPhoto = $state<string | null>(null)

  $effect(() => {
    const i = current.data
    if (!i || filled) return
    name = i.name
    sku = i.sku ?? ''
    unit = i.unit
    vatApplies = i.vat_applies
    buy = i.cost_price === null ? '' : fromPaisa(i.cost_price)
    sell = fromPaisa(i.sell_price)
    lowStock = i.low_stock_at
    categoryId = i.category_id === null ? '' : String(i.category_id)
    existingPhoto = i.photo_url
    filled = true
  })

  let nameQ = $state('')
  $effect(() => debounce(() => name.trim(), 250, (v) => (nameQ = v)))
  const suggest = resource(() =>
    nameQ ? api.get<{ data: Item[] }>('/items/suggest', { q: nameQ, limit: 8 }) : Promise.resolve<{ data: Item[] }>({ data: [] }),
  )
  const others = $derived((suggest.data?.data ?? []).filter((i) => i.id !== editId))
  const sameName = $derived(others.find((i) => i.name.trim().toLowerCase() === name.trim().toLowerCase()))
  const similar = $derived(others.filter((i) => i.id !== sameName?.id))

  const vatRate = $derived(session.business?.vat_rate ?? 0)
  const sellPaisa = $derived(toPaisa(sell))
  const sellHint = $derived.by(() => {
    if (!vatApplies) return tr('No VAT on this item', 'यो सामानमा भ्याट छैन')
    if (sellPaisa === null) return tr('VAT included', 'भ्याट सहित')
    const exVat = Math.round((sellPaisa * 100) / (100 + vatRate))
    return `${tr('VAT included. Without VAT', 'भ्याट सहित। भ्याट बाहेक')}: ${rs(exVat, { paisa: true })}`
  })

  const unitOptions = $derived(UNITS.some((u) => u[0] === unit) ? UNITS : [...UNITS, [unit, unit, unit] as [string, string, string]])

  let file = $state<File | null>(null)
  let previewUrl = $state<string | null>(null)
  let photoErr = $state('')
  let photoInput = $state<HTMLInputElement>()
  const photoAction = action()
  const shownPhoto = $derived(previewUrl ?? existingPhoto)

  onDestroy(() => {
    if (previewUrl) URL.revokeObjectURL(previewUrl)
  })

  function pick(e: Event): void {
    const input = e.currentTarget as HTMLInputElement
    const f = input.files?.[0] ?? null
    photoErr = ''
    if (!f) return
    if (!PHOTO_TYPES.includes(f.type)) {
      photoErr = tr('The photo must be a JPG, PNG or WebP file.', 'फोटो JPG, PNG वा WebP हुनुपर्छ।')
      input.value = ''
      return
    }
    if (f.size > PHOTO_MAX) {
      photoErr = tr('The photo must be 2 MB or smaller.', 'फोटो २ MB वा सानो हुनुपर्छ।')
      input.value = ''
      return
    }
    if (previewUrl) URL.revokeObjectURL(previewUrl)
    file = f
    previewUrl = URL.createObjectURL(f)
  }

  function clearFile(): void {
    if (previewUrl) URL.revokeObjectURL(previewUrl)
    previewUrl = null
    file = null
  }

  async function removePhoto(): Promise<void> {
    if (file) {
      clearFile()
      return
    }
    if (editId === null) return
    const done = await photoAction.run(() => api.delete(`/items/${editId}/photo`))
    if (done === undefined) return
    existingPhoto = null
    toast('Photo removed', 'फोटो हटाइयो')
  }

  let clientErr = $state<Record<string, string>>({})
  const save = action()
  const restore = action()
  const existing = $derived(save.error?.body?.existing_item as Existing | undefined)

  function err(field: string): string | null {
    return clientErr[field] || save.field(field)
  }

  function check(): boolean {
    const e: Record<string, string> = {}
    if (!name.trim()) e.name = tr('Enter the item name.', 'सामानको नाम लेख्नुहोस्।')
    if (toPaisa(buy) === null) e.cost_price = tr('Enter the buying price, for example 86.50.', 'खरिद मूल्य लेख्नुहोस्।')
    if (toPaisa(sell) === null) e.sell_price = tr('Enter the selling price, for example 115.', 'बिक्री मूल्य लेख्नुहोस्।')
    clientErr = e
    return Object.keys(e).length === 0
  }

  async function submit(e: SubmitEvent): Promise<void> {
    e.preventDefault()
    const cost = toPaisa(buy)
    const price = toPaisa(sell)
    if (!check() || cost === null || price === null) return
    const body = {
      name: name.trim(),
      sku: sku.trim() || null,
      unit: unit.trim() || 'pcs',
      vat_applies: vatApplies,
      cost_price: cost,
      sell_price: price,
      low_stock_at: lowStock,
      category_id: categoryId ? Number(categoryId) : null,
    }
    const id = await save.run(async () => {
      if (editId !== null) {
        await api.patch(`/items/${editId}`, body)
        return editId
      }
      const res = await api.post<{ data: Item }>('/items', body)
      return res.data.id
    })
    if (id === undefined) return

    let photoFailed = false
    if (file) {
      const data = new FormData()
      data.append('photo', file)
      try {
        await request('POST', `/items/${id}/photo`, { body: data })
      } catch {
        photoFailed = true
      }
    }
    if (photoFailed) toast('Item saved. The photo did not upload.', 'सामान सेभ भयो। फोटो अपलोड भएन।')
    else toast('Item saved', 'सामान सेभ भयो')
    navigate(`/items/${id}`, true)
  }

  async function restoreExisting(ex: Existing): Promise<void> {
    const ok = await restore.run(() => api.post(`/items/${ex.id}/restore`))
    if (ok === undefined) return
    toast(`Restored: ${ex.name}`, `फिर्ता ल्याइयो: ${ex.name}`)
    navigate(`/items/${ex.id}`, true)
  }
</script>

{#if editId !== null && current.error}
  <div class="page narrow"><ErrorCard error={current.error} retry={current.reload} /></div>
{:else if editId !== null && !filled}
  <div class="page narrow"><Skeleton card /><Skeleton rows={3} /></div>
{:else}
  <form class="page narrow" onsubmit={submit}>
    <section class="hstack" style="gap:16px">
      <button type="button" class="photo-pick" aria-label={tr('Add photo', 'फोटो थप्ने')} onclick={() => photoInput?.click()}>
        {#if shownPhoto}
          <img src={shownPhoto} alt="" />
        {:else}
          <span class="ms">add_a_photo</span>
        {/if}
      </button>
      <div class="stack-sm">
        <span class="bold">{tr('Item photo', 'सामानको फोटो')}</span>
        <span class="small muted">{tr('Optional. It helps you find the item when selling.', 'फोटो वैकल्पिक हो। बिक्री गर्दा सामान चिन्न सजिलो हुन्छ।')}</span>
        {#if shownPhoto}
          <button type="button" class="btn btn-ghost btn-sm" style="align-self:flex-start" disabled={photoAction.busy} onclick={removePhoto}>
            <span class="ms">delete</span><span>{tr('Remove photo', 'फोटो हटाउने')}</span>
          </button>
        {/if}
        {#if photoErr || photoAction.error}
          <span class="field-error">{photoErr || photoAction.error?.message}</span>
        {/if}
      </div>
      <input bind:this={photoInput} type="file" accept="image/jpeg,image/png,image/webp" hidden onchange={pick} />
    </section>

    <Field label={tr('Item name', 'सामानको नाम')} error={err('name')}>
      <input bind:value={name} autocomplete="off" />
    </Field>

    {#if existing}
      <div class="card tonal stack-sm">
        <div class="hstack" style="align-items:flex-start">
          <span class="ms warn">{existing.deleted ? 'history' : 'lightbulb'}</span>
          <span>
            {existing.deleted
              ? tr(`"${existing.name}" was deleted before.`, `"${existing.name}" पहिले हटाइएको थियो।`)
              : tr(`${existing.name} already exists. Use that item instead?`, `${existing.name} पहिल्यै छ। त्यही सामान प्रयोग गर्ने?`)}
          </span>
        </div>
        {#if existing.deleted}
          <button type="button" class="btn btn-tonal btn-sm" style="align-self:flex-start" disabled={restore.busy} onclick={() => restoreExisting(existing)}>
            <span class="ms">restore</span><span>{tr('Restore it?', 'फिर्ता ल्याउने?')}</span>
          </button>
          {#if restore.error}
            <span class="field-error">{restore.error.message}</span>
          {/if}
        {:else}
          <a class="btn btn-tonal btn-sm" style="align-self:flex-start" href={`#/items/${existing.id}`}>{tr('Use', 'प्रयोग गर्ने')}</a>
        {/if}
      </div>
    {:else if sameName}
      <div class="card tonal stack-sm">
        <div class="hstack" style="align-items:flex-start">
          <span class="ms info">lightbulb</span>
          <span>{tr(`${sameName.name} already exists. Use that item instead?`, `${sameName.name} पहिल्यै छ। त्यही सामान प्रयोग गर्ने?`)}</span>
        </div>
        <a class="btn btn-tonal btn-sm" style="align-self:flex-start" href={`#/items/${sameName.id}`}>{tr('Use', 'प्रयोग गर्ने')}</a>
      </div>
    {/if}

    {#if similar.length > 0 && name.trim()}
      <div class="list">
        {#each similar as s (s.id)}
          <a class="row" href={`#/items/${s.id}`}>
            <div class="row-main">
              <div class="row-title">{s.name}</div>
              <div class="row-sub">{num(s.quantity)} {s.unit}</div>
            </div>
            <span class="ms chev">chevron_right</span>
          </a>
        {/each}
      </div>
    {/if}

    <Field label={tr('Code or barcode (optional)', 'कोड वा बारकोड (वैकल्पिक)')} error={err('sku')}>
      <input bind:value={sku} autocomplete="off" />
    </Field>

    <div class="form-grid two">
      <Field label={tr('Category', 'वर्ग')} error={err('category_id')}>
        <select bind:value={categoryId}>
          <option value="">{tr('No category', 'वर्ग छैन')}</option>
          {#each cats.data ?? [] as c (c.id)}
            <option value={String(c.id)}>{c.name}</option>
          {/each}
        </select>
      </Field>
      <Field label={tr('Unit', 'एकाइ')} error={err('unit')}>
        <select bind:value={unit}>
          {#each unitOptions as [v, en, ne] (v)}
            <option value={v}>{tr(en, ne)}</option>
          {/each}
        </select>
      </Field>
      <Field label={tr('Selling price', 'बिक्री मूल्य')} error={err('sell_price')} hint={sellHint}>
        <div class="input-group">
          <span class="prefix">Rs</span>
          <input inputmode="decimal" placeholder="0" bind:value={sell} />
        </div>
      </Field>
      <Field label={tr('Buying price', 'खरिद मूल्य')} error={err('cost_price')} hint={tr('Without VAT', 'भ्याट बाहेक')}>
        <div class="input-group">
          <span class="prefix">Rs</span>
          <input inputmode="decimal" placeholder="0" bind:value={buy} />
        </div>
      </Field>
    </div>

    <div class="card hstack between" style="padding:14px 16px">
      <div class="stack-sm" style="gap:2px">
        <span class="bold">{tr('VAT applies', 'भ्याट लाग्ने')}</span>
        <span class="small muted">{tr('Turn off for items with no VAT, like milk', 'दूध जस्तो भ्याट नलाग्ने सामानमा बन्द गर्नुहोस्')}</span>
      </div>
      <label class="switch">
        <input type="checkbox" bind:checked={vatApplies} />
        <span></span>
      </label>
    </div>

    <div class="card hstack between" style="padding:14px 16px">
      <div class="stack-sm" style="gap:2px">
        <span class="bold">{tr('Low stock level', 'कम स्टकको सीमा')}</span>
        <span class="small muted">{tr('Alert me when stock is below this', 'यो भन्दा कम हुँदा सूचना आउँछ')}</span>
      </div>
      <div class="stepper">
        <button type="button" aria-label={tr('Less', 'कम')} onclick={() => (lowStock = Math.max(0, lowStock - 1))}><span class="ms">remove</span></button>
        <span class="val">{num(lowStock)}</span>
        <button type="button" aria-label={tr('More', 'थप')} onclick={() => (lowStock = Math.min(1000000, lowStock + 1))}><span class="ms">add</span></button>
      </div>
    </div>

    {#if editId === null}
      <div class="alert info">
        <span class="ms">info</span>
        <div>{tr('New items start at 0 stock. Stock comes in from purchases.', 'नयाँ सामानको स्टक ० बाट सुरु हुन्छ। स्टक खरिदबाट थपिन्छ।')}</div>
      </div>
    {/if}

    {#if save.error && Object.keys(save.error.errors).length === 0 && !existing}
      <div class="alert bad"><span class="ms">error</span><div>{save.error.message}</div></div>
    {/if}

    <div class="bottom-bar">
      <a class="btn btn-outline btn-lg" href={editId !== null ? `#/items/${editId}` : '#/items'} style="flex:1">{tr('Cancel', 'रद्द')}</a>
      <button class="btn btn-primary btn-lg" type="submit" style="flex:1.4" disabled={save.busy}>
        <span class="ms">check</span><span>{save.busy ? tr('Saving…', 'सेभ हुँदैछ…') : tr('Save', 'सेभ गर्ने')}</span>
      </button>
    </div>
  </form>
{/if}

<style>
  .photo-pick {
    width: 88px;
    height: 88px;
    flex: none;
    border-radius: 22px;
    background: var(--surface-2);
    border: 1.5px dashed var(--muted);
    color: var(--muted);
    display: grid;
    place-items: center;
    overflow: hidden;
    padding: 0;
  }
  .photo-pick img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
</style>
