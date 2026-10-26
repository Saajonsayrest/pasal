<script lang="ts">
  import { api, newKey } from '../lib/api'
  import { action, resource } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import { toast } from '../lib/toast.svelte'
  import type { Category, Item } from '../lib/types'
  import Field from '../components/Field.svelte'
  import Sheet from '../components/Sheet.svelte'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  type CountRow = { item_id: number; item_name: string; system: number; counted: number; difference: number }
  type Draft = { counts: Record<string, string>; note: string }
  type Status = 'all' | 'uncounted' | 'different'

  const DRAFT_KEY = 'pasal-count-draft'
  const WHOLE = /^\d+$/

  function readDraft(): Draft {
    try {
      const saved = JSON.parse(localStorage.getItem(DRAFT_KEY) ?? '{}') as Partial<Draft>
      return { counts: saved.counts ?? {}, note: saved.note ?? '' }
    } catch {
      return { counts: {}, note: '' }
    }
  }

  function writeDraft(draft: Draft): void {
    const counts = Object.fromEntries(Object.entries(draft.counts).filter(([, v]) => v.trim() !== ''))
    try {
      if (Object.keys(counts).length === 0 && !draft.note) localStorage.removeItem(DRAFT_KEY)
      else localStorage.setItem(DRAFT_KEY, JSON.stringify({ counts, note: draft.note }))
    } catch {
      // Storage can be blocked (private mode). The counts still work for this visit.
    }
  }

  const saved = readDraft()
  const items = resource(() => api.all<Item>('/items'))
  const cats = resource(() => api.all<Category>('/categories'))

  let counts = $state<Record<string, string>>(saved.counts)
  let note = $state(saved.note)
  let search = $state('')
  let status = $state<Status>('all')
  let category = $state('all')
  let reviewOpen = $state(false)
  let result = $state<{ rows: CountRow[]; changed: number } | null>(null)
  const save = action()
  let key = newKey()

  $effect(() => {
    writeDraft({ counts: $state.snapshot(counts), note })
  })

  const all = $derived(items.data ?? [])
  const catById = $derived(new Map<number, Category>((cats.data ?? []).map((c) => [c.id, c])))
  const hasInvalid = $derived(Object.values(counts).some((v) => v.trim() !== '' && !WHOLE.test(v.trim())))
  const saveError = $derived.by(() => save.message ?? (save.error ? (Object.values(save.error.errors).flat()[0] ?? null) : null))

  function countOf(item: Item): number | null {
    const raw = (counts[String(item.id)] ?? '').trim()
    return WHOLE.test(raw) ? Number(raw) : null
  }

  const counted = $derived(
    all.flatMap((item) => {
      const n = countOf(item)
      return n === null ? [] : [{ item, count: n }]
    }),
  )
  const differences = $derived(counted.filter((c) => c.count !== c.item.quantity))

  const visible = $derived.by(() => {
    const q = search.trim().toLowerCase()
    return all.filter((item) => {
      if (q && !item.name.toLowerCase().includes(q) && !(item.sku ?? '').toLowerCase().includes(q)) return false
      if (category === 'none' && item.category_id !== null) return false
      if (category !== 'all' && category !== 'none' && String(item.category_id) !== category) return false
      const n = countOf(item)
      if (status === 'uncounted') return n === null
      if (status === 'different') return n !== null && n !== item.quantity
      return true
    })
  })

  function setCount(id: number, raw: string): void {
    counts = { ...counts, [String(id)]: raw }
  }

  function diffWords(diff: number): string {
    if (diff < 0) return tr(`Short by ${num(-diff)}`, `${num(-diff)} कम`)
    if (diff > 0) return tr(`Extra ${num(diff)}`, `${num(diff)} बढी`)
    return tr('Matches', 'मिल्यो')
  }

  function diffClass(diff: number): 'warn' | 'info' | 'good' {
    if (diff < 0) return 'warn'
    if (diff > 0) return 'info'
    return 'good'
  }

  function countLabel(n: number): string {
    return tr(`${num(n)} ${n === 1 ? 'item' : 'items'}`, `${num(n)} सामान`)
  }

  async function submit(): Promise<void> {
    const body = {
      ...(note.trim() ? { note: note.trim() } : {}),
      items: counted.map((c) => ({ item_id: c.item.id, counted: c.count })),
    }
    const res = await save.run(() => api.post<{ data: CountRow[]; items_changed: number }>('/stock-counts', body, key))
    if (!res) return
    result = { rows: res.data, changed: res.items_changed }
    key = newKey()
    counts = {}
    note = ''
    reviewOpen = false
    toast('Stock count saved', 'स्टक गणना सेभ भयो')
    void items.reload()
  }
</script>

<div class="page">
  {#if result}
    <section class="card stack">
      <div class="card-head">
        <h3>{tr('Count saved', 'गणना सेभ भयो')}</h3>
        <button class="btn btn-sm btn-tonal" onclick={() => (result = null)}>{tr('Close', 'बन्द')}</button>
      </div>
      <p class="muted">{tr(`${num(result.changed)} items changed`, `${num(result.changed)} सामानमा परिवर्तन भयो`)}</p>
      <div class="list">
        {#each result.rows as r (r.item_id)}
          <div class="row">
            <div class="row-main">
              <div class="row-title">{r.item_name}</div>
              <div class="row-sub">{tr(`System ${num(r.system)} · counted ${num(r.counted)}`, `सिस्टम ${num(r.system)} · गनेको ${num(r.counted)}`)}</div>
            </div>
            <span class="badge {diffClass(r.difference)}">{diffWords(r.difference)}</span>
          </div>
        {/each}
      </div>
    </section>
  {/if}

  {#if hasInvalid}
    <div class="alert warn"><span class="ms">info</span><div>{tr('Counts must be whole numbers, 0 or more.', 'गन्ती पूरा संख्या हुनुपर्छ, ० वा माथि।')}</div></div>
  {/if}

  <label class="search">
    <span class="ms">search</span>
    <input placeholder={tr('Search item name or code', 'सामानको नाम वा कोड खोज्नुहोस्')} bind:value={search} />
  </label>

  <div class="chips">
    <button class="chip" class:active={category === 'all'} onclick={() => (category = 'all')}>{tr('All categories', 'सबै वर्ग')}</button>
    <button class="chip" class:active={category === 'none'} onclick={() => (category = 'none')}>{tr('No category', 'बिना वर्ग')}</button>
    {#each cats.data ?? [] as c (c.id)}
      <button class="chip" class:active={category === String(c.id)} onclick={() => (category = String(c.id))}>{catById.get(c.id)?.name ?? ''}</button>
    {/each}
  </div>

  <div class="chips">
    <button class="chip" class:active={status === 'uncounted'} onclick={() => (status = 'uncounted')}>{tr('Not counted', 'नगनिएको')}</button>
    <button class="chip" class:active={status === 'different'} onclick={() => (status = 'different')}>{tr('Different', 'फरक')}</button>
    <button class="chip" class:active={status === 'all'} onclick={() => (status = 'all')}>{tr('All', 'सबै')}</button>
  </div>

  {#if items.error}
    <ErrorCard error={items.error} retry={items.reload} />
  {:else if items.loading && !items.data}
    <Skeleton rows={6} />
  {:else if all.length === 0}
    <Empty icon="inventory_2" title={tr('No items yet', 'अहिलेसम्म सामान छैन')} text={tr('Add items first, then count them here.', 'पहिले सामान थप्नुहोस्, त्यसपछि यहाँ गन्नुहोस्।')} />
  {:else if visible.length === 0}
    <Empty icon="search_off" title={tr('No items match', 'मेल खाने सामान भेटिएन')} />
  {:else}
    <div class="list">
      {#each visible as item (item.id)}
        {@const n = countOf(item)}
        <div class="row">
          <span class="icon-tile"><span class="ms">{catById.get(item.category_id ?? -1)?.icon ?? 'inventory_2'}</span></span>
          <div class="row-main">
            <div class="row-title">{item.name}</div>
            <div class="row-sub">
              <span>{tr(`System ${num(item.quantity)} ${item.unit}`, `सिस्टम ${num(item.quantity)} ${item.unit === 'pcs' ? 'पिस' : item.unit}`)}</span>
              ·
              {#if n === null}
                <span class="badge">{tr('Not counted', 'नगनिएको')}</span>
              {:else if n === item.quantity}
                <span class="badge good"><span class="ms">check</span><span>{diffWords(0)}</span></span>
              {:else if n < item.quantity}
                <span class="badge warn"><span class="ms">arrow_downward</span><span>{diffWords(n - item.quantity)}</span></span>
              {:else}
                <span class="badge info"><span class="ms">arrow_upward</span><span>{diffWords(n - item.quantity)}</span></span>
              {/if}
            </div>
          </div>
          <input
            class="input count"
            type="number"
            inputmode="numeric"
            min="0"
            step="1"
            placeholder={tr('Count', 'गन्ने')}
            aria-label={item.name}
            value={counts[String(item.id)] ?? ''}
            oninput={(e) => setCount(item.id, e.currentTarget.value)}
          />
        </div>
      {/each}
    </div>
  {/if}

  <Field label={tr('Note', 'नोट')}>
    <input bind:value={note} placeholder={tr('Example: Month end', 'उदाहरण: महिनाको अन्त्य')} />
  </Field>

  <section class="card stack-sm">
    <div class="kv">
      <div><span class="k">{tr('Counted', 'गनियो')}</span><span class="v">{num(counted.length)} / {num(all.length)}</span></div>
      <div><span class="k">{tr('Differences', 'फरक')}</span><span class="v">{num(differences.length)}</span></div>
    </div>
  </section>

  <div class="bottom-bar">
    <button class="btn btn-primary btn-lg btn-block" disabled={counted.length === 0 || hasInvalid} onclick={() => (reviewOpen = true)}>
      <span class="ms">compare_arrows</span>
      <span>{differences.length > 0 ? tr(`Review ${num(differences.length)} differences`, `${num(differences.length)} फरक हेर्ने`) : tr('Review count', 'गणना हेर्ने')}</span>
    </button>
  </div>
</div>

<Sheet bind:open={reviewOpen} title={tr('Check before saving', 'सेभ गर्नु अघि हेर्नुहोस्')}>
  <p class="small muted">{tr('Each difference adds a change to stock history.', 'हरेक फरकले स्टक इतिहासमा परिवर्तन थप्छ।')}</p>
  {#if differences.length === 0}
    <p>{tr('Everything matches the system.', 'सबै सामान सिस्टमसँग मिल्छ।')}</p>
  {:else}
    <div class="list">
      {#each differences as c (c.item.id)}
        <div class="row">
          <span class="icon-tile {diffClass(c.count - c.item.quantity)}"><span class="ms">{c.count < c.item.quantity ? 'arrow_downward' : 'arrow_upward'}</span></span>
          <div class="row-main">
            <div class="row-title">{c.item.name}</div>
            <div class="row-sub">{tr(`System ${num(c.item.quantity)} · counted ${num(c.count)}`, `सिस्टम ${num(c.item.quantity)} · गनेको ${num(c.count)}`)}</div>
          </div>
          <span class="amount {diffClass(c.count - c.item.quantity)}">{c.count > c.item.quantity ? '+' : '-'}{num(Math.abs(c.count - c.item.quantity))}</span>
        </div>
      {/each}
    </div>
  {/if}
  {#if saveError}
    <div class="alert bad"><span class="ms">error</span><div>{saveError}</div></div>
  {/if}
  <button class="btn btn-primary btn-lg btn-block" disabled={save.busy || counted.length === 0} onclick={submit}>
    <span class="ms">done_all</span><span>{save.busy ? tr('Saving…', 'सेभ हुँदैछ…') : tr('Save count', 'गणना सेभ गर्ने')}</span>
  </button>
</Sheet>

<style>
  .count {
    width: 96px;
    min-height: 44px;
    text-align: center;
    font-weight: 700;
    flex: none;
  }
</style>
