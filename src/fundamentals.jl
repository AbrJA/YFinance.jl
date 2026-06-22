# ─────────────────────────────────────────────────────────────────────────────
# fundamentals.jl — Financial statement data retrieval
# Returns Dict{String,Vector} (schema depends on user-selected items).
# ─────────────────────────────────────────────────────────────────────────────

const FUNDAMENTAL_TYPES = Dict{String,Vector{String}}(
    "income_statement" => [
        "Amortization", "AmortizationOfIntangiblesIncomeStatement",
        "BasicAverageShares", "BasicEPS", "CostOfRevenue", "DilutedAverageShares",
        "DilutedEPS", "DilutedNIAvailtoComStockholders", "DividendPerShare",
        "EBIT", "EBITDA", "GeneralAndAdministrativeExpense", "GrossProfit",
        "InterestExpense", "InterestExpenseNonOperating", "InterestIncome",
        "InterestIncomeNonOperating", "MinorityInterests", "NetIncome",
        "NetIncomeCommonStockholders", "NetIncomeContinuousOperations",
        "NetIncomeFromContinuingAndDiscontinuedOperation",
        "NetIncomeFromContinuingOperationNetMinorityInterest",
        "NetIncomeIncludingNoncontrollingInterests", "NetInterestIncome",
        "NetNonOperatingInterestIncomeExpense", "NormalizedBasicEPS",
        "NormalizedDilutedEPS", "NormalizedEBITDA", "NormalizedIncome",
        "OperatingExpense", "OperatingIncome", "OperatingRevenue",
        "OtherIncomeExpense", "OtherNonOperatingIncomeExpenses",
        "PreferredStockDividends", "PretaxIncome", "ReconciledCostOfRevenue",
        "ReconciledDepreciation", "ResearchAndDevelopment",
        "SellingGeneralAndAdministration", "TaxProvision", "TaxRateForCalcs",
        "TotalExpenses", "TotalOperatingIncomeAsReported", "TotalRevenue",
        "TotalUnusualItems", "TotalUnusualItemsExcludingGoodwill",
    ],
    "balance_sheet" => [
        "AccountsPayable", "AccountsReceivable", "AccumulatedDepreciation",
        "AdditionalPaidInCapital", "CashAndCashEquivalents",
        "CashCashEquivalentsAndShortTermInvestments", "CashFinancial",
        "CommonStock", "CommonStockEquity", "CurrentAssets", "CurrentDebt",
        "CurrentDebtAndCapitalLeaseObligation", "CurrentLiabilities",
        "GoodwillAndOtherIntangibleAssets", "GrossPPE", "Inventory",
        "InvestedCapital", "InvestmentsAndAdvances", "LongTermDebt",
        "LongTermDebtAndCapitalLeaseObligation", "MachineryFurnitureEquipment",
        "MinorityInterest", "NetDebt", "NetPPE", "NetTangibleAssets",
        "NonCurrentAssets", "OtherCurrentAssets", "OtherCurrentLiabilities",
        "OtherNonCurrentAssets", "OtherNonCurrentLiabilities",
        "OtherShortTermInvestments", "Payables", "PayablesAndAccruedExpenses",
        "Receivables", "RetainedEarnings", "ShareIssued", "StockholdersEquity",
        "TangibleBookValue", "TotalAssets", "TotalCapitalization", "TotalDebt",
        "TotalEquityGrossMinorityInterest", "TotalLiabilitiesNetMinorityInterest",
        "TotalNonCurrentAssets", "TotalNonCurrentLiabilitiesNetMinorityInterest",
        "TreasuryStock", "WorkingCapital",
    ],
    "cash_flow" => [
        "BeginningCashPosition", "CapitalExpenditure", "CashDividendsPaid",
        "CashFlowFromContinuingFinancingActivities",
        "CashFlowFromContinuingInvestingActivities",
        "CashFlowFromContinuingOperatingActivities",
        "ChangeInAccountPayable", "ChangeInInventory",
        "ChangeInOtherWorkingCapital", "ChangeInPayable",
        "ChangeInPayablesAndAccruedExpense", "ChangeInReceivables",
        "ChangeInWorkingCapital", "CommonStockDividendPaid",
        "CommonStockIssuance", "CommonStockPayments", "DeferredIncomeTax",
        "Depreciation", "DepreciationAmortizationDepletion",
        "DepreciationAndAmortization", "EndCashPosition",
        "FinancingCashFlow", "FreeCashFlow", "InvestingCashFlow",
        "IssuanceOfCapitalStock", "IssuanceOfDebt", "LongTermDebtIssuance",
        "LongTermDebtPayments", "NetCommonStockIssuance", "NetIncome",
        "NetIncomeFromContinuingOperations", "NetInvestmentPurchaseAndSale",
        "NetIssuancePaymentsOfDebt", "NetLongTermDebtIssuance",
        "NetOtherFinancingCharges", "NetOtherInvestingChanges",
        "NetPPEPurchaseAndSale", "NetShortTermDebtIssuance",
        "OperatingCashFlow", "PurchaseOfBusiness", "PurchaseOfInvestment",
        "PurchaseOfPPE", "RepaymentOfDebt", "RepurchaseOfCapitalStock",
        "SaleOfInvestment", "StockBasedCompensation",
    ],
    "valuation" => [
        "ForwardPeRatio", "PsRatio", "PbRatio", "EnterprisesValueEBITDARatio",
        "EnterprisesValueRevenueRatio", "PeRatio", "MarketCap",
        "EnterpriseValue", "PegRatio",
    ],
)

const FUNDAMENTAL_INTERVALS = ["annual", "quarterly", "monthly"]

# All valid item names (flattened)
const _ALL_FUNDAMENTAL_ITEMS = Set{String}(Iterators.flatten(values(FUNDAMENTAL_TYPES)))

"""
    get_fundamentals(symbol, item, interval, startdt, enddt; throw_error=false) -> Dict

Retrieve financial statement data from Yahoo Finance.

# Arguments
- `symbol::String` — Ticker (e.g. "AAPL")
- `item::String` — Statement type ("income_statement", "balance_sheet", "cash_flow",
  "valuation") or a specific line item (e.g. "TotalRevenue")
- `interval::String` — "annual", "quarterly", or "monthly"
- `startdt` / `enddt` — Date range (Date, DateTime, or "yyyy-mm-dd")
- `throw_error::Bool=false` — Throw on errors vs return empty Dict

# Returns
`Dict{String,Vector}` with "timestamp" key and one key per metric.

# Examples
```julia
get_fundamentals("AAPL", "income_statement", "annual", "2020-01-01", "2024-01-01")
get_fundamentals("AAPL", "TotalRevenue", "quarterly", "2022-01-01", "2024-01-01")
```
"""
function get_fundamentals(symbol::AbstractString, item::AbstractString,
                          interval::AbstractString, startdt, enddt; throw_error::Bool=false)
    @assert interval in FUNDAMENTAL_INTERVALS "Invalid interval '$interval'. Use: annual, quarterly, monthly"

    start_unix = _to_unix(startdt)
    end_unix = _to_unix(enddt)

    # Determine if fetching entire statement or single item
    is_statement = haskey(FUNDAMENTAL_TYPES, item)
    if !is_statement
        @assert item in _ALL_FUNDAMENTAL_ITEMS "Unknown item '$item'. See FUNDAMENTAL_TYPES for valid items."
    end

    query_items = if is_statement
        join(string.(interval, FUNDAMENTAL_TYPES[item]), ",")
    else
        string(interval, item)
    end

    params = Dict("symbol" => symbol, "type" => query_items,
                  "period1" => start_unix, "period2" => end_unix, "formatted" => "false")
    url = _build_url("https://query2.finance.yahoo.com/ws/fundamentals-timeseries/v1/finance/timeseries/$symbol", params)

    resp = _yahoo_get(url, symbol; timeout=10, throw_error)
    isnothing(resp) && return Dict{String,Vector}()

    return _parse_fundamentals(resp.body, item, interval, is_statement)
end

function _parse_fundamentals(body::Vector{UInt8}, item::String, interval::String, is_statement::Bool)
    parsed = JSON.parse(String(copy(body)))
    results = parsed["timeseries"]["result"]

    if is_statement
        output = Dict{String,Vector}()
        for entry in results
            haskey(entry, "timestamp") || continue
            ts = unix2datetime.(entry["timestamp"])
            key_name = entry["meta"]["type"][1]
            values_data = entry[key_name]
            vals = [v["reportedValue"]["raw"] for v in values_data]
            output["timestamp"] = ts
            output[replace(key_name, Regex("^(quarterly|annual|monthly)") => "")] = vals
        end
        return output
    else
        # Single item
        entry = results[1]
        query_key = string(interval, item)
        if !haskey(entry, query_key)
            return Dict{String,Vector}()
        end
        ts = unix2datetime.(entry["timestamp"])
        vals = [v["reportedValue"]["raw"] for v in entry[query_key]]
        return Dict{String,Vector}("timestamp" => ts, item => vals)
    end
end
