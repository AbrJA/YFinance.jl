# ─── Code Quality Tests (Aqua.jl + JET.jl) ───────────────────────────────────
# These tests validate code quality without being runtime dependencies.
# They are slow to precompile, so guard them behind an ENV flag.

@testset "Code Quality" begin
    if get(ENV, "YFINANCE_QUALITY_TESTS", "false") == "true" || "quality" in ARGS
        @testset "Aqua.jl" begin
            using Aqua
            Aqua.test_all(YFinance;
                ambiguities=false,         # Intentional dispatch on Union types
                stale_deps=false,          # Aqua/JET are test-only extras
                persistent_tasks=false,    # Downloads.Downloader uses background tasks
            )
        end

        @testset "JET.jl" begin
            using JET
            # Only test our own code, not dependencies
            result = JET.report_package(YFinance;
                target_defined_modules=true,
            )
            @test length(JET.get_reports(result)) == 0
        end
    else
        @info "Skipping quality tests (set YFINANCE_QUALITY_TESTS=true to enable)"
    end
end
