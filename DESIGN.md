---
name: Obsidian Punch
colors:
  surface: '#121411'
  surface-dim: '#121411'
  surface-bright: '#383a36'
  surface-container-lowest: '#0d0f0c'
  surface-container-low: '#1a1c19'
  surface-container: '#1e201d'
  surface-container-high: '#292a27'
  surface-container-highest: '#333532'
  on-surface: '#e3e3de'
  on-surface-variant: '#d1c5ad'
  inverse-surface: '#e3e3de'
  inverse-on-surface: '#2f312e'
  outline: '#9a907a'
  outline-variant: '#4d4634'
  surface-tint: '#edc22e'
  primary: '#fff2d7'
  on-primary: '#3d2f00'
  primary-container: '#ffd23f'
  on-primary-container: '#725a00'
  inverse-primary: '#745c00'
  secondary: '#c8c6c5'
  on-secondary: '#313030'
  secondary-container: '#4a4949'
  on-secondary-container: '#bab8b7'
  tertiary: '#f5f2f2'
  on-tertiary: '#303030'
  tertiary-container: '#d9d6d6'
  on-tertiary-container: '#5d5d5d'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffe089'
  primary-fixed-dim: '#edc22e'
  on-primary-fixed: '#241a00'
  on-primary-fixed-variant: '#574500'
  secondary-fixed: '#e5e2e1'
  secondary-fixed-dim: '#c8c6c5'
  on-secondary-fixed: '#1c1b1b'
  on-secondary-fixed-variant: '#474646'
  tertiary-fixed: '#e4e2e1'
  tertiary-fixed-dim: '#c8c6c5'
  on-tertiary-fixed: '#1b1c1c'
  on-tertiary-fixed-variant: '#474746'
  background: '#121411'
  on-background: '#e3e3de'
  surface-variant: '#333532'
typography:
  display-lg:
    fontFamily: Bricolage Grotesque
    fontSize: 48px
    fontWeight: '800'
    lineHeight: '1.1'
    letterSpacing: -0.04em
  headline-lg:
    fontFamily: Bricolage Grotesque
    fontSize: 32px
    fontWeight: '700'
    lineHeight: '1.2'
  headline-lg-mobile:
    fontFamily: Bricolage Grotesque
    fontSize: 24px
    fontWeight: '700'
    lineHeight: '1.2'
  title-md:
    fontFamily: Bricolage Grotesque
    fontSize: 20px
    fontWeight: '600'
    lineHeight: '1.4'
  body-lg:
    fontFamily: Bricolage Grotesque
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.6'
  body-md:
    fontFamily: Bricolage Grotesque
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.6'
  label-bold:
    fontFamily: Bricolage Grotesque
    fontSize: 14px
    fontWeight: '700'
    lineHeight: '1'
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  xs: 4px
  sm: 12px
  md: 24px
  lg: 40px
  xl: 64px
  gutter: 24px
  margin: 24px
---

## Brand & Style

The design system adopts a **Rough Comic Neo-Brutalism** aesthetic optimized for high-performance dark environments. It targets a bold, tech-forward audience that values high-energy interfaces with a "raw" edge. 

The personality is intentionally unapologetic and high-contrast, combining the structural grit of Neo-Brutalism with the approachable, hand-drawn energy of comic book layouts. The UI evokes a sense of urgency, precision, and tactile satisfaction through heavy strokes, vibrant accents, and significant depth created by high-contrast offsets rather than traditional shadows.

## Colors

The palette is anchored by a deep **Charcoal (#121212)** base, providing a void-like canvas that allows the signature **Vibrant Yellow (#FFD23F)** to pop with maximum intensity. 

- **Primary:** Vibrant Yellow for high-priority actions and brand elements.
- **Surface:** Deep Charcoal for the main background.
- **Surface-Container:** Dark Gray (#2A2A2A) for elevated modules and cards.
- **On-Surface:** Light Cream (#F5F5F0) for primary text to ensure high legibility and a softer contrast than pure white.
- **Status:** Green (#4ADE80) and Red (#F87171) are tuned to higher saturations to remain vibrant against the dark background while signaling financial status.

## Typography

This design system exclusively utilizes **Bricolage Grotesque** to maintain a quirky, characterful, and eclectic tone. 

- **Display & Headlines:** Set with tight tracking and heavy weights. Use the "Compressed" or "Condensed" axes where available for a more aggressive, editorial look.
- **Body Text:** Maintains generous line height for readability against the dark background.
- **Labels:** Always bold and often uppercase to mimic comic book dialogue or technical callouts.
- **Contrast:** Ensure all text on dark surfaces uses the Light Cream (#F5F5F0) token to prevent visual "halation" while maintaining accessibility.

## Layout & Spacing

The layout philosophy follows a **Fixed-Fluid Hybrid** model. Content is organized within a 12-column grid on desktop, transitioning to a 4-column grid on mobile.

- **The Offset:** Instead of standard centering, elements often feel "heavy" with 4px or 8px hard-shadow offsets.
- **Rhythm:** An 8px base unit drives all padding and margins. 
- **Margins:** Desktop containers use a maximum width of 1280px with 40px side margins, while mobile utilizes 24px margins to maximize screen real estate.
- **Gutters:** 24px fixed gutters ensure that even with heavy borders, the content has room to breathe.

## Elevation & Depth

Depth is communicated through **Neo-Brutalist Hard Shadows** rather than blurs or gradients. 

- **Hard Shadows:** Use a solid, 100% opacity black (#000000) offset. For primary yellow buttons, the shadow should be black. For dark-gray cards, the shadow remains black, creating a "stacked" physical effect.
- **Borders:** Every container, button, and input must have a **2px or 3px solid border**. On dark surfaces, use Black (#000000) for the border to maintain the "rough comic" look. If the background is pure black, use the Surface-Container (#2A2A2A) as a subtle border or a thin white stroke for critical focus states.
- **No Blurs:** Avoid all Gaussian blurs, transparency, or frosted glass effects. Every layer is opaque and clearly defined.

## Shapes

The "Round Eight" philosophy is applied throughout the design system. 

- **Standard Radius:** 0.5rem (8px) for all primary components (Buttons, Inputs, Small Cards).
- **Large Radius:** 1rem (16px) for major containers and layout sections.
- **Icons:** Should follow a thick-stroke, slightly rounded aesthetic to match the container language. Avoid razor-sharp corners or hyper-thin lines.

## Components

### Buttons
- **Primary:** Yellow background, black text, 3px black border, 4px black hard-shadow offset.
- **Secondary:** Dark Gray background, Cream text, 3px black border, 4px black hard-shadow offset.
- **Interaction:** On hover, the hard shadow "compresses" (offset moves to 0px) and the button moves 4px down and right to simulate a physical press.

### Cards
- **Surface:** Dark Gray (#2A2A2A) with a 2px black border.
- **Header:** Often separated by a horizontal 2px black line.

### Input Fields
- **Background:** Pure Black (#000000) or a slightly lighter gray.
- **Border:** 2px solid black, changing to 2px Vibrant Yellow on focus.
- **Placeholder:** Mid-gray to ensure the user understands the field is empty.

### Chips & Lists
- Chips should use the same yellow background as primary buttons but with a 1px border.
- Lists should feature 2px black separators between items, with high-contrast text for headers and secondary-contrast text for metadata.

### Semantic Indicators
- **Income (Green):** Used for large numerical displays and success icons.
- **Expense (Red):** Used for warnings, negative balances, and destructive actions.