# ─── Fundamentals Integration Tests ───────────────────────────────────────────

@testset "Fundamentals (Integration)" begin

    @testset "Full Statement" begin
        sleep(0.5)
        result = get_fundamentals("AAPL", "income_statement", "annual",
                                  today() - Year(5), today())
        @test result isa Dict
        @test haskey(result, "timestamp")
        @test length(result["timestamp"]) >= 3
        # Should have multiple line items
        @test length(keys(result)) > 5
    end

    @testset "Single Item" begin
        sleep(0.5)
        result = get_fundamentals("AAPL", "TotalRevenue", "quarterly",
                                  today() - Year(3), today())
        @test haskey(result, "TotalRevenue")
        @test haskey(result, "timestamp")
        @test length(result["TotalRevenue"]) >= 4
    end

    @testset "Balance Sheet" begin
        sleep(0.5)
        result = get_fundamentals("MSFT", "balance_sheet", "annual",
                                  "2020-01-01", "2024-01-01")
        @test haskey(result, "timestamp")
        @test length(keys(result)) > 3
    end

    @testset "Cash Flow" begin
        sleep(0.5)
        result = get_fundamentals("AAPL", "cash_flow", "quarterly",
                                  "2022-01-01", "2024-01-01")
        @test haskey(result, "timestamp")
    end

    @testset "Valuation" begin
        sleep(0.5)
        result = get_fundamentals("AAPL", "valuation", "quarterly",
                                  "2022-01-01", "2024-01-01")
        @test haskey(result, "timestamp")
    end

    @testset "Invalid Symbol" begin
        sleep(0.5)
        result = get_fundamentals("XYZNOTREAL999", "income_statement", "annual",
                                  "2020-01-01", "2021-01-01")
        @test isempty(result)
    end
end
