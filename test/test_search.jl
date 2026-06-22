# ─── Search & News Integration Tests ─────────────────────────────────────────

@testset "Search (Integration)" begin

    @testset "Symbol Search" begin
        sleep(0.5)
        results = search_symbols("microsoft")
        @test results isa SearchResults
        @test length(results) > 0
        @test results[1] isa SearchResult
        # Microsoft should be in results
        @test any(r -> r.symbol == "MSFT", results)
    end

    @testset "Search Fields" begin
        sleep(0.5)
        results = search_symbols("apple")
        r = results[1]
        @test !isempty(r.symbol)
        @test !isempty(r.name)
        @test !isempty(r.exchange)
        @test !isempty(r.type)
    end

    @testset "Symbol Validation" begin
        sleep(0.5)
        @test is_valid_symbol("AAPL") == true
        sleep(0.5)
        @test is_valid_symbol("XYZNOTREAL999") == false
    end

    @testset "Valid Symbols Filter" begin
        sleep(0.5)
        result = valid_symbols(["AAPL", "MSFT", "XYZNOTREAL999"])
        @test "AAPL" in result || "aapl" in result
        @test "MSFT" in result || "msft" in result
        @test !("XYZNOTREAL999" in result)

        # Single symbol
        @test valid_symbols("AAPL") == ["AAPL"]
        sleep(0.5)
        @test valid_symbols("XYZNOTREAL999") == String[]
    end
end

@testset "News (Integration)" begin
    sleep(0.5)
    news = search_news("AAPL")
    @test news isa NewsResults
    @test length(news) > 0

    @test news[1] isa NewsItem
    @test !isempty(news[1].title)
    @test !isempty(news[1].link)

    # Helper functions
    @test titles(news) isa Vector{String}
    @test links(news) isa Vector{String}
    @test timestamps(news) isa Vector{DateTime}
    @test length(titles(news)) == length(news)
end
