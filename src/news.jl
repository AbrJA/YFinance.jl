# ─────────────────────────────────────────────────────────────────────────────
# news.jl — News search
# ─────────────────────────────────────────────────────────────────────────────

const _NEWS_LANGS = Dict{String,Tuple{String,String}}(
    "en-us" => ("en-US", "US"), "en-ca" => ("en-CA", "CA"),
    "en-gb" => ("en-GB", "GB"), "en-au" => ("en-AU", "AU"),
    "en-nz" => ("en-NZ", "NZ"), "en-sg" => ("en-SG", "SG"),
    "en-in" => ("en-IN", "IN"), "de" => ("de-DE", "DE"),
    "es" => ("es-ES", "ES"), "fr" => ("fr-FR", "FR"),
    "it" => ("it-IT", "IT"), "pt-br" => ("pt-BR", "BR"),
    "zh" => ("zh-Hant-HK", "HK"), "zh-tw" => ("zh-TW", "TW"),
)

"""
    search_news(query; lang="en-us", throw_error=false) -> NewsResults

Search for news articles related to a symbol or topic.

# Arguments
- `query::String` — Search term (ticker or keyword)
- `lang::String` — Language/region code. Supported: $(join(sort(collect(keys(_NEWS_LANGS))), ", "))
- `throw_error::Bool=false` — Throw on errors vs return empty NewsResults

# Examples
```julia
news = search_news("AAPL")
titles(news)   # Vector of headline strings
links(news)    # Vector of URLs
```
"""
function search_news(query::String; lang::String="en-us", throw_error::Bool=false)::NewsResults
    haskey(_NEWS_LANGS, lang) || throw(ArgumentError(
        "Unsupported language '$lang'. Options: $(join(sort(collect(keys(_NEWS_LANGS))), ", "))"
    ))

    lang_code, region = _NEWS_LANGS[lang]
    params = Dict("q" => query, "lang" => lang_code, "region" => region)
    url = _build_url("https://query2.finance.yahoo.com/v1/finance/search", params)
    resp = _yahoo_get(url, query; timeout=10, throw_error)
    isnothing(resp) && return NewsResults(NewsItem[])

    parsed = JSON.parse(String(copy(resp.body)))

    items = NewsItem[]
    for a in get(parsed, "news", [])
        push!(items, NewsItem(
            string(get(a, "title", "")),
            string(get(a, "publisher", "")),
            string(get(a, "link", "")),
            unix2datetime(get(a, "providerPublishTime", 0)),
            haskey(a, "relatedTickers") ? String.(a["relatedTickers"]) : String[],
        ))
    end
    return NewsResults(items)
end
