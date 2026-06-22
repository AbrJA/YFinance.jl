# ─────────────────────────────────────────────────────────────────────────────
# tables.jl — Tables.jl interface for YFinance typed structs
# Enables: get_prices("AAPL") |> DataFrame
# ─────────────────────────────────────────────────────────────────────────────

# ─── PriceData ────────────────────────────────────────────────────────────────

Tables.istable(::Type{PriceData}) = true
Tables.columnaccess(::Type{PriceData}) = true
Tables.columns(p::PriceData) = p

function Tables.columnnames(p::PriceData)
    cols = [:ticker, :timestamp, :open, :high, :low, :close, :adjclose, :volume]
    isempty(p.dividend) || push!(cols, :dividend)
    isempty(p.split_ratio) || push!(cols, :split_ratio)
    return cols
end

function Tables.getcolumn(p::PriceData, nm::Symbol)
    nm === :ticker && return fill(p.ticker, length(p))
    nm === :timestamp && return p.timestamp
    nm === :open && return p.open
    nm === :high && return p.high
    nm === :low && return p.low
    nm === :close && return p.close
    nm === :adjclose && return p.adjclose
    nm === :volume && return p.volume
    nm === :dividend && return p.dividend
    nm === :split_ratio && return p.split_ratio
    throw(ArgumentError("Unknown column: $nm"))
end

Tables.getcolumn(p::PriceData, i::Int) = Tables.getcolumn(p, Tables.columnnames(p)[i])

function Tables.schema(p::PriceData)
    names = Tables.columnnames(p)
    types = [nm === :ticker ? String : nm === :timestamp ? DateTime : Float64 for nm in names]
    return Tables.Schema(names, types)
end

# ─── DividendData ─────────────────────────────────────────────────────────────

Tables.istable(::Type{DividendData}) = true
Tables.columnaccess(::Type{DividendData}) = true
Tables.columns(d::DividendData) = d

Tables.columnnames(::DividendData) = (:ticker, :timestamp, :dividend)

function Tables.getcolumn(d::DividendData, nm::Symbol)
    nm === :ticker && return fill(d.ticker, length(d))
    nm === :timestamp && return d.timestamp
    nm === :dividend && return d.dividend
    throw(ArgumentError("Unknown column: $nm"))
end

Tables.getcolumn(d::DividendData, i::Int) = Tables.getcolumn(d, Tables.columnnames(d)[i])

function Tables.schema(d::DividendData)
    Tables.Schema((:ticker, :timestamp, :dividend), (String, DateTime, Float64))
end

# ─── SplitData ────────────────────────────────────────────────────────────────

Tables.istable(::Type{SplitData}) = true
Tables.columnaccess(::Type{SplitData}) = true
Tables.columns(s::SplitData) = s

Tables.columnnames(::SplitData) = (:ticker, :timestamp, :numerator, :denominator, :ratio)

function Tables.getcolumn(s::SplitData, nm::Symbol)
    nm === :ticker && return fill(s.ticker, length(s))
    nm === :timestamp && return s.timestamp
    nm === :numerator && return s.numerator
    nm === :denominator && return s.denominator
    nm === :ratio && return s.ratio
    throw(ArgumentError("Unknown column: $nm"))
end

Tables.getcolumn(s::SplitData, i::Int) = Tables.getcolumn(s, Tables.columnnames(s)[i])

function Tables.schema(::SplitData)
    Tables.Schema((:ticker, :timestamp, :numerator, :denominator, :ratio),
                  (String, DateTime, Int, Int, Float64))
end

# ─── OptionChain ──────────────────────────────────────────────────────────────

Tables.istable(::Type{OptionChain}) = true
Tables.columnaccess(::Type{OptionChain}) = true
Tables.columns(o::OptionChain) = o

const _OPTION_COLS = (:symbol, :strike, :currency, :last_price, :change,
                      :percent_change, :volume, :open_interest, :bid, :ask,
                      :contract_size, :expiration, :last_trade, :implied_vol,
                      :in_the_money, :type)

Tables.columnnames(::OptionChain) = _OPTION_COLS

function Tables.getcolumn(o::OptionChain, nm::Symbol)
    contracts = vcat(o.calls, o.puts)
    nm === :symbol && return [c.symbol for c in contracts]
    nm === :strike && return [c.strike for c in contracts]
    nm === :currency && return [c.currency for c in contracts]
    nm === :last_price && return [c.last_price for c in contracts]
    nm === :change && return [c.change for c in contracts]
    nm === :percent_change && return [c.percent_change for c in contracts]
    nm === :volume && return Union{Missing,Int}[c.volume for c in contracts]
    nm === :open_interest && return Union{Missing,Int}[c.open_interest for c in contracts]
    nm === :bid && return [c.bid for c in contracts]
    nm === :ask && return [c.ask for c in contracts]
    nm === :contract_size && return [c.contract_size for c in contracts]
    nm === :expiration && return [c.expiration for c in contracts]
    nm === :last_trade && return [c.last_trade for c in contracts]
    nm === :implied_vol && return [c.implied_vol for c in contracts]
    nm === :in_the_money && return [c.in_the_money for c in contracts]
    nm === :type && return [c.type for c in contracts]
    throw(ArgumentError("Unknown column: $nm"))
end

Tables.getcolumn(o::OptionChain, i::Int) = Tables.getcolumn(o, _OPTION_COLS[i])
