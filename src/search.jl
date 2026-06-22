# ─────────────────────────────────────────────────────────────────────────────
# search.jl — Symbol search
# ─────────────────────────────────────────────────────────────────────────────

"""
    search_symbols(query::String; throw_error=false) -> SearchResults

Search for securities by name, ticker, or keyword.

# Examples
```julia
results = search_symbols("microsoft")
results[1].symbol  # "MSFT"
results[1].name    # "Microsoft Corporation"
```
"""
function search_symbols(query::String; throw_error::Bool=false)::SearchResults
    url = _build_url("https://query2.finance.yahoo.com/v1/finance/search", Dict("q" => query))
    resp = _yahoo_get(url, query; timeout=10, throw_error)
    isnothing(resp) && return SearchResults(SearchResult[])

    parsed = JSON.parse(String(copy(resp.body)))
    quotes = get(parsed, "quotes", [])

    items = SearchResult[]
    sizehint!(items, length(quotes))
    for q in quotes
        push!(items, SearchResult(
            string(get(q, "symbol", "")),
            string(get(q, "shortname", "")),
            "$(get(q, "exchDisp", "")) ($(get(q, "exchange", "")))",
            string(get(q, "quoteType", "")),
            string(get(q, "sector", "")),
            string(get(q, "industry", "")),
        ))
    end
    return SearchResults(items)
end
