# ─────────────────────────────────────────────────────────────────────────────
# Proxy_Auth.jl — Proxy configuration (backed by _SESSION)
# ─────────────────────────────────────────────────────────────────────────────

# Legacy compat — existing code may reference _PROXY_SETTINGS
_PROXY_SETTINGS = (;proxy = nothing, auth = Dict())

"""
    create_proxy_settings(p::AbstractString, user=nothing, password=nothing)

Configures proxy settings for all Yahoo Finance requests.

## Arguments
 * `p::String` (Required) — proxy URL, e.g. "http://proxy.xyz.com:8080"
 * `user::String` — username (optional, for authenticated proxies)
 * `password::String` — password (optional, for authenticated proxies)
"""
function create_proxy_settings(p::AbstractString, user=nothing, password=nothing)
    lock(_SESSION.lock) do
        _SESSION.proxy = p
        if isnothing(user) || isnothing(password)
            _SESSION.proxy_auth = Dict{String,String}()
        else
            _SESSION.proxy_auth = Dict("Proxy-Authorization" => "Basic " * Base64.base64encode(user * ":" * password))
        end
        # Update legacy global for backward compat
        global _PROXY_SETTINGS = (;proxy=_SESSION.proxy, auth=_SESSION.proxy_auth)
        # Force session renewal with new proxy
        _SESSION.initialized = false
    end
    return nothing
end

"""
    clear_proxy_settings()

Clears proxy configuration, reverting to direct connections.
"""
function clear_proxy_settings()
    lock(_SESSION.lock) do
        _SESSION.proxy = nothing
        _SESSION.proxy_auth = Dict{String,String}()
        global _PROXY_SETTINGS = (;proxy = nothing, auth = Dict())
        _SESSION.initialized = false
    end
    return nothing
end

