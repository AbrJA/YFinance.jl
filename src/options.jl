# ─────────────────────────────────────────────────────────────────────────────
# options.jl — Options chain data retrieval
# ─────────────────────────────────────────────────────────────────────────────

"""
    options(symbol::String; expiration_date=nothing, timeout=10) -> OptionsChain

Retrieve options chain data from Yahoo Finance.

# Arguments
- `symbol` — Ticker symbol (e.g., `"AAPL"`)
- `expiration_date` — Specific expiration date (`Date` or `nothing` for nearest)
- `timeout` — HTTP timeout in seconds

# Returns
An [`OptionsChain`](@ref) with `.calls` and `.puts` fields (each implements `Tables.jl`).

# Examples
```julia
julia> chain = options("AAPL")
OptionsChain("AAPL", 72 calls, 69 puts)

julia> using DataFrames
julia> chain.calls |> DataFrame
julia> chain.puts |> DataFrame
```
"""
function options(symbol::String; expiration_date::Union{Date,Nothing}=nothing, timeout::Int=10)
    _ensure_session!()

    symbol = String(symbol)

    query_params = Dict("formatted" => "false", "crumb" => _SESSION.crumb)
    if !isnothing(expiration_date)
        query_params["date"] = string(_date_to_unix(expiration_date))
    end

    url = _build_url("https://query2.finance.yahoo.com/v7/finance/options/$(symbol)", query_params)
    resp = _yahoo_request(url, symbol; timeout)
    return _parse_options_response(resp.body, symbol)
end

const _OPTION_COLUMNS = [
    "contractSymbol", "strike", "currency", "lastPrice", "change",
    "percentChange", "volume", "openInterest", "bid", "ask",
    "contractSize", "expiration", "lastTradeDate", "impliedVolatility", "inTheMoney", "type"
]

function _parse_options_response(body, symbol)
    res = JSON.parse(String(copy(body)))
    option_data = res["optionChain"]["result"][1]["options"][1]
    puts_raw = option_data["puts"]
    calls_raw = option_data["calls"]

    calls = _parse_option_side(calls_raw, "call")
    puts = _parse_option_side(puts_raw, "put")

    return OptionsChain(symbol, calls, puts)
end

function _parse_option_side(raw_data, side_type::String)
    data = OrderedDict{String, Vector}(
        "contractSymbol" => Any[],
        "strike" => Any[],
        "currency" => Any[],
        "lastPrice" => Any[],
        "change" => Any[],
        "percentChange" => Any[],
        "volume" => Any[],
        "openInterest" => Any[],
        "bid" => Any[],
        "ask" => Any[],
        "contractSize" => Any[],
        "expiration" => Any[],
        "lastTradeDate" => Any[],
        "impliedVolatility" => Any[],
        "inTheMoney" => Any[],
        "type" => Any[],
    )

    for entry in raw_data
        for col in keys(data)
            if col == "type"
                push!(data[col], side_type)
            elseif !haskey(entry, col)
                push!(data[col], missing)
            elseif col in ("expiration", "lastTradeDate")
                push!(data[col], unix2datetime(entry[col]))
            else
                push!(data[col], entry[col])
            end
        end
    end

    return OptionSide(data)
end
