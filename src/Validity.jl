"""
    validate_symbol(symbol::AbstractString)

Validates a Symbol (Ticker). Returns `true` if the ticker is valid and `false` if the ticker is not valid.

# Arguments

 * smybol`::String` is a ticker (e.g. AAPL for Apple Computers, or ^GSPC for the S&P500)  

# How it works

Checks if the HTTP request works (status 200) or whether the request errors (common status in this case: 404)    

"""
function validate_symbol(symbol::AbstractString)
    _set_cookies_and_crumb()
    res = try
        q = Dict("range"=>"1d", "interval"=>"1d")
        url = _build_url("https://query2.finance.yahoo.com/v8/finance/chart/$(symbol)", q)
        headers = _make_headers(; cookies=_COOKIE)
        resp = _request(url; headers=headers, timeout=10, throw_on_error=false)
        resp.status
    catch e 
        0
    end #end try
        return isequal(res,200) ? true : false
end #end validate_symbol

"""
    get_valid_symbols(symbol::AbstractString)

Takes a symbol. If the symbol is valid it returns the symbol in a vector if not it returns and empy vector.

# Arguments

 * smybol`::AbstractString` is a ticker (e.g. AAPL for Apple Computers, or ^GSPC for the S&P500)  

# Examples

```julia-repl
julia> get_valid_symbols("AAPL")
1-element Vector{String}:
 "AAPL"

julia> get_valid_symbols("asdfs")
 String[]
```

"""
function get_valid_symbols(symbol::AbstractString)
    valid = validate_symbol(symbol)
    return  valid ? [symbol] : String[]
end #end get_valid_symbols


"""
    get_valid_symbols(symbol::AbstractVector{<:AbstractString})

Takes a `AbstractVector` of symbols and returns only the valid ones.

# Arguments

 * smybol`::AbstractVector{<:AbstractString}` is a vector of tickers (e.g. AAPL for Apple Computers, or ^GSPC for the S&P500)  

# Examples

```julia-repl
julia> get_valid_symbols("AAPL","AMD","asdfs")
2-element Vector{String}:
 "AAPL"
 "AMD"
```

"""
function get_valid_symbols(symbol::AbstractVector{<:AbstractString})
    idx = collect(validate_symbol.(symbol))
    return  symbol[idx]
end #end get_valid_symbols
