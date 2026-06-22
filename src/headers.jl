# ─────────────────────────────────────────────────────────────────────────────
# headers.jl — Dynamic browser header generation
# Generates realistic browser headers from combinatorial parts.
# Produces unique headers per request to avoid fingerprint-based blocking.
# ─────────────────────────────────────────────────────────────────────────────

# ─── Component Data ───────────────────────────────────────────────────────────

const _BROWSERS = (
    # (brand, ua_template, sec_ch_ua_template, platform, os_string)
    (brand=:chrome, platforms=("Windows", "macOS", "X11")),
    (brand=:edge,   platforms=("Windows",)),
    (brand=:firefox, platforms=("Windows", "macOS", "X11")),
)

const _CHROME_VERSIONS = (120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130)
const _EDGE_VERSIONS = (120, 121, 122, 123, 124, 125, 126, 127, 128)
const _FIREFOX_VERSIONS = (115, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130)

const _OS_STRINGS = Dict(
    "Windows" => ("Windows NT 10.0; Win64; x64", "Windows NT 11.0; Win64; x64"),
    "macOS"   => ("Macintosh; Intel Mac OS X 10_15_7", "Macintosh; Intel Mac OS X 14_5"),
    "X11"     => ("X11; Linux x86_64", "X11; Ubuntu; Linux x86_64"),
)

const _ACCEPT_LANGUAGES = (
    "en-US,en;q=0.9",
    "en-US,en;q=0.9,es;q=0.8",
    "en-GB,en;q=0.9",
    "en-US,en;q=0.8",
    "en-US,es;q=0.6",
    "en-CA,en;q=0.9",
    "en-AU,en;q=0.9",
)

const _ACCEPT_ENCODINGS = ("gzip", "gzip, deflate", "gzip, deflate, br")

# ─── Header Builder ───────────────────────────────────────────────────────────

"""
    _random_header() -> Dict{String,String}

Generate a random but realistic browser header dictionary.
Uses combinatorial parts to produce thousands of unique profiles.
"""
function _random_header()::Dict{String,String}
    browser = rand((:chrome, :edge, :firefox))
    lang = rand(_ACCEPT_LANGUAGES)
    encoding = rand(_ACCEPT_ENCODINGS)

    if browser === :chrome
        ver = rand(_CHROME_VERSIONS)
        platform = rand(("Windows", "macOS", "X11"))
        os = rand(_OS_STRINGS[platform])
        ua = "Mozilla/5.0 ($os) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$ver.0.0.0 Safari/537.36"
        sec_ch = "\"Google Chrome\";v=\"$ver\", \"Chromium\";v=\"$ver\", \"Not_A Brand\";v=\"24\""
        return Dict{String,String}(
            "User-Agent" => ua,
            "accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
            "accept-encoding" => encoding,
            "accept-language" => lang,
            "sec-ch-ua" => sec_ch,
            "sec-ch-ua-mobile" => "?0",
            "sec-ch-ua-platform" => "\"$platform\"",
            "sec-fetch-dest" => "document",
            "sec-fetch-mode" => "navigate",
            "sec-fetch-site" => "none",
            "sec-fetch-user" => "?1",
            "upgrade-insecure-requests" => "1",
        )
    elseif browser === :edge
        ver = rand(_EDGE_VERSIONS)
        os = rand(_OS_STRINGS["Windows"])
        ua = "Mozilla/5.0 ($os) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$ver.0.0.0 Safari/537.36 Edg/$ver.0.0.0"
        sec_ch = "\"Microsoft Edge\";v=\"$ver\", \"Chromium\";v=\"$ver\", \"Not_A Brand\";v=\"24\""
        return Dict{String,String}(
            "User-Agent" => ua,
            "accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8",
            "accept-encoding" => encoding,
            "accept-language" => lang,
            "sec-ch-ua" => sec_ch,
            "sec-ch-ua-mobile" => "?0",
            "sec-ch-ua-platform" => "\"Windows\"",
            "sec-fetch-dest" => "document",
            "sec-fetch-mode" => "navigate",
            "sec-fetch-site" => "none",
            "sec-fetch-user" => "?1",
            "upgrade-insecure-requests" => "1",
        )
    else  # firefox
        ver = rand(_FIREFOX_VERSIONS)
        platform = rand(("Windows", "macOS", "X11"))
        os = rand(_OS_STRINGS[platform])
        ua = "Mozilla/5.0 ($os; rv:$ver.0) Gecko/20100101 Firefox/$ver.0"
        return Dict{String,String}(
            "User-Agent" => ua,
            "accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "accept-encoding" => encoding,
            "accept-language" => lang,
            "sec-fetch-dest" => "document",
            "sec-fetch-mode" => "navigate",
            "sec-fetch-site" => "none",
            "sec-fetch-user" => "?1",
            "upgrade-insecure-requests" => "1",
        )
    end
end
