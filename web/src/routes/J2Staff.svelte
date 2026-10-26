<script lang="ts">
  import { api } from '../lib/api'
  import { resource, action } from '../lib/resource.svelte'
  import { session } from '../lib/session.svelte'
  import { tr } from '../lib/i18n'
  import { toast } from '../lib/toast.svelte'
  import { initials } from '../lib/util'
  import type { Role, User } from '../lib/types'
  import Sheet from '../components/Sheet.svelte'
  import Field from '../components/Field.svelte'
  import Skeleton from '../components/Skeleton.svelte'
  import ErrorCard from '../components/ErrorCard.svelte'

  const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'

  const list = resource(() => api.all<User>('/users'))
  const users = $derived(list.data ?? [])

  let addOpen = $state(false)
  let editOpen = $state(false)
  let removeOpen = $state(false)
  let target = $state<User | null>(null)

  let name = $state('')
  let email = $state('')
  let password = $state('')
  let role = $state<Role>('staff')
  let showPw = $state(false)
  let tried = $state(false)
  let created = $state<{ name: string; password: string } | null>(null)

  const addJob = action()
  const editJob = action()
  const removeJob = action()

  const roleChanged = $derived(!!target && role !== target.role)
  const passwordLength = $derived(password.length)
  const passwordError = $derived(
    tried && passwordLength > 0 && (passwordLength < 10 || passwordLength > 100)
      ? tr('Use 10 to 100 characters', '१० देखि १०० अक्षरसम्मको पासवर्ड राख्नुहोस्')
      : null,
  )

  function resetForm(): void {
    name = ''
    email = ''
    password = ''
    role = 'staff'
    showPw = false
    tried = false
  }

  function openAdd(): void {
    resetForm()
    created = null
    addJob.clear()
    addOpen = true
  }

  function openEdit(u: User): void {
    resetForm()
    target = u
    name = u.name
    email = u.email
    role = u.role
    editJob.clear()
    editOpen = true
  }

  function askRemove(u: User): void {
    target = u
    removeJob.clear()
    editOpen = false
    removeOpen = true
  }

  function generate(): void {
    const bytes = crypto.getRandomValues(new Uint32Array(14))
    password = Array.from(bytes, (b) => ALPHABET[b % ALPHABET.length]).join('')
    showPw = true
  }

  async function addUser(e: Event): Promise<void> {
    e.preventDefault()
    tried = true
    if (passwordError) return
    const body = { name: name.trim(), email: email.trim(), password, role }
    const ok = await addJob.run(() => api.post('/users', body))
    if (ok) {
      created = { name: body.name, password: body.password }
      void list.reload()
    }
  }

  async function editUser(e: Event): Promise<void> {
    e.preventDefault()
    const u = target
    if (!u) return
    tried = true
    if (passwordError) return
    const body: Record<string, string> = {}
    if (name.trim() !== u.name) body.name = name.trim()
    if (email.trim() !== u.email) body.email = email.trim()
    if (role !== u.role) body.role = role
    if (password) body.password = password
    if (Object.keys(body).length === 0) {
      editOpen = false
      return
    }
    const signsOut = 'role' in body || 'password' in body
    const ok = await editJob.run(() => api.patch(`/users/${u.id}`, body))
    if (ok) {
      editOpen = false
      toast(
        signsOut ? `Saved. ${u.name} is signed out on every phone.` : 'Saved',
        signsOut ? `सेभ भयो। ${u.name} सबै फोनबाट साइन आउट भए।` : 'सेभ भयो',
      )
      void list.reload()
    }
  }

  async function removeUser(): Promise<void> {
    const u = target
    if (!u) return
    const ok = await removeJob.run(() => api.delete<{ message: string }>(`/users/${u.id}`))
    if (ok) {
      removeOpen = false
      toast(`${u.name} removed`, `${u.name} हटाइयो`)
      void list.reload()
    }
  }
</script>

<div class="page">
  <div class="alert">
    <span class="ms">info</span>
    <div>{tr('Staff cannot see buying prices, purchases, reports or VAT.', 'कर्मचारीले खरिद भाउ, खरिद, रिपोर्ट र भ्याट देख्न सक्दैनन्।')}</div>
  </div>

  {#if list.error}
    <ErrorCard error={list.error} retry={list.reload} />
  {:else if list.loading && !list.data}
    <Skeleton rows={3} />
  {:else}
    <div class="list">
      {#each users as u (u.id)}
        {@const me = u.id === session.user?.id}
        {#if me}
          <div class="row">
            <span class="avatar">{initials(u.name)}</span>
            <div class="row-main">
              <div class="row-title">{u.name} <span class="tiny muted">{tr('(You)', '(तपाईं)')}</span></div>
              <div class="row-sub">{u.email}</div>
            </div>
            <span class="badge" class:primary={u.role === 'owner'}>{u.role === 'owner' ? tr('Owner', 'मालिक') : tr('Staff', 'कर्मचारी')}</span>
          </div>
        {:else}
          <button class="row" onclick={() => openEdit(u)}>
            <span class="avatar">{initials(u.name)}</span>
            <div class="row-main">
              <div class="row-title">{u.name}</div>
              <div class="row-sub">{u.email}</div>
            </div>
            <span class="badge" class:primary={u.role === 'owner'}>{u.role === 'owner' ? tr('Owner', 'मालिक') : tr('Staff', 'कर्मचारी')}</span>
            <span class="ms chev">chevron_right</span>
          </button>
        {/if}
      {/each}
    </div>
  {/if}

  <button class="fab" onclick={openAdd}><span class="ms">person_add</span><span>{tr('Add staff', 'कर्मचारी थप्ने')}</span></button>

  <Sheet bind:open={addOpen} title={tr('Add staff', 'कर्मचारी थप्ने')}>
    {#if created}
      <div class="alert good">
        <span class="ms">check_circle</span>
        <div class="stack-sm">
          <div class="alert-title">{tr(`${created.name} is added`, `${created.name} थपियो`)}</div>
          <div>{tr('Share this password with them now. It is not shown again.', 'यो पासवर्ड अहिले नै उनीसँग साझा गर्नुहोस्। यो फेरि देखाइने छैन।')}</div>
          <div class="bold" style="font-size:18px;word-break:break-all">{created.password}</div>
        </div>
      </div>
      <button class="btn btn-primary btn-lg btn-block" type="button" onclick={() => (addOpen = false)}>{tr('Done', 'भयो')}</button>
    {:else}
      <form class="stack" onsubmit={addUser}>
        <Field label={tr('Name', 'नाम')} error={addJob.field('name')}>
          <input bind:value={name} required maxlength="100" placeholder={tr('Full name', 'पूरा नाम')} />
        </Field>
        <Field label={tr('Email', 'इमेल')} error={addJob.field('email')}>
          <input type="email" bind:value={email} required maxlength="150" placeholder="name@example.com" />
        </Field>
        <Field label={tr('Password', 'पासवर्ड')} error={passwordError ?? addJob.field('password')} hint={tr('At least 10 characters.', 'कम्तीमा १० अक्षरको हुनुपर्छ।')}>
          <div class="input-group">
            <input type={showPw ? 'text' : 'password'} bind:value={password} required style="padding-right:96px" autocomplete="new-password" />
            <button class="btn btn-ghost btn-sm suffix" type="button" onclick={() => (showPw = !showPw)}>
              <span>{showPw ? tr('Hide', 'लुकाउने') : tr('Show', 'देखाउने')}</span>
            </button>
          </div>
        </Field>
        <button class="btn btn-tonal btn-block" type="button" onclick={generate}><span class="ms">key</span><span>{tr('Generate a password', 'पासवर्ड बनाउने')}</span></button>
        <div class="field">
          <span class="label">{tr('Role', 'भूमिका')}</span>
          <div class="seg block">
            <button type="button" class:active={role === 'owner'} onclick={() => (role = 'owner')}>{tr('Owner', 'मालिक')}</button>
            <button type="button" class:active={role === 'staff'} onclick={() => (role = 'staff')}>{tr('Staff', 'कर्मचारी')}</button>
          </div>
        </div>
        {#if addJob.message}
          <div class="alert bad"><span class="ms">error</span><div>{addJob.message}</div></div>
        {/if}
        <button class="btn btn-primary btn-lg btn-block" type="submit" disabled={addJob.busy}>
          <span class="ms">check</span><span>{addJob.busy ? tr('Adding…', 'थपिँदैछ…') : tr('Add staff', 'कर्मचारी थप्ने')}</span>
        </button>
      </form>
    {/if}
  </Sheet>

  <Sheet bind:open={editOpen} title={target?.name ?? ''}>
    {#if target}
      <form class="stack" onsubmit={editUser}>
        <Field label={tr('Name', 'नाम')} error={editJob.field('name')}>
          <input bind:value={name} required maxlength="100" />
        </Field>
        <Field label={tr('Email', 'इमेल')} error={editJob.field('email')}>
          <input type="email" bind:value={email} required maxlength="150" />
        </Field>
        <div class="field">
          <span class="label">{tr('Role', 'भूमिका')}</span>
          <div class="seg block">
            <button type="button" class:active={role === 'owner'} onclick={() => (role = 'owner')}>{tr('Owner', 'मालिक')}</button>
            <button type="button" class:active={role === 'staff'} onclick={() => (role = 'staff')}>{tr('Staff', 'कर्मचारी')}</button>
          </div>
        </div>
        <Field label={tr('New password (leave empty to keep)', 'नयाँ पासवर्ड (खाली छोड्नुहोस्)')} error={passwordError ?? editJob.field('password')}>
          <div class="input-group">
            <input type={showPw ? 'text' : 'password'} bind:value={password} style="padding-right:96px" autocomplete="new-password" />
            <button class="btn btn-ghost btn-sm suffix" type="button" onclick={() => (showPw = !showPw)}>
              <span>{showPw ? tr('Hide', 'लुकाउने') : tr('Show', 'देखाउने')}</span>
            </button>
          </div>
        </Field>
        {#if roleChanged || passwordLength > 0}
          <div class="alert warn"><span class="ms">warning</span><div>{tr(`${target.name} is signed out on every phone when you save.`, `सेभ गर्दा ${target.name} सबै फोनबाट साइन आउट हुन्छन्।`)}</div></div>
        {/if}
        {#if editJob.message}
          <div class="alert bad"><span class="ms">error</span><div>{editJob.message}</div></div>
        {/if}
        <button class="btn btn-primary btn-block" type="submit" disabled={editJob.busy}>
          <span>{editJob.busy ? tr('Saving…', 'सेभ हुँदैछ…') : tr('Save', 'सेभ गर्ने')}</span>
        </button>
        <div class="divider"></div>
        <button class="btn btn-danger btn-block" type="button" onclick={() => target && askRemove(target)}>
          <span class="ms">person_remove</span><span>{tr('Remove staff', 'कर्मचारी हटाउने')}</span>
        </button>
      </form>
    {/if}
  </Sheet>

  <Sheet bind:open={removeOpen} title={tr('Remove staff?', 'कर्मचारी हटाउने?')}>
    {#if target}
      <p>{tr(`Removing signs ${target.name} out on every phone.`, `हटाउँदा ${target.name} सबै फोनबाट साइन आउट हुन्छन्।`)}</p>
      {#if removeJob.message}
        <div class="alert bad"><span class="ms">error</span><div>{removeJob.message}</div></div>
      {/if}
      <div class="hstack">
        <button class="btn btn-tonal btn-lg" style="flex:1" type="button" onclick={() => (removeOpen = false)}>{tr('Cancel', 'रद्द')}</button>
        <button class="btn btn-danger btn-lg" style="flex:1" type="button" disabled={removeJob.busy} onclick={removeUser}>
          <span>{removeJob.busy ? tr('Removing…', 'हटाउँदैछ…') : tr('Remove', 'हटाउने')}</span>
        </button>
      </div>
    {/if}
  </Sheet>
</div>
