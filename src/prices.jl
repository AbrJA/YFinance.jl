# ─────────────────────────────────────────────────────────────────────────────
# prices.jl — Price, dividend, and split data retrieval
# ─────────────────────────────────────────────────────────────────────────────

# ─── Date Utilities ───────────────────────────────────────────────────────────

_date_to_unix(dt::Date) = Int(floor(datetime2unix(DateTime(dt))))
_date_to_unix(dt::DateTime) = Int(floor(datetime2unix(dt)))
_date_to_unix(dt::AbstractString) = _date_to_unix(Date(dt, dateformat"yyyy-mm-dd"))

function _clean_values(x::AbstractVector)
    output = Vector{Float64}(undef, length(x))
    map!(output, x) do val
        if isnothing(val)
            return NaN
        elseif val isa Integer
            return Float64(val)
        else
            return Float64(val)
        end
    end
    return output
end
_clean_values(x::AbstractVector{Float64}) = x

# ─── Prices ──────────────────────────────────────────────────────────────────

const _VALID_INTERVALS = ("1m","2m","5m","15m","30m","60m","90m","1h","1d","5d","1wk","1mo","3mo")
const _MINUTE_INTERVALS = ("1m","2m","5m","15m","30m","60m","90m")

"""
    prices(symbol::String; range="5d", interval="1d", startdt="", enddt="", prepost=false, autoadjust=true, timeout=10, exchange_local_time=false, wait=0.0) -> PriceData

Retrieve historical price data from Yahoo Finance.

# Arguments
- `symbol` — Ticker symbol (e.g., `"AAPL"`, `"^GSPC"`)
- `range` — Time range: `"1d"`, `"5d"`, `"1mo"`, `"3mo"`, `"6mo"`, `"1y"`, `"5y"`, `"ytd"`, `"max"`
- `interval` — Data interval: `"1m"`, `"5m"`, `"15m"`, `"1h"`, `"1d"`, `"1wk"`, `"1mo"`
- `startdt`, `enddt` — Start/end dates (`Date`, `DateTime`, or `"yyyy-mm-dd"` string). Both required if one is provided.
- `prepost` — Include pre/post market data
- `autoadjust` — Adjust OHLC by adjclose ratio (daily+ only)
- `timeout` — HTTP timeout in seconds
- `exchange_local_time` — Use exchange local time instead of GMT
- `wait` — Seconds between API calls for chunked minute data

# Returns
A [`PriceData`](@ref) struct (implements `Tables.jl`).

# Examples
```julia
julia> prices("AAPL", range="5d")
PriceData("AAPL", 5 rows, 2024-01-02T14:30:00 to 2024-01-08T14:30:00)

julia> using DataFrames
julia> prices("AAPL", range="5d") |> DataFrame
5×8 DataFrame
...
```
"""
function prices(symbol::String;
    range::String="5d",
    interval::String="1d",
    startdt::Union{Date,DateTime,AbstractString}="",
    enddt::Union{Date,DateTime,AbstractString}="",
    prepost::Bool=false,
    autoadjust::Bool=true,
    timeout::Int=10,
    exchange_local_time::Bool=false,
    wait::Float64=0.0
)
    @assert interval in _VALID_INTERVALS "Invalid interval '$interval'. Choose from: $(join(_VALID_INTERVALS, ", "))"

    if startdt == "" && enddt == ""
        return _prices_by_range(symbol, range; interval, prepost, autoadjust, timeout, exchange_local_time, wait)
    else
        (startdt == "" || enddt == "") && error("Both startdt and enddt must be provided if one is specified.")
        start_unix = _date_to_unix(startdt)
        end_unix = _date_to_unix(enddt)
        return _prices_by_dates(symbol, start_unix, end_unix; interval, prepost, autoadjust, timeout, exchange_local_time, wait)
    end
end

function _prices_by_range(symbol::String, range::String; interval::String="1d", kwargs...)
    end_unix = Int(floor(datetime2unix(now())))
    start_unix = if range == "max"
        0
    elseif range == "ytd"
        _date_to_unix(Date(year(today()), 1, 1))
    else
        duration = if endswith(range, "mo")
            Month(parse(Int, range[1:end-2]))
        elseif endswith(range, "m")
            Minute(parse(Int, range[1:end-1]))
        elseif endswith(range, "d")
            Day(parse(Int, range[1:end-1]))
        elseif endswith(range, "y")
            Year(parse(Int, range[1:end-1]))
        else
            error("Invalid range format: '$range'")
        end
        _date_to_unix(now() - duration)
    end
    return _prices_by_dates(symbol, start_unix, end_unix; interval, kwargs...)
end

function _prices_by_dates(symbol::String, startdt::Int, enddt::Int;
    interval::String="1d", prepost::Bool=false, autoadjust::Bool=true,
    timeout::Int=10, exchange_local_time::Bool=false, wait::Float64=0.0
)
    # Minute data validation
    if interval in _MINUTE_INTERVALS
        thirty_days_ago = Int(floor(datetime2unix(now() - Day(30))))
        if startdt < thirty_days_ago
            earliest = Date(unix2datetime(thirty_days_ago))
            throw(YFinanceError(symbol, "Minute data only available for last 30 days. Earliest: $earliest", nothing))
        end
        # Chunk requests for periods > 7 days
        if enddt - startdt > 7 * 86400
            return _chunked_minute_prices(symbol, startdt, enddt, interval; prepost, autoadjust, timeout, exchange_local_time, wait)
        end
    end

    params = Dict{String,Union{String,Int,Bool}}(
        "period1" => startdt,
        "period2" => enddt,
        "interval" => interval,
        "includePrePost" => prepost,
    )
    url = _build_url("$(_BASE_URL)/v8/finance/chart/$(uppercase(symbol))", params)
    resp = _yahoo_request(url, symbol; timeout)
    return _parse_price_response(resp.body, symbol, interval, autoadjust, exchange_local_time)
end

function _chunked_minute_prices(symbol::String, startdt::Int, enddt::Int, interval::String; wait::Float64=0.0, kwargs...)
    chunk_size = 7 * 86400
    chunks = [(t, min(t + chunk_size - 1, enddt)) for t in startdt:chunk_size:enddt]

    all_timestamps = DateTime[]
    all_open = Float64[]
    all_high = Float64[]
    all_low = Float64[]
    all_close = Float64[]
    all_volume = Float64[]

    for (i, (cs, ce)) in enumerate(chunks)
        i > 1 && sleep(wait)
        chunk = _prices_by_dates(symbol, cs, ce; interval, kwargs...)
        append!(all_timestamps, chunk.timestamp)
        append!(all_open, chunk.open)
        append!(all_high, chunk.high)
        append!(all_low, chunk.low)
        append!(all_close, chunk.close)
        append!(all_volume, chunk.volume)
    end

    return PriceData(symbol, all_timestamps, all_open, all_high, all_low, all_close, all_volume, nothing)
end

function _parse_price_response(body, symbol, interval, autoadjust, exchange_local_time)
    res = JSON.parse(String(copy(body)))["chart"]["result"][1]
    time_offset = exchange_local_time ? res["meta"]["gmtoffset"] : 0

    haskey(res, "timestamp") || throw(YFinanceError(symbol, "No historical data available", nothing))
    timestamps = res["timestamp"]

    # Handle duplicate last timestamp
    idx = length(timestamps) - length(unique(timestamps)) == 1 ? (1:length(timestamps)-1) : eachindex(timestamps)

    ts = Dates.unix2datetime.(view(timestamps, idx) .+ time_offset)
    quote_data = res["indicators"]["quote"][1]

    open_v = _clean_values(quote_data["open"][idx])
    high_v = _clean_values(quote_data["high"][idx])
    low_v = _clean_values(quote_data["low"][idx])
    close_v = _clean_values(quote_data["close"][idx])
    vol_v = _clean_values(quote_data["volume"][idx])

    adjclose_v = nothing
    if interval ∉ _MINUTE_INTERVALS
        adjclose_v = _clean_values(res["indicators"]["adjclose"][1]["adjclose"][idx])
        if autoadjust
            ratio = adjclose_v ./ close_v
            open_v .*= ratio
            high_v .*= ratio
            low_v .*= ratio
            vol_v .*= ratio
        end
    end

    return PriceData(symbol, collect(ts), open_v, high_v, low_v, close_v, vol_v, adjclose_v)
end

# ─── Dividends ────────────────────────────────────────────────────────────────

"""
    dividends(symbol::String; startdt="", enddt="", timeout=10, exchange_local_time=false) -> DividendData

Retrieve dividend history from Yahoo Finance.

# Arguments
- `symbol` — Ticker symbol
- `startdt`, `enddt` — Date range (optional, defaults to all available)
- `timeout` — HTTP timeout in seconds
- `exchange_local_time` — Use exchange local time

# Returns
A [`DividendData`](@ref) struct (implements `Tables.jl`).

# Examples
```julia
julia> dividends("AAPL", startdt="2021-01-01", enddt="2022-01-01")
DividendData("AAPL", 4 entries)

julia> using DataFrames
julia> dividends("AAPL", startdt="2021-01-01", enddt="2022-01-01") |> DataFrame
```
"""
function dividends(symbol::String;
    startdt::Union{Date,DateTime,AbstractString}="",
    enddt::Union{Date,DateTime,AbstractString}="",
    timeout::Int=10,
    exchange_local_time::Bool=false
)
    start_unix = isempty(string(startdt)) ? 0 : _date_to_unix(startdt)
    end_unix = isempty(string(enddt)) ? Int(floor(datetime2unix(now()))) : _date_to_unix(enddt)

    params = Dict{String,Union{String,Int}}(
        "period1" => start_unix,
        "period2" => end_unix,
        "interval" => "1d",
        "events" => "div"
    )
    url = _build_url("$(_BASE_URL)/v8/finance/chart/$(uppercase(symbol))", params)
    resp = _yahoo_request(url, symbol; timeout)
    return _parse_dividend_response(resp.body, symbol, exchange_local_time)
end

function _parse_dividend_response(body, symbol, exchange_local_time)
    res = JSON.parse(String(copy(body)))["chart"]["result"][1]
    time_offset = exchange_local_time ? res["meta"]["gmtoffset"] : 0

    ts = DateTime[]
    divs = Float64[]

    if haskey(res, "events") && haskey(res["events"], "dividends")
        for v in values(res["events"]["dividends"])
            push!(ts, unix2datetime(v["date"] + time_offset))
            push!(divs, Float64(v["amount"]))
        end
    end

    return DividendData(symbol, ts, divs)
end

# ─── Splits ───────────────────────────────────────────────────────────────────

"""
    splits(symbol::String; startdt="", enddt="", timeout=10, exchange_local_time=false) -> SplitData

Retrieve stock split history from Yahoo Finance.

# Arguments
- `symbol` — Ticker symbol
- `startdt`, `enddt` — Date range (optional, defaults to all available)
- `timeout` — HTTP timeout in seconds
- `exchange_local_time` — Use exchange local time

# Returns
A [`SplitData`](@ref) struct (implements `Tables.jl`).

# Examples
```julia
julia> splits("AAPL", startdt="2000-01-01", enddt="2021-01-01")
SplitData("AAPL", 3 entries)

julia> using DataFrames
julia> splits("AAPL", startdt="2000-01-01", enddt="2021-01-01") |> DataFrame
```
"""
function splits(symbol::String;
    startdt::Union{Date,DateTime,AbstractString}="",
    enddt::Union{Date,DateTime,AbstractString}="",
    timeout::Int=10,
    exchange_local_time::Bool=false
)
    start_unix = isempty(string(startdt)) ? 0 : _date_to_unix(startdt)
    end_unix = isempty(string(enddt)) ? Int(floor(datetime2unix(now()))) : _date_to_unix(enddt)

    params = Dict{String,Union{String,Int}}(
        "period1" => start_unix,
        "period2" => end_unix,
        "interval" => "1d",
        "events" => "splits"
    )
    url = _build_url("$(_BASE_URL)/v8/finance/chart/$(uppercase(symbol))", params)
    resp = _yahoo_request(url, symbol; timeout)
    return _parse_splits_response(resp.body, symbol, exchange_local_time)
end

function _parse_splits_response(body, symbol, exchange_local_time)
    res = JSON.parse(String(copy(body)))["chart"]["result"][1]
    time_offset = exchange_local_time ? res["meta"]["gmtoffset"] : 0

    ts = DateTime[]
    nums = Int[]
    denoms = Int[]

    if haskey(res, "events") && haskey(res["events"], "splits")
        for v in values(res["events"]["splits"])
            push!(ts, unix2datetime(v["date"] + time_offset))
            push!(nums, v["numerator"])
            push!(denoms, v["denominator"])
        end
    end

    ratios = isempty(nums) ? Float64[] : Float64.(nums) ./ Float64.(denoms)
    return SplitData(symbol, ts, nums, denoms, ratios)
end
