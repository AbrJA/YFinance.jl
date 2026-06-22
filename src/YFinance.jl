module YFinance

    using Base64
    using OrderedCollections
    using Dates
    using Downloads
    using JSON
    using Tables

    # ─── Public API — Data Retrieval ─────────────────────────────────────────
    export get_prices, get_dividends, get_splits
    export get_options, get_fundamentals
    export get_quote_summary
    export search_symbols, search_news
    export is_valid_symbol, valid_symbols

    # ─── Public API — Types ──────────────────────────────────────────────────
    export SearchResult, SearchResults
    export NewsItem, NewsResults
    export YFinanceTable
    export titles, links, timestamps

    # ─── Public API — Configuration ──────────────────────────────────────────
    export set_proxy!, clear_proxy!

    # ─── Public API — QuoteSummary Accessors ─────────────────────────────────
    export calendar_events, earnings_estimates, earnings_per_share
    export insider_holders, insider_transactions
    export institutional_ownership, major_holders_breakdown
    export recommendation_trend, summary_detail
    export sector_industry, upgrade_downgrade_history

    # ─── Public API — Constants ──────────────────────────────────────────────
    export QUOTE_SUMMARY_ITEMS, FUNDAMENTAL_TYPES, FUNDAMENTAL_INTERVALS

    # ─── Load Order ──────────────────────────────────────────────────────────
    include("headers.jl")
    include("network.jl")
    include("Proxy_Auth.jl")
    include("Validity.jl")
    include("Prices.jl")
    include("QuoteSummary.jl")
    include("Fundamental.jl")
    include("Options.jl")
    include("Search_Symbol.jl")
    include("News_Search.jl")
    include("tables.jl")

end
