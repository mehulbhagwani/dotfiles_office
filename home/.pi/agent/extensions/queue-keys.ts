/**
 * Codex queue keys, reversed.
 *
 * While the agent is busy:
 * - Enter queues a follow-up (waits until the run finishes)
 * - Tab steers (delivered after the current turn)
 *
 * While idle, Enter still sends and Tab still completes.
 * Enter stays completion-confirm when the autocomplete menu is open.
 *
 * Requires ~/.pi/agent/keybindings.json to bind app.message.followUp to enter.
 */
import { CustomEditor, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Editor, matchesKey, type EditorTheme, type TUI } from "@earendil-works/pi-tui";
import type { KeybindingsManager } from "@earendil-works/pi-coding-agent";

type SubmittableEditor = {
	submitValue(): void;
};

class QueueKeysEditor extends CustomEditor {
	constructor(
		tui: TUI,
		theme: EditorTheme,
		keybindings: KeybindingsManager,
		private readonly isBusy: () => boolean,
	) {
		super(tui, theme, keybindings, { embedWorkingStatus: true });
	}

	handleInput(data: string): void {
		// followUp is bound to Enter, which would otherwise beat autocomplete confirm.
		if (matchesKey(data, "enter") && this.isShowingAutocomplete()) {
			Editor.prototype.handleInput.call(this, data);
			return;
		}

		if (matchesKey(data, "tab") && this.isBusy() && !this.isShowingAutocomplete()) {
			const text = this.getText().trim();
			if (text.length > 0) {
				(this as unknown as SubmittableEditor).submitValue();
				return;
			}
		}

		super.handleInput(data);
	}
}

export default function (pi: ExtensionAPI) {
	let streaming = false;
	let compacting = false;
	const isBusy = () => streaming || compacting;

	pi.on("agent_start", () => {
		streaming = true;
	});
	pi.on("agent_settled", () => {
		streaming = false;
	});
	pi.on("session_before_compact", () => {
		compacting = true;
	});
	pi.on("session_compact", () => {
		compacting = false;
	});
	pi.on("session_compact_failed", () => {
		compacting = false;
	});

	pi.on("session_start", (_event, ctx) => {
		if (!ctx.hasUI) return;
		ctx.ui.setEditorComponent(
			(tui, theme, keybindings) => new QueueKeysEditor(tui, theme, keybindings, isBusy),
		);
	});
}
