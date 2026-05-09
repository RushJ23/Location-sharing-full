# build_prod.ps1 — Build production Android App Bundle (and optionally iOS IPA) on Windows.
# Secrets are injected via --dart-define so they are compiled in and never bundled as a readable asset.
# NOTE: iOS builds require macOS with Xcode; that step is skipped automatically on Windows.
#
# Usage (PowerShell):
#   $env:SUPABASE_URL      = "https://your-project-ref.supabase.co"
#   $env:SUPABASE_ANON_KEY = "your-supabase-anon-key-here"
#   $env:GOOGLE_MAPS_API_KEY = "your-google-maps-api-key-here"
#   .\build_prod.ps1

$ErrorActionPreference = "Stop"

# ── Validate required environment variables ───────────────────────────────────

if (-not $env:SUPABASE_URL) {
    Write-Error "ERROR: SUPABASE_URL is not set.`n  `$env:SUPABASE_URL = 'https://your-project-ref.supabase.co'"
    exit 1
}

if (-not $env:SUPABASE_ANON_KEY) {
    Write-Error "ERROR: SUPABASE_ANON_KEY is not set.`n  `$env:SUPABASE_ANON_KEY = 'your-supabase-anon-key-here'"
    exit 1
}

if (-not $env:GOOGLE_MAPS_API_KEY) {
    Write-Error "ERROR: GOOGLE_MAPS_API_KEY is not set.`n  `$env:GOOGLE_MAPS_API_KEY = 'your-google-maps-api-key-here'"
    exit 1
}

# ── Android Build ─────────────────────────────────────────────────────────────

Write-Host "Building production Android App Bundle..."

flutter build appbundle --release `
    "--dart-define=SUPABASE_URL=$env:SUPABASE_URL" `
    "--dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY" `
    "--dart-define=GOOGLE_MAPS_API_KEY=$env:GOOGLE_MAPS_API_KEY"

Write-Host ""
Write-Host "Android build succeeded."
Write-Host "Output: build\app\outputs\bundle\release\app-release.aab"

# ── iOS Build (macOS only) ────────────────────────────────────────────────────

if ($IsWindows -or ($env:OS -eq "Windows_NT")) {
    Write-Host ""
    Write-Host "Skipping iOS build — iOS builds require macOS with Xcode."
    Write-Host "Run build_prod_ios.sh on a Mac to produce the IPA."
} else {
    Write-Host ""
    Write-Host "Building production iOS IPA..."

    flutter build ipa --release `
        "--dart-define=SUPABASE_URL=$env:SUPABASE_URL" `
        "--dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY" `
        "--dart-define=GOOGLE_MAPS_API_KEY=$env:GOOGLE_MAPS_API_KEY"

    Write-Host ""
    Write-Host "iOS build succeeded."
    Write-Host "Output: build/ios/ipa/*.ipa"
}
