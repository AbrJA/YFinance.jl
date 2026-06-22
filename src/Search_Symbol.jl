# ─────────────────────────────────────────────────────────────────────────────
# Search_Symbol.jl — Symbol search
# ─────────────────────────────────────────────────────────────────────────────

# ─── Search Item Struct ───────────────────────────────────────────────────────

"""
    SearchResult

A single search result from Yahoo Finance symbol search.

# Fields
- `symbol::String` — Ticker symbol
- `shortname::String` — Short display name
- `exchange::String` — Exchange name
- `quoteType::String` — Asset type (EQUITY, FUTURE, ETF, etc.)
- `sector::String` — Sector (equity only, empty otherwise)
- `industry::String` — Industry (equity only, empty otherwise)
"""
struct SearchResult
    symbol::String
    shortname::String
    exchange::String
    quoteType::String
    sector::String
    industry::String
end

"""
    SearchResults <: AbstractVector{SearchResult}

A collection of search results. Behaves as an `AbstractVector`.
"""
struct SearchResults <: AbstractVector{SearchResult}
    items::Vector{SearchResult}
end

Base.size(x::SearchResults) = size(x.items)
Base.getindex(x::SearchResults, i::Int) = x.items[i]
Base.IndexStyle(::Type{SearchResults}) = IndexLinear()

function Base.show(io::IO, item::SearchResult)
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

function Base.show(io::IO, ::MIME"text/plain", x::SearchResults)
    print(io, "$(length(x))-element SearchResults:")
    for item in x.items
        show(io, item)
    end
end

# ─── Search Function ─────────────────────────────────────────────────────────

"""
    search_symbols(search_term::String) -> SearchResults

Search for securities by name or keyword.

# Arguments
- `search_term::String` — Company name, ticker, or keyword (e.g., "microsoft", "micro")

# Returns
A `SearchResults` (AbstractVector of `SearchResult`).
"""
function search_symbols(search_term::String)::SearchResults
    url = _build_url("https://query2.finance.yahoo.com/v1/finance/search", Dict("q" => search_term))
    resp = _yahoo_get(url, search_term; timeout=10, throw_error=true)
    parsed = JSON.parse(String(copy(resp.body)))
    quotes = get(parsed, "quotes", [])

    items = SearchResult[]
    sizehint!(items, length(quotes))
    for q in quotes
        symbol = string(get(q, "symbol", ""))
        shortname = string(get(q, "shortname", ""))
        exchange = "$(get(q, "exchDisp", "")) ($(get(q, "exchange", "")))"
        quoteType = string(get(q, "quoteType", ""))
        sector = string(get(q, "sector", ""))
        industry = string(get(q, "industry", ""))
        push!(items, SearchResult(symbol, shortname, exchange, quoteType, sector, industry))
    end
    return SearchResults(items)
end
