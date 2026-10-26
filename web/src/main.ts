import '@fontsource/inter/400.css'
import '@fontsource/inter/500.css'
import '@fontsource/inter/600.css'
import '@fontsource/inter/700.css'
import '@fontsource/inter/800.css'
import '@fontsource/noto-sans-devanagari/400.css'
import '@fontsource/noto-sans-devanagari/500.css'
import '@fontsource/noto-sans-devanagari/600.css'
import '@fontsource/noto-sans-devanagari/700.css'
import 'material-symbols/rounded.css'
import './styles/pasal.css'
import { mount } from 'svelte'
import App from './App.svelte'
import { session } from './lib/session.svelte'

mount(App, { target: document.getElementById('app')! })
void session.restore()
