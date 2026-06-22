# ─────────────────────────────────────────────────────────────────────────────
# tables.jl — Tables.jl interface for YFinance result types
# ─────────────────────────────────────────────────────────────────────────────

import Tables

# ─── PriceData ────────────────────────────────────────────────────────────────

Tables.istable(::Type{PriceData}) = true
Tables.columnaccess(::Type{PriceData}) = true
Tables.columns(x::PriceData) = x

function Tables.columnnames(x::PriceData)
    cols = [:ticker, :timestamp, :open, :high, :low, :close, :volume]
    if !isnothing(x.adjclose)
        push!(cols, :adjclose)
    end
    return cols
end

function Tables.getcolumn(x::PriceData, nm::Symbol)
    nm === :ticker && return fill(x.ticker, length(x.timestamp))
    nm === :timestamp && return x.timestamp
    nm === :open && return x.open
    nm === :high && return x.high
    nm === :low && return x.low
    nm === :close && return x.close
    nm === :volume && return x.volume
    nm === :adjclose && return x.adjclose
    throw(ArgumentError("PriceData has no column :$nm"))
end

Tables.getcolumn(x::PriceData, i::Int) = Tables.getcolumn(x, Tables.columnnames(x)[i])

# ─── DividendData ─────────────────────────────────────────────────────────────

Tables.istable(::Type{DividendData}) = true
Tables.columnaccess(::Type{DividendData}) = true
Tables.columns(x::DividendData) = x
Tables.columnnames(::DividendData) = [:ticker, :timestamp, :dividend]

function Tables.getcolumn(x::DividendData, nm::Symbol)
    nm === :ticker && return fill(x.ticker, length(x.timestamp))
    nm === :timestamp && return x.timestamp
    nm === :dividend && return x.dividend
    throw(ArgumentError("DividendData has no column :$nm"))
end

Tables.getcolumn(x::DividendData, i::Int) = Tables.getcolumn(x, Tables.columnnames(x)[i])

# ─── SplitData ────────────────────────────────────────────────────────────────

Tables.istable(::Type{SplitData}) = true
Tables.columnaccess(::Type{SplitData}) = true
Tables.columns(x::SplitData) = x
Tables.columnnames(::SplitData) = [:ticker, :timestamp, :numerator, :denominator, :ratio]

function Tables.getcolumn(x::SplitData, nm::Symbol)
    nm === :ticker && return fill(x.ticker, length(x.timestamp))
    nm === :timestamp && return x.timestamp
    nm === :numerator && return x.numerator
    nm === :denominator && return x.denominator
    nm === :ratio && return x.ratio
    throw(ArgumentError("SplitData has no column :$nm"))
end

Tables.getcolumn(x::SplitData, i::Int) = Tables.getcolumn(x, Tables.columnnames(x)[i])

# ─── OptionSide ───────────────────────────────────────────────────────────────

Tables.istable(::Type{OptionSide}) = true
Tables.columnaccess(::Type{OptionSide}) = true
Tables.columns(x::OptionSide) = x
Tables.columnnames(x::OptionSide) = Symbol.(collect(keys(x.data)))

function Tables.getcolumn(x::OptionSide, nm::Symbol)
    k = String(nm)
    haskey(x.data, k) || throw(ArgumentError("OptionSide has no column :$nm"))
    return x.data[k]
end

Tables.getcolumn(x::OptionSide, i::Int) = Tables.getcolumn(x, Tables.columnnames(x)[i])

# ─── FundamentalData ──────────────────────────────────────────────────────────

Tables.istable(::Type{FundamentalData}) = true
Tables.columnaccess(::Type{FundamentalData}) = true
Tables.columns(x::FundamentalData) = x
Tables.columnnames(x::FundamentalData) = Symbol.(collect(keys(x.data)))

function Tables.getcolumn(x::FundamentalData, nm::Symbol)
    k = String(nm)
    haskey(x.data, k) || throw(ArgumentError("FundamentalData has no column :$nm"))
    return x.data[k]
end

Tables.getcolumn(x::FundamentalData, i::Int) = Tables.getcolumn(x, Tables.columnnames(x)[i])
