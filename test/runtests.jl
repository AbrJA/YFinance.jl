using YFinance
using Test
using Dates
using Base64
using Tables

# Test helpers
include("helpers.jl")

# Unit tests (no network)
include("test_unit.jl")

# Integration tests (network required, rate-limit tolerant)
include("test_prices.jl")
include("test_options.jl")
include("test_summary.jl")
include("test_fundamentals.jl")
include("test_search.jl")

# Code quality (optional, slow)
include("test_quality.jl")
