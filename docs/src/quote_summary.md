# Quote Summary

## `quote_summary`

Retrieve detailed quote summary data (30+ available modules).

```@docs
quote_summary
```

## Accessor Functions

All accessors accept either a `Dict` returned by `quote_summary()` or a ticker symbol string directly.

```@docs
calendar_events
earnings_estimates
eps
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
using YFinance

# Full summary
qs = quote_summary("AAPL")

# Specific module
quote_summary("AAPL", item="summaryDetail")

# Accessor functions (with Dict)
calendar_events(qs)
recommendation_trend(qs)

# Accessor functions (with symbol — calls quote_summary internally)
earnings_estimates("AAPL")
insider_holders("MSFT")
sector_industry("GOOG")
```

## Constants

```@docs
QUOTE_SUMMARY_ITEMS
```
