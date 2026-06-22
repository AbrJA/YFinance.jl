# ─────────────────────────────────────────────────────────────────────────────
# validate.jl — Symbol validation
# ─────────────────────────────────────────────────────────────────────────────

"""
    is_valid_symbol(symbol::AbstractString) -> Bool

Check if a ticker symbol exists on Yahoo Finance.
"""
function is_valid_symbol(symbol::AbstractString)::Bool
    try
        url = _build_url("$(_BASE_URL)/v8/finance/chart/$symbol", Dict("range" => "1d", "interval" => "1d"))
        resp = _request(url; timeout=10, throw_on_error=false)
        return resp.status == 200
    catch
        return false
    end
end

"""
    valid_symbols(symbols) -> Vector{String}

Filter symbols, returning only valid ones.

# Arguments
- `symbols::AbstractVector{<:AbstractString}` — Tickers to validate
- `symbols::AbstractString` — Single ticker (returns 0 or 1 element vector)
"""
valid_symbols(s::AbstractString) = is_valid_symbol(s) ? [s] : String[]
valid_symbols(ss::AbstractVector{<:AbstractString}) = filter(is_valid_symbol, ss)
