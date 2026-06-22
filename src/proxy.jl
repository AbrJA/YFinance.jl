# ─────────────────────────────────────────────────────────────────────────────
# proxy.jl — Proxy configuration
# ─────────────────────────────────────────────────────────────────────────────

"""
    set_proxy!(url, user=nothing, password=nothing)

Configure HTTP proxy for all Yahoo Finance requests.

# Arguments
- `url::String` — Proxy URL (e.g. "http://proxy.example.com:8080")
- `user` — Username for authenticated proxies (optional)
- `password` — Password for authenticated proxies (optional)
"""
function set_proxy!(url::AbstractString, user=nothing, password=nothing)
    lock(_SESSION.lock) do
        _SESSION.proxy = String(url)
        if isnothing(user) || isnothing(password)
            _SESSION.proxy_auth = Dict{String,String}()
        else
            encoded = base64encode(string(user) * ":" * string(password))
            _SESSION.proxy_auth = Dict{String,String}("Proxy-Authorization" => "Basic $encoded")
        end
        _SESSION.initialized = false
    end
    return nothing
end

"""
    clear_proxy!()

Remove proxy configuration, revert to direct connections.
"""
function clear_proxy!()
    lock(_SESSION.lock) do
        _SESSION.proxy = nothing
        _SESSION.proxy_auth = Dict{String,String}()
        _SESSION.initialized = false
    end
    return nothing
end
