"""
    is_valid_symbol(symbol::AbstractString)

Check if a ticker symbol is valid. Returns `true` if valid, `false` otherwise.

# Arguments
- `symbol::AbstractString` — A ticker (e.g. "AAPL", "^GSPC")
"""
function is_valid_symbol(symbol::AbstractString)
    try
        q = Dict("range"=>"1d", "interval"=>"1d")
        url = _build_url("$(_BASE_URL)/v8/finance/chart/$(symbol)", q)
        resp = _request(url; timeout=10, throw_on_error=false)
        return resp.status == 200
    catch
        return false
    end
end

"""
    valid_symbols(symbol::AbstractString)

If the symbol is valid, returns it in a vector; otherwise returns an empty vector.

# Arguments
- `symbol::AbstractString` — A ticker (e.g. "AAPL", "^GSPC")
"""
function valid_symbols(symbol::AbstractString)
    valid = is_valid_symbol(symbol)
    return valid ? [symbol] : String[]
end

"""
    valid_symbols(symbols::AbstractVector{<:AbstractString})

Filter a vector of symbols, returning only the valid ones.

# Arguments
- `symbols::AbstractVector{<:AbstractString}` — Vector of tickers
"""
function valid_symbols(symbols::AbstractVector{<:AbstractString})
    idx = collect(is_valid_symbol.(symbols))
    return symbols[idx]
end
