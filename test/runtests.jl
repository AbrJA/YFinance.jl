using YFinance, Dates, Base64, Tables, OrderedCollections
using Test

@testset "YFinance" begin

    # ─── Unit Tests (no network) ─────────────────────────────────────────────
    @testset "Internal Utilities" begin
        # Date conversion
        @test YFinance._date_to_unix("2000-01-01") == 946684800
        @test YFinance._date_to_unix(Date(2000, 1, 1)) == 946684800
        @test YFinance._date_to_unix(DateTime(2000, 1, 1)) == 946684800
        @test YFinance._date_to_unix(Date(1970, 1, 1)) == 0
        @test YFinance._date_to_unix(Date(200, 1, 1)) == -55855785600

        # URL encoding
        @test YFinance._uri_encode("hello world") == "hello%20world"
        @test YFinance._uri_encode("AAPL") == "AAPL"
        @test YFinance._uri_encode("a&b=c") == "a%26b%3Dc"
        @test YFinance._uri_encode("") == ""
        @test YFinance._uri_encode("café") == "caf%C3%A9"

        # URL building
        @test YFinance._build_url("https://example.com", Dict("a" => "1")) == "https://example.com?a=1"
        @test YFinance._build_url("https://example.com", Dict{String,String}()) == "https://example.com"
        @test YFinance._build_url("https://example.com", Dict("a" => "1", "b" => "")) == "https://example.com?a=1"

        # Clean prices with nothing values
        v = [1.0, 2.0, 3.0]
        @test YFinance._clean_prices_nothing(v) === v
        @test YFinance._clean_prices_nothing([1, 2, 3]) == [1.0, 2.0, 3.0]
        @test isnan(YFinance._clean_prices_nothing([nothing, 1.0])[1])
        @test isequal(YFinance._clean_prices_nothing([nothing, nothing]), [NaN, NaN])

        # ResponseError display
        err = YFinance.ResponseError(404, UInt8[])
        @test sprint(showerror, err) == "ResponseError: HTTP 404"
        err2 = YFinance.ResponseError(500, Vector{UInt8}("Server Error"))
        @test contains(sprint(showerror, err2), "Server Error")
    end

    @testset "Process Response" begin
        price_test_resp = UInt8[0x7b, 0x22, 0x63, 0x68, 0x61, 0x72, 0x74, 0x22, 0x3a, 0x7b, 0x22, 0x72, 0x65, 0x73, 0x75, 0x6c, 0x74, 0x22, 0x3a, 0x5b, 0x7b, 0x22, 0x6d, 0x65, 0x74, 0x61, 0x22, 0x3a, 0x7b, 0x22, 0x63, 0x75, 0x72, 0x72, 0x65, 0x6e, 0x63, 0x79, 0x22, 0x3a, 0x22, 0x55, 0x53, 0x44, 0x22, 0x2c, 0x22, 0x73, 0x79, 0x6d, 0x62, 0x6f, 0x6c, 0x22, 0x3a, 0x22, 0x41, 0x41, 0x50, 0x4c, 0x22, 0x2c, 0x22, 0x65, 0x78, 0x63, 0x68, 0x61, 0x6e, 0x67, 0x65, 0x4e, 0x61, 0x6d, 0x65, 0x22, 0x3a, 0x22, 0x4e, 0x4d, 0x53, 0x22, 0x2c, 0x22, 0x66, 0x75, 0x6c, 0x6c, 0x45, 0x78, 0x63, 0x68, 0x61, 0x6e, 0x67, 0x65, 0x4e, 0x61, 0x6d, 0x65, 0x22, 0x3a, 0x22, 0x4e, 0x61, 0x73, 0x64, 0x61, 0x71, 0x47, 0x53, 0x22, 0x2c, 0x22, 0x69, 0x6e, 0x73, 0x74, 0x72, 0x75, 0x6d, 0x65, 0x6e, 0x74, 0x54, 0x79, 0x70, 0x65, 0x22, 0x3a, 0x22, 0x45, 0x51, 0x55, 0x49, 0x54, 0x59, 0x22, 0x2c, 0x22, 0x66, 0x69, 0x72, 0x73, 0x74, 0x54, 0x72, 0x61, 0x64, 0x65, 0x44, 0x61, 0x74, 0x65, 0x22, 0x3a, 0x33, 0x34, 0x35, 0x34, 0x37, 0x39, 0x34, 0x30, 0x30, 0x2c, 0x22, 0x72, 0x65, 0x67, 0x75, 0x6c, 0x61, 0x72, 0x4d, 0x61, 0x72, 0x6b, 0x65, 0x74, 0x54, 0x69, 0x6d, 0x65, 0x22, 0x3a, 0x31, 0x37, 0x32, 0x38, 0x30, 0x37, 0x32, 0x30, 0x30, 0x31, 0x2c, 0x22, 0x68, 0x61, 0x73, 0x50, 0x72, 0x65, 0x50, 0x6f, 0x73, 0x74, 0x4d, 0x61, 0x72, 0x6b, 0x65, 0x74, 0x44, 0x61, 0x74, 0x61, 0x22, 0x3a, 0x74, 0x72, 0x75, 0x65, 0x2c, 0x22, 0x67, 0x6d, 0x74, 0x6f, 0x66, 0x66, 0x73, 0x65, 0x74, 0x22, 0x3a, 0x2d, 0x31, 0x34, 0x34, 0x30, 0x30, 0x2c, 0x22, 0x74, 0x69, 0x6d, 0x65, 0x7a, 0x6f, 0x6e, 0x65, 0x22, 0x3a, 0x22, 0x45, 0x44, 0x54, 0x22, 0x2c, 0x22, 0x65, 0x78, 0x63, 0x68, 0x61, 0x6e, 0x67, 0x65, 0x54, 0x69, 0x6d, 0x65, 0x7a, 0x6f, 0x6e, 0x65, 0x4e, 0x61, 0x6d, 0x65, 0x22, 0x3a, 0x22, 0x41, 0x6d, 0x65, 0x72, 0x69, 0x63, 0x61, 0x2f, 0x4e, 0x65, 0x77, 0x5f, 0x59, 0x6f, 0x72, 0x6b, 0x22, 0x2c, 0x22, 0x72, 0x65, 0x67, 0x75, 0x6c, 0x61, 0x72, 0x4d, 0x61, 0x72, 0x6b, 0x65, 0x74, 0x50, 0x72, 0x69, 0x63, 0x65, 0x22, 0x3a, 0x32, 0x32, 0x36, 0x2e, 0x38, 0x30, 0x30, 0x30, 0x30, 0x33, 0x30, 0x35, 0x31, 0x37, 0x35, 0x37, 0x38, 0x31, 0x2c, 0x22, 0x63, 0x68, 0x61, 0x72, 0x74, 0x50, 0x72, 0x65, 0x76, 0x69, 0x6f, 0x75, 0x73, 0x43, 0x6c, 0x6f, 0x73, 0x65, 0x22, 0x3a, 0x32, 0x32, 0x37, 0x2e, 0x35, 0x35, 0x30, 0x30, 0x30, 0x33, 0x30, 0x35, 0x31, 0x37, 0x35, 0x37, 0x38, 0x2c, 0x22, 0x64, 0x61, 0x74, 0x61, 0x47, 0x72, 0x61, 0x6e, 0x75, 0x6c, 0x61, 0x72, 0x69, 0x74, 0x79, 0x22, 0x3a, 0x22, 0x31, 0x64, 0x22, 0x2c, 0x22, 0x72, 0x61, 0x6e, 0x67, 0x65, 0x22, 0x3a, 0x22, 0x22, 0x2c, 0x22, 0x76, 0x61, 0x6c, 0x69, 0x64, 0x52, 0x61, 0x6e, 0x67, 0x65, 0x73, 0x22, 0x3a, 0x5b, 0x22, 0x31, 0x64, 0x22, 0x2c, 0x22, 0x35, 0x64, 0x22, 0x2c, 0x22, 0x31, 0x6d, 0x6f, 0x22, 0x2c, 0x22, 0x33, 0x6d, 0x6f, 0x22, 0x2c, 0x22, 0x36, 0x6d, 0x6f, 0x22, 0x2c, 0x22, 0x31, 0x79, 0x22, 0x2c, 0x22, 0x32, 0x79, 0x22, 0x2c, 0x22, 0x35, 0x79, 0x22, 0x2c, 0x22, 0x31, 0x30, 0x79, 0x22, 0x2c, 0x22, 0x79, 0x74, 0x64, 0x22, 0x2c, 0x22, 0x6d, 0x61, 0x78, 0x22, 0x5d, 0x7d, 0x2c, 0x22, 0x74, 0x69, 0x6d, 0x65, 0x73, 0x74, 0x61, 0x6d, 0x70, 0x22, 0x3a, 0x5b, 0x31, 0x37, 0x32, 0x38, 0x30, 0x34, 0x35, 0x30, 0x30, 0x30, 0x5d, 0x2c, 0x22, 0x69, 0x6e, 0x64, 0x69, 0x63, 0x61, 0x74, 0x6f, 0x72, 0x73, 0x22, 0x3a, 0x7b, 0x22, 0x71, 0x75, 0x6f, 0x74, 0x65, 0x22, 0x3a, 0x5b, 0x7b, 0x22, 0x68, 0x69, 0x67, 0x68, 0x22, 0x3a, 0x5b, 0x32, 0x32, 0x38, 0x2e, 0x38, 0x30, 0x30, 0x30, 0x30, 0x33, 0x30, 0x35, 0x31, 0x37, 0x35, 0x37, 0x38, 0x31, 0x5d, 0x2c, 0x22, 0x6f, 0x70, 0x65, 0x6e, 0x22, 0x3a, 0x5b, 0x32, 0x32, 0x38, 0x2e, 0x30, 0x32, 0x39, 0x39, 0x39, 0x38, 0x37, 0x37, 0x39, 0x32, 0x39, 0x36, 0x38, 0x38, 0x5d, 0x2c, 0x22, 0x6c, 0x6f, 0x77, 0x22, 0x3a, 0x5b, 0x32, 0x32, 0x35, 0x2e, 0x33, 0x37, 0x30, 0x30, 0x30, 0x32, 0x37, 0x34, 0x36, 0x35, 0x38, 0x32, 0x30, 0x33, 0x5d, 0x2c, 0x22, 0x63, 0x6c, 0x6f, 0x73, 0x65, 0x22, 0x3a, 0x5b, 0x32, 0x32, 0x36, 0x2e, 0x38, 0x30, 0x30, 0x30, 0x30, 0x33, 0x30, 0x35, 0x31, 0x37, 0x35, 0x37, 0x38, 0x31, 0x5d, 0x2c, 0x22, 0x76, 0x6f, 0x6c, 0x75, 0x6d, 0x65, 0x22, 0x3a, 0x5b, 0x33, 0x38, 0x32, 0x37, 0x33, 0x37, 0x30, 0x30, 0x5d, 0x7d, 0x5d, 0x2c, 0x22, 0x61, 0x64, 0x6a, 0x63, 0x6c, 0x6f, 0x73, 0x65, 0x22, 0x3a, 0x5b, 0x7b, 0x22, 0x61, 0x64, 0x6a, 0x63, 0x6c, 0x6f, 0x73, 0x65, 0x22, 0x3a, 0x5b, 0x32, 0x32, 0x36, 0x2e, 0x38, 0x30, 0x30, 0x30, 0x30, 0x33, 0x30, 0x35, 0x31, 0x37, 0x35, 0x37, 0x38, 0x31, 0x5d, 0x7d, 0x5d, 0x7d, 0x7d, 0x5d, 0x2c, 0x22, 0x65, 0x72, 0x72, 0x6f, 0x72, 0x22, 0x3a, 0x6e, 0x75, 0x6c, 0x6c, 0x7d, 0x7d]
        d = YFinance._process_response(price_test_resp, "AAPL", "1d", false, false, false)
        @test d["ticker"] == "AAPL"
        @test haskey(d, "timestamp")
        @test haskey(d, "open")
        @test haskey(d, "close")
        @test haskey(d, "vol")
        @test length(d["timestamp"]) == length(d["open"])
        @test all(x -> x isa Float64, d["open"])

        # With autoadjust
        d_adj = YFinance._process_response(price_test_resp, "AAPL", "1d", true, false, false)
        @test haskey(d_adj, "adjclose")

        # With exchange local time
        d_local = YFinance._process_response(price_test_resp, "AAPL", "1d", false, true, false)
        @test d_local["timestamp"] != d["timestamp"]
    end

    @testset "Input Validation" begin
        # Invalid interval
        @test_throws AssertionError get_prices("AAPL", interval="invalid")
        # Invalid news language
        @test_throws ArgumentError search_news("AAPL", lang="xx-yy")
        # Invalid fundamental interval
        @test_throws AssertionError get_fundamentals("AAPL", "income_statement", "invalid_interval", "2020-01-01", "2021-01-01")
        # Invalid fundamental item
        @test_throws AssertionError get_fundamentals("AAPL", "not_a_real_item", "annual", "2020-01-01", "2021-01-01")
    end

    @testset "Proxy Settings" begin
        # Set proxy with auth
        set_proxy!("http://proxy.test:8080", "user123", "pass456")
        @test YFinance._SESSION.proxy == "http://proxy.test:8080"
        @test haskey(YFinance._SESSION.proxy_auth, "Proxy-Authorization")
        @test YFinance._SESSION.proxy_auth["Proxy-Authorization"] == "Basic $(Base64.base64encode("user123:pass456"))"

        # Set proxy without auth
        set_proxy!("http://open-proxy.test:3128")
        @test YFinance._SESSION.proxy == "http://open-proxy.test:3128"
        @test isempty(YFinance._SESSION.proxy_auth)

        # Clear
        clear_proxy!()
        @test isnothing(YFinance._SESSION.proxy)
        @test isempty(YFinance._SESSION.proxy_auth)
    end

    @testset "Constants" begin
        @test QUOTE_SUMMARY_ITEMS isa Vector{String}
        @test "price" in QUOTE_SUMMARY_ITEMS
        @test FUNDAMENTAL_TYPES isa OrderedCollections.OrderedDict
        @test haskey(FUNDAMENTAL_TYPES, "income_statement")
        @test FUNDAMENTAL_INTERVALS isa Vector{String}
        @test "annual" in FUNDAMENTAL_INTERVALS
    end

    # ─── Integration Tests (network required) ─────────────────────────────────
    @testset "Symbol Validation" begin
        ta = valid_symbols(["aapl", "amd", "adsflajsldf"])
        @test "aapl" in ta || "AAPL" in ta
        @test !("adsflajsldf" in ta)
        @test length(ta) == 2

        @test is_valid_symbol("AAPL") == true
        @test is_valid_symbol("XYZNOTREAL123") == false
    end

    @testset "Get Prices" begin
        # Basic daily price fetch
        ta = get_prices("AAPL", range="5d", interval="1d")
        @test !isempty(ta)
        @test ta["ticker"] == "AAPL"
        @test length(ta["timestamp"]) > 0
        @test length(ta["open"]) == length(ta["close"])
        @test all(x -> x > 0, filter(!isnan, ta["close"]))

        # Minute data
        ta_min = get_prices("AAPL", interval="1m", range="5d")
        @test !isempty(ta_min)
        @test length(ta_min["timestamp"]) > 1

        # Date range request
        sleep(1)
        ta_range = get_prices("ADANIENT.NS", startdt="2023-01-01", enddt="2024-01-01")
        @test length(ta_range["timestamp"]) > 100

        # Non-US market
        sleep(1)
        ta_nse = get_prices("RELIANCE.NS", range="5d")
        @test !isempty(ta_nse)

        # Edge: invalid symbol with throw_error=false returns empty
        sleep(1)
        ta_bad = get_prices("XYZNOTREAL123", range="1d", throw_error=false)
        @test isempty(ta_bad)

        # Edge: minute data older than 30 days gives warning
        old_start = Dates.format(today() - Day(60), "yyyy-mm-dd")
        old_end = Dates.format(today() - Day(55), "yyyy-mm-dd")
        ta_old = get_prices("AAPL", startdt=old_start, enddt=old_end, interval="1m", throw_error=false)
        @test isempty(ta_old)
    end

    @testset "Dividends and Splits" begin
        sleep(1)
        # Google stock split 2022
        ta = get_prices("GOOGL", interval="1d", startdt="2022-01-01", enddt="2023-01-01", exchange_local_time=true, divsplits=true)
        @test haskey(ta, "div")
        @test haskey(ta, "split_ratio")
        @test maximum(ta["split_ratio"]) == 20  # 20:1 split
        @test length(ta["timestamp"]) == length(ta["div"])
        @test length(ta["timestamp"]) == length(ta["split_ratio"])

        # Dedicated splits function
        sleep(1)
        s = get_splits("AAPL", startdt="2000-01-01", enddt="2021-01-01")
        @test haskey(s, "ticker")
        @test s["ticker"] == "AAPL"
        @test length(s["timestamp"]) >= 3

        # Dedicated dividends function
        sleep(1)
        divs = get_dividends("AAPL", startdt="2021-01-01", enddt="2022-01-01")
        @test haskey(divs, "div")
        @test length(divs["div"]) >= 3
        @test all(x -> x > 0, divs["div"])
    end

    @testset "Fundamental Data" begin
        sleep(1)
        # Income statement
        ta = get_fundamentals("AAPL", "income_statement", "annual", Dates.today() - Year(5), Dates.today())
        @test "InterestExpense" in keys(ta)
        @test length(ta["InterestExpense"]) >= 3
        @test haskey(ta, "timestamp")

        # Single item
        sleep(1)
        ta_item = get_fundamentals("AAPL", "TotalRevenue", "quarterly", Dates.today() - Year(3), Dates.today())
        @test haskey(ta_item, "TotalRevenue")
        @test length(ta_item["TotalRevenue"]) >= 4

        # Invalid symbol
        sleep(1)
        ta_bad = get_fundamentals("XYZNOTREAL123", "income_statement", "annual", "2020-01-01", "2021-01-01")
        @test isempty(ta_bad)
    end

    @testset "Options" begin
        sleep(1)
        ta = get_options("AAPL")
        @test haskey(ta, "calls")
        @test haskey(ta, "puts")
        # Options data may be empty on weekends/holidays
        if !isempty(ta["calls"])
            @test length(ta["calls"]["strike"]) > 1
            @test length(ta["puts"]["strike"]) > 1
        end

        # Invalid symbol
        sleep(1)
        ta_bad = get_options("XYZNOTREAL123", throw_error=false)
        @test isnothing(ta_bad) || isempty(ta_bad)
    end

    @testset "QuoteSummary" begin
        sleep(1)
        ta = get_quote_summary("AAPL")
        @test "price" in keys(ta)

        @test haskey(calendar_events(ta), "earnings_dates")
        @test haskey(earnings_estimates(ta), "estimate")
        @test haskey(earnings_per_share(ta), "estimate")
        @test haskey(insider_holders(ta), "name")
        @test haskey(insider_transactions(ta), "filerName")
        @test haskey(institutional_ownership(ta), "organization")
        @test haskey(major_holders_breakdown(ta), "institutionsCount")
        @test haskey(recommendation_trend(ta), "strongbuy")
        @test haskey(summary_detail(ta), "tradeable")
        @test haskey(sector_industry(ta), "sector")
        @test haskey(upgrade_downgrade_history(ta), "firm")
    end

    @testset "Search Symbols" begin
        sleep(1)
        ta = search_symbols("microsoft")
        @test ta isa SearchResults
        @test length(ta) > 0
        @test ta[1] isa SearchResult
        @test !isempty(ta[1].symbol)

        # Search with special characters
        sleep(1)
        ta2 = search_symbols("S&P 500")
        @test ta2 isa SearchResults
    end

    @testset "News Search" begin
        sleep(1)
        ta = search_news("MSFT")
        @test ta isa NewsResults
        @test length(ta) > 0
        @test ta[1] isa NewsItem
        @test !isempty(ta[1].title)

        # Accessor functions
        @test length(titles(ta)) > 0
        @test titles(ta)[1] isa String
        @test length(links(ta)) > 0
        @test links(ta)[1] isa String
        @test length(timestamps(ta)) > 0
        @test timestamps(ta)[1] isa DateTime

        # Different language
        sleep(1)
        ta_de = search_news("Apple", lang="de")
        @test ta_de isa NewsResults
    end

    # ─── Tables.jl Integration ────────────────────────────────────────────────
    @testset "Tables.jl Interface" begin
        sleep(1)
        p = get_prices("AAPL", range="5d")
        t = YFinanceTable(p)
        @test Tables.istable(typeof(t))
        @test :ticker in Tables.columnnames(t)
        @test :open in Tables.columnnames(t)
        schema = Tables.schema(t)
        @test schema isa Tables.Schema

        # Row iteration
        rows = collect(Tables.rows(t))
        @test length(rows) > 0
        @test rows[1].ticker == "AAPL"

        # Column access
        @test Tables.getcolumn(t, :ticker) isa Vector{String}
        @test Tables.getcolumn(t, :open) isa Vector{Float64}
    end
end
