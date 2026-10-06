# Glyph Player — Live TV visual direction

Mode: Operate (task: find a channel and watch it). Surface: desktop app, dark, mouse + keyboard.
Build path: code-first (Flutter; no image comps).

## World
A broadcast control room at night: near-black ink, one hot **tally** light (the red-orange lamp that says a source is live). Everything else recedes so channel logos and the picture carry colour. Bold where it matters (the Recentes row, the live indicator), quiet elsewhere.

## Palette (opaque, tinted toward blue-ink; no pure black/white)
| Token | Hex | Use |
|---|---|---|
| ink | `#0B0E14` | app background |
| panel | `#131822` | rail, panels |
| tile | `#1A2030` | card/logo tile base |
| tileHi | `#222A3E` | hover tile |
| line | `#2A3348` | hairlines |
| text | `#E8ECF4` | primary (contrast ≥ 12:1 on ink) |
| textDim | `#98A3BB` | secondary (≥ 6:1 on ink) |
| tally | `#FF5B3A` | live dot, focus ring, primary action |
| tallyDim | `#FF5B3A` @ 18% | selected row background |

Single accent (tally). No gradients, no glass, no coloured side borders.

## Type (bundled, OFL)
- Display / row titles: **Bricolage Grotesque** 600–700, 22/28 row titles, 28/32 page title, tight tracking (-0.01em).
- UI / channel names: **Instrument Sans** 400–600, 14/20 names, 12/16 meta.
Both bundled as assets (no runtime network).

## Layout
- **Left rail** 72 px: logo glyph, Ao vivo (active), Configurações at bottom. Active item = tally marker + text, not a filled pill.
- **Top bar** in content: page title "Ao vivo" left, search field right (⌘/Ctrl-K focuses it).
- **Home = rows.** First row **Recentes** is the focal moment: wide 16:9 cards (240×135) with a live dot; then Favoritos, then one row per group with standard cards (168×112). Row title + item count in dim text. Horizontal scroll with mouse wheel and ←/→ when focused.
- **Channel card:** tile with centred logo (contain, 56% of height), name below (1 line, ellipsis). Missing/failed logo → monogram (first letters) on tile, not a generic TV icon.
- **Hover/focus:** tile → tileHi, scale 1.03, 2 px tally focus ring (keyboard focus always visible). 120 ms.
- **Empty state** (no channels): headline "Nenhum canal ainda", one sentence, single primary button → Configurações.
- **Progress during import:** 2 px tally line under the top bar + text in Configurações; UI stays interactive.

## Player
Full-bleed video. Channel panel slides in from the right (320 px, panel at 94% opacity, solid, no blur), 220 ms exponential ease-out (cubic-bezier 0.16, 1, 0.3, 1). Current channel = tallyDim row with a live dot. ↑/↓ zap, L toggles panel, Esc back, star toggles favourite. Controls auto-hide after 2.5 s without mouse movement.

## Motion
One authored moment: the player panel slide. Everything else is 120 ms hover feedback. Respect reduced motion (skip scale and slide, cross-fade only).

## Anti-goals
No hero banners, no fake program art, no emoji/Unicode icons (use Material Symbols Rounded via Flutter Icons), no section kickers, no identical icon-heading-text cards.

## Accessibility
Contrast as above, visible keyboard focus everywhere, tooltips on icon buttons, minimum hit target 40×40.
