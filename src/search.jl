# ─────────────────────────────────────────────────────────────────────────────
# search.jl — Symbol search
# ─────────────────────────────────────────────────────────────────────────────

"""
    search_symbols(query::String; timeout=10) -> SearchResults

Search for securities by name or keyword on Yahoo Finance.

# Arguments
- `query` — Company name, ticker, or keyword (e.g., `"microsoft"`, `"tech"`)
- `timeout` — HTTP timeout in seconds

# Returns
A [`SearchResults`](@ref) (AbstractVector of [`SearchResult`](@ref)).

# Example
```julia
julia> search_symbols("microsoft")
7-element SearchResults:
  Symbol:   MSFT
  Name:     Microsoft Corporation
  Type:     EQUITY
  Exchange: NASDAQ (NMS)
  ...
```
"""
function search_symbols(query::String; timeout::Int=10)::SearchResults
    url = _build_url("https://query2.finance.yahoo.com/v1/finance/search", Dict("q" => query))
    resp = _yahoo_request(url, query; timeout)
    parsed = JSON.parse(String(copy(resp.body)))
    quotes = get(parsed, "quotes", [])

    items = SearchResult[]
    sizehint!(items, length(quotes))
    for q in quotes
        sym = string(get(q, "symbol", ""))
        name = string(get(q, "shortname", ""))
        exchange = "$(get(q, "exchDisp", "")) ($(get(q, "exchange", "")))"
        quote_type = string(get(q, "quoteType", ""))
        sector = string(get(q, "sector", ""))
        industry = string(get(q, "industry", ""))
        push!(items, SearchResult(sym, name, exchange, quote_type, sector, industry))
    end
    return SearchResults(items)
end
