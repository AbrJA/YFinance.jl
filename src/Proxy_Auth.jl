# ─────────────────────────────────────────────────────────────────────────────
# Proxy_Auth.jl — Proxy configuration (backed by _SESSION)
# ─────────────────────────────────────────────────────────────────────────────

"""
    set_proxy!(proxy::AbstractString, user=nothing, password=nothing)

Configure proxy settings for all Yahoo Finance requests.

# Arguments
- `proxy::String` — Proxy URL (e.g., "http://proxy.example.com:8080")
- `user::String` — Username for authenticated proxies (optional)
- `password::String` — Password for authenticated proxies (optional)
"""
function set_proxy!(proxy::AbstractString, user=nothing, password=nothing)
    lock(_SESSION.lock) do
        _SESSION.proxy = String(proxy)
        if isnothing(user) || isnothing(password)
            _SESSION.proxy_auth = Dict{String,String}()
        else
            encoded = Base64.base64encode(string(user) * ":" * string(password))
            _SESSION.proxy_auth = Dict{String,String}("Proxy-Authorization" => "Basic $encoded")
        end
        # Force session renewal with new proxy settings
        _SESSION.initialized = false
    end
    return nothing
end

"""
    clear_proxy!()

Clear proxy configuration, reverting to direct connections.
"""
function clear_proxy!()
    lock(_SESSION.lock) do
        _SESSION.proxy = nothing
        _SESSION.proxy_auth = Dict{String,String}()
        _SESSION.initialized = false
    end
    return nothing
end
