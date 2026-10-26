<script lang="ts">
  import { api } from '../lib/api'
  import { session } from '../lib/session.svelte'
  import { navigate } from '../lib/router.svelte'
  import { action } from '../lib/resource.svelte'
  import { toast } from '../lib/toast.svelte'
  import { tr } from '../lib/i18n'
  import { initials } from '../lib/util'
  import Field from '../components/Field.svelte'
  import Sheet from '../components/Sheet.svelte'

  let passOpen = $state(false)
  let devicesOpen = $state(false)
  let currentPassword = $state('')
  let newPassword = $state('')
  let leaving = $state(false)
  const save = action()

  const lengthError = $derived(
    newPassword.length > 0 && (newPassword.length < 10 || newPassword.length > 100)
      ? tr('Use 10 to 100 characters.', 'कम्तीमा १० र बढीमा १०० अक्षर हुनुपर्छ।')
      : null,
  )

  async function changePassword(e: Event) {
    e.preventDefault()
    if (lengthError) return
    const ok = await save.run(() => api.post('/me/password', { current_password: currentPassword, password: newPassword }))
    if (ok === undefined) return
    currentPassword = ''
    newPassword = ''
    passOpen = false
    toast('Password changed', 'पासवर्ड बदलियो')
  }

  async function signOut() {
    toast('Signed out', 'साइन आउट भयो')
    await session.logout()
    navigate('/login')
  }

  async function signOutEverywhere() {
    leaving = true
    await session.logout(true)
    leaving = false
    toast('Signed out on all devices', 'सबै यन्त्रबाट साइन आउट भयो')
    navigate('/login')
  }

  function openPassword() {
    save.clear()
    passOpen = true
  }
</script>

<div class="page narrow">
  <section class="card stack" style="align-items:center;text-align:center;padding:24px 16px">
    <span class="avatar" style="width:88px;height:88px;font-size:30px">{initials(session.user?.name ?? '')}</span>
    <div class="stack-sm" style="align-items:center">
      <h2>{session.user?.name}</h2>
      <span class="muted">{session.user?.email}</span>
      <span class="small muted">{session.business?.name ?? 'PASAL'}</span>
    </div>
    <div class="hstack wrap" style="justify-content:center">
      {#if session.isOwner}
        <span class="badge primary">{tr('Owner', 'मालिक')}</span>
      {:else}
        <span class="badge info">{tr('Staff', 'कर्मचारी')}</span>
      {/if}
    </div>
  </section>

  <div class="section-title"><h3>{tr('Security', 'सुरक्षा')}</h3></div>
  <div class="list">
    <button class="row" type="button" onclick={openPassword}>
      <span class="icon-tile"><span class="ms">key</span></span>
      <div class="row-main"><div class="row-title">{tr('Change password', 'पासवर्ड बदल्ने')}</div></div>
      <span class="ms chev">chevron_right</span>
    </button>
    <a class="row" href="#/settings/look">
      <span class="icon-tile"><span class="ms">palette</span></span>
      <div class="row-main"><div class="row-title">{tr('App look and language', 'एपको रूप र भाषा')}</div></div>
      <span class="ms chev">chevron_right</span>
    </a>
  </div>

  <div class="section-title"><h3>{tr('Signed in', 'साइन इन')}</h3></div>
  <div class="list">
    <button class="row" type="button" onclick={signOut}>
      <span class="icon-tile"><span class="ms">logout</span></span>
      <div class="row-main"><div class="row-title">{tr('Sign out', 'साइन आउट')}</div></div>
    </button>
    <button class="row" type="button" onclick={() => (devicesOpen = true)}>
      <span class="icon-tile bad"><span class="ms">devices</span></span>
      <div class="row-main">
        <div class="row-title bad">{tr('Sign out on all devices', 'सबै यन्त्रबाट साइन आउट')}</div>
        <div class="row-sub">{tr('Use it if you lost a phone', 'फोन हराएको भए यो प्रयोग गर्नुहोस्')}</div>
      </div>
      <span class="ms chev">chevron_right</span>
    </button>
  </div>
</div>

<Sheet bind:open={passOpen} title={tr('Change password', 'पासवर्ड बदल्ने')}>
  <form class="stack" onsubmit={changePassword}>
    <Field label={tr('Current password', 'हालको पासवर्ड')} error={save.field('current_password')}>
      <input type="password" autocomplete="current-password" required bind:value={currentPassword} />
    </Field>
    <Field label={tr('New password', 'नयाँ पासवर्ड')} error={save.field('password') ?? lengthError} hint={tr('At least 10 characters.', 'कम्तीमा १० अक्षरको हुनुपर्छ।')}>
      <input type="password" autocomplete="new-password" required bind:value={newPassword} />
    </Field>
    {#if save.message}
      <div class="alert bad"><span class="ms">error</span><div>{save.message}</div></div>
    {/if}
    <button class="btn btn-primary btn-lg btn-block" type="submit" disabled={save.busy || !currentPassword || !newPassword}>
      <span class="ms">check</span><span>{save.busy ? tr('Saving…', 'सेभ हुँदैछ…') : tr('Save new password', 'नयाँ पासवर्ड सेभ गर्ने')}</span>
    </button>
  </form>
</Sheet>

<Sheet bind:open={devicesOpen} title={tr('Sign out on all devices?', 'सबै यन्त्रबाट साइन आउट?')}>
  <div class="stack">
    <div class="alert warn"><span class="ms">warning</span><div>{tr('This signs out every phone that uses this account. Use it if you lost a phone. You must log in again on each phone.', 'यसले यो खाता चलाउने सबै फोनबाट साइन आउट गर्छ। फोन हराएको भए यो प्रयोग गर्नुहोस्। हरेक फोनमा फेरि लग इन गर्नुपर्छ।')}</div></div>
    <button class="btn btn-danger btn-lg btn-block" type="button" disabled={leaving} onclick={signOutEverywhere}>
      <span class="ms">devices</span><span>{tr('Sign out everywhere', 'सबै ठाउँबाट साइन आउट')}</span>
    </button>
    <button class="btn btn-outline btn-block" type="button" onclick={() => (devicesOpen = false)}>{tr('Cancel', 'रद्द गर्ने')}</button>
  </div>
</Sheet>
