// Compact, theme-aware footer. Quota reads are passive and active-provider-only.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFile, type ChildProcess } from "node:child_process";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import path from "node:path";

const REFRESH_MS = 60_000;
const PROVIDERS = new Set([
  "claude", "codex", "cursor", "copilot", "grok", "kimi", "zai", "alibaba",
  "opencode-go", "commandcode", "minimax", "mimo", "deepseek", "openrouter",
  "elevenlabs", "devin", "muse", "higgsfield",
]);
// Never probe agy: a signed-out CLI may open an interactive OAuth browser tab.
const ALIASES: Record<string, string> = { anthropic: "claude", "openai-codex": "codex" };

interface QuotaWindow {
  id: string;
  label?: string;
  percentRemaining?: number;
  resetsAt?: string;
}
interface QuotaProvider {
  provider: string;
  windows?: QuotaWindow[];
  state?: { status?: string; stale?: boolean };
}

function resetLabel(at: string | undefined): string {
  const ms = Date.parse(at ?? "") - Date.now();
  if (!Number.isFinite(ms) || ms <= 0) return "";
  const minutes = Math.ceil(ms / 60_000);
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.ceil(minutes / 60);
  return hours < 48 ? `${hours}h` : `${Math.ceil(hours / 24)}d`;
}

export default function (pi: ExtensionAPI) {
  let stop = () => {};
  let refresh = () => {};
  pi.on("session_shutdown", () => stop());
  pi.on("model_select", () => refresh());
  pi.on("session_start", (_event, ctx) => {
    stop();
    if (ctx.mode !== "tui") return;

    let disposed = false;
    let child: ChildProcess | undefined;
    let provider: string | undefined;
    let quota: QuotaProvider | undefined;
    let fetchedAt = 0;
    let unavailable = false;
    let requestRender = () => {};
    let unsubscribe = () => {};

    refresh = () => {
      if (disposed) return;
      const active = ctx.model?.provider ?? "";
      const next = ALIASES[active] ?? active;
      if (next !== provider) {
        child?.kill();
        child = undefined;
        provider = next;
        quota = undefined;
        fetchedAt = 0;
        unavailable = false;
      }
      if (!PROVIDERS.has(next) || child || Date.now() - fetchedAt < REFRESH_MS) {
        requestRender();
        return;
      }
      fetchedAt = Date.now();
      const running = execFile("quota-axi", [
        "--json", "--no-credential-refresh", "--provider", next, "--max-age", "1m",
      ], { timeout: 10_000 }, (error, stdout) => {
        if (disposed || provider !== next || child !== running) return;
        child = undefined;
        quota = undefined;
        unavailable = true;
        if (!error) {
          try {
            const data = JSON.parse(stdout) as { providers?: QuotaProvider[] };
            if (Array.isArray(data.providers)) {
              quota = data.providers.find(p => p.provider === next);
              unavailable = !quota;
            }
          } catch {
            // Failed reads must not keep presenting old percentages as fresh.
          }
        }
        requestRender();
      });
      child = running;
    };
    const timer = setInterval(() => refresh(), REFRESH_MS);
    timer.unref();
    stop = () => {
      if (disposed) return;
      disposed = true;
      clearInterval(timer);
      child?.kill();
      child = undefined;
      unsubscribe();
    };

    ctx.ui.setFooter((tui, theme, footerData) => {
      requestRender = () => tui.requestRender();
      unsubscribe = footerData.onBranchChange(requestRender);
      return {
        invalidate() {},
        dispose: stop,
        render(width: number): string[] {
          if (width <= 0) return [""];
          const dir = path.basename(ctx.cwd) || ctx.cwd;
          const branch = footerData.getGitBranch();
          const effort = pi.getThinkingLevel();
          const model = ctx.model?.id ?? "no-model";
          const left = theme.fg("accent", `${dir}${branch ? ` (${branch})` : ""} · ${model} · ${effort}`);
          const percent = ctx.getContextUsage()?.percent;
          const context = theme.fg(
            percent != null && percent >= 85 ? "error" : percent != null && percent >= 65 ? "warning" : "dim",
            `ctx ${percent != null && Number.isFinite(percent) ? `${Math.round(percent)}%` : "?"}`,
          );
          const active = ctx.model?.provider ?? "";
          const matches = provider === (ALIASES[active] ?? active);
          let quotaText = "";
          let compactQuota = "";
          if (matches && PROVIDERS.has(provider ?? "")) {
            const state = quota?.state;
            if (unavailable) {
              quotaText = theme.fg("dim", "quota unavailable");
            } else if (quota && (state?.stale || state?.status !== "fresh" || Date.now() - fetchedAt > REFRESH_MS * 2)) {
              quotaText = theme.fg("warning", "quota stale");
            } else if (quota) {
              const windows = Array.isArray(quota.windows) ? quota.windows : [];
              const parts: string[] = [];
              const short: string[] = [];
              for (const window of windows) {
                const remaining = window.percentRemaining;
                if (typeof remaining !== "number" || !Number.isFinite(remaining)) continue;
                const label = window.id === "five_hour" ? "5h" : window.id === "weekly" ? "week" : window.label ?? window.id;
                const text = `${label} ${Math.round(Math.max(0, Math.min(100, remaining)))}% left`;
                const color = remaining <= 10 ? "error" : remaining <= 25 ? "warning" : "dim";
                const reset = resetLabel(window.resetsAt);
                short.push(theme.fg(color, text));
                parts.push(theme.fg(color, `${text}${reset ? ` (reset ${reset})` : ""}`));
              }
              quotaText = parts.join(" · ");
              compactQuota = short.join(" · ");
            }
          }
          let right = context + (quotaText ? ` · ${quotaText}` : "");
          // Drop reset details, then quota before sacrificing context or overflowing.
          if (visibleWidth(right) > width / 2 && compactQuota) right = `${context} · ${compactQuota}`;
          if (visibleWidth(right) >= width - 8) right = context;
          const leftWidth = Math.max(0, width - visibleWidth(right) - 1);
          const clippedLeft = truncateToWidth(left, leftWidth);
          const line = leftWidth > 0
            ? clippedLeft + " ".repeat(Math.max(1, width - visibleWidth(clippedLeft) - visibleWidth(right))) + right
            : right;
          const lines = [truncateToWidth(line, width)];
          const statuses = [...footerData.getExtensionStatuses().values()].filter(Boolean);
          if (statuses.length) lines.push(truncateToWidth(statuses.join(" · "), width));
          return lines;
        },
      };
    });
    refresh();
  });
}
