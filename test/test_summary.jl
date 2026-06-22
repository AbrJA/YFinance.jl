# ─── QuoteSummary Integration Tests ───────────────────────────────────────────

@testset "QuoteSummary (Integration)" begin
    sleep(0.5)
    qs = get_quote_summary("AAPL")
    @test qs isa Dict
    @test haskey(qs, "price")
    @test haskey(qs, "summaryDetail")

    @testset "Single Module" begin
        sleep(0.5)
        price_data = get_quote_summary("AAPL", item="price")
        @test price_data isa Dict
        @test haskey(price_data, "regularMarketPrice")
    end

    @testset "Multiple Modules" begin
        sleep(0.5)
        multi = get_quote_summary("AAPL", item=["price", "summaryDetail"])
        @test haskey(multi, "price")
        @test haskey(multi, "summaryDetail")
    end

    @testset "calendar_events" begin
        result = calendar_events(qs)
        @test haskey(result, "earnings_dates")
        @test result["earnings_dates"] isa Vector{DateTime}
    end

    @testset "earnings_estimates" begin
        result = earnings_estimates(qs)
        @test haskey(result, "estimate")
        @test haskey(result, "quarter")
        @test length(result["estimate"]) > 0
    end

    @testset "earnings_per_share" begin
        result = earnings_per_share(qs)
        @test haskey(result, "estimate")
        @test haskey(result, "actual")
        @test haskey(result, "surprise")
    end

    @testset "insider_holders" begin
        result = insider_holders(qs)
        @test haskey(result, "name")
        @test length(result["name"]) > 0
    end

    @testset "insider_transactions" begin
        result = insider_transactions(qs)
        @test haskey(result, "name")
        @test haskey(result, "shares")
    end

    @testset "institutional_ownership" begin
        result = institutional_ownership(qs)
        @test haskey(result, "organization")
        @test length(result["organization"]) > 0
    end

    @testset "major_holders_breakdown" begin
        result = major_holders_breakdown(qs)
        @test haskey(result, "institutionsCount")
    end

    @testset "recommendation_trend" begin
        result = recommendation_trend(qs)
        @test haskey(result, "strongbuy")
        @test haskey(result, "buy")
        @test length(result["period"]) > 0
    end

    @testset "summary_detail" begin
        result = summary_detail(qs)
        @test result isa Dict
        @test !haskey(result, "maxAge")
    end

    @testset "sector_industry" begin
        result = sector_industry(qs)
        @test haskey(result, "sector")
        @test haskey(result, "industry")
        @test result["sector"] == "Technology"
    end

    @testset "upgrade_downgrade_history" begin
        result = upgrade_downgrade_history(qs)
        @test haskey(result, "firm")
        @test haskey(result, "date")
        @test length(result["firm"]) > 0
    end

    @testset "String Shortcut" begin
        sleep(0.5)
        result = sector_industry("AAPL")
        @test result["sector"] == "Technology"
    end

    @testset "Invalid Module" begin
        @test_throws AssertionError get_quote_summary("AAPL", item="not_a_module")
    end
end
