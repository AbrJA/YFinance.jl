# ─────────────────────────────────────────────────────────────────────────────
# cookie_and_crumb.jl — Backward-compatible session management API
# All state now lives in _SESSION (network.jl). These functions provide the
# public/exported interface and backward compat for existing user code.
# ─────────────────────────────────────────────────────────────────────────────

"""
    _rand_header()

Chooses a random browser header from the HEADERS pool.
"""
_rand_header() = rand(HEADERS)

"""
    get_cookie()

Retrieves cookies from Yahoo Finance. Returns a Dict{String,String}.
"""
function get_cookie()
    _ensure_session!()
    return copy(_SESSION.cookie)
end

"""
    get_crumb()

Returns the current session crumb. Initializes the session if needed.
"""
function get_crumb()
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

Ensures the session is initialized (cookie + crumb are available).
Thread-safe and idempotent — safe to call from any endpoint.
"""
_set_cookies_and_crumb() = _ensure_session!()

# Legacy global access (for backward compat with user code that reads these)
# These are now computed properties backed by _SESSION

"""
    _COOKIE

Returns the current session cookie dict. (Backward-compatible accessor)
"""
macro _get_cookie()
    return :(_SESSION.cookie)
end

