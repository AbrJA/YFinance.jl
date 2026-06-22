# ─────────────────────────────────────────────────────────────────────────────
# quote_summary.jl — Quote summary and accessor functions
# ─────────────────────────────────────────────────────────────────────────────

"""
    quote_summary(symbol::String; item=nothing, timeout=10) -> Dict{String,Any}

Retrieve quote summary data from Yahoo Finance.

# Arguments
- `symbol` — Ticker symbol (e.g., `"AAPL"`)
- `item` — Module name(s): a `String` or `Vector{String}`. Valid items in [`QUOTE_SUMMARY_ITEMS`](@ref). If `nothing`, fetches all available items.
- `timeout` — HTTP timeout in seconds

# Returns
A `Dict{String,Any}`. When `item` is a single string, returns that module's data directly.

# Examples
```julia
julia> quote_summary("AAPL")
Dict{String, Any} with 31 entries...

julia> quote_summary("AAPL", item="quoteType")
Dict{String, Any} with 13 entries...
```
"""
function quote_summary(symbol::String; item=nothing, timeout::Int=10)
    _ensure_session!()
    if isempty(_SESSION.crumb)
        throw(YFinanceError(symbol, "Could not retrieve crumb for quote summary", nothing))
    end

    symbol = _validated_symbol(symbol)

    if isnothing(item)
        item = QUOTE_SUMMARY_ITEMS
    end

    @assert all(in.(isa(item, AbstractString) ? [item] : item, Ref(QUOTE_SUMMARY_ITEMS))) "Invalid item(s). Valid options: QUOTE_SUMMARY_ITEMS"

    modules_str = isa(item, AbstractString) ? item : join(item, ",")
    q = Dict("formatted" => "false", "modules" => modules_str, "crumb" => _SESSION.crumb)

    url = _build_url("https://query2.finance.yahoo.com/v10/finance/quoteSummary/$(symbol)", q)
    resp = _yahoo_request(url, symbol; timeout)
    res = JSON.parse(String(copy(resp.body)))

    if isa(item, AbstractString)
        return res["quoteSummary"]["result"][1][item]
    else
        return res["quoteSummary"]["result"][1]
    end
end

# ─── Helpers ──────────────────────────────────────────────────────────────────

function _no_key_missing(x::AbstractDict, k::String, subitem=nothing, to_date=false, from_int=false)
    haskey(x, k) || return missing
    if isnothing(subitem)
        to_date ? (from_int ? unix2datetime(x[k]) : DateTime(x[k])) : x[k]
    else
        to_date ? (from_int ? unix2datetime(x[k][subitem]) : DateTime(x[k][subitem])) : x[k][subitem]
    end
end

_quote_type(qs::AbstractDict) = qs["quoteType"]["quoteType"]

const _FIELD_QUOTE_TYPES = Dict(
    :calendarEvents => ["EQUITY"],
    :earnings => ["EQUITY"],
    :earningsHistory => ["EQUITY"],
    :insiderHolders => ["EQUITY"],
    :insiderTransactions => ["EQUITY"],
    :institutionOwnership => ["EQUITY"],
    :majorHoldersBreakdown => ["EQUITY"],
    :recommendationTrend => ["EQUITY"],
    :summaryDetail => ["ETF", "MUTUALFUND", "CURRENCY", "FUTURE", "EQUITY"],
    :summaryProfile => ["ETF", "MUTUALFUND", "EQUITY"],
    :upgradeDowngradeHistory => ["EQUITY"],
)

function _assert_field_available(qs::AbstractDict, field::Symbol, field_name::String)
    qt = _quote_type(qs)
    valid = get(_FIELD_QUOTE_TYPES, field, String[])
    qt in valid || throw(YFinanceError("", "$field_name not available for $qt (only: $(join(valid, ", ")))", nothing))
    haskey(qs, String(field)) || throw(YFinanceError("", "No $field_name data in quote summary", nothing))
end

# ─── Accessor Functions ───────────────────────────────────────────────────────

"""
    calendar_events(qs::AbstractDict)
    calendar_events(symbol::AbstractString)

Extract calendar events (dividend date, earnings dates, ex-dividend date) from quote summary.
"""
function calendar_events(qs::AbstractDict)
    _assert_field_available(qs, :calendarEvents, "calendar events")
    ce = qs["calendarEvents"]
    return OrderedDict{String,Any}(
        "dividend_date" => unix2datetime(ce["dividendDate"]),
        "earnings_dates" => unix2datetime.(ce["earnings"]["earningsDate"]),
        "exdividend_date" => unix2datetime(ce["exDividendDate"])
    )
end
calendar_events(symbol::AbstractString) = quote_summary(symbol) |> calendar_events

"""
    earnings_estimates(qs::AbstractDict)
    earnings_estimates(symbol::AbstractString)

Extract quarterly earnings estimates and actuals from quote summary.
"""
function earnings_estimates(qs::AbstractDict)
    _assert_field_available(qs, :earnings, "earnings estimates")
    ec = qs["earnings"]["earningsChart"]
    isempty(ec["quarterly"]) && return OrderedDict{String,Vector}()

    quarter = String[]
    actual = Union{Missing,Float64}[]
    estimate = Float64[]
    for i in ec["quarterly"]
        push!(quarter, i["date"])
        push!(actual, i["actual"])
        push!(estimate, i["estimate"])
    end
    push!(quarter, string(ec["currentQuarterEstimateDate"], ec["currentQuarterEstimateYear"]))
    push!(actual, missing)
    push!(estimate, ec["currentQuarterEstimate"])

    return OrderedDict{String,Vector}("quarter" => quarter, "estimate" => estimate, "actual" => actual)
end
earnings_estimates(symbol::AbstractString) = quote_summary(symbol) |> earnings_estimates

"""
    eps(qs::AbstractDict)
    eps(symbol::AbstractString)

Extract earnings per share history from quote summary.
"""
function eps(qs::AbstractDict)
    _assert_field_available(qs, :earningsHistory, "EPS")
    history = qs["earningsHistory"]["history"]
    isempty(history) && return OrderedDict{String,Vector}()

    quarter = DateTime[]
    actual_v = Float64[]
    estimate_v = Float64[]
    surprise_v = Float64[]
    for i in history
        push!(quarter, DateTime(i["quarter"]["fmt"]))
        push!(actual_v, i["epsActual"]["raw"])
        push!(estimate_v, i["epsEstimate"]["raw"])
        push!(surprise_v, i["surprisePercent"]["raw"])
    end
    return OrderedDict{String,Vector}("quarter" => quarter, "estimate" => estimate_v, "actual" => actual_v, "surprise" => surprise_v)
end
eps(symbol::AbstractString) = quote_summary(symbol) |> eps

"""
    insider_holders(qs::AbstractDict)
    insider_holders(symbol::AbstractString)

Extract insider holdings from quote summary.
"""
function insider_holders(qs::AbstractDict)
    _assert_field_available(qs, :insiderHolders, "insider holders")
    holders = qs["insiderHolders"]["holders"]
    isempty(holders) && return OrderedDict{String,Vector}()

    name = String[]
    relation = Union{Missing,String}[]
    des = Union{Missing,String}[]
    lasttrandt = Union{Missing,DateTime}[]
    direct = Union{Missing,Int}[]
    direct_dt = Union{Missing,DateTime}[]
    indirect = Union{Missing,Int}[]
    indirect_dt = Union{Missing,DateTime}[]

    for i in holders
        push!(name, i["name"])
        push!(relation, _no_key_missing(i, "relation"))
        push!(des, _no_key_missing(i, "transactionDescription"))
        push!(lasttrandt, _no_key_missing(i, "latestTransDate", "fmt", true))
        push!(direct, _no_key_missing(i, "positionDirect", "raw"))
        push!(direct_dt, _no_key_missing(i, "positionDirectDate", "fmt", true))
        push!(indirect, _no_key_missing(i, "positionIndirect", "raw"))
        push!(indirect_dt, _no_key_missing(i, "positionIndirectDate", "fmt", true))
    end

    return OrderedDict{String,Vector}(
        "name" => name, "relation" => relation, "description" => des,
        "latest_trans_date" => lasttrandt, "position_direct" => direct,
        "position_direct_date" => direct_dt, "position_indirect" => indirect,
        "position_indirect_date" => indirect_dt
    )
end
insider_holders(symbol::AbstractString) = quote_summary(symbol) |> insider_holders

"""
    insider_transactions(qs::AbstractDict)
    insider_transactions(symbol::AbstractString)

Extract insider transactions from quote summary.
"""
function insider_transactions(qs::AbstractDict)
    _assert_field_available(qs, :insiderTransactions, "insider transactions")
    txns = qs["insiderTransactions"]["transactions"]
    isempty(txns) && return OrderedDict{String,Vector}()

    name = String[]
    relation = Union{Missing,String}[]
    text = Union{Missing,String}[]
    date = Union{Missing,DateTime}[]
    ownership = Union{Missing,String}[]
    shares = Union{Missing,Int}[]
    value = Union{Missing,Int}[]

    for i in txns
        push!(name, i["filerName"])
        push!(relation, _no_key_missing(i, "filerRelation"))
        push!(text, _no_key_missing(i, "transactionText"))
        push!(date, _no_key_missing(i, "startDate", "fmt", true))
        push!(ownership, _no_key_missing(i, "ownership"))
        push!(shares, _no_key_missing(i, "shares", "raw"))
        push!(value, _no_key_missing(i, "value", "raw"))
    end

    return OrderedDict{String,Vector}(
        "filer_name" => name, "filer_relation" => relation, "transaction_text" => text,
        "date" => date, "ownership" => ownership, "shares" => shares, "value" => value
    )
end
insider_transactions(symbol::AbstractString) = quote_summary(symbol) |> insider_transactions

"""
    institutional_ownership(qs::AbstractDict)
    institutional_ownership(symbol::AbstractString)

Extract institutional ownership from quote summary.
"""
function institutional_ownership(qs::AbstractDict)
    _assert_field_available(qs, :institutionOwnership, "institutional ownership")
    owners = qs["institutionOwnership"]["ownershipList"]
    isempty(owners) && return OrderedDict{String,Vector}()

    organization = String[]
    report_date = Union{Missing,DateTime}[]
    pct_held = Union{Missing,Float64}[]
    position = Union{Missing,Int}[]
    value = Union{Missing,Int}[]
    pct_change = Union{Missing,Float64}[]

    for i in owners
        push!(organization, i["organization"])
        push!(report_date, _no_key_missing(i, "reportDate", "fmt", true))
        push!(pct_held, _no_key_missing(i, "pctHeld", "raw"))
        push!(position, _no_key_missing(i, "position", "raw"))
        push!(value, _no_key_missing(i, "value", "raw"))
        push!(pct_change, _no_key_missing(i, "pctChange", "raw"))
    end

    return OrderedDict{String,Vector}(
        "organization" => organization, "report_date" => report_date,
        "pct_held" => pct_held, "position" => position,
        "value" => value, "pct_change" => pct_change
    )
end
institutional_ownership(symbol::AbstractString) = quote_summary(symbol) |> institutional_ownership

"""
    major_holders_breakdown(qs::AbstractDict)
    major_holders_breakdown(symbol::AbstractString)

Extract major holders breakdown from quote summary.
"""
function major_holders_breakdown(qs::AbstractDict)
    _assert_field_available(qs, :majorHoldersBreakdown, "major holders breakdown")
    result = OrderedDict{String,Real}(String(k) => v for (k, v) in qs["majorHoldersBreakdown"])
    delete!(result, "maxAge")
    return result
end
major_holders_breakdown(symbol::AbstractString) = quote_summary(symbol) |> major_holders_breakdown

"""
    recommendation_trend(qs::AbstractDict)
    recommendation_trend(symbol::AbstractString)

Extract analyst recommendation trend from quote summary.
"""
function recommendation_trend(qs::AbstractDict)
    _assert_field_available(qs, :recommendationTrend, "recommendation trend")
    trend = qs["recommendationTrend"]["trend"]
    isempty(trend) && return OrderedDict{String,Vector}()

    period = String[]
    strongbuy = Int[]
    buy = Int[]
    hold = Int[]
    sell = Int[]
    strongsell = Int[]

    for i in trend
        push!(period, i["period"])
        push!(strongbuy, i["strongBuy"])
        push!(buy, i["buy"])
        push!(hold, i["hold"])
        push!(sell, i["sell"])
        push!(strongsell, i["strongSell"])
    end

    return OrderedDict{String,Vector}(
        "period" => period, "strong_buy" => strongbuy, "buy" => buy,
        "hold" => hold, "sell" => sell, "strong_sell" => strongsell
    )
end
recommendation_trend(symbol::AbstractString) = quote_summary(symbol) |> recommendation_trend

"""
    summary_detail(qs::AbstractDict)
    summary_detail(symbol::AbstractString)

Extract summary detail from quote summary.
"""
function summary_detail(qs::AbstractDict)
    _assert_field_available(qs, :summaryDetail, "summary detail")
    result = OrderedDict{String,Any}(String(k) => v for (k, v) in qs["summaryDetail"])
    delete!(result, "maxAge")
    return result
end
summary_detail(symbol::AbstractString) = quote_summary(symbol) |> summary_detail

"""
    sector_industry(qs::AbstractDict)
    sector_industry(symbol::AbstractString)

Extract sector and industry from quote summary.
"""
function sector_industry(qs::AbstractDict)
    _assert_field_available(qs, :summaryProfile, "sector/industry")
    return OrderedDict{String,String}(
        "sector" => qs["summaryProfile"]["sector"],
        "industry" => qs["summaryProfile"]["industry"]
    )
end
sector_industry(symbol::AbstractString) = quote_summary(symbol) |> sector_industry

"""
    upgrade_downgrade_history(qs::AbstractDict)
    upgrade_downgrade_history(symbol::AbstractString)

Extract analyst upgrade/downgrade history from quote summary.
"""
function upgrade_downgrade_history(qs::AbstractDict)
    _assert_field_available(qs, :upgradeDowngradeHistory, "upgrade/downgrade history")
    history = qs["upgradeDowngradeHistory"]["history"]
    isempty(history) && return OrderedDict{String,Vector}()

    firm = String[]
    date = Union{Missing,DateTime}[]
    to_grade = Union{Missing,String}[]
    from_grade = Union{Missing,String}[]
    action = Union{Missing,String}[]

    for i in history
        push!(firm, i["firm"])
        push!(date, _no_key_missing(i, "epochGradeDate", nothing, true, true))
        push!(to_grade, _no_key_missing(i, "toGrade"))
        push!(from_grade, _no_key_missing(i, "fromGrade"))
        push!(action, _no_key_missing(i, "action"))
    end

    return OrderedDict{String,Vector}(
        "firm" => firm, "date" => date, "to_grade" => to_grade,
        "from_grade" => from_grade, "action" => action
    )
end
upgrade_downgrade_history(symbol::AbstractString) = quote_summary(symbol) |> upgrade_downgrade_history
