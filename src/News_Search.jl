# ─────────────────────────────────────────────────────────────────────────────
# News_Search.jl — Yahoo Finance news search
# ─────────────────────────────────────────────────────────────────────────────

"""
    NewsItem

A single news article from Yahoo Finance.

# Fields
- `title::String` — Article title
- `publisher::String` — Publisher name
- `link::String` — URL to the article
- `timestamp::DateTime` — Publication time
- `symbols::Vector{String}` — Related ticker symbols
"""
struct NewsItem
    title::String
    publisher::String
    link::String
    timestamp::DateTime
    symbols::Vector{String}
end

"""
    YahooNews <: AbstractVector{NewsItem}

A collection of news articles. Behaves as an `AbstractVector`.
"""
struct YahooNews <: AbstractVector{NewsItem}
    items::Vector{NewsItem}
end

Base.size(x::YahooNews) = size(x.items)
Base.getindex(x::YahooNews, i::Int) = x.items[i]
Base.IndexStyle(::Type{YahooNews}) = IndexLinear()

"""
    titles(x::YahooNews) -> Vector{String}

Extract all article titles.
"""
titles(x::YahooNews)::Vector{String} = [item.title for item in x.items]

"""
    links(x::YahooNews) -> Vector{String}

Extract all article links.
"""
links(x::YahooNews)::Vector{String} = [item.link for item in x.items]

"""
    timestamps(x::YahooNews) -> Vector{DateTime}

Extract all article timestamps.
"""
timestamps(x::YahooNews)::Vector{DateTime} = [item.timestamp for item in x.items]

function Base.show(io::IO, x::NewsItem)
    str = join(x.symbols, ", ")
    println(io, "Title:\t\t $(x.title)")
    println(io, "Timestamp:\t $(Dates.format(x.timestamp, "u d HH:MM p"))")
    println(io, "Publisher:\t $(x.publisher)")
    println(io, "Link:\t\t $(x.link)")
    println(io, "Symbols:\t $(str)")
end

function Base.show(io::IO, ::MIME"text/plain", x::YahooNews)
    print(io, "$(length(x))-element YahooNews:")
    for item in x.items
        println(io)
        show(io, item)
    end
end

# ─── Supported Languages ─────────────────────────────────────────────────────

const _NEWS_LANGUAGES = Dict{String,Tuple{String,String}}(
    "en-us" => ("en-US", "US"),
    "en-ca" => ("en-CA", "ca"),
    "en-gb" => ("en-GB", "GB"),
    "en-au" => ("en-AU", "AU"),
    "en-nz" => ("en-NZ", "NZ"),
    "en-SG" => ("en-SG", "SG"),
    "en-in" => ("en-IN", "IN"),
    "de"    => ("de-DE", "DE"),
    "es"    => ("es-ES", "ES"),
    "fr"    => ("fr-FR", "FR"),
    "it"    => ("it_IT", "IT"),
    "pt-br" => ("pt-BR", "BR"),
    "zh"    => ("zh-Hant-HK", "HK"),
    "zh-tw" => ("zh-TW", "TW"),
)

"""
    search_news(query::String; lang="en-us") -> YahooNews

Search for news articles related to a symbol or topic.

# Arguments
- `query::String` — Search term (typically a ticker symbol)
- `lang::String` — Language/region. Supported: $(join(sort(collect(keys(_NEWS_LANGUAGES))), ", "))

# Returns
A `YahooNews` (AbstractVector of `NewsItem`).
"""
function search_news(query::String; lang::String="en-us")::YahooNews
    haskey(_NEWS_LANGUAGES, lang) || throw(ArgumentError(
        "Language '$lang' not supported. Choose from: $(join(sort(collect(keys(_NEWS_LANGUAGES))), ", "))"
    ))

    lang_code, region = _NEWS_LANGUAGES[lang]
    params = Dict("q" => query, "lang" => lang_code, "region" => region)
    url = _build_url("https://query2.finance.yahoo.com/v1/finance/search", params)
    resp = _yahoo_get(url, query; timeout=10, throw_error=true)
    parsed = JSON3.read(resp.body)
    news_data = get(parsed, :news, [])

    items = NewsItem[]
    sizehint!(items, length(news_data))
    for article in news_data
        title = string(get(article, :title, ""))
        publisher = string(get(article, :publisher, ""))
        link = string(get(article, :link, ""))
        ts = unix2datetime(get(article, :providerPublishTime, 0))
        symbols = haskey(article, :relatedTickers) ? String.(article.relatedTickers) : String[]
        push!(items, NewsItem(title, publisher, link, ts, symbols))
    end
    return YahooNews(items)
end
