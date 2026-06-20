# ─────────────────────────────────────────────────────────────────────────────
# Search_Symbol.jl — Symbol search and market listing
# ─────────────────────────────────────────────────────────────────────────────

const MARKETS = ("AMEX", "NASDAQ", "NYSE", "SZSE")

"""
    get_all_symbols(market::String) -> Vector{String}

Fetch all ticker symbols from a given market.

# Supported markets
`AMEX`, `NASDAQ`, `NYSE`, `SZSE`

# Example
```julia
julia> get_all_symbols("NYSE")
3127-element Vector{String}:
 "A"
 "AA"
 ⋮
```
"""
function get_all_symbols(market::AbstractString)::Vector{String}
    uppercase(market) in MARKETS || throw(ArgumentError("Invalid market '$(market)'. Supported: $(join(MARKETS, ", "))"))
    url = "https://dumbstockapi.com/stock?format=tickers-only&exchange=$market"
    resp = _yahoo_get(url, market; timeout=10, throw_error=true)
    raw = String(resp.body)
    # Response is JSON array: ["SYM1","SYM2",...]
    symbols = split(raw, ',')
    # Strip brackets and quotes
    return [replace(s, r"[\[\]\"]" => "") for s in symbols]
end

# ─── Search Item Struct ───────────────────────────────────────────────────────

"""
    YahooSearchItem

A single search result from Yahoo Finance symbol search.

# Fields
- `symbol::String` — Ticker symbol
- `shortname::String` — Short display name
- `exchange::String` — Exchange name
- `quoteType::String` — Asset type (EQUITY, FUTURE, ETF, etc.)
- `sector::String` — Sector (equity only, empty otherwise)
- `industry::String` — Industry (equity only, empty otherwise)
"""
struct YahooSearchItem
    symbol::String
    shortname::String
    exchange::String
    quoteType::String
    sector::String
    industry::String
end

"""
    YahooSearch <: AbstractVector{YahooSearchItem}

A collection of search results. Behaves as an `AbstractVector`.
"""
struct YahooSearch <: AbstractVector{YahooSearchItem}
    items::Vector{YahooSearchItem}
end

Base.size(x::YahooSearch) = size(x.items)
Base.getindex(x::YahooSearch, i::Int) = x.items[i]
Base.IndexStyle(::Type{YahooSearch}) = IndexLinear()

function Base.show(io::IO, item::YahooSearchItem)
    println(io)
    println(io, "Symbol:\t $(item.symbol)")
    println(io, "Name:\t $(item.shortname)")
    println(io, "Type:\t $(item.quoteType)")
    println(io, "Exch.:\t $(item.exchange)")
    if !isempty(item.sector)
        println(io, "Sec.:\t $(item.sector)")
        println(io, "Ind.:\t $(item.industry)")
    end
end

function Base.show(io::IO, ::MIME"text/plain", x::YahooSearch)
    print(io, "$(length(x))-element YahooSearch:")
    for item in x.items
        show(io, item)
    end
end

# ─── Search Function ─────────────────────────────────────────────────────────

"""
    get_symbols(search_term::String) -> YahooSearch

Search for securities by name or keyword.

# Arguments
- `search_term::String` — Company name, ticker, or keyword (e.g., "microsoft", "micro")

# Returns
A `YahooSearch` (AbstractVector of `YahooSearchItem`).

# Example
```julia
julia> get_symbols("micro")
7-element YahooSearch:
Symbol:  MSFT
Name:    Microsoft Corporation
Type:    EQUITY
...
```
"""
function get_symbols(search_term::String)::YahooSearch
    url = _build_url("https://query2.finance.yahoo.com/v1/finance/search", Dict("q" => search_term))
    resp = _yahoo_get(url, search_term; timeout=10, throw_error=true)
    parsed = JSON3.read(resp.body)
    quotes = get(parsed, :quotes, [])

    items = YahooSearchItem[]
    sizehint!(items, length(quotes))
    for q in quotes
        symbol = string(get(q, :symbol, ""))
        shortname = string(get(q, :shortname, ""))
        exchange = "$(get(q, :exchDisp, "")) ($(get(q, :exchange, "")))"
        quoteType = string(get(q, :quoteType, ""))
        sector = string(get(q, :sector, ""))
        industry = string(get(q, :industry, ""))
        push!(items, YahooSearchItem(symbol, shortname, exchange, quoteType, sector, industry))
    end
    return YahooSearch(items)
end
