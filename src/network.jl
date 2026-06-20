# ─────────────────────────────────────────────────────────────────────────────
# network.jl — Core networking layer for YFinance.jl
# Provides: YahooSession, rate-limited requests, retry logic, URL building
# ─────────────────────────────────────────────────────────────────────────────

# ─── URL Encoding ─────────────────────────────────────────────────────────────

const _SAFE_URI_CHARS = Set{Char}(vcat(
    collect('A':'Z'), collect('a':'z'), collect('0':'9'), ['-', '.', '_', '~']
))

function _uri_encode(s::AbstractString)
    io = IOBuffer()
    for c in s
        if c in _SAFE_URI_CHARS
            write(io, c)
        else
            for byte in codeunits(string(c))
                write(io, '%', uppercase(string(byte, base=16, pad=2)))
            end
        end
    end
    return String(take!(io))
end

function _build_query_string(params::Dict)
    parts = String[]
    for (k, v) in params
        push!(parts, "$(_uri_encode(string(k)))=$(_uri_encode(string(v)))")
    end
    return join(parts, "&")
end

function _build_url(base::String, params::Dict)
    qs = _build_query_string(params)
    return isempty(qs) ? base : "$base?$qs"
end

# ─── Response Error Type ──────────────────────────────────────────────────────

struct ResponseError <: Exception
    status::Int
    body::Vector{UInt8}
end

function Base.showerror(io::IO, e::ResponseError)
    print(io, "ResponseError: HTTP $(e.status)")
    if !isempty(e.body)
        text = String(copy(e.body))
        if length(text) > 100
            text = text[1:100] * "..."
        end
        print(io, " — ", text)
    end
end

# ─── Yahoo Session (singleton, thread-safe) ───────────────────────────────────

"""
    YahooSession

Holds authentication state (cookie, crumb, header) and rate-limiting configuration.
Thread-safe via a ReentrantLock.
"""
mutable struct YahooSession
    cookie::Dict{String,String}
    crumb::String
    header::Dict{String,String}
    proxy::Union{Nothing,String}
    proxy_auth::Dict{String,String}
    last_request_time::Float64
    min_request_interval::Float64  # seconds between requests
    max_retries::Int
    retry_base_delay::Float64      # base delay for exponential backoff (seconds)
    initialized::Bool
    lock::ReentrantLock
end

function YahooSession()
    return YahooSession(
        Dict{String,String}(),  # cookie
        "",                      # crumb
        Dict{String,String}(),  # header
        nothing,                 # proxy
        Dict{String,String}(),  # proxy_auth
        0.0,                     # last_request_time
        0.3,                     # min_request_interval (300ms)
        3,                       # max_retries
        1.5,                     # retry_base_delay
        false,                   # initialized
        ReentrantLock()          # lock
    )
end

# Global singleton session
const _SESSION = YahooSession()

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

function _build_headers(cookies::Dict{String,String})
    headers = Pair{String,String}[]

    # Browser headers (skip accept-encoding — Downloads.jl doesn't auto-decompress)
    for (k, v) in _SESSION.header
        lowercase(k) == "accept-encoding" && continue
        push!(headers, k => v)
    end
    push!(headers, "Accept-Encoding" => "identity")

    # Proxy auth
    for (k, v) in _SESSION.proxy_auth
        push!(headers, k => v)
    end

    # Cookies
    if !isempty(cookies)
        cookie_str = join(["$k=$v" for (k, v) in cookies], "; ")
        push!(headers, "Cookie" => cookie_str)
    end

    return headers
end

# ─── Cookie Parsing ───────────────────────────────────────────────────────────

function _parse_set_cookie(headers::Vector)
    cookies = Dict{String,String}()
    for (name, value) in headers
        if lowercase(name) == "set-cookie"
            cookie_part = split(value, ";")[1]
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
    if remaining > 0
        sleep(remaining)
    end
    _SESSION.last_request_time = time()
    return nothing
end

# ─── Raw Request (no retry, no rate limit) ────────────────────────────────────

function _raw_request(url::String; headers::Vector{Pair{String,String}}=Pair{String,String}[], timeout::Real=10, throw_on_error::Bool=true)
    output = IOBuffer()

    resp = Downloads.request(url;
        method="GET",
        headers=headers,
        output=output,
        timeout=Float64(timeout),
        throw=false
    )

    body = take!(output)
    resp_status = resp.status
    resp_headers = resp.headers

    if throw_on_error && resp_status >= 400
        throw(ResponseError(resp_status, body))
    end

    return (status=resp_status, body=body, headers=resp_headers)
end

# ─── Main Request Function (rate-limited + retry) ─────────────────────────────

"""
    _request(url; timeout=10, throw_on_error=true)

Makes a rate-limited, retrying GET request using the current session.
Handles 429 (Too Many Requests) with exponential backoff.
On 401/403, renews the session and retries.
"""
function _request(url::String; timeout::Real=10, throw_on_error::Bool=true)
    _ensure_session!()
    headers = _build_headers(_SESSION.cookie)

    for attempt in 1:_SESSION.max_retries
        _throttle!()

        try
            return _raw_request(url; headers=headers, timeout=timeout, throw_on_error=throw_on_error)
        catch e
            if !(e isa ResponseError)
                # Network error — retry if attempts remain
                attempt == _SESSION.max_retries && rethrow()
                sleep(_SESSION.retry_base_delay * 2^(attempt - 1))
                continue
            end

            if e.status == 429
                # Rate limited — wait with exponential backoff
                attempt == _SESSION.max_retries && rethrow()
                delay = _SESSION.retry_base_delay * 2^(attempt - 1)
                sleep(delay)
                continue
            elseif e.status in (401, 403)
                # Auth expired — renew session and retry
                attempt == _SESSION.max_retries && rethrow()
                _renew_session!()
                headers = _build_headers(_SESSION.cookie)
                continue
            else
                # Other HTTP error — don't retry
                rethrow()
            end
        end
    end

    # Should not reach here, but just in case:
    error("Request failed after $(_SESSION.max_retries) attempts: $url")
end

# ─── Yahoo Error Parsing ──────────────────────────────────────────────────────

"""
    _parse_yahoo_error(body, status, symbol)

Parses Yahoo Finance error response bodies. Handles both JSON and plain-text errors.
"""
function _parse_yahoo_error(body::Vector{UInt8}, status::Int, symbol::String="")
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

# These maintain the old interface for Proxy_Auth.jl and exported functions

function _make_headers(; extra_headers::Dict=Dict{String,String}(), cookies::Dict=Dict{String,String}(), use_random_header::Bool=true)
    _ensure_session!()
    return _build_headers(cookies)
end

# ─── High-level Yahoo Request (standardized error handling) ───────────────────

"""
    _yahoo_get(url, symbol; timeout=10, throw_error=false, empty_result=nothing)

Standard pattern for Yahoo Finance GET requests with consistent error handling.
Returns the response NamedTuple on success, or `nothing` on failure (when throw_error=false).
If throw_error=true, raises an error with a descriptive message on failure.
"""
function _yahoo_get(url::String, symbol::String=""; timeout::Real=10, throw_error::Bool=false, empty_result=nothing)
    try
        return _request(url; timeout=timeout)
    catch e
        msg = if e isa ResponseError
            if e.status == 404
                "$symbol is not a valid Symbol."
            elseif e.status == 429
                "Too many requests for $symbol. Rate limit exceeded after retries."
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

