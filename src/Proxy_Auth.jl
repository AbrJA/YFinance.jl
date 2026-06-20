# ─────────────────────────────────────────────────────────────────────────────
# Proxy_Auth.jl — Proxy configuration (backed by _SESSION)
# ─────────────────────────────────────────────────────────────────────────────

# Legacy compat struct — existing user code may reference _PROXY_SETTINGS
_PROXY_SETTINGS = (proxy=nothing, auth=Dict{String,String}())

"""
    create_proxy_settings(proxy::AbstractString, user=nothing, password=nothing)

Configure proxy settings for all Yahoo Finance requests.

# Arguments
- `proxy::String` — Proxy URL (e.g., "http://proxy.example.com:8080")
- `user::String` — Username for authenticated proxies (optional)
- `password::String` — Password for authenticated proxies (optional)
"""
function create_proxy_settings(proxy::AbstractString, user=nothing, password=nothing)
    lock(_SESSION.lock) do
        _SESSION.proxy = String(proxy)
        if isnothing(user) || isnothing(password)
            _SESSION.proxy_auth = Dict{String,String}()
        else
            encoded = Base64.base64encode(string(user) * ":" * string(password))
            _SESSION.proxy_auth = Dict{String,String}("Proxy-Authorization" => "Basic $encoded")
        end
        # Update legacy global for backward compat
        global _PROXY_SETTINGS = (proxy=_SESSION.proxy, auth=_SESSION.proxy_auth)
        # Force session renewal with new proxy settings
        _SESSION.initialized = false
    end
    return nothing
end

"""
    clear_proxy_settings()

Clear proxy configuration, reverting to direct connections.
"""
function clear_proxy_settings()
    lock(_SESSION.lock) do
        _SESSION.proxy = nothing
        _SESSION.proxy_auth = Dict{String,String}()
        global _PROXY_SETTINGS = (proxy=nothing, auth=Dict{String,String}())
        _SESSION.initialized = false
    end
    return nothing
end
