"""Store requirements the factory checks against.

Sources (checked 2026-10): Google Play Console help "Add preview assets to
showcase your app" and "Create and set up your app"; Apple App Store Connect
help "Screenshot specifications" and "App information". When a store changes a
rule, change it here and nowhere else.
"""

# Text limits, in characters (App Store keywords are counted in bytes).
PLAY_TEXT = {
    "title": 30,
    "short_description": 80,
    "full_description": 4000,
}
APPSTORE_TEXT = {
    "name": 30,
    "subtitle": 30,
    "promotional_text": 170,
    "description": 4000,
    "keywords": 100,  # bytes, comma separated
}

# Images: (width, height)
PLAY_ICON = (512, 512)  # 32-bit PNG, alpha allowed, max 1 MB
PLAY_ICON_MAX_BYTES = 1024 * 1024
PLAY_FEATURE_GRAPHIC = (1024, 500)  # JPEG or 24-bit PNG, no alpha
PLAY_SCREENSHOTS_MIN, PLAY_SCREENSHOTS_MAX = 2, 8
PLAY_SCREENSHOT_SIDE_MIN, PLAY_SCREENSHOT_SIDE_MAX = 320, 3840
PLAY_SCREENSHOT = (1080, 1920)  # 9:16, eligible for promotion (>=1080 px)

APPSTORE_ICON = (1024, 1024)  # PNG, no alpha, no rounded corners
APPSTORE_SCREENSHOTS_MIN, APPSTORE_SCREENSHOTS_MAX = 1, 10
# Sizes we produce. Each is one of Apple's accepted portrait sizes.
APPSTORE_IPHONE_69 = (1320, 2868)  # 6.9" display, the required iPhone set
APPSTORE_IPAD_13 = (2064, 2752)  # 13" display, required when iPad is supported
APPSTORE_IPHONE_ACCEPTED = {(1320, 2868), (1290, 2796), (1260, 2736)}
APPSTORE_IPAD_ACCEPTED = {(2064, 2752), (2048, 2732)}

SCREENSHOT_SETS = {
    "play/phone": PLAY_SCREENSHOT,
    "appstore/iphone-6.9": APPSTORE_IPHONE_69,
}
# Apps are built iPhone-only (TARGETED_DEVICE_FAMILY = 1), so App Store Connect
# asks for no iPad screenshots. iPad users can still run the iPhone app.

PLACEHOLDER_WORDS = ("lorem ipsum", "placeholder", "tbd", "todo", "fixme", "your app name", "example.com")
