/**
 * /clear — start a new session, spelled the way the other agent CLIs spell it.
 *
 * Pi's own command is /new; Claude Code, Codex and the rest of this setup say
 * /clear. One word for one action means no per-tool muscle memory, so this is
 * an alias rather than a third meaning: clearing throws the conversation away
 * and starts a new session file, exactly like /new. /new keeps working, and
 * `pi --mode rpc` clients see both.
 *
 * Two behaviors make it safe to type blind:
 *   - a run still in flight is stopped first, not silently orphaned behind a
 *     new session (the notify says so);
 *   - a vetoed session switch (a session_shutdown handler can cancel one)
 *     reports itself instead of leaving the screen looking cleared.
 *
 * Nothing here touches the terminal scrollback: Pi renders its transcript
 * itself, so the only honest way to "clear" is to start a session with no
 * history in it.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.registerCommand("clear", {
    description: "Clear the conversation: start a new session (/new)",
    handler: async (_args, ctx) => {
      const interrupted = !ctx.isIdle();
      if (interrupted) {
        // abort(), then wait, because newSession() is rejected while a run is
        // active and a queued continuation would just rebuild the old thread.
        await ctx.abort();
        await ctx.waitForIdle();
      }

      const result = await ctx.newSession({
        withSession: async (fresh) => {
          fresh.ui.notify(interrupted ? "Cleared (stopped the running turn)" : "Cleared", "info");
        },
      });

      // Only reached when a handler refused the switch, so ctx is still live.
      if (result.cancelled) {
        ctx.ui.notify("Clear cancelled", "warning");
      }
    },
  });
}
