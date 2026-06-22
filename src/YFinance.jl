module YFinance

    using Base64
    using Dates
    using Downloads
    using JSON
    using Tables

    # ─── Public API — Types ──────────────────────────────────────────────────
    export PriceData, DividendData, SplitData
    export OptionChain, OptionContract
    export SearchResult, SearchResults
    export NewsItem, NewsResults

    # ─── Public API — Data Retrieval ─────────────────────────────────────────
    export get_prices, get_dividends, get_splits
    export get_options
    export get_fundamentals
    export get_quote_summary
    export search_symbols, search_news
    export is_valid_symbol, valid_symbols

    # ─── Public API — QuoteSummary Accessors ─────────────────────────────────
    export calendar_events, earnings_estimates, earnings_per_share
    export insider_holders, insider_transactions
    export institutional_ownership, major_holders_breakdown
    export recommendation_trend, summary_detail
    export sector_industry, upgrade_downgrade_history

    # ─── Public API — News Helpers ───────────────────────────────────────────
    export titles, links, timestamps

    # ─── Public API — Configuration ──────────────────────────────────────────
    export set_proxy!, clear_proxy!

    # ─── Public API — Constants ──────────────────────────────────────────────
    export QUOTE_SUMMARY_ITEMS, FUNDAMENTAL_TYPES, FUNDAMENTAL_INTERVALS

    # ─── Source Files ────────────────────────────────────────────────────────
    include("types.jl")
    include("headers.jl")
    include("network.jl")
    include("tables.jl")
    include("proxy.jl")
    include("validate.jl")
    include("prices.jl")
    include("summary.jl")
    include("fundamentals.jl")
    include("options.jl")
    include("search.jl")
    include("news.jl")

end
