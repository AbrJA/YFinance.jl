"""
    get_options(symbol::String; throw_error=false, expiration_date=nothing)

Fetch options data from Yahoo Finance.

Returns an `OrderedDict` with "calls" and "puts" entries, each an `OrderedDict`
that can be piped to `DataFrame`.

# Arguments
- `symbol::String` — Ticker symbol (e.g. "AAPL", "^GSPC")
- `throw_error::Bool` — If `true`, throws on invalid symbol. Default: `false`.
- `expiration_date::Union{Date,Nothing}` — Filter by expiration date. Default: `nothing`.

# Examples
```julia-repl
julia> get_Options("AAPL")
OrderedDict{String, OrderedDict{String, Vector{Any}}} with 2 entries:
  "calls" => OrderedDict("contractSymbol"=>["AAPL221230C00050000", "AAPL221230C00055000",…
  "puts"  => OrderedDict("contractSymbol"=>["AAPL221230P00050000", "AAPL221230P00055000",…

julia> using DataFrames
julia> get_Options("AAPL")["calls"] |> DataFrame
72×16 DataFrame
 Row │ contractSymbol       strike  currency  lastPrice  change  percentChange  volume   ⋯
     │ Any                  Any     Any       Any        Any     Any            Any      ⋯
─────┼────────────────────────────────────────────────────────────────────────────────────
   1 │ AAPL221230C00050000  50      USD       79.85      0       0              1        ⋯
   2 │ AAPL221230C00055000  55      USD       72.85      0       0              1
   3 │ AAPL221230C00060000  60      USD       66.4       0       0              19
  ⋮  │          ⋮             ⋮        ⋮          ⋮        ⋮           ⋮           ⋮     ⋱
  71 │ AAPL221230C00230000  230     USD       0.02       0       0              missing
  72 │ AAPL221230C00250000  250     USD       0.01       0       0              2        ⋯
                                                             9 columns and 67 rows omitted

julia> using DataFrames
julia> data  = get_Options("AAPL");
julia> vcat( [DataFrame(i) for i in values(data)]...)
141×16 DataFrame
 Row │ contractSymbol       strike  currency  lastPrice  change  percentChange  volume   ⋯
     │ Any                  Any     Any       Any        Any     Any            Any      ⋯
─────┼────────────────────────────────────────────────────────────────────────────────────
   1 │ AAPL221230C00050000  50      USD       79.85      0       0              1        ⋯
   2 │ AAPL221230C00055000  55      USD       72.85      0       0              1
   3 │ AAPL221230C00060000  60      USD       66.4       0       0              19
  ⋮  │          ⋮             ⋮        ⋮          ⋮        ⋮           ⋮          ⋮      ⋱
 140 │ AAPL221230P00225000  225     USD       94.65      0       0              1
 141 │ AAPL221230P00230000  230     USD       99.65      0       0              1        ⋯
                                                            9 columns and 136 rows omitted
```
"""
function get_options(symbol::String; throw_error::Bool=false, expiration_date::Union{Date,Nothing}=nothing)
    _ensure_session!()
    if isempty(_SESSION.crumb)
        @warn "This item requires a crumb but a crumb could not be successfully retrieved!"
        return nothing
    end

    # Construct API request
    query_params = Dict("formatted" => "false", "crumb" => _SESSION.crumb)
    if !isnothing(expiration_date)
        query_params["date"] = string(_date_to_unix(expiration_date))
    end

    url = _build_url("https://query2.finance.yahoo.com/v7/finance/options/$(symbol)", query_params)
    resp = _yahoo_get(url, symbol; timeout=10, throw_error=throw_error)
    isnothing(resp) && return OrderedCollections.OrderedDict()

    res = JSON.parse(String(copy(resp.body)))
    result_data = get(get(res, "optionChain", Dict()), "result", [])
    if isempty(result_data) || isempty(get(result_data[1], "options", []))
        return OrderedCollections.OrderedDict()
    end
    puts = result_data[1]["options"][1]["puts"]
    calls = result_data[1]["options"][1]["calls"]
    res_p = OrderedCollections.OrderedDict(
        "contractSymbol"=> [],
        "strike"=> [],
        "currency"=> [],
        "lastPrice"=> [],
        "change"=> [],
        "percentChange"=> [],
        "volume"=> [],
        "openInterest"=> [],
        "bid"=> [],
        "ask"=> [],
        "contractSize"=> [],
        "expiration"=> [],
        "lastTradeDate"=> [],
        "impliedVolatility"=> [],
        "inTheMoney"=> []
        )
    res_c = OrderedCollections.OrderedDict(
        "contractSymbol"=> [],
        "strike"=> [],
        "currency"=> [],
        "lastPrice"=> [],
        "change"=> [],
        "percentChange"=> [],
        "volume"=> [],
        "openInterest"=> [],
        "bid"=> [],
        "ask"=> [],
        "contractSize"=> [],
        "expiration"=> [],
        "lastTradeDate"=> [],
        "impliedVolatility"=> [],
        "inTheMoney"=> []
        )

    for i in eachindex(puts)
        for j in keys(res_p)
            if !in(j, keys(puts[i]))
                push!(res_p[j], missing)
            else
                if in(j, ["expiration","lastTradeDate"])
                push!(res_p[j], unix2datetime(puts[i][j]))
                else
                    push!(res_p[j], puts[i][j])
                end
            end
        end
    end
    for i in eachindex(calls)
        for j in keys(res_c)
            if !in(j, keys(calls[i]))
                push!(res_c[j], missing)
            else
                if in(j, ["expiration","lastTradeDate"])
                    push!(res_c[j], unix2datetime(calls[i][j]))
                    else
                        push!(res_c[j], calls[i][j])
                    end
            end
        end
    end
    res_c["type"] = repeat(["call"], length(res_c["strike"]))
    res_p["type"] = repeat(["put"], length(res_p["strike"]))
    return OrderedCollections.OrderedDict("calls" => res_c, "puts" => res_p)
end

