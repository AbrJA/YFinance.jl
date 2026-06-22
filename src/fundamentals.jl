# ─────────────────────────────────────────────────────────────────────────────
# fundamentals.jl — Financial statement data retrieval
# ─────────────────────────────────────────────────────────────────────────────

"""
    fundamentals(symbol::AbstractString, item::AbstractString, interval::AbstractString, startdt, enddt; timeout=10) -> FundamentalData

Retrieve financial statement data from Yahoo Finance.

# Arguments
- `symbol` — Ticker symbol (e.g., `"AAPL"`)
- `item` — Statement type (`"income_statement"`, `"balance_sheet"`, `"cash_flow"`, `"valuation"`) or a specific sub-item (e.g., `"TotalRevenue"`)
- `interval` — `"annual"`, `"quarterly"`, or `"monthly"`
- `startdt`, `enddt` — Date range (`Date`, `DateTime`, or `"yyyy-mm-dd"` string)
- `timeout` — HTTP timeout in seconds

# Returns
A [`FundamentalData`](@ref) struct (implements `Tables.jl`).

# Examples
```julia
julia> fundamentals("AAPL", "income_statement", "quarterly", "2022-01-01", "2023-01-01")
FundamentalData("AAPL", 4 rows × 35 columns)

julia> using DataFrames
julia> fundamentals("AAPL", "TotalRevenue", "quarterly", "2022-01-01", "2023-01-01") |> DataFrame
```
"""
function fundamentals(symbol::AbstractString, item::AbstractString, interval::AbstractString, startdt, enddt; timeout::Int=10)
    symbol = _validated_symbol(symbol)

    start_unix = _date_to_unix(startdt)
    end_unix = _date_to_unix(enddt)

    @assert interval in FUNDAMENTAL_INTERVALS "Invalid interval '$interval'. Choose from: $(join(FUNDAMENTAL_INTERVALS, ", "))"

    # Determine if requesting entire statement or single item
    if haskey(FUNDAMENTAL_TYPES, item)
        entire_statement = true
        query_items = join(string.(interval, FUNDAMENTAL_TYPES[item]), ",")
    else
        entire_statement = false
        all_items = vcat(values(FUNDAMENTAL_TYPES)...)
        @assert item in all_items "Invalid item '$item'. View valid items with FUNDAMENTAL_TYPES"
        query_items = string(interval, item)
    end

    q = Dict(
        "symbol" => symbol,
        "type" => query_items,
        "period1" => start_unix,
        "period2" => end_unix,
        "formatted" => "false"
    )
    url = _build_url("https://query2.finance.yahoo.com/ws/fundamentals-timeseries/v1/finance/timeseries/$(symbol)", q)
    resp = _yahoo_request(url, symbol; timeout)
    res = JSON.parse(String(copy(resp.body)))["timeseries"]["result"]

    if entire_statement
        return _parse_fundamental_statement(res, symbol, interval)
    else
        return _parse_fundamental_item(res, symbol, item, query_items)
    end
end

function _parse_fundamental_statement(res, symbol, interval)
    result = OrderedDict{String, Vector}()

    for entry in res
        haskey(entry, "timestamp") || continue
        timestamp = unix2datetime.(entry["timestamp"])
        k = entry["meta"]["type"][1]
        values_vec = Any[]
        for j in Base.values(entry[k])
            push!(values_vec, j["reportedValue"]["raw"])
        end
        result["timestamp"] = timestamp
        result[replace(k, r"^(quarterly|annual|monthly)" => "")] = values_vec
    end

    return FundamentalData(symbol, result)
end

function _parse_fundamental_item(res, symbol, item, query_items)
    if isempty(res) || !haskey(res[1], query_items)
        throw(YFinanceError(symbol, "No data available for item '$item'", nothing))
    end

    values_vec = Any[]
    for i in Base.values(res[1][query_items])
        push!(values_vec, i["reportedValue"]["raw"])
    end

    result = OrderedDict{String, Vector}(
        "timestamp" => unix2datetime.(res[1]["timestamp"]),
        item => values_vec
    )
    return FundamentalData(symbol, result)
end
