# ─── Fundamentals Integration Tests ───────────────────────────────────────────

@testset "Fundamentals (Integration)" begin

    @testset "Full Statement" begin
        sleep(2)
        result = with_retry(() -> begin
            r = get_fundamentals("AAPL", "income_statement", "annual", today() - Year(5), today())
            isempty(r) ? nothing : r
        end)
        if !isnothing(result) && !isempty(result)
            @test haskey(result, "timestamp")
            @test length(result["timestamp"]) >= 3
            @test length(keys(result)) > 5
        else
            @test_broken false
        end
    end

    @testset "Single Item" begin
        sleep(2)
        result = with_retry(() -> begin
            r = get_fundamentals("AAPL", "TotalRevenue", "quarterly", today() - Year(3), today())
            isempty(r) ? nothing : r
        end)
        if !isnothing(result) && !isempty(result)
            @test haskey(result, "TotalRevenue")
            @test haskey(result, "timestamp")
            @test length(result["TotalRevenue"]) >= 4
        else
            @test_broken false
        end
    end

    @testset "Invalid Symbol" begin
        sleep(2)
        result = get_fundamentals("XYZNOTREAL999", "income_statement", "annual", "2020-01-01", "2021-01-01")
        @test isempty(result)
    end
end
