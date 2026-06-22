# ─────────────────────────────────────────────────────────────────────────────
# types.jl — Core types for YFinance.jl
# Using typed structs instead of Dict for type stability and performance.
# See: https://docs.julialang.org/en/v1/manual/performance-tips/
# ─────────────────────────────────────────────────────────────────────────────

# ─── Price Data ───────────────────────────────────────────────────────────────

"""
    PriceData

Typed container for OHLCV price data. Implements `Tables.jl` interface
for direct conversion to DataFrames.

# Fields
- `ticker::String`
- `timestamp::Vector{DateTime}`
- `open::Vector{Float64}`
- `high::Vector{Float64}`
- `low::Vector{Float64}`
- `close::Vector{Float64}`
- `adjclose::Vector{Float64}` — adjusted close (same as close for intraday)
- `volume::Vector{Float64}`
- `dividend::Vector{Float64}` — empty unless `divsplits=true`
- `split_ratio::Vector{Float64}` — empty unless `divsplits=true`
"""
struct PriceData
    ticker::String
    timestamp::Vector{DateTime}
    open::Vector{Float64}
    high::Vector{Float64}
    low::Vector{Float64}
    close::Vector{Float64}
    adjclose::Vector{Float64}
    volume::Vector{Float64}
    dividend::Vector{Float64}
    split_ratio::Vector{Float64}
end

function PriceData(ticker::String, n::Int)
    PriceData(ticker, DateTime[], Float64[], Float64[], Float64[],
              Float64[], Float64[], Float64[], Float64[], Float64[])
end

Base.isempty(p::PriceData) = isempty(p.timestamp)
Base.length(p::PriceData) = length(p.timestamp)

function Base.show(io::IO, ::MIME"text/plain", p::PriceData)
    n = length(p)
    print(io, "PriceData(\"$(p.ticker)\", $n rows")
    if !isempty(p.timestamp)
        print(io, ", ", first(p.timestamp), " to ", last(p.timestamp))
    end
    print(io, ")")
end

# ─── Dividend Data ────────────────────────────────────────────────────────────

"""
    DividendData

Typed container for dividend data.

# Fields
- `ticker::String`
- `timestamp::Vector{DateTime}`
- `dividend::Vector{Float64}`
"""
struct DividendData
    ticker::String
    timestamp::Vector{DateTime}
    dividend::Vector{Float64}
end

DividendData(ticker::String) = DividendData(ticker, DateTime[], Float64[])
Base.isempty(d::DividendData) = isempty(d.timestamp)
Base.length(d::DividendData) = length(d.timestamp)

# ─── Split Data ──────────────────────────────────────────────────────────────

"""
    SplitData

Typed container for stock split data.

# Fields
- `ticker::String`
- `timestamp::Vector{DateTime}`
- `numerator::Vector{Int}`
- `denominator::Vector{Int}`
- `ratio::Vector{Float64}`
"""
struct SplitData
    ticker::String
    timestamp::Vector{DateTime}
    numerator::Vector{Int}
    denominator::Vector{Int}
    ratio::Vector{Float64}
end

SplitData(ticker::String) = SplitData(ticker, DateTime[], Int[], Int[], Float64[])
Base.isempty(s::SplitData) = isempty(s.timestamp)
Base.length(s::SplitData) = length(s.timestamp)

# ─── Option Contract ─────────────────────────────────────────────────────────

"""
    OptionContract

A single option contract.
"""
struct OptionContract
    symbol::String
    strike::Float64
    currency::String
    last_price::Float64
    change::Float64
    percent_change::Float64
    volume::Union{Missing,Int}
    open_interest::Union{Missing,Int}
    bid::Float64
    ask::Float64
    contract_size::String
    expiration::DateTime
    last_trade::DateTime
    implied_vol::Float64
    in_the_money::Bool
    type::String  # "call" or "put"
end

# ─── Option Chain ─────────────────────────────────────────────────────────────

"""
    OptionChain

Contains calls and puts for a given symbol/expiration.
Implements `Tables.jl` interface.
"""
struct OptionChain
    ticker::String
    calls::Vector{OptionContract}
    puts::Vector{OptionContract}
end

Base.isempty(o::OptionChain) = isempty(o.calls) && isempty(o.puts)

function Base.show(io::IO, ::MIME"text/plain", o::OptionChain)
    print(io, "OptionChain(\"$(o.ticker)\", $(length(o.calls)) calls, $(length(o.puts)) puts)")
end

# ─── Search Types (already struct-based, keep them) ───────────────────────────

"""
    SearchResult

A single search result from Yahoo Finance.

# Fields
- `symbol::String` — Ticker symbol
- `name::String` — Display name
- `exchange::String` — Exchange name
- `type::String` — Asset type (EQUITY, ETF, FUTURE, etc.)
- `sector::String` — Sector (empty if not equity)
- `industry::String` — Industry (empty if not equity)
"""
struct SearchResult
    symbol::String
    name::String
    exchange::String
    type::String
    sector::String
    industry::String
end

"""
    SearchResults <: AbstractVector{SearchResult}

Collection of search results. Behaves as `AbstractVector`.
"""
struct SearchResults <: AbstractVector{SearchResult}
    items::Vector{SearchResult}
end

Base.size(x::SearchResults) = size(x.items)
Base.getindex(x::SearchResults, i::Int) = x.items[i]
Base.IndexStyle(::Type{SearchResults}) = IndexLinear()

function Base.show(io::IO, item::SearchResult)
    print(io, "SearchResult(\"$(item.symbol)\", \"$(item.name)\", $(item.type))")
end

function Base.show(io::IO, ::MIME"text/plain", x::SearchResults)
    println(io, "$(length(x))-element SearchResults:")
    for (i, item) in enumerate(x.items)
        i > 10 && (print(io, "  ⋮"); break)
        println(io, "  $(item.symbol) — $(item.name) [$(item.type)]")
    end
end

# ─── News Types ───────────────────────────────────────────────────────────────

"""
    NewsItem

A single news article.

# Fields
- `title::String`
- `publisher::String`
- `link::String`
- `timestamp::DateTime`
- `symbols::Vector{String}` — Related tickers
"""
struct NewsItem
    title::String
    publisher::String
    link::String
    timestamp::DateTime
    symbols::Vector{String}
end

"""
    NewsResults <: AbstractVector{NewsItem}

Collection of news articles. Behaves as `AbstractVector`.
"""
struct NewsResults <: AbstractVector{NewsItem}
    items::Vector{NewsItem}
end

Base.size(x::NewsResults) = size(x.items)
Base.getindex(x::NewsResults, i::Int) = x.items[i]
Base.IndexStyle(::Type{NewsResults}) = IndexLinear()

titles(x::NewsResults)::Vector{String} = [i.title for i in x.items]
links(x::NewsResults)::Vector{String} = [i.link for i in x.items]
timestamps(x::NewsResults)::Vector{DateTime} = [i.timestamp for i in x.items]

function Base.show(io::IO, ::MIME"text/plain", x::NewsResults)
    println(io, "$(length(x))-element NewsResults:")
    for (i, item) in enumerate(x.items)
        i > 5 && (print(io, "  ⋮"); break)
        println(io, "  $(item.title) [$(item.publisher)]")
    end
end
