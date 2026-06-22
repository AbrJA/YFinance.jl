# Configuration

## Proxy Settings

```@docs
set_proxy
clear_proxy
```

### Examples

```julia
using YFinance

# Unauthenticated proxy
set_proxy("http://proxy.example.com:8080")

# Authenticated proxy
set_proxy("http://proxy.example.com:8080", user="admin", password="secret")

# Remove proxy
clear_proxy()
```

## Symbol Validation

```@docs
is_valid_symbol
valid_symbols
```

### Examples

```julia
using YFinance

is_valid_symbol("AAPL")   # true
is_valid_symbol("XYZFAKE") # false

valid_symbols(["AAPL", "INVALID", "MSFT"])  # ["AAPL", "MSFT"]
```

## Error Handling

```@docs
YFinanceError
```

All functions throw `YFinanceError` on failure. Use `try/catch` for graceful handling:

```julia
try
    data = prices("INVALID_TICKER")
catch e::YFinanceError
    @warn "Failed" symbol=e.symbol message=e.message status=e.status
end
```
