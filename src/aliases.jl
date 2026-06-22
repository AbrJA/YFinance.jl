# ─────────────────────────────────────────────────────────────────────────────
# aliases.jl — v0.3.0 function names (Julia-idiomatic snake_case, no `get_` prefix)
# New names return YFinanceTable (Tables.jl compatible).
# Old names remain available and return OrderedDict as before.
# ─────────────────────────────────────────────────────────────────────────────

# Helper: wrap result in YFinanceTable if it's an OrderedDict
_wrap_table(x::OrderedDict) = YFinanceTable(x)
_wrap_table(x) = x  # nothing, empty dict, etc. pass through

# ─── Prices ───────────────────────────────────────────────────────────────────

"""
    prices(symbol; startdt, enddt, range, interval, kwargs...) -> YFinanceTable

Fetch historical price data for a ticker symbol.
Returns a `YFinanceTable` (Tables.jl compatible — pipe to `DataFrame` directly).

See `get_prices` for full documentation.
"""
prices(args...; kwargs...) = _wrap_table(get_prices(args...; kwargs...))

"""
    splits(symbol; startdt, enddt, kwargs...) -> YFinanceTable

Fetch stock split history for a ticker symbol.

See `get_splits` for full documentation.
"""
splits(args...; kwargs...) = _wrap_table(get_splits(args...; kwargs...))

"""
    dividends(symbol; startdt, enddt, kwargs...) -> YFinanceTable

Fetch dividend history for a ticker symbol.

See `get_dividends` for full documentation.
"""
dividends(args...; kwargs...) = _wrap_table(get_dividends(args...; kwargs...))

# ─── Options ──────────────────────────────────────────────────────────────────

"""
    options(symbol; throw_error=false, expiration_date=nothing)

Fetch the options chain for a ticker symbol.

See `get_Options` for full documentation.
"""
options(args...; kwargs...) = get_Options(args...; kwargs...)

# ─── Fundamentals ─────────────────────────────────────────────────────────────

"""
    fundamentals(symbol, item, interval, startdt, enddt; throw_error=false) -> YFinanceTable

Fetch fundamental financial data.

See `get_Fundamental` for full documentation.
"""
fundamentals(args...; kwargs...) = _wrap_table(get_Fundamental(args...; kwargs...))

# ─── Quote Summary ────────────────────────────────────────────────────────────

"""
    quote_summary(symbol; item=nothing, throw_error=false)

Fetch quote summary data.

See `get_quoteSummary` for full documentation.
"""
quote_summary(args...; kwargs...) = get_quoteSummary(args...; kwargs...)

# ─── QuoteSummary accessors ───────────────────────────────────────────────────

"""
    calendar_events(quoteSummary)

Extract calendar events from a quote summary. See `get_calendar_events`.
"""
const calendar_events = get_calendar_events

"""
    earnings_estimates(quoteSummary)

Extract earnings estimates. See `get_earnings_estimates`.
"""
const earnings_estimates = get_earnings_estimates

"""
    eps(quoteSummary)

Extract EPS data. See `get_eps`.
"""
const eps = get_eps

"""
    insider_holders(quoteSummary)

Extract insider holders. See `get_insider_holders`.
"""
const insider_holders = get_insider_holders

"""
    insider_transactions(quoteSummary)

Extract insider transactions. See `get_insider_transactions`.
"""
const insider_transactions = get_insider_transactions

"""
    institutional_ownership(quoteSummary)

Extract institutional ownership data. See `get_institutional_ownership`.
"""
const institutional_ownership = get_institutional_ownership

"""
    major_holders_breakdown(quoteSummary)

Extract major holders breakdown. See `get_major_holders_breakdown`.
"""
const major_holders_breakdown = get_major_holders_breakdown

"""
    recommendation_trend(quoteSummary)

Extract analyst recommendation trends. See `get_recommendation_trend`.
"""
const recommendation_trend = get_recommendation_trend

"""
    summary_detail(quoteSummary)

Extract summary details. See `get_summary_detail`.
"""
const summary_detail = get_summary_detail

"""
    sector_industry(quoteSummary)

Extract sector and industry info. See `get_sector_industry`.
"""
const sector_industry = get_sector_industry

"""
    upgrade_downgrade_history(quoteSummary)

Extract upgrade/downgrade history. See `get_upgrade_downgrade_history`.
"""
const upgrade_downgrade_history = get_upgrade_downgrade_history

# ─── Search ──────────────────────────────────────────────────────────────────

"""
    search_symbols(query)

Search for ticker symbols matching a query. See `get_symbols`.
"""
const search_symbols = get_symbols

# ─── Validation ───────────────────────────────────────────────────────────────

"""
    is_valid_symbol(symbol)

Check if a symbol is valid. See `validate_symbol`.
"""
const is_valid_symbol = validate_symbol

"""
    valid_symbols(symbols)

Return only valid symbols from a list. See `get_valid_symbols`.
"""
const valid_symbols = get_valid_symbols

# ─── Proxy ────────────────────────────────────────────────────────────────────

"""
    set_proxy(proxy, user=nothing, password=nothing)

Configure proxy settings for API requests. See `create_proxy_settings`.
"""
const set_proxy = create_proxy_settings

"""
    clear_proxy()

Clear proxy settings. See `clear_proxy_settings`.
"""
const clear_proxy = clear_proxy_settings

# ─── Constants ────────────────────────────────────────────────────────────────

"""Alias for `_QuoteSummary_Items`."""
const QUOTE_SUMMARY_ITEMS = _QuoteSummary_Items

"""Alias for `_Fundamental_Types`."""
const FUNDAMENTAL_TYPES = _Fundamental_Types

"""Alias for `_Fundamental_Intervals`."""
const FUNDAMENTAL_INTERVALS = _Fundamental_Intervals
