import { defineRootSetup } from '@slidev/types'

export default defineRootSetup(() => {
  const style = document.createElement('style')
  style.textContent = `
    :root { --slidev-code-background: #1a1b26 !important; }
    pre { --shiki-dark: #a9b1d6 !important; --shiki-light: #a9b1d6 !important; }

    /* Slidev's two-cols layout has no built-in gap or divider, the two
       sides otherwise sit flush against each other. */
    .slidev-layout.two-columns { column-gap: 3rem; }
    .slidev-layout.two-columns .col-right {
      border-left: 1px solid rgba(255, 255, 255, 0.15);
      padding-left: 2rem;
    }
  `
  document.head.appendChild(style)
})
