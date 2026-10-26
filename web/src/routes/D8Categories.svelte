<script lang="ts">
  import { api } from '../lib/api'
  import { action, resource } from '../lib/resource.svelte'
  import { tr, num } from '../lib/i18n'
  import { SEEDS } from '../lib/settings.svelte'
  import { toast } from '../lib/toast.svelte'
  import type { Category, Item } from '../lib/types'
  import Field from '../components/Field.svelte'
  import Sheet from '../components/Sheet.svelte'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'
  import Empty from '../components/Empty.svelte'

  const ICONS = [
    'category', 'egg', 'rice_bowl', 'local_drink', 'cookie', 'cleaning_services', 'spa', 'bakery_dining',
    'set_meal', 'nutrition', 'icecream', 'liquor', 'medication', 'checkroom', 'toys', 'pets',
    'home', 'kitchen', 'hardware', 'bolt', 'school', 'devices', 'restaurant', 'store',
  ]
  const SOFT = ['#9e9d24', '#8d6e63', '#5c6bc0', '#ef6c8f', '#26a69a']
  const COLORS = [...SEEDS, ...SOFT]

  const cats = resource(() => api.all<Category>('/categories'))
  let counts = $state<Record<number, number>>({})

  $effect(() => {
    void loadCounts(cats.data ?? [])
  })

  async function loadCounts(list: Category[]): Promise<void> {
    const pairs = await Promise.all(
      list.map(async (c) => {
        try {
          const res = await api.page<Item>('/items', { category_id: c.id, per_page: 1 })
          return [c.id, res.meta.total] as const
        } catch {
          return null
        }
      }),
    )
    counts = Object.fromEntries(pairs.filter((p): p is readonly [number, number] => p !== null))
  }

  let formOpen = $state(false)
  let confirmOpen = $state(false)
  let editing = $state<Category | null>(null)
  let name = $state('')
  let icon = $state('category')
  let color = $state<string>(SEEDS[0])
  const save = action()
  const del = action()

  function validColor(value: string | null): string | null {
    return value && /^#[0-9a-f]{6}$/i.test(value) ? value : null
  }

  function countLabel(n: number): string {
    return tr(`${num(n)} ${n === 1 ? 'item' : 'items'}`, `${num(n)} सामान`)
  }

  function openAdd(): void {
    editing = null
    name = ''
    icon = 'category'
    color = SEEDS[0]
    save.clear()
    formOpen = true
  }

  function openEdit(c: Category): void {
    editing = c
    name = c.name
    icon = c.icon ?? 'category'
    color = c.color ?? SEEDS[0]
    save.clear()
    formOpen = true
  }

  function openConfirm(): void {
    del.clear()
    confirmOpen = true
  }

  async function submit(): Promise<void> {
    const target = editing
    const body = { name: name.trim(), icon, color }
    const ok = await save.run(() => (target ? api.put<Category>(`/categories/${target.id}`, body) : api.post<Category>('/categories', body)))
    if (!ok) return
    formOpen = false
    toast(target ? 'Category saved' : 'Category added', target ? 'वर्ग सेभ भयो' : 'वर्ग थपियो')
    void cats.reload()
  }

  async function remove(): Promise<void> {
    const target = editing
    if (!target) return
    const ok = await del.run(() => api.delete<{ message: string }>(`/categories/${target.id}`))
    if (!ok) return
    confirmOpen = false
    formOpen = false
    toast('Category deleted. Items stay.', 'वर्ग मेटियो। सामान रहन्छन्।')
    void cats.reload()
  }
</script>

<div class="page narrow">
  <p class="muted small">{tr('Use categories to group items. Pick an icon and colour for each.', 'सामानलाई समूहमा राख्न वर्ग प्रयोग गर्नुहोस्। हरेकको लागि आइकन र रंग छान्नुहोस्।')}</p>

  {#if cats.error}
    <ErrorCard error={cats.error} retry={cats.reload} />
  {:else if cats.loading && !cats.data}
    <Skeleton rows={4} />
  {:else if (cats.data ?? []).length === 0}
    <Empty icon="category" title={tr('No categories yet', 'अहिलेसम्म वर्ग छैन')} text={tr('Add a category to group your items.', 'सामान समूहमा राख्न वर्ग थप्नुहोस्।')} />
  {:else}
    <div class="list">
      {#each cats.data ?? [] as c (c.id)}
        {@const tint = validColor(c.color)}
        <button class="row" onclick={() => openEdit(c)}>
          <span class="icon-tile" style={tint ? `background:color-mix(in oklab, ${tint} 18%, var(--surface));color:${tint}` : ''}>
            <span class="ms">{c.icon ?? 'category'}</span>
          </span>
          <div class="row-main"><div class="row-title">{c.name}</div></div>
          {#if counts[c.id] !== undefined}<span class="badge">{countLabel(counts[c.id])}</span>{/if}
          <span class="ms chev">chevron_right</span>
        </button>
      {/each}
    </div>
  {/if}

  <button class="fab" onclick={openAdd}><span class="ms">add</span><span>{tr('Add', 'थप्ने')}</span></button>
</div>

<Sheet bind:open={formOpen} title={editing ? tr('Edit category', 'वर्ग सच्याउने') : tr('New category', 'नयाँ वर्ग')}>
  <form class="stack" onsubmit={(e) => { e.preventDefault(); void submit() }}>
    <Field label={tr('Category name', 'वर्गको नाम')} error={save.field('name')}>
      <input required maxlength="100" bind:value={name} placeholder={tr('Example: Spices', 'उदाहरण: मसला')} />
    </Field>

    <span class="small muted">{tr('Icon', 'आइकन')}</span>
    <div class="icon-grid">
      {#each ICONS as ic}
        <button type="button" class="item-tile" class:selected={icon === ic} aria-label={ic} onclick={() => (icon = ic)}>
          <span class="ms">{ic}</span>
        </button>
      {/each}
    </div>

    <span class="small muted">{tr('Colour', 'रंग')}</span>
    <div class="hstack wrap" style="gap:12px">
      {#each COLORS as col}
        <button type="button" class="swatch" class:selected={color === col} style="background:{col}" aria-label={col} onclick={() => (color = col)}></button>
      {/each}
    </div>

    {#if save.message}
      <div class="alert bad"><span class="ms">error</span><div>{save.message}</div></div>
    {/if}
    <button class="btn btn-primary btn-lg btn-block" type="submit" disabled={save.busy}>
      <span class="ms">check</span><span>{save.busy ? tr('Saving…', 'सेभ हुँदैछ…') : tr('Save', 'सेभ गर्ने')}</span>
    </button>
    {#if editing}
      <button type="button" class="btn btn-danger btn-block" onclick={openConfirm}><span class="ms">delete</span><span>{tr('Delete category', 'वर्ग मेटाउने')}</span></button>
    {/if}
  </form>
</Sheet>

<Sheet bind:open={confirmOpen} title={tr('Delete category?', 'वर्ग मेटाउने हो?')}>
  <div class="alert warn">
    <span class="ms">info</span>
    <div>{tr('Deleting keeps the items. They just have no category.', 'मेटाउँदा सामान हट्दैनन्। तिनको वर्ग मात्र खाली हुन्छ।')}</div>
  </div>
  {#if del.message}
    <div class="alert bad"><span class="ms">error</span><div>{del.message}</div></div>
  {/if}
  <button class="btn btn-danger btn-lg btn-block" disabled={del.busy} onclick={remove}>
    <span class="ms">delete</span><span>{del.busy ? tr('Deleting…', 'मेटिँदैछ…') : tr('Delete', 'मेटाउने')}</span>
  </button>
  <button class="btn btn-tonal btn-block" onclick={() => (confirmOpen = false)}>{tr('Cancel', 'रद्द गर्ने')}</button>
</Sheet>

<style>
  .icon-grid {
    display: grid;
    grid-template-columns: repeat(6, 1fr);
    gap: 8px;
  }
  .icon-grid .item-tile {
    min-height: 0;
    align-items: center;
    justify-content: center;
    padding: 10px 0;
  }
  .swatch {
    width: 36px;
    height: 36px;
    border-radius: 50%;
    border: 3px solid var(--surface);
  }
  .swatch.selected {
    outline: 2px solid var(--text);
    outline-offset: 1px;
  }
</style>
