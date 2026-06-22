# ─────────────────────────────────────────────────────────────────────────────
# prices.jl — Price, dividend, and split data retrieval
# ─────────────────────────────────────────────────────────────────────────────

const _BASE_URL = "https://query2.finance.yahoo.com"

# ─── Date Conversion ──────────────────────────────────────────────────────────

_to_unix(dt::Date)::Int = Int(floor(datetime2unix(DateTime(dt))))
_to_unix(dt::DateTime)::Int = Int(floor(datetime2unix(dt)))
_to_unix(dt::AbstractString)::Int = _to_unix(Date(dt, dateformat"yyyy-mm-dd"))

# ─── NaN-safe vector cleaning ─────────────────────────────────────────────────

function _clean_vec(x::AbstractVector)::Vector{Float64}
    out = Vector{Float64}(undef, length(x))
    @inbounds for i in eachindex(x)
        v = x[i]
        out[i] = isnothing(v) ? NaN : Float64(v)
    end
    return out
end
_clean_vec(x::Vector{Float64}) = x

# ─── Valid Intervals ──────────────────────────────────────────────────────────

const _VALID_INTERVALS = ("1m","2m","5m","15m","30m","60m","90m","1h","1d","5d","1wk","1mo","3mo")
const _INTRADAY = ("1m","2m","5m","15m","30m","60m","90m")

# ─── get_prices ───────────────────────────────────────────────────────────────

"""
    get_prices(symbol; range="5d", interval="1d", startdt="", enddt="", kwargs...) -> PriceData

Retrieve OHLCV price data from Yahoo Finance. Returns a `PriceData` struct
that implements `Tables.jl` (pipe directly to `DataFrame`).

# Arguments
- `symbol::String` — Ticker (e.g. "AAPL", "^GSPC", "RELIANCE.NS")
- `range::String` — Time range: "1d","5d","1mo","3mo","6mo","1y","2y","5y","10y","ytd","max"
- `interval::String` — Bar size: "1m","2m","5m","15m","30m","60m","90m","1h","1d","5d","1wk","1mo","3mo"
- `startdt` / `enddt` — Date range (Date, DateTime, or "yyyy-mm-dd" String)
- `prepost::Bool=false` — Include pre/post market data
- `autoadjust::Bool=true` — Adjust OHLC by split/dividend factor (daily+ only)
- `divsplits::Bool=false` — Include dividend and split ratio columns
- `exchange_local_time::Bool=false` — Timestamps in exchange local time vs GMT
- `timeout::Int=10` — HTTP timeout in seconds
- `throw_error::Bool=false` — Throw on errors vs return empty PriceData
- `wait::Float64=0.0` — Delay between API calls for chunked minute requests

# Examples
```julia
get_prices("AAPL", range="5d")
get_prices("MSFT", startdt="2024-01-01", enddt="2024-06-01")
get_prices("AAPL", range="1mo", interval="1h")

# Direct to DataFrame
using DataFrames
get_prices("AAPL", range="5d") |> DataFrame
```
"""
function get_prices(symbol::String;
                    range::String="5d",
                    interval::String="1d",
                    startdt::Union{Date,DateTime,AbstractString}="",
                    enddt::Union{Date,DateTime,AbstractString}="",
                    prepost::Bool=false,
                    autoadjust::Bool=true,
                    divsplits::Bool=false,
                    exchange_local_time::Bool=false,
                    timeout::Int=10,
                    throw_error::Bool=false,
                    wait::Float64=0.0)
    @assert interval in _VALID_INTERVALS "Invalid interval '$interval'. Valid: $(join(_VALID_INTERVALS, ", "))"

    if startdt == "" && enddt == ""
        start_unix, end_unix = _range_to_unix(range)
    else
        (startdt == "" || enddt == "") && error("Both startdt and enddt must be provided.")
        start_unix = _to_unix(startdt)
        end_unix = _to_unix(enddt)
    end

    return _fetch_prices(symbol, start_unix, end_unix;
                         interval, prepost, autoadjust, divsplits,
                         exchange_local_time, timeout, throw_error, wait)
end

# Convenience: positional date args
function get_prices(symbol::String, startdt::Union{Date,DateTime,AbstractString},
                    enddt::Union{Date,DateTime,AbstractString}; kwargs...)
    get_prices(symbol; startdt, enddt, kwargs...)
end

# ─── Internal: range → unix timestamps ────────────────────────────────────────

function _range_to_unix(range::String)
    end_unix = Int(floor(datetime2unix(now())))
    start_unix = if range == "max"
        0
    elseif range == "ytd"
        _to_unix(Date(year(today()), 1, 1))
    else
        dur = if endswith(range, "mo") && length(range) > 2
            n = tryparse(Int, range[1:end-2])
            isnothing(n) && error("Invalid range '$range'.")
            Month(n)
        elseif endswith(range, "m") && length(range) > 1
            n = tryparse(Int, range[1:end-1])
            isnothing(n) && error("Invalid range '$range'.")
            Minute(n)
        elseif endswith(range, "d") && length(range) > 1
            n = tryparse(Int, range[1:end-1])
            isnothing(n) && error("Invalid range '$range'.")
            Day(n)
        elseif endswith(range, "y") && length(range) > 1
            n = tryparse(Int, range[1:end-1])
            isnothing(n) && error("Invalid range '$range'.")
            Year(n)
        else
            error("Invalid range '$range'. Use: Nd, Nmo, Ny, Nm, 'ytd', or 'max'.")
        end
        _to_unix(now() - dur)
    end
    return start_unix, end_unix
end

# ─── Internal: core fetch logic ───────────────────────────────────────────────

function _fetch_prices(symbol::String, start_unix::Int, end_unix::Int;
                       interval::String="1d", prepost::Bool=false,
                       autoadjust::Bool=true, divsplits::Bool=false,
                       exchange_local_time::Bool=false, timeout::Int=10,
                       throw_error::Bool=false, wait::Float64=0.0)
    # Minute data: max 30 days back
    if interval in _INTRADAY
        thirty_days = Int(floor(datetime2unix(now() - Day(30))))
        if start_unix < thirty_days
            msg = "Minute data only available for last 30 days. Earliest: $(Date(unix2datetime(thirty_days)))"
            throw_error ? error(msg) : (@warn msg; return PriceData(symbol, 0))
        end
        # Chunk into 7-day windows
        if end_unix - start_unix > 7 * 86400
            return _chunked_fetch(symbol, start_unix, end_unix;
                                  interval, prepost, autoadjust, exchange_local_time,
                                  timeout, throw_error, wait)
        end
    end

    params = Dict{String,Any}(
        "period1" => start_unix,
        "period2" => end_unix,
        "interval" => interval,
        "includePrePost" => prepost,
        "events" => divsplits ? "div,splits" : ""
    )
    url = _build_url("$(_BASE_URL)/v8/finance/chart/$(uppercase(symbol))", params)

    resp = _yahoo_get(url, symbol; timeout, throw_error)
    isnothing(resp) && return PriceData(symbol, 0)

    try
        return _parse_prices(resp.body, symbol, interval, autoadjust, exchange_local_time, divsplits)
    catch e
        throw_error && rethrow()
        @warn "Failed to parse price data for $symbol: $(sprint(showerror, e))"
        return PriceData(symbol, 0)
    end
end

# ─── Internal: chunked minute data ───────────────────────────────────────────

function _chunked_fetch(symbol::String, start_unix::Int, end_unix::Int; wait::Float64=0.0, kwargs...)
    chunk_size = 7 * 86400
    result = PriceData(symbol, 0)

    for (i, t) in enumerate(start_unix:chunk_size:end_unix)
        i > 1 && wait > 0 && sleep(wait)
        chunk_end = min(t + chunk_size - 1, end_unix)
        chunk = _fetch_prices(symbol, t, chunk_end; kwargs..., wait=0.0)
        isempty(chunk) && continue

        if isempty(result)
            result = chunk
        else
            append!(result.timestamp, chunk.timestamp)
            append!(result.open, chunk.open)
            append!(result.high, chunk.high)
            append!(result.low, chunk.low)
            append!(result.close, chunk.close)
            append!(result.adjclose, chunk.adjclose)
            append!(result.volume, chunk.volume)
        end
    end
    return result
end

# ─── Internal: parse JSON response → PriceData ───────────────────────────────

function _parse_prices(body::Vector{UInt8}, symbol::String, interval::String,
                       autoadjust::Bool, local_time::Bool, divsplits::Bool)
    res = JSON.parse(String(copy(body)))["chart"]["result"][1]
    offset = local_time ? res["meta"]["gmtoffset"] : 0

    haskey(res, "timestamp") || error("No data for $symbol in this period")
    raw_ts = res["timestamp"]

    # Deduplicate trailing timestamp
    n = length(raw_ts)
    idx = (n > 1 && raw_ts[end] == raw_ts[end-1]) ? (1:n-1) : (1:n)

    ts = unix2datetime.(view(raw_ts, idx) .+ offset)
    quote_data = res["indicators"]["quote"][1]

    open_v  = _clean_vec(quote_data["open"][idx])
    high_v  = _clean_vec(quote_data["high"][idx])
    low_v   = _clean_vec(quote_data["low"][idx])
    close_v = _clean_vec(quote_data["close"][idx])
    vol_v   = _clean_vec(quote_data["volume"][idx])

    # Adjusted close (only for daily+)
    if interval ∉ _INTRADAY && haskey(res["indicators"], "adjclose")
        adjclose_v = _clean_vec(res["indicators"]["adjclose"][1]["adjclose"][idx])
    else
        adjclose_v = copy(close_v)
    end

    # Auto-adjust OHLCV
    if autoadjust && interval ∉ _INTRADAY
        ratio = adjclose_v ./ close_v
        open_v  .*= ratio
        high_v  .*= ratio
        low_v   .*= ratio
        # Volume: divide by ratio (more shares outstanding → volume adjusts inversely)
        for i in eachindex(vol_v)
            r = ratio[i]
            if !isnan(r) && r != 0.0
                vol_v[i] /= r
            end
        end
    end

    # Dividends and splits
    div_v = Float64[]
    split_v = Float64[]
    if divsplits && interval == "1d" && haskey(res, "events")
        div_v = zeros(Float64, length(idx))
        split_v = ones(Float64, length(idx))

        if haskey(res["events"], "dividends")
            for v in values(res["events"]["dividends"])
                dt = unix2datetime(v["date"] + offset)
                for j in eachindex(ts)
                    ts[j] == dt && (div_v[j] = v["amount"]; break)
                end
            end
        end
        if haskey(res["events"], "splits")
            for v in values(res["events"]["splits"])
                dt = unix2datetime(v["date"] + offset)
                for j in eachindex(ts)
                    ts[j] == dt && (split_v[j] = v["numerator"] / v["denominator"]; break)
                end
            end
        end
    elseif divsplits && interval != "1d"
        @warn "divsplits only works with interval=\"1d\""
    end

    return PriceData(symbol, ts, open_v, high_v, low_v, close_v, adjclose_v, vol_v, div_v, split_v)
end

# ─── get_dividends ────────────────────────────────────────────────────────────

"""
    get_dividends(symbol; startdt="", enddt="", kwargs...) -> DividendData

Retrieve dividend history. Returns `DividendData` (Tables.jl compatible).

# Examples
```julia
get_dividends("AAPL", startdt="2021-01-01", enddt="2022-01-01")
get_dividends("AAPL") |> DataFrame
```
"""
function get_dividends(symbol::String;
                       startdt::Union{Date,DateTime,AbstractString}="",
                       enddt::Union{Date,DateTime,AbstractString}="",
                       timeout::Int=10, throw_error::Bool=false,
                       exchange_local_time::Bool=false)
    start_unix = isempty(string(startdt)) ? 0 : _to_unix(startdt)
    end_unix = isempty(string(enddt)) ? Int(floor(datetime2unix(now()))) : _to_unix(enddt)

    params = Dict{String,Any}(
        "period1" => start_unix, "period2" => end_unix,
        "interval" => "1d", "events" => "div"
    )
    url = _build_url("$(_BASE_URL)/v8/finance/chart/$(uppercase(symbol))", params)

    resp = _yahoo_get(url, symbol; timeout, throw_error)
    isnothing(resp) && return DividendData(symbol)

    res = JSON.parse(String(copy(resp.body)))["chart"]["result"][1]
    offset = exchange_local_time ? res["meta"]["gmtoffset"] : 0
    result = DividendData(symbol)

    if haskey(res, "events") && haskey(res["events"], "dividends")
        for v in values(res["events"]["dividends"])
            push!(result.timestamp, unix2datetime(v["date"] + offset))
            push!(result.dividend, Float64(v["amount"]))
        end
    end
    return result
end

# ─── get_splits ───────────────────────────────────────────────────────────────

"""
    get_splits(symbol; startdt="", enddt="", kwargs...) -> SplitData

Retrieve stock split history. Returns `SplitData` (Tables.jl compatible).

# Examples
```julia
get_splits("AAPL", startdt="2000-01-01", enddt="2021-01-01")
get_splits("GOOGL") |> DataFrame
```
"""
function get_splits(symbol::String;
                    startdt::Union{Date,DateTime,AbstractString}="",
                    enddt::Union{Date,DateTime,AbstractString}="",
                    timeout::Int=10, throw_error::Bool=false,
                    exchange_local_time::Bool=false)
    start_unix = isempty(string(startdt)) ? 0 : _to_unix(startdt)
    end_unix = isempty(string(enddt)) ? Int(floor(datetime2unix(now()))) : _to_unix(enddt)

    params = Dict{String,Any}(
        "period1" => start_unix, "period2" => end_unix,
        "interval" => "1d", "events" => "splits"
    )
    url = _build_url("$(_BASE_URL)/v8/finance/chart/$(uppercase(symbol))", params)

    resp = _yahoo_get(url, symbol; timeout, throw_error)
    isnothing(resp) && return SplitData(symbol)

    res = JSON.parse(String(copy(resp.body)))["chart"]["result"][1]
    offset = exchange_local_time ? res["meta"]["gmtoffset"] : 0
    result = SplitData(symbol)

    if haskey(res, "events") && haskey(res["events"], "splits")
        for v in values(res["events"]["splits"])
            push!(result.timestamp, unix2datetime(v["date"] + offset))
            push!(result.numerator, Int(v["numerator"]))
            push!(result.denominator, Int(v["denominator"]))
            push!(result.ratio, v["numerator"] / v["denominator"])
        end
    end
    return result
end
