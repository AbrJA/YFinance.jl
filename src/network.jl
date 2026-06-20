# ─────────────────────────────────────────────────────────────────────────────
# network.jl — Core networking layer for YFinance.jl
# Provides: YahooSession, rate-limited requests, retry logic, URL building,
#           connection pooling via persistent Downloader
# ─────────────────────────────────────────────────────────────────────────────

# ─── URL Encoding ─────────────────────────────────────────────────────────────

const _SAFE_URI_CHARS = Set{Char}(vcat(
    collect('A':'Z'), collect('a':'z'), collect('0':'9'),
    ['-', '.', '_', '~']
))

"""
    _uri_encode(s::AbstractString) -> String

Percent-encode a string for use in URLs (RFC 3986).
"""
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

"""
    _build_query_string(params) -> String

Build a URL query string from key-value pairs. Skips empty string values.
"""
function _build_query_string(params)::String
    parts = String[]
    for (k, v) in params
        sv = string(v)
        isempty(sv) && continue
        push!(parts, "$(_uri_encode(string(k)))=$(_uri_encode(sv))")
    end
    return join(parts, '&')
end

"""
    _build_url(base::AbstractString, params) -> String

Append query parameters to a base URL.
"""
function _build_url(base::AbstractString, params)::String
    qs = _build_query_string(params)
    return isempty(qs) ? String(base) : "$base?$qs"
end

# ─── Response Error Type ──────────────────────────────────────────────────────

"""
    ResponseError <: Exception

Represents an HTTP error response from the Yahoo Finance API.
"""
struct ResponseError <: Exception
    status::Int
    body::Vector{UInt8}
end

function Base.showerror(io::IO, e::ResponseError)
    print(io, "ResponseError: HTTP ", e.status)
    if !isempty(e.body)
        text = String(copy(e.body))
        if length(text) > 200
            text = text[1:200] * "…"
        end
        print(io, " — ", text)
    end
end

# ─── Yahoo Session (singleton, thread-safe) ───────────────────────────────────

"""
    YahooSession

Holds authentication state (cookie, crumb), rate-limiting configuration,
and a persistent `Downloads.Downloader` for connection reuse.
Thread-safe via `ReentrantLock`.
"""
mutable struct YahooSession
    # Auth state
    cookie::Dict{String,String}
    crumb::String
    header::Dict{String,String}

    # Proxy config
    proxy::Union{Nothing,String}
    proxy_auth::Dict{String,String}

    # Rate limiting
    last_request_time::Float64
    const min_request_interval::Float64  # seconds between requests
    const max_retries::Int
    const retry_base_delay::Float64      # base delay for exponential backoff

    # Connection pooling
    downloader::Union{Nothing,Downloads.Downloader}

    # State
    initialized::Bool
    const lock::ReentrantLock
end

function YahooSession(;
    min_request_interval::Float64=0.3,
    max_retries::Int=3,
    retry_base_delay::Float64=1.5
)
    return YahooSession(
        Dict{String,String}(),   # cookie
        "",                       # crumb
        Dict{String,String}(),   # header
        nothing,                  # proxy
        Dict{String,String}(),   # proxy_auth
        0.0,                      # last_request_time
        min_request_interval,
        max_retries,
        retry_base_delay,
        nothing,                  # downloader (lazy init)
        false,                    # initialized
        ReentrantLock()
    )
end

"""Global singleton session — all requests go through this."""
const _SESSION = YahooSession()

# ─── Connection Pooling ───────────────────────────────────────────────────────

"""
    _get_downloader() -> Downloads.Downloader

Returns the persistent Downloader instance (connection pool).
Creates one on first use.
"""
function _get_downloader()::Downloads.Downloader
    if isnothing(_SESSION.downloader)
        _SESSION.downloader = Downloads.Downloader()
    end
    return _SESSION.downloader
end

# ─── Session Management ───────────────────────────────────────────────────────

"""
    _ensure_session!()

Thread-safe initialization of the Yahoo session (cookie + crumb).
Only fetches if not already initialized.
"""
function _ensure_session!()
    lock(_SESSION.lock) do
        if !_SESSION.initialized
            _SESSION.header = _rand_header()
            _fetch_cookie!()
            _fetch_crumb!()
            _SESSION.initialized = true
        end
    end
    return nothing
end

"""
    _renew_session!()

Forces a fresh cookie+crumb fetch regardless of current state.
Call when receiving 401/403 responses.
"""
function _renew_session!()
    lock(_SESSION.lock) do
        _SESSION.header = _rand_header()
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
    resp = _raw_request("https://query2.finance.yahoo.com/v1/test/getcrumb"; headers=headers, timeout=10, throw_on_error=false)
    _SESSION.crumb = String(resp.body)
    if isempty(_SESSION.crumb)
        @warn "Crumb could not be retrieved. Certain data items will not be available!"
    end
end

# ─── Header Building ─────────────────────────────────────────────────────────

function _build_headers(cookies::Dict{String,String})::Vector{Pair{String,String}}
    headers = Pair{String,String}[]
    sizehint!(headers, 12)

    # Browser headers (override accept-encoding to avoid gzip issues)
    for (k, v) in _SESSION.header
        lowercase(k) == "accept-encoding" && continue
        push!(headers, k => v)
    end
    push!(headers, "Accept-Encoding" => "identity")

    # Proxy auth headers
    for (k, v) in _SESSION.proxy_auth
        push!(headers, k => v)
    end

    # Cookies
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

"""
    _throttle!()

Enforces minimum interval between requests.
"""
function _throttle!()
    elapsed = time() - _SESSION.last_request_time
    remaining = _SESSION.min_request_interval - elapsed
    if remaining > 0.0
        sleep(remaining)
    end
    _SESSION.last_request_time = time()
    return nothing
end

# ─── Raw Request (no retry, no rate limit) ────────────────────────────────────

"""
    _raw_request(url; headers, timeout, throw_on_error) -> NamedTuple

Low-level GET request using the persistent Downloader. No retry or rate limiting.
"""
function _raw_request(url::AbstractString;
    headers::Vector{Pair{String,String}}=Pair{String,String}[],
    timeout::Real=10,
    throw_on_error::Bool=true
)
    output = IOBuffer()
    downloader = _get_downloader()

    resp = Downloads.request(url;
        method="GET",
        headers=headers,
        output=output,
        timeout=Float64(timeout),
        downloader=downloader,
        throw=false
    )

    body = take!(output)
    resp_status = resp.status
    resp_headers = Pair{String,String}[String(k) => String(v) for (k, v) in resp.headers]

    if throw_on_error && resp_status >= 400
        throw(ResponseError(resp_status, body))
    end

    return (status=resp_status, body=body, headers=resp_headers)
end

# ─── Main Request Function (rate-limited + retry) ─────────────────────────────

"""
    _request(url; timeout=10, throw_on_error=true) -> NamedTuple

Makes a rate-limited, retrying GET request using the current session.
- Throttles to respect `min_request_interval`
- Retries on 429 with exponential backoff
- Renews session on 401/403 before retrying
- Retries on transient network errors
"""
function _request(url::AbstractString; timeout::Real=10, throw_on_error::Bool=true)
    _ensure_session!()
    headers = _build_headers(_SESSION.cookie)

    for attempt in 1:_SESSION.max_retries
        _throttle!()

        try
            return _raw_request(url; headers=headers, timeout=timeout, throw_on_error=throw_on_error)
        catch e
            is_last = attempt == _SESSION.max_retries

            if !(e isa ResponseError)
                # Network/timeout error — retry with backoff
                is_last && rethrow()
                sleep(_SESSION.retry_base_delay * 2^(attempt - 1))
                continue
            end

            if e.status == 429
                # Rate limited — exponential backoff
                is_last && rethrow()
                sleep(_SESSION.retry_base_delay * 2^(attempt - 1))
                continue
            elseif e.status in (401, 403)
                # Auth expired — renew and retry
                is_last && rethrow()
                _renew_session!()
                headers = _build_headers(_SESSION.cookie)
                continue
            else
                # Other HTTP error — don't retry
                rethrow()
            end
        end
    end

    # Unreachable, but satisfies the compiler
    error("Request failed after $(_SESSION.max_retries) attempts: $url")
end

# ─── Yahoo Error Parsing ──────────────────────────────────────────────────────

"""
    _parse_yahoo_error(body, status, symbol) -> String

Parses Yahoo Finance error response bodies. Handles both JSON and plain-text.
"""
function _parse_yahoo_error(body::Vector{UInt8}, status::Int, symbol::String="")::String
    try
        yahoo_error = JSON3.read(body)
        if haskey(yahoo_error, :finance)
            return string(yahoo_error.finance.error.description)
        elseif haskey(yahoo_error, :chart) && haskey(yahoo_error.chart, :error)
            desc = string(yahoo_error.chart.error.description)
            date_matches = collect(eachmatch(r"(-)?[0-9]{1,}", desc))
            if length(date_matches) >= 2
                error_dates = unix2datetime.(parse.(Float64, [m.match for m in date_matches[1:2]]))
                return "Data doesn't exist for startDate = $(error_dates[1]), endDate = $(error_dates[2]) for $symbol"
            end
            return desc
        else
            return "HTTP error $status for $symbol"
        end
    catch
        text = String(copy(body))
        return isempty(text) ? "HTTP error $status for $symbol" : strip(text)
    end
end

# ─── Backward-compatible API ──────────────────────────────────────────────────

function _make_headers(; extra_headers::Dict=Dict{String,String}(), cookies::Dict=Dict{String,String}(), use_random_header::Bool=true)
    _ensure_session!()
    return _build_headers(cookies)
end

# ─── High-level Yahoo Request ─────────────────────────────────────────────────

"""
    _yahoo_get(url, symbol; timeout=10, throw_error=false, empty_result=nothing)

Standard pattern for all Yahoo Finance GET requests.
Returns the response NamedTuple on success, or `nothing` on failure (when `throw_error=false`).
"""
function _yahoo_get(url::AbstractString, symbol::String=""; timeout::Real=10, throw_error::Bool=false, empty_result=nothing)
    try
        return _request(url; timeout=timeout)
    catch e
        msg = if e isa ResponseError
            if e.status == 404
                "$symbol is not a valid symbol."
            elseif e.status == 429
                "Rate limit exceeded for $symbol after $(_SESSION.max_retries) retries."
            else
                _parse_yahoo_error(e.body, e.status, symbol)
            end
        else
            "Request failed for $symbol: $(sprint(showerror, e))"
        end

        if throw_error
            error(msg)
        else
            @warn msg
            return nothing
        end
    end
end
