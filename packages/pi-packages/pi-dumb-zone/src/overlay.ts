import type { ExtensionContext, Theme } from "@mariozechner/pi-coding-agent";
import { truncateToWidth } from "@mariozechner/pi-tui";
import { DUMB_ZONE_MESSAGE, OVERLAY_COOLDOWN_MS } from "./constants";
import { createThemedBoxRenderer } from "./lib/box-renderer";

let overlayActive = false;
let lastOverlayTime = 0;

/**
 * Check if enough time has passed since last overlay.
 */
export function shouldShowOverlay(): boolean {
  if (overlayActive) return false;

  const now = Date.now();
  if (now - lastOverlayTime < OVERLAY_COOLDOWN_MS) {
    return false;
  }

  return true;
}

/**
 * Reset cooldown timer (for testing).
 */
export function resetCooldown(): void {
  lastOverlayTime = 0;
  overlayActive = false;
}

/**
 * Trigger dumb zone overlay display.
 */
export function triggerDumbZoneOverlay(ctx: ExtensionContext, details: string): void {
  if (!ctx.hasUI) return;
  if (!shouldShowOverlay()) return;

  lastOverlayTime = Date.now();
  void showDumbZoneOverlay(ctx, details);
}

/**
 * Show the dumb zone overlay.
 */
async function showDumbZoneOverlay(ctx: ExtensionContext, details: string): Promise<void> {
  if (overlayActive) return;
  overlayActive = true;

  try {
    await ctx.ui.custom<void>(
      (_tui, theme, _keybindings, done) => {
        let closed = false;
        const close = () => {
          if (closed) return;
          closed = true;
          done(undefined);
        };

        return new DumbZoneOverlay(theme, details, close);
      },
      {
        overlay: true,
        overlayOptions: {
          width: "60%",
          minWidth: 40,
          maxHeight: 7,
          anchor: "center",
        },
      }
    );
  } finally {
    overlayActive = false;
  }
}

class DumbZoneOverlay {
  constructor(
    private readonly theme: Theme,
    private readonly details: string,
    private readonly onClose: () => void
  ) {}

  handleInput(_data: string): void {
    this.onClose();
  }

  render(width: number): string[] {
    const box = createThemedBoxRenderer(width, this.theme);

    const title = truncateToWidth(DUMB_ZONE_MESSAGE, box.innerWidth, "");
    const styledTitle = this.theme.fg("error", this.theme.bold(title));

    const detailsText = truncateToWidth(this.details, box.innerWidth, "");
    const styledDetails = this.theme.fg("warning", detailsText);

    return [
      box.top(),
      box.centeredRow(styledTitle),
      box.empty(),
      box.centeredRow(styledDetails),
      box.empty(),
      box.bottom(),
    ];
  }

  invalidate(): void {}
}
