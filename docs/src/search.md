# Search & News

## Symbol Search

```@docs
search_symbols
```

### Examples

```julia
using YFinance

results = search_symbols("microsoft")
results[1].symbol    # "MSFT"
results[1].name      # "Microsoft Corporation"
results[1].exchange  # "NASDAQ (NMS)"
```

## News Search

```@docs
search_news
```

### Examples

```julia
using YFinance

news = search_news("AAPL")
titles(news)       # Vector of headlines
links(news)        # Vector of URLs
timestamps(news)   # Vector of DateTime

# Different language
search_news("TSLA", lang="de")
```

## Helper Functions

```@docs
titles
links
timestamps
```

## Types

```@docs
SearchResult
SearchResults
NewsItem
NewsResults
```
