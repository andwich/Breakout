extends Node


# Workspace surfaces
const BACKGROUND := Color("#0B0D12")
const SURFACE := Color("#121722")
const SURFACE_ELEVATED := Color("#1A2130")
const BORDER_SUBTLE := Color("#2B3445")
const BORDER_STRONG := Color("#44516A")

# Typography and semantic state
const TEXT_PRIMARY := Color("#E7EDF7")
const TEXT_MUTED := Color("#93A1B5")
const ACCENT := Color("#78A9FF")
const SUCCESS := Color("#67D49B")
const WARNING := Color("#F2C66D")
const DANGER := Color("#F17B7B")
const INFO := Color("#85B8FF")

# Gameplay material roles
const BRICK_STANDARD := Color("#334155")
const BRICK_DURABLE := Color("#52627A")
const BRICK_BOSS := Color("#865E9C")
const BALL := Color("#F4F7FB")
const PADDLE := ACCENT
const PADDLE_STICKY := WARNING
const PADDLE_WIDE := SUCCESS

# Spacing and panel layout
const PANEL_RADIUS := 8
const PANEL_MARGIN := Vector2i(12, 8)

# Temporary compatibility aliases: remove only after all consumers migrate.
const NEON_BG := BACKGROUND
const NEON_CYAN := ACCENT
const NEON_MAGENTA := INFO
const NEON_LIME := SUCCESS
const NEON_YELLOW := WARNING
const NEON_RED := DANGER
const NEON_PURPLE := BRICK_BOSS
