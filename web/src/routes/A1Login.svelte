<script lang="ts">
  import { session } from '../lib/session.svelte'
  import { settings } from '../lib/settings.svelte'
  import { navigate } from '../lib/router.svelte'
  import { action } from '../lib/resource.svelte'
  import { toast } from '../lib/toast.svelte'
  import { tr } from '../lib/i18n'
  import Field from '../components/Field.svelte'

  let email = $state('')
  let password = $state('')
  let show = $state(false)
  const save = action()

  async function submit(e: Event) {
    e.preventDefault()
    const ok = await save.run(async () => {
      await session.login(email.trim(), password)
      return true
    })
    if (ok) {
      toast(`Logged in. Welcome, ${session.user?.name.split(' ')[0]}.`, `लग इन भयो। स्वागत छ, ${session.user?.name.split(' ')[0]}।`)
      navigate('/', true)
    }
  }
</script>

<form class="page narrow" onsubmit={submit}>
  <div class="chips" style="justify-content:flex-end">
    <button type="button" class="chip" class:active={!settings.ne} onclick={() => settings.set({ lang: 'en' })}>English</button>
    <button type="button" class="chip" class:active={settings.ne} onclick={() => settings.set({ lang: 'ne' })}>नेपाली</button>
  </div>

  <section class="stack" style="align-items:center;text-align:center;margin-top:24px">
    <div class="icon-tile lg" style="width:84px;height:84px;border-radius:28px;font-size:38px;font-weight:800;background:var(--primary);color:var(--on-seed)">प</div>
    <h1>PASAL</h1>
    <p class="muted">{tr('Stock, sales and credit, made simple', 'स्टक, बिक्री र उधारोको सजिलो हिसाब')}</p>
  </section>

  <section class="card stack" style="margin-top:12px">
    <Field label={tr('Email', 'इमेल')} error={save.field('email')}>
      <input type="email" autocomplete="username" required bind:value={email} />
    </Field>
    <Field label={tr('Password', 'पासवर्ड')} error={save.field('password')}>
      <div class="input-group">
        <input type={show ? 'text' : 'password'} autocomplete="current-password" required bind:value={password} style="padding-right:96px" />
        <button class="btn btn-ghost btn-sm suffix" type="button" onclick={() => (show = !show)}>
          <span class="ms">{show ? 'visibility_off' : 'visibility'}</span><span>{show ? tr('Hide', 'लुकाउने') : tr('Show', 'देखाउने')}</span>
        </button>
      </div>
    </Field>
    {#if save.message}
      <div class="alert bad"><span class="ms">error</span><div>{save.message}</div></div>
    {/if}
    <div class="hstack" style="justify-content:flex-end">
      <a class="btn btn-ghost btn-sm" href="#/forgot-password">{tr('Forgot password?', 'पासवर्ड बिर्सनुभयो?')}</a>
    </div>
  </section>

  <div class="bottom-bar">
    <button class="btn btn-primary btn-lg btn-block" type="submit" disabled={save.busy || !email || !password}>
      <span class="ms">login</span><span>{save.busy ? tr('Logging in…', 'लग इन हुँदैछ…') : tr('Log in', 'लग इन')}</span>
    </button>
  </div>
</form>
