# ─────────────────────────────────────────────────────────────────────────────
# network.jl — Core networking layer for YFinance.jl
# Session management, HTTP requests, cookie/crumb, rate limiting, connection pooling
# ─────────────────────────────────────────────────────────────────────────────

const _BASE_URL = "https://query2.finance.yahoo.com"

# ─── URL Encoding ─────────────────────────────────────────────────────────────

const _SAFE_URI_CHARS = Set{Char}(vcat(
    collect('A':'Z'), collect('a':'z'), collect('0':'9'),
    ['-', '.', '_', '~']
))

function _uri_encode(s::AbstractString)::String
    io = IOBuffer(sizehint=ncodeunits(s))
    for c in s
        if c in _SAFE_URI_CHARS
            write(io, c)
        else
            for byte in codeunits(string(c))
                write(io, '%', uppercase(string(byte; base=16, pad=2)))
            end
        end
    end
    return String(take!(io))
end

function _build_query_string(params)::String
    parts = String[]
    for (k, v) in params
        sv = string(v)
        isempty(sv) && continue
        push!(parts, "$(_uri_encode(string(k)))=$(_uri_encode(sv))")
    end
    return join(parts, '&')
end

function _build_url(base::AbstractString, params)::String
    qs = _build_query_string(params)
    return isempty(qs) ? String(base) : "$base?$qs"
end

# ─── Yahoo Session ────────────────────────────────────────────────────────────

mutable struct YahooSession
    cookie::Dict{String,String}
    crumb::String
    header::Dict{String,String}
    proxy::Union{Nothing,String}
    proxy_auth::Dict{String,String}
    last_request_time::Float64
    const min_request_interval::Float64
    const max_retries::Int
    const retry_base_delay::Float64
    downloader::Union{Nothing,Downloads.Downloader}
    initialized::Bool
    const lock::ReentrantLock
end

function YahooSession(;
    min_request_interval::Float64=0.3,
    max_retries::Int=3,
    retry_base_delay::Float64=1.5
)
    return YahooSession(
        Dict{String,String}(), "", Dict{String,String}(),
        nothing, Dict{String,String}(),
        0.0, min_request_interval, max_retries, retry_base_delay,
        nothing, false, ReentrantLock()
    )
end

const _SESSION = YahooSession()

# ─── Connection Pooling ───────────────────────────────────────────────────────

function _get_downloader()::Downloads.Downloader
    if isnothing(_SESSION.downloader)
        _SESSION.downloader = Downloads.Downloader()
    end
    return _SESSION.downloader
end

# ─── Session Management ───────────────────────────────────────────────────────

function _ensure_session!()
    lock(_SESSION.lock) do
        if !_SESSION.initialized
            _SESSION.header = rand(HEADERS)
            _fetch_cookie!()
            _fetch_crumb!()
            _SESSION.initialized = true
        end
    end
    return nothing
end

function _renew_session!()
    lock(_SESSION.lock) do
        _SESSION.header = rand(HEADERS)
        _fetch_cookie!()
        _fetch_crumb!()
        _SESSION.initialized = true
    end
    return nothing
end

function _fetch_cookie!()
    headers = _build_headers(Dict{String,String}())
    resp = _raw_request("https://fc.yahoo.com"; headers=headers, timeout=10, throw_on_error=false)
    _SESSION.cookie = _parse_set_cookie(resp.headers)
end

function _fetch_crumb!()
    headers = _build_headers(_SESSION.cookie)
    resp = _raw_request("$(_BASE_URL)/v1/test/getcrumb"; headers=headers, timeout=10, throw_on_error=false)
    _SESSION.crumb = String(resp.body)
end

# ─── Header Building ─────────────────────────────────────────────────────────

function _build_headers(cookies::Dict{String,String})::Vector{Pair{String,String}}
    headers = Pair{String,String}[]
    sizehint!(headers, 12)
    for (k, v) in _SESSION.header
        lowercase(k) == "accept-encoding" && continue
        push!(headers, k => v)
    end
    push!(headers, "Accept-Encoding" => "identity")
    for (k, v) in _SESSION.proxy_auth
        push!(headers, k => v)
    end
    if !isempty(cookies)
        cookie_str = join(("$k=$v" for (k, v) in cookies), "; ")
        push!(headers, "Cookie" => cookie_str)
    end
    return headers
end

# ─── Cookie Parsing ───────────────────────────────────────────────────────────

function _parse_set_cookie(headers::Vector)::Dict{String,String}
    cookies = Dict{String,String}()
    for (name, value) in headers
        if lowercase(name) == "set-cookie"
            cookie_part = first(split(value, ';'))
            eq_pos = findfirst('=', cookie_part)
            if !isnothing(eq_pos)
                cname = strip(String(cookie_part[1:eq_pos-1]))
                cvalue = strip(String(cookie_part[eq_pos+1:end]))
                cookies[cname] = cvalue
            end
        end
    end
    return cookies
end

# ─── Rate Limiting ────────────────────────────────────────────────────────────

function _throttle!()
    elapsed = time() - _SESSION.last_request_time
    remaining = _SESSION.min_request_interval - elapsed
    if remaining > 0.0
        sleep(remaining)
    end
    _SESSION.last_request_time = time()
    return nothing
end

# ─── Raw Request ──────────────────────────────────────────────────────────────

function _raw_request(url::AbstractString;
    headers::Vector{Pair{String,String}}=Pair{String,String}[],
    timeout::Real=10,
    throw_on_error::Bool=true
)
    output = IOBuffer()
    downloader = _get_downloader()
    resp = Downloads.request(url;
        method="GET", headers=headers, output=output,
        timeout=Float64(timeout), downloader=downloader, throw=false
    )
    body = take!(output)
    resp_status = resp.status
    resp_headers = Pair{String,String}[String(k) => String(v) for (k, v) in resp.headers]

    if throw_on_error && resp_status >= 400
        throw(YFinanceError("", "HTTP request failed", resp_status))
    end

    return (status=resp_status, body=body, headers=resp_headers)
end

# ─── High-Level Request with Retry ───────────────────────────────────────────

function _yahoo_request(url::AbstractString, symbol::String; timeout::Int=10)
    _ensure_session!()
    headers = _build_headers(_SESSION.cookie)

    for attempt in 1:_SESSION.max_retries
        _throttle!()
        resp = _raw_request(url; headers=headers, timeout=timeout, throw_on_error=false)

        if resp.status == 200
            return resp
        elseif resp.status in (401, 403)
            _renew_session!()
            headers = _build_headers(_SESSION.cookie)
        elseif resp.status == 429
            delay = _SESSION.retry_base_delay * (2^(attempt - 1))
            sleep(delay)
        else
            throw(YFinanceError(symbol, "Request failed: HTTP $(resp.status)", resp.status))
        end
    end

    throw(YFinanceError(symbol, "Request failed after $(_SESSION.max_retries) retries", nothing))
end
