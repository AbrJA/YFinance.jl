# ─── Options Integration Tests ────────────────────────────────────────────────

@testset "Options (Integration)" begin
    sleep(0.5)
    chain = get_options("AAPL")
    @test chain isa OptionChain
    @test chain.ticker == "AAPL"

    # May be empty on weekends but struct is valid
    if !isempty(chain)
        @test length(chain.calls) > 0
        @test length(chain.puts) > 0

        c = chain.calls[1]
        @test c isa OptionContract
        @test c.strike > 0
        @test c.type == "call"
        @test c.currency == "USD"
        @test c.expiration > DateTime(2020, 1, 1)

        p = chain.puts[1]
        @test p.type == "put"

        # Tables interface
        @test Tables.istable(typeof(chain))
        cols = Tables.getcolumn(chain, :strike)
        @test length(cols) == length(chain.calls) + length(chain.puts)
    end

    @testset "Invalid Symbol" begin
        sleep(0.5)
        bad = get_options("XYZNOTREAL999", throw_error=false)
        @test bad isa OptionChain
        @test isempty(bad)
    end
end
