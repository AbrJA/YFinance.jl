# Quote Summary

## `get_quote_summary`

Retrieve comprehensive company data from Yahoo Finance. Returns `Dict{String,Any}`.

```@docs
get_quote_summary
```

### Examples

```julia
# All modules
qs = get_quote_summary("AAPL")
keys(qs)  # Available modules

# Single module
price = get_quote_summary("AAPL", item="price")
price["regularMarketPrice"]
```

---

## Accessor Functions

Convenience functions that extract and structure specific data from the quote summary.
Each accepts either a `Dict` (from `get_quote_summary`) or a `String` (ticker symbol).

```@docs
calendar_events
earnings_estimates
earnings_per_share
insider_holders
insider_transactions
institutional_ownership
major_holders_breakdown
recommendation_trend
summary_detail
sector_industry
upgrade_downgrade_history
```

### Examples

```julia
# From a pre-fetched quote summary
qs = get_quote_summary("AAPL")
sector_industry(qs)
recommendation_trend(qs)
earnings_per_share(qs)

# Or pass a symbol directly (fetches internally)
sector_industry("AAPL")
recommendation_trend("MSFT")
insider_transactions("TSLA")
```

### Available Quote Summary Modules

See `YFinance.QUOTE_SUMMARY_ITEMS` for the full list of available modules:

```julia
YFinance.QUOTE_SUMMARY_ITEMS
# "assetProfile", "balanceSheetHistory", "calendarEvents", ...
```
