extends Node


# Playfield and chrome
const BACKGROUND := Color("#03050B")
const SURFACE := Color("#070B14")
const SURFACE_ELEVATED := Color("#0A1020")
const BORDER_SUBTLE := Color("#00C9E8", 0.38)
const BORDER_STRONG := Color("#00E5FF", 0.85)

# HUD and state roles
const TEXT_PRIMARY := Color("#F7FBFF")
const TEXT_MUTED := Color("#7F91AD")
const ACCENT := Color("#00E5FF")      # Score / normal paddle / cyan bricks
const SUCCESS := Color("#00F07A")     # GO / wide paddle / green bricks
const WARNING := Color("#FFD400")     # Level / transitions / yellow bricks
const DANGER := Color("#FF167F")      # Lives / hazards / pink bricks
const INFO := Color("#189CFF")        # Blue bricks and utility indicators

# Gameplay material roles
const BRICK_STANDARD := ACCENT
const BRICK_DURABLE := Color("#FF7A00")
const BRICK_BOSS := Color("#FF167F")
const BALL := Color("#FFFFFF")
const PADDLE := ACCENT
const PADDLE_STICKY := WARNING
const PADDLE_WIDE := SUCCESS

# Typography and layout
const HUD_FONT_SIZE := 22
const CALLOUT_FONT_SIZE := 76
const PANEL_RADIUS := 0
const PANEL_MARGIN := Vector2i(18, 12)

# Temporary compatibility aliases: remove only after all consumers migrate.
const NEON_BG := BACKGROUND
const NEON_CYAN := ACCENT
const NEON_MAGENTA := INFO
const NEON_LIME := SUCCESS
const NEON_YELLOW := WARNING
const NEON_RED := DANGER
const NEON_PURPLE := BRICK_BOSS
