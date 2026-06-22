using YFinance
using Dates
using Test
using OrderedCollections
using Tables
using JSON

@testset "YFinance.jl v0.3" begin

    # ═══════════════════════════════════════════════════════════════════════════
    # UNIT TESTS — No network required
    # ═══════════════════════════════════════════════════════════════════════════

    @testset "Types — Construction & Display" begin
        # ─── YFinanceError ────────────────────────────────────────────────────
        @testset "YFinanceError" begin
            err = YFinanceError("AAPL", "test error", 404)
            @test err.symbol == "AAPL"
            @test err.message == "test error"
            @test err.status == 404
            s = sprint(showerror, err)
            @test contains(s, "AAPL")
            @test contains(s, "test error")
            @test contains(s, "404")

            err_no_status = YFinanceError("X", "no http", nothing)
            s2 = sprint(showerror, err_no_status)
            @test contains(s2, "X")
            @test !contains(s2, "HTTP")
        end

        # ─── PriceData ────────────────────────────────────────────────────────
        @testset "PriceData" begin
            pd = PriceData("AAPL",
                [DateTime(2024,1,1), DateTime(2024,1,2), DateTime(2024,1,3)],
                [100.0, 101.0, 102.0],
                [102.0, 103.0, 104.0],
                [99.0, 100.0, 101.0],
                [101.0, 102.0, 103.0],
                [1e6, 2e6, 3e6],
                [101.5, 102.5, 103.5]
            )
            @test pd.ticker == "AAPL"
            @test length(pd) == 3
            @test !isempty(pd)
            s = sprint(show, MIME"text/plain"(), pd)
            @test contains(s, "PriceData")
            @test contains(s, "AAPL")
            @test contains(s, "3 rows")
            @test contains(s, "2024-01-01")
            @test contains(s, "2024-01-03")

            # Empty
            empty_pd = PriceData("X", DateTime[], Float64[], Float64[], Float64[], Float64[], Float64[], nothing)
            @test isempty(empty_pd)
            @test length(empty_pd) == 0
            s_empty = sprint(show, MIME"text/plain"(), empty_pd)
            @test contains(s_empty, "0 rows")

            # Without adjclose
            pd_no_adj = PriceData("Y", [DateTime(2024,1,1)], [1.0], [2.0], [0.5], [1.5], [100.0], nothing)
            @test length(pd_no_adj) == 1
        end

        # ─── DividendData ─────────────────────────────────────────────────────
        @testset "DividendData" begin
            dd = DividendData("AAPL", [DateTime(2024,1,1), DateTime(2024,4,1)], [0.24, 0.25])
            @test dd.ticker == "AAPL"
            @test length(dd) == 2
            @test !isempty(dd)
            s = sprint(show, MIME"text/plain"(), dd)
            @test contains(s, "DividendData")
            @test contains(s, "2 entries")

            empty_dd = DividendData("X", DateTime[], Float64[])
            @test isempty(empty_dd)
        end

        # ─── SplitData ────────────────────────────────────────────────────────
        @testset "SplitData" begin
            sd = SplitData("AAPL",
                [DateTime(2014,6,9), DateTime(2020,8,31)],
                [7, 4], [1, 1], [7.0, 4.0]
            )
            @test sd.ticker == "AAPL"
            @test length(sd) == 2
            @test !isempty(sd)
            s = sprint(show, MIME"text/plain"(), sd)
            @test contains(s, "SplitData")
            @test contains(s, "2 entries")

            empty_sd = SplitData("X", DateTime[], Int[], Int[], Float64[])
            @test isempty(empty_sd)
        end

        # ─── OptionSide & OptionsChain ────────────────────────────────────────
        @testset "OptionsChain" begin
            calls = OptionSide(OrderedDict("strike" => Any[150.0, 155.0, 160.0], "bid" => Any[5.0, 3.0, 1.0]))
            puts = OptionSide(OrderedDict("strike" => Any[145.0, 140.0]))
            oc = OptionsChain("AAPL", calls, puts)

            @test length(oc.calls) == 3
            @test length(oc.puts) == 2
            @test !isempty(oc.calls)
            s = sprint(show, MIME"text/plain"(), oc)
            @test contains(s, "OptionsChain")
            @test contains(s, "AAPL")
            @test contains(s, "3 calls")
            @test contains(s, "2 puts")

            empty_os = OptionSide(OrderedDict{String,Vector}())
            @test isempty(empty_os)
            @test length(empty_os) == 0
        end

        # ─── FundamentalData ──────────────────────────────────────────────────
        @testset "FundamentalData" begin
            fd = FundamentalData("AAPL", OrderedDict{String,Vector}(
                "timestamp" => [DateTime(2022,1,1), DateTime(2023,1,1)],
                "TotalRevenue" => Any[394328000000, 383285000000],
                "NetIncome" => Any[99803000000, 96995000000]
            ))
            @test fd.ticker == "AAPL"
            @test length(fd) == 2
            @test !isempty(fd)
            s = sprint(show, MIME"text/plain"(), fd)
            @test contains(s, "FundamentalData")
            @test contains(s, "2 rows")
            @test contains(s, "3 columns")

            empty_fd = FundamentalData("X", OrderedDict{String,Vector}())
            @test isempty(empty_fd)
            @test length(empty_fd) == 0
        end

        # ─── SearchResult & SearchResults ─────────────────────────────────────
        @testset "SearchResults" begin
            items = [
                SearchResult("MSFT", "Microsoft Corporation", "NASDAQ (NMS)", "EQUITY", "Technology", "Software"),
                SearchResult("MSFAX", "MS Fund", "NASDAQ", "MUTUALFUND", "", ""),
            ]
            srs = SearchResults(items)
            @test length(srs) == 2
            @test srs[1].symbol == "MSFT"
            @test srs[2].name == "MS Fund"
            @test srs[1].sector == "Technology"
            @test srs[2].sector == ""

            s1 = sprint(show, items[1])
            @test contains(s1, "MSFT")
            @test contains(s1, "Microsoft")
            @test contains(s1, "Technology")

            s2 = sprint(show, items[2])
            @test !contains(s2, "Sector")

            s_all = sprint(show, MIME"text/plain"(), srs)
            @test contains(s_all, "2-element SearchResults")
        end

        # ─── NewsItem & NewsResults ───────────────────────────────────────────
        @testset "NewsResults" begin
            items = [
                NewsItem("Apple hits record", "Reuters", "http://r.com/1", DateTime(2024,1,15,10,30), ["AAPL"]),
                NewsItem("Tech rally", "Bloomberg", "http://b.com/2", DateTime(2024,1,15,11,0), ["AAPL", "MSFT"]),
                NewsItem("Market update", "WSJ", "http://wsj.com/3", DateTime(2024,1,15,12,0), String[]),
            ]
            nr = NewsResults(items)
            @test length(nr) == 3
            @test nr[1].title == "Apple hits record"
            @test nr[2].publisher == "Bloomberg"

            @test titles(nr) == ["Apple hits record", "Tech rally", "Market update"]
            @test links(nr) == ["http://r.com/1", "http://b.com/2", "http://wsj.com/3"]
            @test timestamps(nr) == [DateTime(2024,1,15,10,30), DateTime(2024,1,15,11,0), DateTime(2024,1,15,12,0)]

            s1 = sprint(show, items[1])
            @test contains(s1, "Apple hits record")
            @test contains(s1, "Reuters")

            s3 = sprint(show, items[3])
            @test !contains(s3, "Symbols")

            s_all = sprint(show, MIME"text/plain"(), nr)
            @test contains(s_all, "3-element NewsResults")
        end
    end

    # ═══════════════════════════════════════════════════════════════════════════
    @testset "Tables.jl Interface" begin

        @testset "PriceData Tables" begin
            pd = PriceData("AAPL",
                [DateTime(2024,1,1), DateTime(2024,1,2)],
                [100.0, 101.0], [102.0, 103.0], [99.0, 100.0],
                [101.0, 102.0], [1e6, 2e6], [101.5, 102.5]
            )
            @test Tables.istable(typeof(pd))
            @test Tables.columnaccess(typeof(pd))
            cols = Tables.columnnames(pd)
            @test :ticker in cols
            @test :timestamp in cols
            @test :open in cols
            @test :high in cols
            @test :low in cols
            @test :close in cols
            @test :volume in cols
            @test :adjclose in cols
            @test length(cols) == 8

            @test Tables.getcolumn(pd, :ticker) == ["AAPL", "AAPL"]
            @test Tables.getcolumn(pd, :timestamp) == [DateTime(2024,1,1), DateTime(2024,1,2)]
            @test Tables.getcolumn(pd, :open) == [100.0, 101.0]
            @test Tables.getcolumn(pd, :high) == [102.0, 103.0]
            @test Tables.getcolumn(pd, :low) == [99.0, 100.0]
            @test Tables.getcolumn(pd, :close) == [101.0, 102.0]
            @test Tables.getcolumn(pd, :volume) == [1e6, 2e6]
            @test Tables.getcolumn(pd, :adjclose) == [101.5, 102.5]

            # Integer index access
            @test Tables.getcolumn(pd, 1) == ["AAPL", "AAPL"]
            @test Tables.getcolumn(pd, 2) == [DateTime(2024,1,1), DateTime(2024,1,2)]

            # Invalid column
            @test_throws ArgumentError Tables.getcolumn(pd, :nonexistent)

            # Without adjclose
            pd2 = PriceData("X", [DateTime(2024,1,1)], [1.0], [2.0], [0.5], [1.5], [100.0], nothing)
            @test :adjclose ∉ Tables.columnnames(pd2)
            @test length(Tables.columnnames(pd2)) == 7
        end

        @testset "DividendData Tables" begin
            dd = DividendData("AAPL", [DateTime(2024,1,1), DateTime(2024,4,1)], [0.24, 0.25])
            @test Tables.istable(typeof(dd))
            @test Tables.columnaccess(typeof(dd))
            @test Tables.columnnames(dd) == [:ticker, :timestamp, :dividend]
            @test Tables.getcolumn(dd, :ticker) == ["AAPL", "AAPL"]
            @test Tables.getcolumn(dd, :timestamp) == [DateTime(2024,1,1), DateTime(2024,4,1)]
            @test Tables.getcolumn(dd, :dividend) == [0.24, 0.25]
            @test Tables.getcolumn(dd, 1) == ["AAPL", "AAPL"]
            @test Tables.getcolumn(dd, 3) == [0.24, 0.25]
            @test_throws ArgumentError Tables.getcolumn(dd, :invalid)
        end

        @testset "SplitData Tables" begin
            sd = SplitData("AAPL", [DateTime(2020,8,31)], [4], [1], [4.0])
            @test Tables.istable(typeof(sd))
            @test Tables.columnaccess(typeof(sd))
            @test Tables.columnnames(sd) == [:ticker, :timestamp, :numerator, :denominator, :ratio]
            @test Tables.getcolumn(sd, :ticker) == ["AAPL"]
            @test Tables.getcolumn(sd, :numerator) == [4]
            @test Tables.getcolumn(sd, :denominator) == [1]
            @test Tables.getcolumn(sd, :ratio) == [4.0]
            @test Tables.getcolumn(sd, 5) == [4.0]
            @test_throws ArgumentError Tables.getcolumn(sd, :bad)
        end

        @testset "OptionSide Tables" begin
            os = OptionSide(OrderedDict(
                "strike" => Any[150.0, 155.0],
                "bid" => Any[5.0, 3.0],
                "ask" => Any[5.5, 3.5]
            ))
            @test Tables.istable(typeof(os))
            @test Tables.columnaccess(typeof(os))
            names = Tables.columnnames(os)
            @test :strike in names
            @test :bid in names
            @test :ask in names
            @test Tables.getcolumn(os, :strike) == Any[150.0, 155.0]
            @test Tables.getcolumn(os, :bid) == Any[5.0, 3.0]
            @test Tables.getcolumn(os, 1) == Any[150.0, 155.0]
            @test_throws ArgumentError Tables.getcolumn(os, :nonexistent)
        end

        @testset "FundamentalData Tables" begin
            fd = FundamentalData("AAPL", OrderedDict{String,Vector}(
                "timestamp" => [DateTime(2023,1,1)],
                "TotalRevenue" => Any[383285000000]
            ))
            @test Tables.istable(typeof(fd))
            @test Tables.columnaccess(typeof(fd))
            names = Tables.columnnames(fd)
            @test :timestamp in names
            @test :TotalRevenue in names
            @test Tables.getcolumn(fd, :timestamp) == [DateTime(2023,1,1)]
            @test Tables.getcolumn(fd, :TotalRevenue) == Any[383285000000]
            @test Tables.getcolumn(fd, 1) == [DateTime(2023,1,1)]
            @test_throws ArgumentError Tables.getcolumn(fd, :fake)
        end
    end

    # ═══════════════════════════════════════════════════════════════════════════
    @testset "Internal Utilities" begin

        @testset "Date Conversion" begin
            @test YFinance._date_to_unix("2000-01-01") == 946684800
            @test YFinance._date_to_unix(Date(2000, 1, 1)) == 946684800
            @test YFinance._date_to_unix(DateTime(2000, 1, 1)) == 946684800
            @test YFinance._date_to_unix(Date(1970, 1, 1)) == 0
            @test YFinance._date_to_unix("1970-01-01") == 0
            @test YFinance._date_to_unix(Date(2024, 6, 15)) == 1718409600
            # Negative unix times
            @test YFinance._date_to_unix(Date(1969, 1, 1)) < 0
        end

        @testset "URL Encoding" begin
            @test YFinance._uri_encode("hello world") == "hello%20world"
            @test YFinance._uri_encode("AAPL") == "AAPL"
            @test YFinance._uri_encode("a&b=c") == "a%26b%3Dc"
            @test YFinance._uri_encode("") == ""
            @test YFinance._uri_encode("café") == "caf%C3%A9"
            @test YFinance._uri_encode("foo/bar") == "foo%2Fbar"
            @test YFinance._uri_encode("a+b") == "a%2Bb"
            @test YFinance._uri_encode("hello-world_v2.0~test") == "hello-world_v2.0~test"
        end

        @testset "URL Building" begin
            @test YFinance._build_url("https://example.com", Dict("a" => "1")) == "https://example.com?a=1"
            @test YFinance._build_url("https://example.com", Dict{String,String}()) == "https://example.com"
            # Empty values are skipped
            @test YFinance._build_url("https://example.com", Dict("a" => "1", "b" => "")) == "https://example.com?a=1"
            # Special characters encoded
            url = YFinance._build_url("https://x.com", Dict("q" => "hello world"))
            @test contains(url, "hello%20world")
        end

        @testset "Query String Building" begin
            @test YFinance._build_query_string(Dict{String,String}()) == ""
            @test YFinance._build_query_string(Dict("k" => "v")) == "k=v"
            # Empty values skipped
            @test YFinance._build_query_string(Dict("a" => "", "b" => "2")) == "b=2"
        end

        @testset "Clean Values" begin
            # Float64 passthrough
            v = [1.0, 2.0, 3.0]
            @test YFinance._clean_values(v) === v

            # Integer conversion
            @test YFinance._clean_values([1, 2, 3]) == [1.0, 2.0, 3.0]

            # Nothing → NaN
            result = YFinance._clean_values([nothing, 1.0, nothing])
            @test isnan(result[1])
            @test result[2] == 1.0
            @test isnan(result[3])

            # Mixed types
            result2 = YFinance._clean_values([1, nothing, 3.5])
            @test result2[1] == 1.0
            @test isnan(result2[2])
            @test result2[3] == 3.5

            # All nothing
            all_nan = YFinance._clean_values([nothing, nothing])
            @test all(isnan, all_nan)

            # Empty vector
            @test YFinance._clean_values(Any[]) == Float64[]
        end

        @testset "Cookie Parsing" begin
            headers = [
                "Set-Cookie" => "A3=d=AQAB; path=/; domain=.yahoo.com",
                "Content-Type" => "text/html",
                "set-cookie" => "B=xyz123; path=/; domain=.yahoo.com",
            ]
            cookies = YFinance._parse_set_cookie(headers)
            @test cookies["A3"] == "d=AQAB"
            @test cookies["B"] == "xyz123"

            # Empty headers
            @test isempty(YFinance._parse_set_cookie(Pair{String,String}[]))

            # No cookies
            @test isempty(YFinance._parse_set_cookie(["Content-Type" => "text/html"]))
        end
    end

    # ═══════════════════════════════════════════════════════════════════════════
    @testset "Constants" begin
        @test "income_statement" in keys(FUNDAMENTAL_TYPES)
        @test "balance_sheet" in keys(FUNDAMENTAL_TYPES)
        @test "cash_flow" in keys(FUNDAMENTAL_TYPES)
        @test "valuation" in keys(FUNDAMENTAL_TYPES)
        @test length(keys(FUNDAMENTAL_TYPES)) == 4

        @test "TotalRevenue" in FUNDAMENTAL_TYPES["income_statement"]
        @test "NetIncome" in FUNDAMENTAL_TYPES["income_statement"]
        @test "TotalAssets" in FUNDAMENTAL_TYPES["balance_sheet"]
        @test "FreeCashFlow" in FUNDAMENTAL_TYPES["cash_flow"]
        @test "MarketCap" in FUNDAMENTAL_TYPES["valuation"]

        @test FUNDAMENTAL_INTERVALS == ["annual", "quarterly", "monthly"]

        @test "assetProfile" in QUOTE_SUMMARY_ITEMS
        @test "summaryDetail" in QUOTE_SUMMARY_ITEMS
        @test "earnings" in QUOTE_SUMMARY_ITEMS
        @test "calendarEvents" in QUOTE_SUMMARY_ITEMS
        @test "upgradeDowngradeHistory" in QUOTE_SUMMARY_ITEMS
        @test length(QUOTE_SUMMARY_ITEMS) >= 30
    end

    # ═══════════════════════════════════════════════════════════════════════════
    @testset "Input Validation (no network)" begin
        # Invalid interval for prices — throws either AssertionError (pure validation) or
        # YFinanceError (symbol validated first via network). Either error is acceptable.
        @test_throws Exception prices("AAPL", interval="invalid")
        @test_throws Exception prices("AAPL", interval="2d")
        @test_throws Exception prices("AAPL", interval="")

        # Invalid fundamental interval/item — symbol validation may throw first
        @test_throws Exception fundamentals("AAPL", "income_statement", "invalid", "2020-01-01", "2021-01-01")
        @test_throws Exception fundamentals("AAPL", "income_statement", "weekly", "2020-01-01", "2021-01-01")
        @test_throws Exception fundamentals("AAPL", "not_a_real_item", "annual", "2020-01-01", "2021-01-01")
        @test_throws Exception fundamentals("AAPL", "fake_statement", "quarterly", "2020-01-01", "2021-01-01")

        # Invalid news language
        @test_throws ArgumentError search_news("AAPL", lang="xx-yy")
        @test_throws ArgumentError search_news("AAPL", lang="klingon")

        # Both dates required
        @test_throws Exception prices("AAPL", startdt="2020-01-01")
        @test_throws Exception prices("AAPL", enddt="2020-01-01")
    end

    # ═══════════════════════════════════════════════════════════════════════════
    @testset "Proxy Settings" begin
        # Set proxy with auth
        set_proxy("http://proxy.test:8080", user="user123", password="pass456")
        @test YFinance._SESSION.proxy == "http://proxy.test:8080"
        @test haskey(YFinance._SESSION.proxy_auth, "Proxy-Authorization")
        @test startswith(YFinance._SESSION.proxy_auth["Proxy-Authorization"], "Basic ")
        # Verify base64 encoding
        using Base64
        expected = "Basic " * Base64.base64encode("user123:pass456")
        @test YFinance._SESSION.proxy_auth["Proxy-Authorization"] == expected
        @test !YFinance._SESSION.initialized  # Forces re-init

        # Set proxy without auth
        set_proxy("http://open-proxy.test:3128")
        @test YFinance._SESSION.proxy == "http://open-proxy.test:3128"
        @test isempty(YFinance._SESSION.proxy_auth)
        @test !YFinance._SESSION.initialized

        # Clear proxy
        clear_proxy()
        @test isnothing(YFinance._SESSION.proxy)
        @test isempty(YFinance._SESSION.proxy_auth)
        @test !YFinance._SESSION.initialized
    end

    # ═══════════════════════════════════════════════════════════════════════════
    @testset "Response Parsing — Prices" begin

        @testset "Standard daily response" begin
            json = """{"chart":{"result":[{
                "meta":{"currency":"USD","symbol":"TEST","gmtoffset":-14400},
                "timestamp":[1700000000,1700100000,1700200000],
                "indicators":{
                    "quote":[{"open":[100.0,101.0,102.0],"high":[102.0,103.0,104.0],"low":[99.0,100.0,101.0],"close":[101.0,102.0,103.0],"volume":[1000000,2000000,3000000]}],
                    "adjclose":[{"adjclose":[101.5,102.5,103.5]}]
                }
            }]}}"""
            body = Vector{UInt8}(json)
            pd = YFinance._parse_price_response(body, "TEST", "1d", false, false)
            @test pd.ticker == "TEST"
            @test length(pd) == 3
            @test pd.open == [100.0, 101.0, 102.0]
            @test pd.high == [102.0, 103.0, 104.0]
            @test pd.low == [99.0, 100.0, 101.0]
            @test pd.close == [101.0, 102.0, 103.0]
            @test pd.volume == [1000000.0, 2000000.0, 3000000.0]
            @test pd.adjclose == [101.5, 102.5, 103.5]
        end

        @testset "Autoadjust" begin
            json = """{"chart":{"result":[{
                "meta":{"currency":"USD","symbol":"TEST","gmtoffset":0},
                "timestamp":[1700000000,1700100000],
                "indicators":{
                    "quote":[{"open":[100.0,200.0],"high":[110.0,210.0],"low":[90.0,190.0],"close":[105.0,205.0],"volume":[1000,2000]}],
                    "adjclose":[{"adjclose":[52.5,102.5]}]
                }
            }]}}"""
            body = Vector{UInt8}(json)
            pd = YFinance._parse_price_response(body, "TEST", "1d", true, false)
            # ratio[1] = 52.5/105.0 = 0.5, ratio[2] = 102.5/205.0 = 0.5
            @test pd.open[1] ≈ 50.0
            @test pd.high[1] ≈ 55.0
            @test pd.low[1] ≈ 45.0
            @test pd.volume[1] ≈ 500.0
            @test pd.open[2] ≈ 100.0
        end

        @testset "Exchange local time" begin
            json = """{"chart":{"result":[{
                "meta":{"currency":"USD","symbol":"TEST","gmtoffset":-14400},
                "timestamp":[1700000000],
                "indicators":{
                    "quote":[{"open":[100.0],"high":[102.0],"low":[99.0],"close":[101.0],"volume":[1000000]}],
                    "adjclose":[{"adjclose":[101.0]}]
                }
            }]}}"""
            body = Vector{UInt8}(json)
            pd_gmt = YFinance._parse_price_response(body, "TEST", "1d", false, false)
            pd_local = YFinance._parse_price_response(body, "TEST", "1d", false, true)
            # Local time should differ by -14400 seconds (4 hours)
            @test pd_local.timestamp[1] != pd_gmt.timestamp[1]
            diff = pd_gmt.timestamp[1] - pd_local.timestamp[1]
            @test Dates.value(diff) == 14400 * 1000  # milliseconds
        end

        @testset "Minute interval (no adjclose)" begin
            json = """{"chart":{"result":[{
                "meta":{"currency":"USD","symbol":"TEST","gmtoffset":0},
                "timestamp":[1700000000,1700001000],
                "indicators":{
                    "quote":[{"open":[100.0,101.0],"high":[102.0,103.0],"low":[99.0,100.0],"close":[101.0,102.0],"volume":[1000000,2000000]}]
                }
            }]}}"""
            body = Vector{UInt8}(json)
            pd = YFinance._parse_price_response(body, "TEST", "1m", false, false)
            @test isnothing(pd.adjclose)
            @test pd.open == [100.0, 101.0]
            @test pd.volume == [1000000.0, 2000000.0]
        end

        @testset "Duplicate last timestamp handling" begin
            json = """{"chart":{"result":[{
                "meta":{"currency":"USD","symbol":"TEST","gmtoffset":0},
                "timestamp":[1700000000,1700100000,1700100000],
                "indicators":{
                    "quote":[{"open":[100.0,101.0,102.0],"high":[102.0,103.0,104.0],"low":[99.0,100.0,101.0],"close":[101.0,102.0,103.0],"volume":[1000,2000,3000]}],
                    "adjclose":[{"adjclose":[101.0,102.0,103.0]}]
                }
            }]}}"""
            body = Vector{UInt8}(json)
            pd = YFinance._parse_price_response(body, "TEST", "1d", false, false)
            # Should drop the duplicate last timestamp
            @test length(pd) == 2
        end

        @testset "Nothing values in price data" begin
            json = """{"chart":{"result":[{
                "meta":{"currency":"USD","symbol":"TEST","gmtoffset":0},
                "timestamp":[1700000000,1700100000],
                "indicators":{
                    "quote":[{"open":[100.0,null],"high":[102.0,null],"low":[99.0,null],"close":[101.0,null],"volume":[1000000,null]}],
                    "adjclose":[{"adjclose":[101.0,null]}]
                }
            }]}}"""
            body = Vector{UInt8}(json)
            pd = YFinance._parse_price_response(body, "TEST", "1d", false, false)
            @test pd.open[1] == 100.0
            @test isnan(pd.open[2])
            @test isnan(pd.high[2])
            @test isnan(pd.close[2])
            @test isnan(pd.volume[2])
        end

        @testset "No timestamp → error" begin
            json = """{"chart":{"result":[{
                "meta":{"currency":"USD","symbol":"TEST","gmtoffset":0},
                "indicators":{"quote":[{"open":[],"high":[],"low":[],"close":[],"volume":[]}]}
            }]}}"""
            body = Vector{UInt8}(json)
            @test_throws YFinanceError YFinance._parse_price_response(body, "TEST", "1d", false, false)
        end
    end

    # ═══════════════════════════════════════════════════════════════════════════
    @testset "Response Parsing — Dividends" begin

        @testset "With dividends" begin
            json = """{"chart":{"result":[{
                "meta":{"gmtoffset":-14400},
                "timestamp":[1700000000],
                "events":{"dividends":{
                    "1700000000":{"date":1700000000,"amount":0.24},
                    "1700500000":{"date":1700500000,"amount":0.25}
                }},
                "indicators":{"quote":[{"open":[100.0],"high":[102.0],"low":[99.0],"close":[101.0],"volume":[1000000]}],"adjclose":[{"adjclose":[101.0]}]}
            }]}}"""
            body = Vector{UInt8}(json)
            dd = YFinance._parse_dividend_response(body, "TEST", false)
            @test dd.ticker == "TEST"
            @test length(dd) == 2
            @test 0.24 in dd.dividend
            @test 0.25 in dd.dividend
        end

        @testset "No dividends" begin
            json = """{"chart":{"result":[{
                "meta":{"gmtoffset":0},
                "timestamp":[1700000000],
                "indicators":{"quote":[{"open":[100.0],"high":[102.0],"low":[99.0],"close":[101.0],"volume":[1000000]}],"adjclose":[{"adjclose":[101.0]}]}
            }]}}"""
            body = Vector{UInt8}(json)
            dd = YFinance._parse_dividend_response(body, "BRK-A", false)
            @test dd.ticker == "BRK-A"
            @test isempty(dd)
        end

        @testset "Exchange local time" begin
            json = """{"chart":{"result":[{
                "meta":{"gmtoffset":-18000},
                "timestamp":[1700000000],
                "events":{"dividends":{"1700000000":{"date":1700000000,"amount":0.5}}},
                "indicators":{"quote":[{"open":[1.0],"high":[1.0],"low":[1.0],"close":[1.0],"volume":[1]}],"adjclose":[{"adjclose":[1.0]}]}
            }]}}"""
            body = Vector{UInt8}(json)
            dd_gmt = YFinance._parse_dividend_response(body, "T", false)
            dd_local = YFinance._parse_dividend_response(body, "T", true)
            @test dd_gmt.timestamp[1] != dd_local.timestamp[1]
        end
    end

    # ═══════════════════════════════════════════════════════════════════════════
    @testset "Response Parsing — Splits" begin

        @testset "With splits" begin
            json = """{"chart":{"result":[{
                "meta":{"gmtoffset":0},
                "timestamp":[1700000000],
                "events":{"splits":{
                    "1600000000":{"date":1600000000,"numerator":4,"denominator":1},
                    "1500000000":{"date":1500000000,"numerator":7,"denominator":1}
                }},
                "indicators":{"quote":[{"open":[100.0],"high":[102.0],"low":[99.0],"close":[101.0],"volume":[1000000]}],"adjclose":[{"adjclose":[101.0]}]}
            }]}}"""
            body = Vector{UInt8}(json)
            sd = YFinance._parse_splits_response(body, "AAPL", false)
            @test sd.ticker == "AAPL"
            @test length(sd) == 2
            @test 4 in sd.numerator
            @test 7 in sd.numerator
            @test all(==(1), sd.denominator)
            @test 4.0 in sd.ratio
            @test 7.0 in sd.ratio
        end

        @testset "No splits" begin
            json = """{"chart":{"result":[{
                "meta":{"gmtoffset":0},
                "timestamp":[1700000000],
                "indicators":{"quote":[{"open":[100.0],"high":[102.0],"low":[99.0],"close":[101.0],"volume":[1000000]}],"adjclose":[{"adjclose":[101.0]}]}
            }]}}"""
            body = Vector{UInt8}(json)
            sd = YFinance._parse_splits_response(body, "MSFT", false)
            @test sd.ticker == "MSFT"
            @test isempty(sd)
            @test sd.ratio == Float64[]
        end

        @testset "Non-trivial ratio" begin
            json = """{"chart":{"result":[{
                "meta":{"gmtoffset":0},
                "timestamp":[1700000000],
                "events":{"splits":{"1700000000":{"date":1700000000,"numerator":3,"denominator":2}}},
                "indicators":{"quote":[{"open":[100.0],"high":[102.0],"low":[99.0],"close":[101.0],"volume":[1000000]}],"adjclose":[{"adjclose":[101.0]}]}
            }]}}"""
            body = Vector{UInt8}(json)
            sd = YFinance._parse_splits_response(body, "TEST", false)
            @test sd.numerator == [3]
            @test sd.denominator == [2]
            @test sd.ratio[1] ≈ 1.5
        end
    end

    # ═══════════════════════════════════════════════════════════════════════════
    @testset "Response Parsing — Options" begin
        json = """{"optionChain":{"result":[{"options":[{
            "calls":[
                {"contractSymbol":"AAPL240315C00150000","strike":150.0,"currency":"USD","lastPrice":25.0,"change":1.5,"percentChange":6.0,"volume":100,"openInterest":500,"bid":24.5,"ask":25.5,"contractSize":"REGULAR","expiration":1710460800,"lastTradeDate":1710374400,"impliedVolatility":0.35,"inTheMoney":true},
                {"contractSymbol":"AAPL240315C00160000","strike":160.0,"currency":"USD","lastPrice":15.0,"change":-0.5,"percentChange":-3.2,"volume":50,"openInterest":300,"bid":14.5,"ask":15.5,"contractSize":"REGULAR","expiration":1710460800,"lastTradeDate":1710374400,"impliedVolatility":0.30,"inTheMoney":true}
            ],
            "puts":[
                {"contractSymbol":"AAPL240315P00150000","strike":150.0,"currency":"USD","lastPrice":2.0,"change":0.3,"percentChange":17.6,"openInterest":200,"bid":1.8,"ask":2.2,"contractSize":"REGULAR","expiration":1710460800,"lastTradeDate":1710374400,"impliedVolatility":0.28,"inTheMoney":false}
            ]
        }]}]}}"""
        body = Vector{UInt8}(json)
        oc = YFinance._parse_options_response(body, "AAPL")
        @test oc.ticker == "AAPL"
        @test length(oc.calls) == 2
        @test length(oc.puts) == 1

        # Calls data
        @test oc.calls.data["strike"] == Any[150.0, 160.0]
        @test oc.calls.data["type"] == Any["call", "call"]
        @test oc.calls.data["contractSymbol"][1] == "AAPL240315C00150000"
        @test oc.calls.data["impliedVolatility"] == Any[0.35, 0.30]

        # Puts data
        @test oc.puts.data["strike"] == Any[150.0]
        @test oc.puts.data["type"] == Any["put"]
        @test oc.puts.data["inTheMoney"] == Any[false]

        # Expiration converted to DateTime
        @test oc.calls.data["expiration"][1] isa DateTime
        @test oc.puts.data["lastTradeDate"][1] isa DateTime

        # Missing fields → missing
        @test ismissing(oc.puts.data["volume"][1])
    end

    # ═══════════════════════════════════════════════════════════════════════════
    @testset "Response Parsing — Fundamentals" begin

        @testset "Entire statement" begin
            json = """{"timeseries":{"result":[
                {"meta":{"type":["quarterlyTotalRevenue"]},"timestamp":[1672444800,1680220800],"quarterlyTotalRevenue":[{"reportedValue":{"raw":100000}},{"reportedValue":{"raw":110000}}]},
                {"meta":{"type":["quarterlyNetIncome"]},"timestamp":[1672444800,1680220800],"quarterlyNetIncome":[{"reportedValue":{"raw":20000}},{"reportedValue":{"raw":22000}}]}
            ]}}"""
            body = Vector{UInt8}(json)
            res = JSON.parse(String(copy(body)))["timeseries"]["result"]
            fd = YFinance._parse_fundamental_statement(res, "TEST", "quarterly")
            @test fd.ticker == "TEST"
            @test haskey(fd.data, "timestamp")
            @test haskey(fd.data, "TotalRevenue")
            @test haskey(fd.data, "NetIncome")
            @test fd.data["TotalRevenue"] == Any[100000, 110000]
            @test fd.data["NetIncome"] == Any[20000, 22000]
            @test length(fd) == 2
        end

        @testset "Single item" begin
            json = """{"timeseries":{"result":[
                {"meta":{"type":["annualTotalRevenue"]},"timestamp":[1672444800,1703980800],"annualTotalRevenue":[{"reportedValue":{"raw":394328000000}},{"reportedValue":{"raw":383285000000}}]}
            ]}}"""
            body = Vector{UInt8}(json)
            res = JSON.parse(String(copy(body)))["timeseries"]["result"]
            fd = YFinance._parse_fundamental_item(res, "AAPL", "TotalRevenue", "annualTotalRevenue")
            @test fd.ticker == "AAPL"
            @test haskey(fd.data, "timestamp")
            @test haskey(fd.data, "TotalRevenue")
            @test fd.data["TotalRevenue"] == Any[394328000000, 383285000000]
        end

        @testset "Missing data throws" begin
            json = """{"timeseries":{"result":[{"meta":{"type":["annualFakeItem"]}}]}}"""
            body = Vector{UInt8}(json)
            res = JSON.parse(String(copy(body)))["timeseries"]["result"]
            @test_throws YFinanceError YFinance._parse_fundamental_item(res, "X", "FakeItem", "annualFakeItem")
        end

        @testset "Statement with missing entries skipped" begin
            json = """{"timeseries":{"result":[
                {"meta":{"type":["quarterlyRevenue"]}},
                {"meta":{"type":["quarterlyNetIncome"]},"timestamp":[1672444800],"quarterlyNetIncome":[{"reportedValue":{"raw":5000}}]}
            ]}}"""
            body = Vector{UInt8}(json)
            res = JSON.parse(String(copy(body)))["timeseries"]["result"]
            fd = YFinance._parse_fundamental_statement(res, "T", "quarterly")
            # First entry has no timestamp, should be skipped
            @test !haskey(fd.data, "Revenue")
            @test haskey(fd.data, "NetIncome")
        end
    end

    # ═══════════════════════════════════════════════════════════════════════════
    @testset "Quote Summary Helpers" begin

        @testset "_no_key_missing" begin
            d = Dict("name" => "Alice", "age" => 30, "date" => "2024-01-15", "epoch" => 1700000000)

            # Key exists, no subitem
            @test YFinance._no_key_missing(d, "name") == "Alice"
            @test YFinance._no_key_missing(d, "age") == 30

            # Key missing
            @test ismissing(YFinance._no_key_missing(d, "missing_key"))

            # With to_date (string → DateTime)
            @test YFinance._no_key_missing(d, "date", nothing, true, false) == DateTime("2024-01-15")

            # With from_int (unix → DateTime)
            result = YFinance._no_key_missing(d, "epoch", nothing, true, true)
            @test result isa DateTime
            @test result == unix2datetime(1700000000)

            # With subitem
            d2 = Dict("nested" => Dict("raw" => 42, "fmt" => "2024-01-01"))
            @test YFinance._no_key_missing(d2, "nested", "raw") == 42
            @test YFinance._no_key_missing(d2, "nested", "fmt", true) == DateTime("2024-01-01")
        end

        @testset "_assert_field_available" begin
            equity_qs = Dict("quoteType" => Dict("quoteType" => "EQUITY"), "earnings" => Dict())
            etf_qs = Dict("quoteType" => Dict("quoteType" => "ETF"), "summaryDetail" => Dict())

            # Valid — should not throw
            @test (YFinance._assert_field_available(equity_qs, :earnings, "earnings"); true)
            @test (YFinance._assert_field_available(etf_qs, :summaryDetail, "summary detail"); true)

            # Wrong quote type
            @test_throws YFinanceError YFinance._assert_field_available(etf_qs, :earnings, "earnings")

            # Missing field
            qs_no_field = Dict("quoteType" => Dict("quoteType" => "EQUITY"))
            @test_throws YFinanceError YFinance._assert_field_available(qs_no_field, :earnings, "earnings")
        end

        @testset "calendar_events accessor" begin
            qs = Dict(
                "quoteType" => Dict("quoteType" => "EQUITY"),
                "calendarEvents" => Dict(
                    "dividendDate" => 1700000000,
                    "exDividendDate" => 1699500000,
                    "earnings" => Dict("earningsDate" => [1701000000, 1701500000])
                )
            )
            result = calendar_events(qs)
            @test result["dividend_date"] == unix2datetime(1700000000)
            @test result["exdividend_date"] == unix2datetime(1699500000)
            @test length(result["earnings_dates"]) == 2
        end

        @testset "earnings_estimates accessor" begin
            qs = Dict(
                "quoteType" => Dict("quoteType" => "EQUITY"),
                "earnings" => Dict(
                    "earningsChart" => Dict(
                        "quarterly" => [
                            Dict("date" => "4Q2023", "actual" => 2.18, "estimate" => 2.10),
                            Dict("date" => "1Q2024", "actual" => 1.53, "estimate" => 1.50),
                        ],
                        "currentQuarterEstimateDate" => "2Q",
                        "currentQuarterEstimateYear" => 2024,
                        "currentQuarterEstimate" => 1.35,
                    )
                )
            )
            result = earnings_estimates(qs)
            @test result["quarter"] == ["4Q2023", "1Q2024", "2Q2024"]
            @test result["estimate"] == [2.10, 1.50, 1.35]
            @test result["actual"][1] == 2.18
            @test ismissing(result["actual"][3])
        end

        @testset "earnings_estimates empty" begin
            qs = Dict(
                "quoteType" => Dict("quoteType" => "EQUITY"),
                "earnings" => Dict("earningsChart" => Dict("quarterly" => []))
            )
            @test isempty(earnings_estimates(qs))
        end

        @testset "eps accessor" begin
            qs = Dict(
                "quoteType" => Dict("quoteType" => "EQUITY"),
                "earningsHistory" => Dict("history" => [
                    Dict("quarter" => Dict("fmt" => "2023-09-30"), "epsActual" => Dict("raw" => 1.46), "epsEstimate" => Dict("raw" => 1.39), "surprisePercent" => Dict("raw" => 0.05)),
                    Dict("quarter" => Dict("fmt" => "2023-12-31"), "epsActual" => Dict("raw" => 2.18), "epsEstimate" => Dict("raw" => 2.10), "surprisePercent" => Dict("raw" => 0.038)),
                ])
            )
            result = YFinance.eps(qs)
            @test result["quarter"] == [DateTime("2023-09-30"), DateTime("2023-12-31")]
            @test result["actual"] == [1.46, 2.18]
            @test result["estimate"] == [1.39, 2.10]
            @test result["surprise"] == [0.05, 0.038]
        end

        @testset "recommendation_trend accessor" begin
            qs = Dict(
                "quoteType" => Dict("quoteType" => "EQUITY"),
                "recommendationTrend" => Dict("trend" => [
                    Dict("period" => "0m", "strongBuy" => 12, "buy" => 20, "hold" => 5, "sell" => 1, "strongSell" => 0),
                    Dict("period" => "-1m", "strongBuy" => 10, "buy" => 22, "hold" => 6, "sell" => 0, "strongSell" => 0),
                ])
            )
            result = recommendation_trend(qs)
            @test result["period"] == ["0m", "-1m"]
            @test result["strong_buy"] == [12, 10]
            @test result["buy"] == [20, 22]
            @test result["hold"] == [5, 6]
            @test result["sell"] == [1, 0]
            @test result["strong_sell"] == [0, 0]
        end

        @testset "major_holders_breakdown accessor" begin
            qs = Dict(
                "quoteType" => Dict("quoteType" => "EQUITY"),
                "majorHoldersBreakdown" => Dict(
                    "maxAge" => 1,
                    "insidersPercentHeld" => 0.0007,
                    "institutionsPercentHeld" => 0.61,
                    "institutionsCount" => 5500,
                )
            )
            result = major_holders_breakdown(qs)
            @test !haskey(result, "maxAge")
            @test result["insidersPercentHeld"] == 0.0007
            @test result["institutionsPercentHeld"] == 0.61
            @test result["institutionsCount"] == 5500
        end

        @testset "summary_detail accessor" begin
            qs = Dict(
                "quoteType" => Dict("quoteType" => "EQUITY"),
                "summaryDetail" => Dict(
                    "maxAge" => 1,
                    "previousClose" => 195.0,
                    "open" => 196.0,
                    "beta" => 1.25,
                )
            )
            result = summary_detail(qs)
            @test !haskey(result, "maxAge")
            @test result["previousClose"] == 195.0
            @test result["beta"] == 1.25
        end

        @testset "sector_industry accessor" begin
            qs = Dict(
                "quoteType" => Dict("quoteType" => "EQUITY"),
                "summaryProfile" => Dict("sector" => "Technology", "industry" => "Consumer Electronics")
            )
            result = sector_industry(qs)
            @test result["sector"] == "Technology"
            @test result["industry"] == "Consumer Electronics"
        end

        @testset "upgrade_downgrade_history accessor" begin
            qs = Dict(
                "quoteType" => Dict("quoteType" => "EQUITY"),
                "upgradeDowngradeHistory" => Dict("history" => [
                    Dict("firm" => "JP Morgan", "epochGradeDate" => 1700000000, "toGrade" => "Overweight", "fromGrade" => "", "action" => "main"),
                    Dict("firm" => "UBS", "epochGradeDate" => 1699000000, "toGrade" => "Buy", "fromGrade" => "Neutral", "action" => "up"),
                ])
            )
            result = upgrade_downgrade_history(qs)
            @test result["firm"] == ["JP Morgan", "UBS"]
            @test result["to_grade"] == ["Overweight", "Buy"]
            @test result["from_grade"] == ["", "Neutral"]
            @test result["action"] == ["main", "up"]
            @test result["date"][1] isa DateTime
        end

        @testset "upgrade_downgrade_history empty" begin
            qs = Dict(
                "quoteType" => Dict("quoteType" => "EQUITY"),
                "upgradeDowngradeHistory" => Dict("history" => [])
            )
            @test isempty(upgrade_downgrade_history(qs))
        end

        @testset "insider_holders accessor" begin
            qs = Dict(
                "quoteType" => Dict("quoteType" => "EQUITY"),
                "insiderHolders" => Dict("holders" => [
                    Dict("name" => "John Doe", "relation" => "CEO", "transactionDescription" => "Sale",
                         "latestTransDate" => Dict("fmt" => "2024-01-15"),
                         "positionDirect" => Dict("raw" => 500000),
                         "positionDirectDate" => Dict("fmt" => "2024-01-15")),
                ])
            )
            result = insider_holders(qs)
            @test result["name"] == ["John Doe"]
            @test result["relation"] == Union{Missing,String}["CEO"]
            @test result["description"] == Union{Missing,String}["Sale"]
            @test result["latest_trans_date"][1] == DateTime("2024-01-15")
            @test result["position_direct"] == Union{Missing,Int}[500000]
        end

        @testset "insider_transactions accessor" begin
            qs = Dict(
                "quoteType" => Dict("quoteType" => "EQUITY"),
                "insiderTransactions" => Dict("transactions" => [
                    Dict("filerName" => "Jane Smith", "filerRelation" => "CFO",
                         "transactionText" => "Sale at 150",
                         "startDate" => Dict("fmt" => "2024-02-01"),
                         "ownership" => "D", "shares" => Dict("raw" => 10000), "value" => Dict("raw" => 1500000)),
                ])
            )
            result = insider_transactions(qs)
            @test result["filer_name"] == ["Jane Smith"]
            @test result["filer_relation"] == Union{Missing,String}["CFO"]
            @test result["shares"] == Union{Missing,Int}[10000]
            @test result["value"] == Union{Missing,Int}[1500000]
        end

        @testset "institutional_ownership accessor" begin
            qs = Dict(
                "quoteType" => Dict("quoteType" => "EQUITY"),
                "institutionOwnership" => Dict("ownershipList" => [
                    Dict("organization" => "Vanguard", "reportDate" => Dict("fmt" => "2024-03-31"),
                         "pctHeld" => Dict("raw" => 0.08), "position" => Dict("raw" => 1200000000),
                         "value" => Dict("raw" => 200000000000), "pctChange" => Dict("raw" => -0.005)),
                ])
            )
            result = institutional_ownership(qs)
            @test result["organization"] == ["Vanguard"]
            @test result["pct_held"] == Union{Missing,Float64}[0.08]
            @test result["position"] == Union{Missing,Int}[1200000000]
        end
    end

    # ═══════════════════════════════════════════════════════════════════════════
    @testset "Session & Headers" begin
        # Headers pool
        @test length(YFinance.HEADERS) >= 3
        for h in YFinance.HEADERS
            @test haskey(h, "User-Agent")
            @test contains(h["User-Agent"], "Mozilla")
        end

        # Build headers with cookies
        cookies = Dict("A3" => "abc123", "B" => "xyz")
        headers = YFinance._build_headers(cookies)
        cookie_header = filter(p -> p.first == "Cookie", headers)
        @test !isempty(cookie_header)
        @test contains(cookie_header[1].second, "A3=abc123")
        @test contains(cookie_header[1].second, "B=xyz")

        # Build headers without cookies
        headers_empty = YFinance._build_headers(Dict{String,String}())
        cookie_header2 = filter(p -> p.first == "Cookie", headers_empty)
        @test isempty(cookie_header2)

        # Accept-Encoding is overridden to identity
        ae = filter(p -> p.first == "Accept-Encoding", headers_empty)
        @test !isempty(ae)
        @test ae[1].second == "identity"
    end

    # ═══════════════════════════════════════════════════════════════════════════
    @testset "News Language Validation" begin
        # Supported languages
        for lang in ["en-us", "en-gb", "de", "es", "fr", "it", "pt-br", "zh", "zh-tw"]
            @test haskey(YFinance._NEWS_LANGUAGES, lang)
        end

        # Each entry is a Tuple{String,String}
        for (k, v) in YFinance._NEWS_LANGUAGES
            @test v isa Tuple{String,String}
            @test !isempty(v[1])
            @test !isempty(v[2])
        end
    end

    # ═══════════════════════════════════════════════════════════════════════════
    @testset "Edge Cases" begin
        # PriceData with single row
        pd = PriceData("X", [DateTime(2024,1,1)], [1.0], [2.0], [0.5], [1.5], [100.0], [1.5])
        @test length(pd) == 1
        s = sprint(show, MIME"text/plain"(), pd)
        @test contains(s, "1 rows")

        # Tables getcolumn by index at boundaries
        @test Tables.getcolumn(pd, 1) == ["X"]
        @test Tables.getcolumn(pd, 8) == [1.5]

        # FundamentalData without timestamp
        fd = FundamentalData("X", OrderedDict{String,Vector}("Revenue" => Any[100]))
        @test length(fd) == 0  # No timestamp key → length 0
    end

    # ═══════════════════════════════════════════════════════════════════════════
    # INTEGRATION TESTS — Require network access to Yahoo Finance
    # ═══════════════════════════════════════════════════════════════════════════

    @testset "Integration — Session & Validation" begin
        # Session initialization (cookie + crumb)
        YFinance._ensure_session!()
        @test YFinance._SESSION.initialized
        @test !isempty(YFinance._SESSION.cookie)
        @test !isempty(YFinance._SESSION.crumb)
        @test !isempty(YFinance._SESSION.header)

        # Symbol validation
        @test is_valid_symbol("AAPL")
        @test is_valid_symbol("MSFT")
        @test is_valid_symbol("^GSPC")
        @test !is_valid_symbol("XYZNOTAREALTICKER123")
        @test !is_valid_symbol("")

        # valid_symbols filter
        result = valid_symbols(["AAPL", "NOTREAL999", "MSFT"])
        @test "AAPL" in result
        @test "MSFT" in result
        @test "NOTREAL999" ∉ result
    end

    @testset "Integration — Prices" begin
        # Daily prices by range
        pd = prices("AAPL", range="5d", interval="1d")
        @test pd isa PriceData
        @test pd.ticker == "AAPL"
        @test length(pd) >= 1
        @test !any(isempty, [pd.open, pd.high, pd.low, pd.close, pd.volume])
        @test all(x -> x > 0, filter(!isnan, pd.close))
        @test all(x -> x >= 0, filter(!isnan, pd.volume))
        @test pd.timestamp[1] isa DateTime

        # Tables.jl integration
        @test Tables.istable(typeof(pd))
        cols = Tables.columns(pd)
        @test length(Tables.getcolumn(cols, :close)) == length(pd)

        # Autoadjust vs raw
        pd_adj = prices("AAPL", range="1mo", interval="1d", autoadjust=true)
        pd_raw = prices("AAPL", range="1mo", interval="1d", autoadjust=false)
        @test pd_adj isa PriceData
        @test pd_raw isa PriceData
        @test length(pd_adj) >= 1
        @test length(pd_raw) >= 1

        # Prices by date range
        pd_dates = prices("MSFT",
            startdt="2024-01-02", enddt="2024-01-31",
            interval="1d"
        )
        @test pd_dates isa PriceData
        @test pd_dates.ticker == "MSFT"
        @test length(pd_dates) >= 15  # ~20 trading days in January
        @test pd_dates.timestamp[1] >= DateTime(2024, 1, 1)
        @test pd_dates.timestamp[end] <= DateTime(2024, 2, 1)

        # Weekly interval
        pd_wk = prices("GOOGL", range="3mo", interval="1wk")
        @test pd_wk isa PriceData
        @test length(pd_wk) >= 10

        # Exchange local time
        pd_local = prices("AAPL", range="5d", interval="1d", exchange_local_time=true)
        @test pd_local isa PriceData
        @test length(pd_local) >= 1

        # Index symbol
        pd_idx = prices("^GSPC", range="5d", interval="1d")
        @test pd_idx isa PriceData
        @test pd_idx.ticker == "^GSPC"
        @test length(pd_idx) >= 1

        # Invalid symbol
        @test_throws YFinanceError prices("XYZNOTAREALTICKER123", range="5d")
    end

    @testset "Integration — Dividends" begin
        # Company that pays dividends
        dd = dividends("AAPL", startdt="2023-01-01", enddt="2024-01-01")
        @test dd isa DividendData
        @test dd.ticker == "AAPL"
        @test length(dd) >= 3  # AAPL pays quarterly
        @test all(d -> d > 0, dd.dividend)
        @test all(t -> t >= DateTime(2023, 1, 1), dd.timestamp)

        # Tables.jl integration
        @test Tables.istable(typeof(dd))
        @test Tables.getcolumn(dd, :ticker) == fill("AAPL", length(dd))

        # Company without dividends (growth stock)
        dd_none = dividends("AMZN", startdt="2020-01-01", enddt="2020-12-31")
        @test dd_none isa DividendData
        @test isempty(dd_none)

        # Invalid symbol
        @test_throws YFinanceError dividends("XYZNOTAREALTICKER123", startdt="2023-01-01", enddt="2024-01-01")
    end

    @testset "Integration — Splits" begin
        # Historical split (AAPL 4:1 in Aug 2020)
        sd = splits("AAPL", startdt="2020-01-01", enddt="2021-01-01")
        @test sd isa SplitData
        @test sd.ticker == "AAPL"
        @test length(sd) >= 1
        @test 4 in sd.numerator
        @test 1 in sd.denominator
        @test any(r -> r ≈ 4.0, sd.ratio)

        # Tables.jl integration
        @test Tables.istable(typeof(sd))

        # Period with no splits
        sd_none = splits("MSFT", startdt="2023-01-01", enddt="2023-12-31")
        @test sd_none isa SplitData
        @test isempty(sd_none)

        # Invalid symbol
        @test_throws YFinanceError splits("XYZNOTAREALTICKER123", startdt="2023-01-01", enddt="2024-01-01")
    end

    @testset "Integration — Options" begin
        oc = options("AAPL")
        @test oc isa OptionsChain
        @test oc.ticker == "AAPL"
        @test length(oc.calls) >= 1
        @test length(oc.puts) >= 1

        # Check calls have expected columns
        @test haskey(oc.calls.data, "strike")
        @test haskey(oc.calls.data, "bid")
        @test haskey(oc.calls.data, "ask")
        @test haskey(oc.calls.data, "impliedVolatility")
        @test haskey(oc.calls.data, "type")
        @test all(==("call"), oc.calls.data["type"])
        @test all(==("put"), oc.puts.data["type"])

        # Strikes are positive numbers
        @test all(s -> !ismissing(s) && s > 0, oc.calls.data["strike"])
        @test all(s -> !ismissing(s) && s > 0, oc.puts.data["strike"])

        # Tables.jl integration
        @test Tables.istable(typeof(oc.calls))
        @test Tables.istable(typeof(oc.puts))

        # Invalid symbol
        @test_throws YFinanceError options("XYZNOTAREALTICKER123")
    end

    @testset "Integration — Fundamentals" begin
        # Entire income statement
        fd = fundamentals("AAPL", "income_statement", "quarterly", "2023-01-01", "2024-01-01")
        @test fd isa FundamentalData
        @test fd.ticker == "AAPL"
        @test length(fd) >= 2  # At least 2 quarters
        @test haskey(fd.data, "timestamp")
        @test haskey(fd.data, "TotalRevenue")
        @test haskey(fd.data, "NetIncome")
        @test all(t -> t isa DateTime, fd.data["timestamp"])

        # Tables.jl
        @test Tables.istable(typeof(fd))

        # Single item
        fd_rev = fundamentals("MSFT", "TotalRevenue", "annual", "2020-01-01", "2024-01-01")
        @test fd_rev isa FundamentalData
        @test fd_rev.ticker == "MSFT"
        @test haskey(fd_rev.data, "TotalRevenue")
        @test length(fd_rev) >= 2

        # Balance sheet
        fd_bs = fundamentals("AAPL", "balance_sheet", "annual", "2022-01-01", "2024-01-01")
        @test fd_bs isa FundamentalData
        @test haskey(fd_bs.data, "TotalAssets")

        # Cash flow
        fd_cf = fundamentals("AAPL", "cash_flow", "quarterly", "2023-01-01", "2024-01-01")
        @test fd_cf isa FundamentalData
        @test haskey(fd_cf.data, "FreeCashFlow") || haskey(fd_cf.data, "OperatingCashFlow")

        # Invalid symbol
        @test_throws YFinanceError fundamentals("XYZNOTAREALTICKER123", "income_statement", "annual", "2023-01-01", "2024-01-01")
    end

    @testset "Integration — Quote Summary" begin
        # Full quote summary
        qs = quote_summary("AAPL")
        @test qs isa Dict
        @test haskey(qs, "quoteType")
        @test qs["quoteType"]["quoteType"] == "EQUITY"
        @test haskey(qs, "summaryDetail")
        @test haskey(qs, "earnings")

        # Single module
        qtype = quote_summary("AAPL", item="quoteType")
        @test qtype isa Dict
        @test qtype["quoteType"] == "EQUITY"
        @test haskey(qtype, "symbol")

        # Accessor functions with real data
        si = sector_industry(qs)
        @test si["sector"] == "Technology"
        @test !isempty(si["industry"])

        sd_result = summary_detail(qs)
        @test haskey(sd_result, "previousClose") || haskey(sd_result, "open")

        rt = recommendation_trend(qs)
        @test haskey(rt, "period")
        @test haskey(rt, "strong_buy")
        @test haskey(rt, "buy")
        @test length(rt["period"]) >= 1

        mhb = major_holders_breakdown(qs)
        @test !isempty(mhb)
        @test !haskey(mhb, "maxAge")

        # Calendar events
        ce = calendar_events(qs)
        @test haskey(ce, "dividend_date") || haskey(ce, "earnings_dates")

        # ETF quote summary
        qs_etf = quote_summary("SPY", item="summaryDetail")
        @test qs_etf isa Dict
    end

    @testset "Integration — Search" begin
        # Search by company name
        results = search_symbols("microsoft")
        @test results isa SearchResults
        @test length(results) >= 1
        @test any(r -> r.symbol == "MSFT", results)
        @test any(r -> contains(lowercase(r.name), "microsoft"), results)

        # Search by ticker
        results2 = search_symbols("AAPL")
        @test length(results2) >= 1
        @test results2[1].symbol == "AAPL"

        # Search returns type info
        msft = filter(r -> r.symbol == "MSFT", results)
        if !isempty(msft)
            @test msft[1].quote_type == "EQUITY"
        end

        # Broad search
        results3 = search_symbols("gold etf")
        @test length(results3) >= 1
    end

    @testset "Integration — News" begin
        # Basic news search
        news = search_news("AAPL")
        @test news isa NewsResults
        @test length(news) >= 1
        @test !isempty(news[1].title)
        @test !isempty(news[1].publisher)
        @test startswith(news[1].link, "http")
        @test news[1].timestamp isa DateTime

        # Helper functions
        @test length(titles(news)) == length(news)
        @test length(links(news)) == length(news)
        @test all(l -> startswith(l, "http"), links(news))

        # Different language
        news_de = search_news("BMW", lang="de")
        @test news_de isa NewsResults
        # May or may not return results depending on availability
    end

    @testset "Integration — Session Renewal" begin
        # Force session invalidation and verify re-init
        YFinance._SESSION.initialized = false
        YFinance._SESSION.crumb = ""
        YFinance._SESSION.cookie = Dict{String,String}()

        # Next request should auto-renew session
        pd = prices("AAPL", range="1d", interval="1d")
        @test pd isa PriceData
        @test YFinance._SESSION.initialized
        @test !isempty(YFinance._SESSION.crumb)
    end

end
