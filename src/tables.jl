# ─────────────────────────────────────────────────────────────────────────────
# tables.jl — Tables.jl interface for YFinance.jl return types
# Allows direct piping to DataFrame: prices("AAPL") |> DataFrame
# ─────────────────────────────────────────────────────────────────────────────

using Tables

# ─── YFinanceTable wrapper ────────────────────────────────────────────────────

"""
    YFinanceTable

Wrapper around the OrderedDict results from YFinance functions that implements
the Tables.jl interface. This allows direct conversion to DataFrames:

```julia
using DataFrames
prices("AAPL", range="5d") |> DataFrame
```
"""
struct YFinanceTable
    data::OrderedDict{String, <:Any}
end

# Make it behave like the underlying OrderedDict for backward compatibility
Base.getindex(t::YFinanceTable, k) = t.data[k]
Base.keys(t::YFinanceTable) = keys(t.data)
Base.haskey(t::YFinanceTable, k) = haskey(t.data, k)
Base.length(t::YFinanceTable) = length(t.data)
Base.isempty(t::YFinanceTable) = isempty(t.data)
Base.iterate(t::YFinanceTable) = iterate(t.data)
Base.iterate(t::YFinanceTable, state) = iterate(t.data, state)
Base.values(t::YFinanceTable) = values(t.data)
Base.get(t::YFinanceTable, k, default) = get(t.data, k, default)

function Base.show(io::IO, t::YFinanceTable)
    show(io, t.data)
end
function Base.show(io::IO, mime::MIME"text/plain", t::YFinanceTable)
    show(io, mime, t.data)
end

# ─── Tables.jl interface ─────────────────────────────────────────────────────

Tables.istable(::Type{YFinanceTable}) = true
Tables.columnaccess(::Type{YFinanceTable}) = true

function Tables.columns(t::YFinanceTable)
    return t
end

function Tables.columnnames(t::YFinanceTable)
    return Symbol.(collect(keys(t.data)))
end

function Tables.getcolumn(t::YFinanceTable, nm::Symbol)
    k = String(nm)
    v = t.data[k]
    if v isa AbstractVector
        return v
    else
        # Scalar values (like "ticker") get expanded to match the table length
        n = _table_nrows(t)
        return fill(v, n)
    end
end

function Tables.getcolumn(t::YFinanceTable, i::Int)
    k = collect(keys(t.data))[i]
    return Tables.getcolumn(t, Symbol(k))
end

function Tables.schema(t::YFinanceTable)
    names = Tables.columnnames(t)
    types = Type[]
    for nm in names
        k = String(nm)
        v = t.data[k]
        if v isa AbstractVector
            push!(types, eltype(v))
        else
            push!(types, typeof(v))
        end
    end
    return Tables.Schema(names, types)
end

function _table_nrows(t::YFinanceTable)
    for v in values(t.data)
        if v isa AbstractVector
            return length(v)
        end
    end
    return 0
end
