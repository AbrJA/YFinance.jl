# ─────────────────────────────────────────────────────────────────────────────
# news.jl — Yahoo Finance news search
# ─────────────────────────────────────────────────────────────────────────────

const _NEWS_LANGUAGES = Dict{String,Tuple{String,String}}(
    "en-us"  => ("en-US", "US"),
    "en-ca"  => ("en-CA", "CA"),
    "en-gb"  => ("en-GB", "GB"),
    "en-au"  => ("en-AU", "AU"),
    "en-nz"  => ("en-NZ", "NZ"),
    "en-sg"  => ("en-SG", "SG"),
    "en-in"  => ("en-IN", "IN"),
    "de"     => ("de-DE", "DE"),
    "es"     => ("es-ES", "ES"),
    "fr"     => ("fr-FR", "FR"),
    "it"     => ("it-IT", "IT"),
    "pt-br"  => ("pt-BR", "BR"),
    "zh"     => ("zh-Hant-HK", "HK"),
    "zh-tw"  => ("zh-TW", "TW"),
)

"""
    search_news(query::String; lang="en-us", timeout=10) -> NewsResults

Search for news articles related to a symbol or topic.

# Arguments
- `query` — Search term (typically a ticker symbol)
- `lang` — Language/region code. Supported: $(join(sort(collect(keys(_NEWS_LANGUAGES))), ", "))
- `timeout` — HTTP timeout in seconds

# Returns
A [`NewsResults`](@ref) (AbstractVector of [`NewsItem`](@ref)).

# Example
```julia
julia> search_news("AAPL")
5-element NewsResults:
  Title:     Apple Reports Record Revenue...
  ...
```
"""
function search_news(query::String; lang::String="en-us", timeout::Int=10)::NewsResults
    haskey(_NEWS_LANGUAGES, lang) || throw(ArgumentError(
        "Language '$lang' not supported. Choose from: $(join(sort(collect(keys(_NEWS_LANGUAGES))), ", "))"
    ))

    lang_code, region = _NEWS_LANGUAGES[lang]
    params = Dict("q" => query, "lang" => lang_code, "region" => region)
    url = _build_url("https://query2.finance.yahoo.com/v1/finance/search", params)
    resp = _yahoo_request(url, query; timeout)
    parsed = JSON.parse(String(copy(resp.body)))
    news_data = get(parsed, "news", [])

    items = NewsItem[]
    sizehint!(items, length(news_data))
    for article in news_data
        title = string(get(article, "title", ""))
        publisher = string(get(article, "publisher", ""))
        link = string(get(article, "link", ""))
        ts = unix2datetime(get(article, "providerPublishTime", 0))
        symbols = haskey(article, "relatedTickers") ? String.(article["relatedTickers"]) : String[]
        push!(items, NewsItem(title, publisher, link, ts, symbols))
    end
    return NewsResults(items)
end
