"""
    _uri_encode(s::AbstractString)

Percent-encodes a string for use in URL query parameters.
"""
function _uri_encode(s::AbstractString)
    io = IOBuffer()
    for c in s
        if c in ('A':'Z') || c in ('a':'z') || c in ('0':'9') || c in ('-', '.', '_', '~')
            write(io, c)
        else
            for byte in codeunits(string(c))
                write(io, '%', uppercase(string(byte, base=16, pad=2)))
            end
        end
    end
    return String(take!(io))
end

"""
    _build_query_string(params::Dict)

Builds a URL query string from a dictionary of parameters.
"""
function _build_query_string(params::Dict)
    parts = String[]
    for (k, v) in params
        push!(parts, "$(_uri_encode(string(k)))=$(_uri_encode(string(v)))")
    end
    return join(parts, "&")
end

"""
    _build_url(base::String, params::Dict)

Builds a full URL with query parameters.
"""
function _build_url(base::String, params::Dict)
    qs = _build_query_string(params)
    return isempty(qs) ? base : "$base?$qs"
end

"""
    _make_headers(; extra_headers::Dict=Dict(), cookies::Dict=Dict())

Builds the headers vector for Downloads.request, merging proxy auth, random header, and cookies.
Note: Filters out accept-encoding to avoid gzip responses that Downloads.jl doesn't auto-decompress.
"""
function _make_headers(; extra_headers::Dict=Dict{String,String}(), cookies::Dict=Dict{String,String}(), use_random_header::Bool=true)
    headers = Pair{String,String}[]

    # Add random browser header (skip accept-encoding since Downloads.jl doesn't auto-decompress)
    if use_random_header && @isdefined(_HEADER)
        for (k, v) in _HEADER
            lowercase(k) == "accept-encoding" && continue
            push!(headers, k => v)
        end
    end
    
    # Explicitly request no compression
    push!(headers, "Accept-Encoding" => "identity")

    # Add proxy auth headers
    if !isempty(_PROXY_SETTINGS[:auth])
        for (k, v) in _PROXY_SETTINGS[:auth]
            push!(headers, k => v)
        end
    end

    # Add extra headers
    for (k, v) in extra_headers
        push!(headers, k => v)
    end

    # Add cookies
    if !isempty(cookies)
        cookie_str = join(["$k=$v" for (k, v) in cookies], "; ")
        push!(headers, "Cookie" => cookie_str)
    end

    return headers
end

"""
    _parse_set_cookie(headers)

Extracts cookies from response headers (Set-Cookie entries).
"""
function _parse_set_cookie(headers::Vector)
    cookies = Dict{String,String}()
    for (name, value) in headers
        if lowercase(name) == "set-cookie"
            # Parse "name=value; ..." format
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

"""
    ResponseError

Custom error type for HTTP response errors.
"""
struct ResponseError <: Exception
    status::Int
    body::Vector{UInt8}
end

"""
    _request(url::String; headers, timeout, throw_on_error)

Makes a GET request using Downloads.jl. Returns a NamedTuple (status, body, headers).
If throw_on_error is true and status >= 400, throws a ResponseError.
"""
function _request(url::String; headers::Vector{Pair{String,String}}=Pair{String,String}[], timeout::Real=10, throw_on_error::Bool=true)
    output = IOBuffer()
    resp_headers = Pair{String,String}[]

    try
        resp = Downloads.request(url;
            method="GET",
            headers=headers,
            output=output,
            timeout=Float64(timeout),
            throw=false
        )

        body = take!(output)
        status = resp.status
        resp_headers = resp.headers

        if throw_on_error && status >= 400
            throw(ResponseError(status, body))
        end

        return (status=status, body=body, headers=resp_headers)
    catch e
        if e isa ResponseError
            rethrow()
        end
        # Network errors (timeout, DNS, etc.)
        throw(e)
    end
end

"""
    _parse_yahoo_error(body::Vector{UInt8}, status::Int, symbol::String)

Attempts to parse a Yahoo Finance error response body as JSON.
Falls back to the raw text if JSON parsing fails.
"""
function _parse_yahoo_error(body::Vector{UInt8}, status::Int, symbol::String)
    try
        yahoo_error = JSON3.read(body)
        if haskey(yahoo_error, :finance)
            return string(yahoo_error.finance.error.description)
        elseif haskey(yahoo_error, :chart) && haskey(yahoo_error.chart, :error)
            error_description = yahoo_error.chart.error.description
            date_matches = collect(eachmatch(r"(-)?[0-9]{1,}", error_description))
            if length(date_matches) >= 2
                error_dates = unix2datetime.(parse.(Float64, [m.match for m in date_matches[1:2]]))
                return "Data doesn't exist for startDate = $(error_dates[1]), endDate = $(error_dates[2]) for $symbol"
            else
                return string(error_description)
            end
        else
            return "HTTP error $status for $symbol"
        end
    catch
        # Body is not valid JSON (e.g., plain text error like "Too Many Requests")
        text = String(body)
        return isempty(text) ? "HTTP error $status for $symbol" : text
    end
end
