# Glyph Player — Live TV visual direction

Mode: Operate (task: find a channel and watch it). Surface: desktop app, dark, mouse + keyboard.
Build path: code-first (Flutter; no image comps).

## World
The app follows the Glyph design system ("A Vitrine do Ourives"): a near-black ground with a trace of purple, one saturated accent (purple) and wine only as support. The brand gem sits at the top of the rail. Channel logos, posters and the picture carry the colour; everything else recedes.

## Palette (Glyph tokens; neutrals carry a trace of purple)
| Token | Hex | Glyph name | Use |
|---|---|---|---|
| ink | `#17131C` | neutral-900 | app background |
| panel / tile | `#241F2B` | neutral-800 | rail, panels, cards |
| tileHi / line | `#453F4E` | neutral-700 | card hover, hairlines, bar tracks |
| text | `#DDD8E0` | neutral-200 | body text |
| textStrong | `#FFFFFF` | ui-text-highlighted | titles |
| textDim | `#A79FB0` | neutral-400 | secondary text (6.3:1 on ink) |
| accent | `#C084FC` | purple-400 / ui-primary | focus ring, primary action, selection, progress (6.9:1 on ink) |
| accentDim | purple-400 @ 18% | | selected row |
| error | `#F87171` | ui-error | errors only |
| wine-400 | `#E77BA6` | ui-secondary | support only, never the main action |

Rules kept from the Glyph guideline: **one light** (purple and wine are the only saturated colours; section tiles are tinted only within the purple-to-wine hues, muted), **wine never leads**, no second accent, no gradients on text or buttons, depth by translucent layers, no hard offset shadows.

## Type (bundled, OFL)
- Display / titles: **Fraunces** 500 (variable font): 22/28 row titles, 28/32 page title, tight tracking.
- UI / body / channel names: **Manrope**: 14/20 names, 12/16 meta.
Both bundled as assets (no runtime network).

## Layout
- **Left rail** 72 px: Glyph gem mark, Ao vivo (active), Configurações at bottom. Active item = accent marker + text, not a filled pill.
- **Top bar** in content: page title "Ao vivo" left, search field right (⌘/Ctrl-K focuses it).
- **Home = rows.** First row **Recentes** is the focal moment: wide 16:9 cards (240×135) with a live dot; then Favoritos, then one row per group with standard cards (168×112). Row title + item count in dim text. Horizontal scroll with mouse wheel and ←/→ when focused.
- **Channel card:** tile with centred logo (contain, 56% of height), name below (1 line, ellipsis). Missing/failed logo → monogram (first letters) on tile, not a generic TV icon.
- **Hover/focus:** tile → tileHi, scale 1.03, 2 px accent (purple-400) focus ring (keyboard focus always visible). 120 ms.
- **Empty state** (no channels): headline "Nenhum canal ainda", one sentence, single primary button → Configurações.
- **Progress during import:** 2 px accent line under the top bar + text in Configurações; UI stays interactive.

## Player
Full-bleed video. Channel panel slides in from the right (320 px, panel at 94% opacity, solid, no blur), 220 ms exponential ease-out (cubic-bezier 0.16, 1, 0.3, 1). Current channel = tallyDim row with a live dot. ↑/↓ zap, L toggles panel, Esc back, star toggles favourite. Controls auto-hide after 2.5 s without mouse movement.

## Motion
One authored moment: the player panel slide. Everything else is 120 ms hover feedback. Respect reduced motion (skip scale and slide, cross-fade only).

## Anti-goals
No hero banners, no fake program art, no emoji/Unicode icons (use Material Symbols Rounded via Flutter Icons), no section kickers, no identical icon-heading-text cards.

## Accessibility
Contrast as above, visible keyboard focus everywhere, tooltips on icon buttons, minimum hit target 40×40.
