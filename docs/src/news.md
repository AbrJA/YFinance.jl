# News

## `search_news`

Search for news articles related to a symbol or topic. Returns a [`NewsResults`](@ref) collection.

```@docs
search_news
```

### Examples

```julia
news = search_news("AAPL")

# Access individual items
news[1].title
news[1].publisher
news[1].link
news[1].timestamp
news[1].symbols  # Related tickers

# Convenience accessors
titles(news)      # Vector{String} of headlines
links(news)       # Vector{String} of URLs
timestamps(news)  # Vector{DateTime}

# Different language/region
news_de = search_news("SAP", lang="de")
```

### `NewsItem` Fields

| Field | Type | Description |
|-------|------|-------------|
| `title` | `String` | Headline |
| `publisher` | `String` | Publisher name |
| `link` | `String` | Article URL |
| `timestamp` | `DateTime` | Publication time |
| `symbols` | `Vector{String}` | Related ticker symbols |

### Supported Languages

`"en-us"`, `"en-ca"`, `"en-gb"`, `"en-au"`, `"en-nz"`, `"en-sg"`, `"en-in"`, `"de"`, `"es"`, `"fr"`, `"it"`, `"pt-br"`, `"zh"`, `"zh-tw"`
