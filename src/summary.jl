# ─────────────────────────────────────────────────────────────────────────────
# summary.jl — QuoteSummary retrieval and accessor functions
# Raw data returned as Dict (schema varies per module).
# Accessor functions extract and normalize common data patterns.
# ─────────────────────────────────────────────────────────────────────────────

const QUOTE_SUMMARY_ITEMS = [
    "assetProfile", "balanceSheetHistory", "balanceSheetHistoryQuarterly",
    "calendarEvents", "cashflowStatementHistory", "cashflowStatementHistoryQuarterly",
    "defaultKeyStatistics", "earnings", "earningsHistory", "earningsTrend",
    "esgScores", "financialData", "fundOwnership", "fundPerformance", "fundProfile",
    "incomeStatementHistory", "incomeStatementHistoryQuarterly",
    "indexTrend", "industryTrend", "insiderHolders", "insiderTransactions",
    "institutionOwnership", "majorDirectHolders", "majorHoldersBreakdown",
    "netSharePurchaseActivity", "price", "quoteType", "recommendationTrend",
    "secFilings", "sectorTrend", "summaryDetail", "summaryProfile",
    "topHoldings", "upgradeDowngradeHistory",
]

"""
    get_quote_summary(symbol; item=nothing, throw_error=false) -> Dict

Fetch quote summary modules from Yahoo Finance.

# Arguments
- `symbol::String` — Ticker (e.g. "AAPL")
- `item` — Module name(s). String or Vector{String}. Default: all modules.
- `throw_error::Bool=false` — Throw on errors vs return empty Dict.

See `QUOTE_SUMMARY_ITEMS` for valid module names.

# Examples
```julia
data = get_quote_summary("AAPL")
data["price"]["regularMarketPrice"]

# Single module
get_quote_summary("AAPL", item="price")

# Multiple modules
get_quote_summary("AAPL", item=["price", "summaryDetail"])
```
"""
function get_quote_summary(symbol::String; item=nothing, throw_error::Bool=false)
    _ensure_session!()
    if isempty(_SESSION.crumb)
        @warn "QuoteSummary requires a crumb which could not be retrieved."
        return Dict{String,Any}()
    end

    modules = if isnothing(item)
        QUOTE_SUMMARY_ITEMS
    elseif item isa AbstractString
        @assert item in QUOTE_SUMMARY_ITEMS "Invalid module '$item'. See QUOTE_SUMMARY_ITEMS."
        [item]
    else
        for m in item
            @assert m in QUOTE_SUMMARY_ITEMS "Invalid module '$m'. See QUOTE_SUMMARY_ITEMS."
        end
        item
    end

    params = Dict("formatted" => "false", "modules" => join(modules, ","), "crumb" => _SESSION.crumb)
    url = _build_url("https://query2.finance.yahoo.com/v10/finance/quoteSummary/$symbol", params)
    resp = _yahoo_get(url, symbol; timeout=10, throw_error)
    isnothing(resp) && return Dict{String,Any}()

    parsed = JSON.parse(String(copy(resp.body)))
    result = parsed["quoteSummary"]["result"][1]

    # If single module requested, return just that module's data
    return (item isa AbstractString) ? result[item] : result
end

# ─── Helper: safe field extraction ────────────────────────────────────────────

function _get(d::AbstractDict, key::String; sub=nothing, as_date=false, from_unix=false)
    !haskey(d, key) && return missing
    val = d[key]
    if !isnothing(sub)
        val isa AbstractDict || return missing
        !haskey(val, sub) && return missing
        val = val[sub]
    end
    as_date && (val = from_unix ? unix2datetime(val) : DateTime(val))
    return val
end

# ─── Accessor: calendar_events ────────────────────────────────────────────────

"""
    calendar_events(summary_or_symbol) -> Dict

Extract calendar events (dividend dates, earnings dates).
Accepts a quote summary Dict or a ticker String.
"""
function calendar_events(qs::AbstractDict)
    _assert_module(qs, "calendarEvents")
    cal = qs["calendarEvents"]
    return Dict{String,Any}(
        "dividend_date" => unix2datetime(get(cal, "dividendDate", 0)),
        "ex_dividend_date" => unix2datetime(get(cal, "exDividendDate", 0)),
        "earnings_dates" => DateTime[unix2datetime(d) for d in get(get(cal, "earnings", Dict()), "earningsDate", [])],
    )
end
calendar_events(s::AbstractString) = get_quote_summary(s) |> calendar_events

# ─── Accessor: earnings_estimates ─────────────────────────────────────────────

"""
    earnings_estimates(summary_or_symbol) -> Dict

Extract quarterly earnings estimates and actuals.
"""
function earnings_estimates(qs::AbstractDict)
    _assert_module(qs, "earnings")
    quarterly = qs["earnings"]["earningsChart"]["quarterly"]
    isempty(quarterly) && return Dict{String,Vector}()

    quarter = String[]
    estimate = Float64[]
    actual = Union{Missing,Float64}[]

    for q in quarterly
        push!(quarter, q["date"])
        push!(estimate, Float64(q["estimate"]))
        push!(actual, Float64(q["actual"]))
    end

    # Add current quarter estimate
    ec = qs["earnings"]["earningsChart"]
    if haskey(ec, "currentQuarterEstimateDate")
        push!(quarter, string(ec["currentQuarterEstimateDate"], ec["currentQuarterEstimateYear"]))
        push!(estimate, Float64(ec["currentQuarterEstimate"]))
        push!(actual, missing)
    end

    return Dict{String,Vector}("quarter" => quarter, "estimate" => estimate, "actual" => actual)
end
earnings_estimates(s::AbstractString) = get_quote_summary(s) |> earnings_estimates

# ─── Accessor: earnings_per_share ─────────────────────────────────────────────

"""
    earnings_per_share(summary_or_symbol) -> Dict

Extract EPS history with estimates, actuals, and surprise %.
"""
function earnings_per_share(qs::AbstractDict)
    _assert_module(qs, "earningsHistory")
    history = qs["earningsHistory"]["history"]
    isempty(history) && return Dict{String,Vector}()

    quarter = DateTime[]
    estimate = Float64[]
    actual = Float64[]
    surprise = Float64[]

    for h in history
        push!(quarter, DateTime(h["quarter"]["fmt"]))
        push!(estimate, Float64(h["epsEstimate"]["raw"]))
        push!(actual, Float64(h["epsActual"]["raw"]))
        push!(surprise, Float64(h["surprisePercent"]["raw"]))
    end

    return Dict{String,Vector}("quarter" => quarter, "estimate" => estimate,
                               "actual" => actual, "surprise" => surprise)
end
earnings_per_share(s::AbstractString) = get_quote_summary(s) |> earnings_per_share

# ─── Accessor: insider_holders ────────────────────────────────────────────────

"""
    insider_holders(summary_or_symbol) -> Dict

Extract insider holdings data.
"""
function insider_holders(qs::AbstractDict)
    _assert_module(qs, "insiderHolders")
    holders = qs["insiderHolders"]["holders"]
    isempty(holders) && return Dict{String,Vector}()

    name = String[]
    relation = Union{Missing,String}[]
    description = Union{Missing,String}[]
    last_trans = Union{Missing,DateTime}[]
    position = Union{Missing,Int}[]
    pos_date = Union{Missing,DateTime}[]

    for h in holders
        push!(name, h["name"])
        push!(relation, _get(h, "relation"))
        push!(description, _get(h, "transactionDescription"))
        push!(last_trans, _get(h, "latestTransDate"; sub="fmt", as_date=true))
        push!(position, _get(h, "positionDirect"; sub="raw"))
        push!(pos_date, _get(h, "positionDirectDate"; sub="fmt", as_date=true))
    end

    return Dict{String,Vector}("name" => name, "relation" => relation,
                               "description" => description, "last_transaction" => last_trans,
                               "position" => position, "position_date" => pos_date)
end
insider_holders(s::AbstractString) = get_quote_summary(s) |> insider_holders

# ─── Accessor: insider_transactions ───────────────────────────────────────────

"""
    insider_transactions(summary_or_symbol) -> Dict

Extract insider transaction history.
"""
function insider_transactions(qs::AbstractDict)
    _assert_module(qs, "insiderTransactions")
    txns = qs["insiderTransactions"]["transactions"]
    isempty(txns) && return Dict{String,Vector}()

    name = String[]
    relation = Union{Missing,String}[]
    text = Union{Missing,String}[]
    date = Union{Missing,DateTime}[]
    shares = Union{Missing,Int}[]
    value = Union{Missing,Int}[]

    for t in txns
        push!(name, t["filerName"])
        push!(relation, _get(t, "filerRelation"))
        push!(text, _get(t, "transactionText"))
        push!(date, _get(t, "startDate"; sub="fmt", as_date=true))
        push!(shares, _get(t, "shares"; sub="raw"))
        push!(value, _get(t, "value"; sub="raw"))
    end

    return Dict{String,Vector}("name" => name, "relation" => relation,
                               "text" => text, "date" => date,
                               "shares" => shares, "value" => value)
end
insider_transactions(s::AbstractString) = get_quote_summary(s) |> insider_transactions

# ─── Accessor: institutional_ownership ────────────────────────────────────────

"""
    institutional_ownership(summary_or_symbol) -> Dict

Extract top institutional owners.
"""
function institutional_ownership(qs::AbstractDict)
    _assert_module(qs, "institutionOwnership")
    owners = qs["institutionOwnership"]["ownershipList"]
    isempty(owners) && return Dict{String,Vector}()

    org = String[]
    report_date = Union{Missing,DateTime}[]
    pct_held = Union{Missing,Float64}[]
    position = Union{Missing,Int}[]
    value = Union{Missing,Int}[]
    pct_change = Union{Missing,Float64}[]

    for o in owners
        push!(org, o["organization"])
        push!(report_date, _get(o, "reportDate"; sub="fmt", as_date=true))
        push!(pct_held, _get(o, "pctHeld"; sub="raw"))
        push!(position, _get(o, "position"; sub="raw"))
        push!(value, _get(o, "value"; sub="raw"))
        push!(pct_change, _get(o, "pctChange"; sub="raw"))
    end

    return Dict{String,Vector}("organization" => org, "report_date" => report_date,
                               "pct_held" => pct_held, "position" => position,
                               "value" => value, "pct_change" => pct_change)
end
institutional_ownership(s::AbstractString) = get_quote_summary(s) |> institutional_ownership

# ─── Accessor: major_holders_breakdown ────────────────────────────────────────

"""
    major_holders_breakdown(summary_or_symbol) -> Dict

Extract major holders breakdown (insider %, institutional %, etc).
"""
function major_holders_breakdown(qs::AbstractDict)
    _assert_module(qs, "majorHoldersBreakdown")
    data = qs["majorHoldersBreakdown"]
    result = Dict{String,Any}(String(k) => v for (k, v) in data)
    delete!(result, "maxAge")
    return result
end
major_holders_breakdown(s::AbstractString) = get_quote_summary(s) |> major_holders_breakdown

# ─── Accessor: recommendation_trend ──────────────────────────────────────────

"""
    recommendation_trend(summary_or_symbol) -> Dict

Extract analyst recommendation trend.
"""
function recommendation_trend(qs::AbstractDict)
    _assert_module(qs, "recommendationTrend")
    trend = qs["recommendationTrend"]["trend"]
    isempty(trend) && return Dict{String,Vector}()

    period = String[]
    strongbuy = Int[]
    buy = Int[]
    hold = Int[]
    sell = Int[]
    strongsell = Int[]

    for t in trend
        push!(period, t["period"])
        push!(strongbuy, Int(t["strongBuy"]))
        push!(buy, Int(t["buy"]))
        push!(hold, Int(t["hold"]))
        push!(sell, Int(t["sell"]))
        push!(strongsell, Int(t["strongSell"]))
    end

    return Dict{String,Vector}("period" => period, "strongbuy" => strongbuy,
                               "buy" => buy, "hold" => hold,
                               "sell" => sell, "strongsell" => strongsell)
end
recommendation_trend(s::AbstractString) = get_quote_summary(s) |> recommendation_trend

# ─── Accessor: summary_detail ─────────────────────────────────────────────────

"""
    summary_detail(summary_or_symbol) -> Dict

Extract summary detail (PE ratios, dividend yield, market cap, etc).
"""
function summary_detail(qs::AbstractDict)
    _assert_module(qs, "summaryDetail")
    result = Dict{String,Any}(String(k) => v for (k, v) in qs["summaryDetail"])
    delete!(result, "maxAge")
    return result
end
summary_detail(s::AbstractString) = get_quote_summary(s) |> summary_detail

# ─── Accessor: sector_industry ────────────────────────────────────────────────

"""
    sector_industry(summary_or_symbol) -> Dict

Extract sector and industry classification.
"""
function sector_industry(qs::AbstractDict)
    @assert haskey(qs, "summaryProfile") "No summaryProfile in quote summary data."
    sp = qs["summaryProfile"]
    return Dict{String,String}("sector" => get(sp, "sector", ""), "industry" => get(sp, "industry", ""))
end
sector_industry(s::AbstractString) = get_quote_summary(s) |> sector_industry

# ─── Accessor: upgrade_downgrade_history ──────────────────────────────────────

"""
    upgrade_downgrade_history(summary_or_symbol) -> Dict

Extract analyst upgrade/downgrade history.
"""
function upgrade_downgrade_history(qs::AbstractDict)
    _assert_module(qs, "upgradeDowngradeHistory")
    history = qs["upgradeDowngradeHistory"]["history"]
    isempty(history) && return Dict{String,Vector}()

    firm = String[]
    date = Union{Missing,DateTime}[]
    to_grade = Union{Missing,String}[]
    from_grade = Union{Missing,String}[]
    action = Union{Missing,String}[]

    for h in history
        push!(firm, h["firm"])
        push!(date, haskey(h, "epochGradeDate") ? unix2datetime(h["epochGradeDate"]) : missing)
        push!(to_grade, _get(h, "toGrade"))
        push!(from_grade, _get(h, "fromGrade"))
        push!(action, _get(h, "action"))
    end

    return Dict{String,Vector}("firm" => firm, "date" => date,
                               "to_grade" => to_grade, "from_grade" => from_grade,
                               "action" => action)
end
upgrade_downgrade_history(s::AbstractString) = get_quote_summary(s) |> upgrade_downgrade_history

# ─── Internal: module assertion ───────────────────────────────────────────────

function _assert_module(qs::AbstractDict, mod::String)
    @assert haskey(qs, mod) "Module '$mod' not found. Fetch with: get_quote_summary(symbol)"
end
