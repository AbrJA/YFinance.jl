# ─────────────────────────────────────────────────────────────────────────────
# validation.jl — Symbol validation
# ─────────────────────────────────────────────────────────────────────────────

"""
    is_valid_symbol(symbol::AbstractString) -> Bool

Check whether a ticker symbol is valid on Yahoo Finance.
Makes a lightweight chart request — returns `true` if HTTP 200, `false` otherwise.

# Example
```julia
julia> is_valid_symbol("AAPL")
true

julia> is_valid_symbol("XYZNOTREAL")
false
```
"""
function is_valid_symbol(symbol::AbstractString)::Bool
    try
        q = Dict("range" => "1d", "interval" => "1d")
        url = _build_url("$(_BASE_URL)/v8/finance/chart/$(symbol)", q)
        _ensure_session!()
        headers = _build_headers(_SESSION.cookie)
        _throttle!()
        resp = _raw_request(url; headers=headers, timeout=10, throw_on_error=false)
        return resp.status == 200
    catch
        return false
    end
end

"""
    valid_symbols(symbols::AbstractVector{<:AbstractString}) -> Vector{String}

Filter a vector of symbols, returning only those that are valid.

# Example
```julia
julia> valid_symbols(["AAPL", "INVALID", "MSFT"])
2-element Vector{String}:
 "AAPL"
 "MSFT"
```
"""
function valid_symbols(symbols::AbstractVector{<:AbstractString})::Vector{String}
    return [s for s in symbols if is_valid_symbol(s)]
end

"""
    _validated_symbol(symbol::AbstractString) -> String

Internal helper. Returns the symbol if valid, throws `YFinanceError` otherwise.
"""
function _validated_symbol(symbol::AbstractString)::String
    is_valid_symbol(symbol) || throw(YFinanceError(symbol, "Invalid symbol: $symbol", nothing))
    return String(symbol)
end
