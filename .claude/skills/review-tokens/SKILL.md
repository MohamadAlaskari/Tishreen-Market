---
name: review-tokens
description: Run the design-token / theme / typography fidelity review on the current diff using the design-token-guardian agent, optionally comparing a screen with its Figma node.
argument-hint: [paths… | figma node id]
disable-model-invocation: true
---
Review design-system fidelity for: **$ARGUMENTS** (empty = current diff in `apps/web`, `packages/ui`; a node id like `8:5` triggers the Figma comparison).

1. Run the frontend hook on each file and keep its COLOR/CONTRAST lines.
2. Delegate to the `design-token-guardian` subagent (pass paths and node id). If a node id is given, have it fetch `get_metadata` + `get_screenshot` and compare against the spec row in `tishreen-handoff/tishreen-handoff/docs/07`.
3. Verify the three presets: render-critical components must not reference a preset; `data-theme` + `.dark` both covered; fonts `font-display|label|mono` used as in `tishreen-handoff/tishreen-handoff/docs/08 §5`.
4. Output the table and "token fidelity: pass/fail" with at most three concrete improvements.
