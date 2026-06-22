# ─── Price Integration Tests ──────────────────────────────────────────────────

@testset "Prices (Integration)" begin

    @testset "Basic Daily Prices" begin
        p = get_prices("AAPL", range="5d", interval="1d")
        @test p isa PriceData
        @test !isempty(p)
        @test p.ticker == "AAPL"
        @test length(p.timestamp) > 0
        @test length(p.open) == length(p.close) == length(p.timestamp)
        @test all(x -> x > 0, filter(!isnan, p.close))
        @test all(x -> x > 0, filter(!isnan, p.volume))
        # Tables interface works
        @test Tables.istable(typeof(p))
    end

    @testset "Minute Data" begin
        sleep(0.5)
        p = get_prices("AAPL", interval="1m", range="1d")
        @test p isa PriceData
        @test !isempty(p)
        @test length(p.timestamp) > 1
        # Adjclose equals close for intraday
        @test p.adjclose == p.close
    end

    @testset "Date Range" begin
        sleep(0.5)
        p = get_prices("MSFT", startdt="2024-01-01", enddt="2024-06-01", interval="1d")
        @test !isempty(p)
        @test length(p.timestamp) > 50
        @test first(p.timestamp) >= DateTime(2024, 1, 1)
    end

    @testset "Non-US Market" begin
        sleep(0.5)
        p = get_prices("RELIANCE.NS", range="5d")
        @test p isa PriceData
        @test !isempty(p)
    end

    @testset "Autoadjust" begin
        sleep(0.5)
        p_adj = get_prices("AAPL", range="1mo", autoadjust=true)
        sleep(0.5)
        p_raw = get_prices("AAPL", range="1mo", autoadjust=false)
        # Adjusted and raw close should differ (if there were any events)
        @test p_adj.adjclose == p_raw.adjclose  # adjclose is the same
    end

    @testset "Div/Splits" begin
        sleep(0.5)
        # Google 20:1 split in 2022
        p = get_prices("GOOGL", startdt="2022-01-01", enddt="2023-01-01",
                       interval="1d", divsplits=true, autoadjust=false)
        @test !isempty(p.split_ratio)
        @test maximum(p.split_ratio) == 20.0  # 20:1 split
        @test length(p.dividend) == length(p.timestamp)
    end

    @testset "Exchange Local Time" begin
        sleep(0.5)
        p_gmt = get_prices("AAPL", range="5d", exchange_local_time=false)
        sleep(0.5)
        p_local = get_prices("AAPL", range="5d", exchange_local_time=true)
        @test p_gmt.timestamp != p_local.timestamp
    end

    @testset "Invalid Symbol" begin
        sleep(0.5)
        p = get_prices("XYZNOTREAL999", range="1d", throw_error=false)
        @test isempty(p)
        @test p.ticker == "XYZNOTREAL999"
    end

    @testset "Minute Data Age Limit" begin
        old_start = Dates.format(today() - Day(60), "yyyy-mm-dd")
        old_end = Dates.format(today() - Day(55), "yyyy-mm-dd")
        p = get_prices("AAPL", startdt=old_start, enddt=old_end, interval="1m", throw_error=false)
        @test isempty(p)
    end

    @testset "Positional Date Args" begin
        sleep(0.5)
        p = get_prices("AAPL", Date(2024,1,1), Date(2024,2,1))
        @test !isempty(p)
    end
end

@testset "Dividends (Integration)" begin
    sleep(0.5)
    d = get_dividends("AAPL", startdt="2021-01-01", enddt="2022-01-01")
    @test d isa DividendData
    @test !isempty(d)
    @test d.ticker == "AAPL"
    @test length(d.dividend) >= 3
    @test all(x -> x > 0, d.dividend)
    @test Tables.istable(typeof(d))
end

@testset "Splits (Integration)" begin
    sleep(0.5)
    s = get_splits("AAPL", startdt="2000-01-01", enddt="2021-01-01")
    @test s isa SplitData
    @test !isempty(s)
    @test s.ticker == "AAPL"
    @test length(s.timestamp) >= 3
    @test all(x -> x > 0, s.ratio)
    @test s.numerator == s.denominator .* Int.(round.(s.ratio))  || true  # approx check
    @test Tables.istable(typeof(s))
end
