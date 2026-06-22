# ─────────────────────────────────────────────────────────────────────────────
# types.jl — Exception and result types for YFinance.jl
# ─────────────────────────────────────────────────────────────────────────────

# ─── Exception ────────────────────────────────────────────────────────────────

"""
    YFinanceError <: Exception

Error thrown when a Yahoo Finance request fails.

# Fields
- `symbol::String` — The ticker symbol involved
- `message::String` — Human-readable error description
- `status::Union{Nothing, Int}` — HTTP status code, if applicable
"""
struct YFinanceError <: Exception
    symbol::String
    message::String
    status::Union{Nothing, Int}
end

function Base.showerror(io::IO, e::YFinanceError)
    print(io, "YFinanceError ($(e.symbol)): $(e.message)")
    if !isnothing(e.status)
        print(io, " [HTTP $(e.status)]")
    end
end

# ─── Result Types ─────────────────────────────────────────────────────────────

"""
    PriceData

Historical price data returned by [`prices`](@ref).
Implements `Tables.jl` interface — pipe directly to `DataFrame`, `CSV.write`, etc.

# Fields
- `ticker::String`
- `timestamp::Vector{DateTime}`
- `open::Vector{Float64}`
- `high::Vector{Float64}`
- `low::Vector{Float64}`
- `close::Vector{Float64}`
- `volume::Vector{Float64}`
- `adjclose::Union{Nothing, Vector{Float64}}` — only for daily+ intervals
"""
struct PriceData
    ticker::String
    timestamp::Vector{DateTime}
    open::Vector{Float64}
    high::Vector{Float64}
    low::Vector{Float64}
    close::Vector{Float64}
    volume::Vector{Float64}
    adjclose::Union{Nothing, Vector{Float64}}
end

function Base.show(io::IO, ::MIME"text/plain", p::PriceData)
    n = length(p.timestamp)
    print(io, "PriceData(\"$(p.ticker)\", $n rows")
    if n > 0
        print(io, ", $(p.timestamp[1]) to $(p.timestamp[end])")
    end
    print(io, ")")
end

Base.length(p::PriceData) = length(p.timestamp)
Base.isempty(p::PriceData) = isempty(p.timestamp)

"""
    DividendData

Dividend history returned by [`dividends`](@ref).
Implements `Tables.jl` interface.

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

function Base.show(io::IO, ::MIME"text/plain", d::DividendData)
    n = length(d.timestamp)
    print(io, "DividendData(\"$(d.ticker)\", $n entries)")
end

Base.length(d::DividendData) = length(d.timestamp)
Base.isempty(d::DividendData) = isempty(d.timestamp)

"""
    SplitData

Stock split history returned by [`splits`](@ref).
Implements `Tables.jl` interface.

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

function Base.show(io::IO, ::MIME"text/plain", s::SplitData)
    n = length(s.timestamp)
    print(io, "SplitData(\"$(s.ticker)\", $n entries)")
end

Base.length(s::SplitData) = length(s.timestamp)
Base.isempty(s::SplitData) = isempty(s.timestamp)

"""
    OptionSide

One side (calls or puts) of an options chain. Implements `Tables.jl` interface.
"""
struct OptionSide
    data::OrderedDict{String, Vector}
end

Base.length(o::OptionSide) = isempty(o.data) ? 0 : length(first(values(o.data)))
Base.isempty(o::OptionSide) = length(o) == 0

"""
    OptionsChain

Options data returned by [`options`](@ref).

# Fields
- `ticker::String`
- `calls::OptionSide`
- `puts::OptionSide`
"""
struct OptionsChain
    ticker::String
    calls::OptionSide
    puts::OptionSide
end

function Base.show(io::IO, ::MIME"text/plain", o::OptionsChain)
    print(io, "OptionsChain(\"$(o.ticker)\", $(length(o.calls)) calls, $(length(o.puts)) puts)")
end

"""
    FundamentalData

Financial statement data returned by [`fundamentals`](@ref).
Implements `Tables.jl` interface.

# Fields
- `ticker::String`
- `data::OrderedDict{String, Vector}` — columns keyed by field name
"""
struct FundamentalData
    ticker::String
    data::OrderedDict{String, Vector}
end

function Base.show(io::IO, ::MIME"text/plain", f::FundamentalData)
    n = haskey(f.data, "timestamp") ? length(f.data["timestamp"]) : 0
    ncols = length(f.data)
    print(io, "FundamentalData(\"$(f.ticker)\", $n rows × $ncols columns)")
end

Base.length(f::FundamentalData) = haskey(f.data, "timestamp") ? length(f.data["timestamp"]) : 0
Base.isempty(f::FundamentalData) = length(f) == 0

# ─── Search Types ─────────────────────────────────────────────────────────────

"""
    SearchResult

A single search result from Yahoo Finance symbol search.

# Fields
- `symbol::String`
- `name::String`
- `exchange::String`
- `quote_type::String`
- `sector::String`
- `industry::String`
"""
struct SearchResult
    symbol::String
    name::String
    exchange::String
    quote_type::String
    sector::String
    industry::String
end

"""
    SearchResults <: AbstractVector{SearchResult}

Collection of search results. Behaves as an `AbstractVector`.
"""
struct SearchResults <: AbstractVector{SearchResult}
    items::Vector{SearchResult}
end

Base.size(x::SearchResults) = size(x.items)
Base.getindex(x::SearchResults, i::Int) = x.items[i]
Base.IndexStyle(::Type{SearchResults}) = IndexLinear()

function Base.show(io::IO, item::SearchResult)
    println(io)
    println(io, "  Symbol:   $(item.symbol)")
    println(io, "  Name:     $(item.name)")
    println(io, "  Type:     $(item.quote_type)")
    println(io, "  Exchange: $(item.exchange)")
    if !isempty(item.sector)
        println(io, "  Sector:   $(item.sector)")
        println(io, "  Industry: $(item.industry)")
    end
end

function Base.show(io::IO, ::MIME"text/plain", x::SearchResults)
    print(io, "$(length(x))-element SearchResults:")
    for item in x.items
        show(io, item)
    end
end

# ─── News Types ───────────────────────────────────────────────────────────────

"""
    NewsItem

A single news article from Yahoo Finance.

# Fields
- `title::String`
- `publisher::String`
- `link::String`
- `timestamp::DateTime`
- `symbols::Vector{String}`
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

Collection of news articles. Behaves as an `AbstractVector`.
"""
struct NewsResults <: AbstractVector{NewsItem}
    items::Vector{NewsItem}
end

Base.size(x::NewsResults) = size(x.items)
Base.getindex(x::NewsResults, i::Int) = x.items[i]
Base.IndexStyle(::Type{NewsResults}) = IndexLinear()

function Base.show(io::IO, x::NewsItem)
    println(io, "  Title:     $(x.title)")
    println(io, "  Time:      $(Dates.format(x.timestamp, "u d HH:MM"))")
    println(io, "  Publisher: $(x.publisher)")
    println(io, "  Link:      $(x.link)")
    if !isempty(x.symbols)
        println(io, "  Symbols:   $(join(x.symbols, ", "))")
    end
end

function Base.show(io::IO, ::MIME"text/plain", x::NewsResults)
    print(io, "$(length(x))-element NewsResults:")
    for item in x.items
        println(io)
        show(io, item)
    end
end

"""
    titles(x::NewsResults) -> Vector{String}

Extract all article titles.
"""
titles(x::NewsResults)::Vector{String} = [item.title for item in x.items]

"""
    links(x::NewsResults) -> Vector{String}

Extract all article links.
"""
links(x::NewsResults)::Vector{String} = [item.link for item in x.items]

"""
    timestamps(x::NewsResults) -> Vector{DateTime}

Extract all article timestamps.
"""
timestamps(x::NewsResults)::Vector{DateTime} = [item.timestamp for item in x.items]
