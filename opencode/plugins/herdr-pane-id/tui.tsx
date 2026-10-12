/** @jsxImportSource @opentui/solid */
// Shows the Herdr pane / tab this TUI runs in, inside OpenCode's footers.
//
// Auto-discovered: OpenCode loads every directory under the global
// <config>/plugins directory that has a tui entrypoint (this file).
// Values come from the environment Herdr injects into its panes:
//   HERDR_PANE_ID=wK:p2  HERDR_TAB_ID=wK:t2  HERDR_WORKSPACE_ID=wK
//
// Optional settings (when listed in cli.json as
// {"package":"./plugins/herdr-pane-id","options":{...}}):
//   show: "pane" | "tab" | "both"   (default: "both")
import { Plugin } from "@opencode/plugin/tui"

const PANE_ID = process.env.HERDR_PANE_ID
const TAB_ID = process.env.HERDR_TAB_ID

function badgeText(options: Readonly<Record<string, any>>): string | undefined {
  const show = options.show ?? "both"
  const pane = show === "tab" ? undefined : PANE_ID
  const tab = show === "pane" ? undefined : TAB_ID
  if (pane && tab) return `${pane} · ${tab}`
  return pane ?? tab
}

function PaneBadge(props: { context: Plugin.Context }) {
  const text = badgeText(props.context.options)
  if (!text) return null
  return (
    <text fg={props.context.theme.text.muted} wrapMode="none" flexShrink={0}>
      {text}
    </text>
  )
}

export default Plugin.define({
  id: "herdr.pane-id",
  setup(context) {
    if (!badgeText(context.options)) return
    context.ui.slot({
      append: "prompt.footer.status",
      render: () => <PaneBadge context={context} />,
    })
    context.ui.slot({
      append: "home.footer.status",
      render: () => <PaneBadge context={context} />,
    })
  },
})
