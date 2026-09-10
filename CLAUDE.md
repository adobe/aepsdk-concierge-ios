# Project Rules for aepsdk-concierge-ios

## Keep the style guide in sync with the theme API

`Documentation/Implementation/style-guide.md` is the source of truth for every CSS variable /
Swift theme property pair this SDK exposes. It has three places that all need to move together
whenever a public theme token is added, renamed, or removed:

1. The relevant property table under `## Theme Tokens` (ex: "Colors - Input", "Colors - Input Icons") --
   CSS variable name, Swift property path, type, default, description.
2. The full-theme JSON template under `## Complete Example` -- add the new CSS key (with an
   empty/placeholder value) in roughly the position it appears in the real theme JSON.
3. The coverage checklist table under `## Implementation Status` (the `| CSS Variable | Status | Notes |`
   list) -- one row per new key, `✅`, and a short note on which Swift file/view consumes it.

If the new token is a genuinely new *pattern* (not just another instance of an existing one --
ex: the gradient start/end/angle key trio), also add or extend the relevant subsection under
`## Value Formats` explaining the pattern once, rather than repeating the explanation in every table row.

**When to do this:** any time a change touches `AEPBrandConcierge/Sources/Theme/` (new/changed public
struct, property, or `CSSKeyMapper`/`CSSValueConverter` entry) -- update the style guide in the same
commit as the code change, not as a follow-up. Do this automatically; don't wait to be asked.
