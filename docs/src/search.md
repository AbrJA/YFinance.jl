# Search

## `search_symbols`

Search for securities by name, ticker, or keyword. Returns a [`SearchResults`](@ref) collection.

```@docs
search_symbols
```

### Examples

```julia
results = search_symbols("microsoft")
results[1].symbol    # "MSFT"
results[1].name      # "Microsoft Corporation"
results[1].exchange  # "NASDAQ (NMS)"
results[1].type      # "EQUITY"

# Iterate
for r in results
    println(r.symbol, " — ", r.name)
end
```

### `SearchResult` Fields

| Field | Type | Description |
|-------|------|-------------|
| `symbol` | `String` | Ticker symbol |
| `name` | `String` | Display name |
| `exchange` | `String` | Exchange name |
| `type` | `String` | Asset type (EQUITY, ETF, FUTURE, etc.) |
| `sector` | `String` | Sector (empty if not equity) |
| `industry` | `String` | Industry (empty if not equity) |

---

## Symbol Validation

```@docs
is_valid_symbol
valid_symbols
```

### Examples

```julia
is_valid_symbol("AAPL")   # true
is_valid_symbol("FAKE")   # false

valid_symbols(["AAPL", "FAKE", "MSFT"])  # ["AAPL", "MSFT"]
```
