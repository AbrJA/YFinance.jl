# ─────────────────────────────────────────────────────────────────────────────
# cookie_and_crumb.jl — Backward-compatible session management API
# All state lives in _SESSION (network.jl). These provide the public interface.
# ─────────────────────────────────────────────────────────────────────────────

"""
    _rand_header() -> Dict{String,String}

Selects a random browser header from the HEADERS pool.
"""
_rand_header()::Dict{String,String} = rand(HEADERS)

"""
    get_cookie() -> Dict{String,String}

Returns a copy of the current session cookies. Initializes session if needed.
"""
function get_cookie()::Dict{String,String}
    _ensure_session!()
    return copy(_SESSION.cookie)
end

"""
    get_crumb() -> String

Returns the current session crumb. Initializes the session if needed.
"""
function get_crumb()::String
    _ensure_session!()
    return _SESSION.crumb
end

"""
    _renew_cookies_and_crumb()

Forces a fresh cookie+crumb fetch.
"""
_renew_cookies_and_crumb() = _renew_session!()

"""
    _set_cookies_and_crumb()

Ensures the session is initialized. Thread-safe and idempotent.
"""
_set_cookies_and_crumb() = _ensure_session!()
