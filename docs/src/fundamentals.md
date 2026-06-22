# Fundamentals

## `fundamentals`

Retrieve financial statement data (income statement, balance sheet, cash flow, or valuation multiples).

```@docs
fundamentals
```

### Examples

```julia
using YFinance, DataFrames

# Full income statement
fundamentals("AAPL", "income_statement", "annual", "2020-01-01", "2024-01-01") |> DataFrame

# Quarterly balance sheet
fundamentals("MSFT", "balance_sheet", "quarterly", "2022-01-01", "2024-01-01") |> DataFrame

# Cash flow
fundamentals("GOOG", "cash_flow", "annual", "2021-01-01", "2024-01-01") |> DataFrame

# Valuation multiples
fundamentals("NFLX", "valuation", "annual", "2021-01-01", "2024-01-01") |> DataFrame

# Single metric
fundamentals("AAPL", "TotalRevenue", "quarterly", "2022-01-01", "2024-01-01") |> DataFrame
```

## Constants

```@docs
FUNDAMENTAL_TYPES
FUNDAMENTAL_INTERVALS
```
