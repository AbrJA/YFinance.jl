# ─── Price Integration Tests ──────────────────────────────────────────────────

@testset "Prices (Integration)" begin

    @testset "Basic Daily Prices" begin
        p = with_retry(() -> get_prices("AAPL", range="5d", interval="1d"))
        @test p isa PriceData
        if !isempty(p)
            @test p.ticker == "AAPL"
            @test length(p.timestamp) > 0
            @test length(p.open) == length(p.close) == length(p.timestamp)
            @test all(x -> x > 0, filter(!isnan, p.close))
            @test Tables.istable(typeof(p))
        else
            @test_broken !isempty(p)
        end
    end

    @testset "Minute Data" begin
        sleep(2)
        p = with_retry(() -> get_prices("AAPL", interval="1m", range="1d"))
        @test p isa PriceData
        if !isempty(p)
            @test length(p.timestamp) > 1
            @test all(isequal.(p.adjclose, p.close))
        else
            @test_broken !isempty(p)
        end
    end

    @testset "Date Range" begin
        sleep(2)
        p = with_retry(() -> get_prices("MSFT", startdt="2024-01-01", enddt="2024-06-01"))
        if !isempty(p)
            @test length(p.timestamp) > 50
            @test first(p.timestamp) >= DateTime(2024, 1, 1)
        else
            @test_broken !isempty(p)
        end
    end

    @testset "Non-US Market" begin
        sleep(2)
        p = with_retry(() -> get_prices("RELIANCE.NS", range="5d"))
        @test p isa PriceData
        if !isempty(p)
            @test p.ticker == "RELIANCE.NS"
        else
            @test_broken !isempty(p)
        end
    end

    @testset "Div/Splits" begin
        sleep(2)
        p = with_retry(() -> get_prices("GOOGL", startdt="2022-01-01", enddt="2023-01-01",
                                        interval="1d", divsplits=true, autoadjust=false))
        if !isempty(p) && !isempty(p.split_ratio)
            @test maximum(p.split_ratio) == 20.0
            @test length(p.dividend) == length(p.timestamp)
        else
            @test_broken !isempty(p)
        end
    end

    @testset "Exchange Local Time" begin
        sleep(2)
        p_gmt = with_retry(() -> get_prices("AAPL", range="5d", exchange_local_time=false))
        sleep(2)
        p_local = with_retry(() -> get_prices("AAPL", range="5d", exchange_local_time=true))
        if !isempty(p_gmt) && !isempty(p_local)
            @test p_gmt.timestamp != p_local.timestamp
        else
            @test_broken !isempty(p_gmt) && !isempty(p_local)
        end
    end

    @testset "Invalid Symbol" begin
        sleep(2)
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
        sleep(2)
        p = with_retry(() -> get_prices("AAPL", Date(2024,1,1), Date(2024,2,1)))
        @test p isa PriceData
        if !isempty(p)
            @test length(p.timestamp) > 0
        else
            @test_broken !isempty(p)
        end
    end
end

@testset "Dividends (Integration)" begin
    sleep(2)
    d = with_retry(() -> get_dividends("AAPL", startdt="2021-01-01", enddt="2022-01-01"))
    @test d isa DividendData
    if !isempty(d)
        @test d.ticker == "AAPL"
        @test length(d.dividend) >= 3
        @test all(x -> x > 0, d.dividend)
        @test Tables.istable(typeof(d))
    else
        @test_broken !isempty(d)
    end
end

@testset "Splits (Integration)" begin
    sleep(2)
    s = with_retry(() -> get_splits("AAPL", startdt="2000-01-01", enddt="2021-01-01"))
    @test s isa SplitData
    if !isempty(s)
        @test s.ticker == "AAPL"
        @test length(s.timestamp) >= 3
        @test all(x -> x > 0, s.ratio)
        @test Tables.istable(typeof(s))
    else
        @test_broken !isempty(s)
    end
end
