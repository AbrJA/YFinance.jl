# Fundamentals

## `get_fundamentals`

Retrieve financial statement data from Yahoo Finance. Returns `Dict{String,Vector}`.

```@docs
get_fundamentals
```

### Examples

```julia
# Full income statement (annual)
data = get_fundamentals("AAPL", "income_statement", "annual", "2020-01-01", "2024-01-01")
data["timestamp"]     # Vector{DateTime}
data["TotalRevenue"]  # Vector (values per period)

# Single line item (quarterly)
rev = get_fundamentals("AAPL", "TotalRevenue", "quarterly", "2022-01-01", "2024-01-01")

# Balance sheet
bs = get_fundamentals("MSFT", "balance_sheet", "annual", "2020-01-01", "2024-01-01")

# Cash flow
cf = get_fundamentals("GOOGL", "cash_flow", "quarterly", "2022-01-01", "2024-01-01")

# Valuation multiples
val = get_fundamentals("AAPL", "valuation", "quarterly", "2022-01-01", "2024-01-01")
```

### Available Statements

| Statement | Key |
|-----------|-----|
| Income Statement | `"income_statement"` |
| Balance Sheet | `"balance_sheet"` |
| Cash Flow | `"cash_flow"` |
| Valuation | `"valuation"` |

### Available Intervals

`"annual"`, `"quarterly"`, `"monthly"`

### Available Items

See `YFinance.FUNDAMENTAL_TYPES` for the complete list of line items per statement.

```julia
# List all income statement items
YFinance.FUNDAMENTAL_TYPES["income_statement"]
```
