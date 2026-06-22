using YFinance
using Dates
using Test
using OrderedCollections

@testset "YFinance.jl v0.3" begin

    # ─── Unit Tests (no network) ─────────────────────────────────────────────
    @testset "Types" begin
        # YFinanceError
        err = YFinanceError("AAPL", "test error", 404)
        @test err.symbol == "AAPL"
        @test err.message == "test error"
        @test err.status == 404
        @test contains(sprint(showerror, err), "AAPL")
        @test contains(sprint(showerror, err), "404")

        err2 = YFinanceError("X", "no status", nothing)
        @test !contains(sprint(showerror, err2), "HTTP")

        # PriceData
        pd = PriceData("AAPL",
            [DateTime(2024,1,1), DateTime(2024,1,2)],
            [100.0, 101.0], [102.0, 103.0], [99.0, 100.0],
            [101.0, 102.0], [1e6, 2e6], [101.5, 102.5]
        )
        @test length(pd) == 2
        @test !isempty(pd)
        @test pd.ticker == "AAPL"
        @test contains(sprint(show, MIME"text/plain"(), pd), "PriceData")
        @test contains(sprint(show, MIME"text/plain"(), pd), "AAPL")

        # Empty PriceData
        empty_pd = PriceData("X", DateTime[], Float64[], Float64[], Float64[], Float64[], Float64[], nothing)
        @test isempty(empty_pd)
        @test length(empty_pd) == 0

        # DividendData
        dd = DividendData("AAPL", [DateTime(2024,1,1)], [0.24])
        @test length(dd) == 1
        @test contains(sprint(show, MIME"text/plain"(), dd), "DividendData")

        # SplitData
        sd = SplitData("AAPL", [DateTime(2020,8,31)], [4], [1], [4.0])
        @test length(sd) == 1
        @test contains(sprint(show, MIME"text/plain"(), sd), "SplitData")

        # OptionsChain
        calls = OptionSide(OrderedDict("strike" => Any[150.0, 155.0]))
        puts = OptionSide(OrderedDict("strike" => Any[145.0]))
        oc = OptionsChain("AAPL", calls, puts)
        @test length(oc.calls) == 2
        @test length(oc.puts) == 1
        @test contains(sprint(show, MIME"text/plain"(), oc), "OptionsChain")

        # FundamentalData
        fd = FundamentalData("AAPL", OrderedDict{String,Vector}("timestamp" => [DateTime(2024,1,1)], "Revenue" => Any[100]))
        @test length(fd) == 1
        @test contains(sprint(show, MIME"text/plain"(), fd), "FundamentalData")

        # SearchResult / SearchResults
        sr = SearchResult("MSFT", "Microsoft", "NASDAQ (NMS)", "EQUITY", "Technology", "Software")
        srs = SearchResults([sr])
        @test length(srs) == 1
        @test srs[1].symbol == "MSFT"

        # NewsItem / NewsResults
        ni = NewsItem("Title", "Publisher", "http://example.com", DateTime(2024,1,1), ["AAPL"])
        nr = NewsResults([ni])
        @test length(nr) == 1
        @test titles(nr) == ["Title"]
        @test links(nr) == ["http://example.com"]
        @test timestamps(nr) == [DateTime(2024,1,1)]
    end

    @testset "Tables.jl Interface" begin
        using Tables

        # PriceData
        pd = PriceData("AAPL",
            [DateTime(2024,1,1), DateTime(2024,1,2)],
            [100.0, 101.0], [102.0, 103.0], [99.0, 100.0],
            [101.0, 102.0], [1e6, 2e6], [101.5, 102.5]
        )
        @test Tables.istable(typeof(pd))
        @test Tables.columnaccess(typeof(pd))
        @test :timestamp in Tables.columnnames(pd)
        @test :adjclose in Tables.columnnames(pd)
        @test Tables.getcolumn(pd, :open) == [100.0, 101.0]
        @test Tables.getcolumn(pd, :ticker) == ["AAPL", "AAPL"]

        # PriceData without adjclose
        pd2 = PriceData("X", [DateTime(2024,1,1)], [1.0], [2.0], [0.5], [1.5], [100.0], nothing)
        @test :adjclose ∉ Tables.columnnames(pd2)

        # DividendData
        dd = DividendData("AAPL", [DateTime(2024,1,1)], [0.24])
        @test Tables.istable(typeof(dd))
        @test Tables.getcolumn(dd, :dividend) == [0.24]

        # SplitData
        sd = SplitData("AAPL", [DateTime(2020,8,31)], [4], [1], [4.0])
        @test Tables.istable(typeof(sd))
        @test Tables.getcolumn(sd, :ratio) == [4.0]

        # OptionSide
        os = OptionSide(OrderedDict("strike" => Any[150.0], "bid" => Any[2.5]))
        @test Tables.istable(typeof(os))
        @test Tables.getcolumn(os, :strike) == Any[150.0]

        # FundamentalData
        fd = FundamentalData("AAPL", OrderedDict{String,Vector}("timestamp" => [DateTime(2024,1,1)], "Revenue" => Any[100]))
        @test Tables.istable(typeof(fd))
        @test Tables.getcolumn(fd, :Revenue) == Any[100]
    end

    @testset "Internal Utilities" begin
        # Date conversion
        @test YFinance._date_to_unix("2000-01-01") == 946684800
        @test YFinance._date_to_unix(Date(2000, 1, 1)) == 946684800
        @test YFinance._date_to_unix(DateTime(2000, 1, 1)) == 946684800

        # URL encoding
        @test YFinance._uri_encode("hello world") == "hello%20world"
        @test YFinance._uri_encode("AAPL") == "AAPL"
        @test YFinance._uri_encode("a&b=c") == "a%26b%3Dc"
        @test YFinance._uri_encode("") == ""

        # URL building
        @test YFinance._build_url("https://example.com", Dict("a" => "1")) == "https://example.com?a=1"
        @test YFinance._build_url("https://example.com", Dict{String,String}()) == "https://example.com"

        # Clean values
        @test YFinance._clean_values([1.0, 2.0]) == [1.0, 2.0]
        @test YFinance._clean_values([1, 2, 3]) == [1.0, 2.0, 3.0]
        @test isnan(YFinance._clean_values([nothing, 1.0])[1])
    end

    @testset "Constants" begin
        @test "income_statement" in keys(FUNDAMENTAL_TYPES)
        @test "balance_sheet" in keys(FUNDAMENTAL_TYPES)
        @test "cash_flow" in keys(FUNDAMENTAL_TYPES)
        @test "valuation" in keys(FUNDAMENTAL_TYPES)
        @test "annual" in FUNDAMENTAL_INTERVALS
        @test "quarterly" in FUNDAMENTAL_INTERVALS
        @test "monthly" in FUNDAMENTAL_INTERVALS
        @test "assetProfile" in QUOTE_SUMMARY_ITEMS
        @test "summaryDetail" in QUOTE_SUMMARY_ITEMS
        @test length(QUOTE_SUMMARY_ITEMS) > 20
    end

    @testset "Input Validation" begin
        # Invalid interval
        @test_throws AssertionError prices("AAPL", interval="invalid")
        # Invalid fundamental interval
        @test_throws AssertionError fundamentals("AAPL", "income_statement", "invalid", "2020-01-01", "2021-01-01")
        # Invalid fundamental item
        @test_throws AssertionError fundamentals("AAPL", "not_a_real_item", "annual", "2020-01-01", "2021-01-01")
        # Invalid news language
        @test_throws ArgumentError search_news("AAPL", lang="xx-yy")
    end

    @testset "Proxy Settings" begin
        # Set proxy with auth
        set_proxy("http://proxy.test:8080", user="user123", password="pass456")
        @test YFinance._SESSION.proxy == "http://proxy.test:8080"
        @test haskey(YFinance._SESSION.proxy_auth, "Proxy-Authorization")
        @test startswith(YFinance._SESSION.proxy_auth["Proxy-Authorization"], "Basic ")

        # Set proxy without auth
        set_proxy("http://open-proxy.test:3128")
        @test YFinance._SESSION.proxy == "http://open-proxy.test:3128"
        @test isempty(YFinance._SESSION.proxy_auth)

        # Clear
        clear_proxy()
        @test isnothing(YFinance._SESSION.proxy)
        @test isempty(YFinance._SESSION.proxy_auth)
    end

    @testset "Price Response Parsing" begin
        # Minimal valid chart response
        chart_json = """{"chart":{"result":[{"meta":{"currency":"USD","symbol":"TEST","gmtoffset":-14400},"timestamp":[1700000000,1700100000],"indicators":{"quote":[{"open":[100.0,101.0],"high":[102.0,103.0],"low":[99.0,100.0],"close":[101.0,102.0],"volume":[1000000,2000000]}],"adjclose":[{"adjclose":[101.0,102.0]}]}}]}}"""
        body = Vector{UInt8}(chart_json)
        pd = YFinance._parse_price_response(body, "TEST", "1d", false, false)
        @test pd.ticker == "TEST"
        @test length(pd) == 2
        @test pd.open == [100.0, 101.0]
        @test pd.close == [101.0, 102.0]
        @test pd.adjclose == [101.0, 102.0]

        # With autoadjust (adjclose == close, so ratio is 1.0)
        pd_adj = YFinance._parse_price_response(body, "TEST", "1d", true, false)
        @test pd_adj.open == [100.0, 101.0]

        # With exchange local time
        pd_local = YFinance._parse_price_response(body, "TEST", "1d", false, true)
        @test pd_local.timestamp != pd.timestamp

        # Minute interval (no adjclose)
        minute_json = """{"chart":{"result":[{"meta":{"currency":"USD","symbol":"TEST","gmtoffset":-14400},"timestamp":[1700000000,1700001000],"indicators":{"quote":[{"open":[100.0,101.0],"high":[102.0,103.0],"low":[99.0,100.0],"close":[101.0,102.0],"volume":[1000000,2000000]}]}}]}}"""
        body_min = Vector{UInt8}(minute_json)
        pd_min = YFinance._parse_price_response(body_min, "TEST", "1m", false, false)
        @test isnothing(pd_min.adjclose)
    end

    @testset "Dividend Response Parsing" begin
        div_json = """{"chart":{"result":[{"meta":{"gmtoffset":-14400},"timestamp":[1700000000],"events":{"dividends":{"1700000000":{"date":1700000000,"amount":0.24}}},"indicators":{"quote":[{"open":[100.0],"high":[102.0],"low":[99.0],"close":[101.0],"volume":[1000000]}],"adjclose":[{"adjclose":[101.0]}]}}]}}"""
        body = Vector{UInt8}(div_json)
        dd = YFinance._parse_dividend_response(body, "TEST", false)
        @test dd.ticker == "TEST"
        @test length(dd) == 1
        @test dd.dividend[1] == 0.24
    end

    @testset "Split Response Parsing" begin
        split_json = """{"chart":{"result":[{"meta":{"gmtoffset":-14400},"timestamp":[1700000000],"events":{"splits":{"1700000000":{"date":1700000000,"numerator":4,"denominator":1}}},"indicators":{"quote":[{"open":[100.0],"high":[102.0],"low":[99.0],"close":[101.0],"volume":[1000000]}],"adjclose":[{"adjclose":[101.0]}]}}]}}"""
        body = Vector{UInt8}(split_json)
        sd = YFinance._parse_splits_response(body, "TEST", false)
        @test sd.ticker == "TEST"
        @test length(sd) == 1
        @test sd.numerator[1] == 4
        @test sd.denominator[1] == 1
        @test sd.ratio[1] == 4.0
    end

end
