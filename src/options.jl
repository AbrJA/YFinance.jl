# ─────────────────────────────────────────────────────────────────────────────
# options.jl — Options chain data retrieval
# ─────────────────────────────────────────────────────────────────────────────

"""
    get_options(symbol; throw_error=false, expdate=nothing) -> OptionChain

Fetch options chain from Yahoo Finance. Returns an `OptionChain` struct
(Tables.jl compatible — pipe to DataFrame for tabular view).

# Arguments
- `symbol::String` — Ticker symbol (e.g. "AAPL")
- `throw_error::Bool=false` — Throw on errors vs return empty OptionChain
- `expdate::Union{Date,Nothing}=nothing` — Filter by expiration date

# Examples
```julia
chain = get_options("AAPL")
chain.calls  # Vector{OptionContract}
chain.puts   # Vector{OptionContract}

using DataFrames
get_options("AAPL") |> DataFrame  # All contracts as table
```
"""
function get_options(symbol::String; throw_error::Bool=false,
                     expdate::Union{Date,Nothing}=nothing)
    _ensure_session!()
    if isempty(_SESSION.crumb)
        @warn "Options require a crumb which could not be retrieved."
        return OptionChain(symbol, OptionContract[], OptionContract[])
    end

    params = Dict{String,String}("formatted" => "false", "crumb" => _SESSION.crumb)
    if !isnothing(expdate)
        params["date"] = string(_to_unix(expdate))
    end

    url = _build_url("https://query2.finance.yahoo.com/v7/finance/options/$symbol", params)
    resp = _yahoo_get(url, symbol; timeout=10, throw_error)
    isnothing(resp) && return OptionChain(symbol, OptionContract[], OptionContract[])

    return _parse_options(resp.body, symbol)
end

function _parse_options(body::Vector{UInt8}, symbol::String)
    parsed = JSON.parse(String(copy(body)))
    chain_result = get(get(parsed, "optionChain", Dict()), "result", [])

    if isempty(chain_result) || isempty(get(chain_result[1], "options", []))
        return OptionChain(symbol, OptionContract[], OptionContract[])
    end

    options = chain_result[1]["options"][1]
    calls = _parse_contracts(get(options, "calls", []), "call")
    puts = _parse_contracts(get(options, "puts", []), "put")
    return OptionChain(symbol, calls, puts)
end

function _parse_contracts(raw::Vector, type::String)::Vector{OptionContract}
    contracts = Vector{OptionContract}(undef, length(raw))
    for (i, c) in enumerate(raw)
        contracts[i] = OptionContract(
            string(get(c, "contractSymbol", "")),
            Float64(get(c, "strike", 0)),
            string(get(c, "currency", "USD")),
            Float64(get(c, "lastPrice", 0)),
            Float64(get(c, "change", 0)),
            Float64(get(c, "percentChange", 0)),
            haskey(c, "volume") ? Int(c["volume"]) : missing,
            haskey(c, "openInterest") ? Int(c["openInterest"]) : missing,
            Float64(get(c, "bid", 0)),
            Float64(get(c, "ask", 0)),
            string(get(c, "contractSize", "REGULAR")),
            unix2datetime(get(c, "expiration", 0)),
            unix2datetime(get(c, "lastTradeDate", 0)),
            Float64(get(c, "impliedVolatility", 0)),
            Bool(get(c, "inTheMoney", false)),
            type,
        )
    end
    return contracts
end
