# ─── Search & News Integration Tests ─────────────────────────────────────────

@testset "Search (Integration)" begin

    @testset "Symbol Search" begin
        sleep(2)
        results = with_retry(() -> search_symbols("microsoft"))
        @test results isa SearchResults
        if length(results) > 0
            @test results[1] isa SearchResult
            @test any(r -> r.symbol == "MSFT", results)
        else
            @test_broken length(results) > 0
        end
    end

    @testset "Symbol Validation" begin
        sleep(2)
        @test is_valid_symbol("AAPL") == true
        sleep(2)
        @test is_valid_symbol("XYZNOTREAL999") == false
    end

    @testset "Valid Symbols Filter" begin
        sleep(2)
        result = valid_symbols(["AAPL", "XYZNOTREAL999"])
        @test "AAPL" in result
        @test !("XYZNOTREAL999" in result)
    end
end

@testset "News (Integration)" begin
    sleep(2)
    news = with_retry(() -> search_news("AAPL"))
    @test news isa NewsResults
    if length(news) > 0
        @test news[1] isa NewsItem
        @test !isempty(news[1].title)
        @test titles(news) isa Vector{String}
        @test links(news) isa Vector{String}
        @test timestamps(news) isa Vector{DateTime}
    else
        @test_broken length(news) > 0
    end
end
