module YFinance

using Base64
using OrderedCollections
using Dates
using Downloads
using JSON
using Tables

# ─── Load Order ───────────────────────────────────────────────────────────────

include("types.jl")
include("constants.jl")
include("headers.jl")
include("network.jl")
include("proxy.jl")
include("validation.jl")
include("tables.jl")
include("prices.jl")
include("fundamentals.jl")
include("options.jl")
include("quote_summary.jl")
include("search.jl")
include("news.jl")

# ─── Exports ─────────────────────────────────────────────────────────────────

# Types
export YFinanceError
export PriceData, DividendData, SplitData
export OptionsChain, OptionSide
export FundamentalData
export SearchResult, SearchResults
export NewsItem, NewsResults

# Data retrieval
export prices, dividends, splits
export fundamentals
export options
export quote_summary
export search_symbols, search_news

# Quote summary accessors
export calendar_events, earnings_estimates, eps
export insider_holders, insider_transactions
export institutional_ownership, major_holders_breakdown
export recommendation_trend, summary_detail
export sector_industry, upgrade_downgrade_history

# Validation
export is_valid_symbol, valid_symbols

# Proxy
export set_proxy, clear_proxy

# Constants
export QUOTE_SUMMARY_ITEMS, FUNDAMENTAL_TYPES, FUNDAMENTAL_INTERVALS

# News helpers
export titles, links, timestamps

end
