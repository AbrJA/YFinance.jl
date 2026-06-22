push!(LOAD_PATH, "../src/")
using YFinance
using Documenter, OrderedCollections

makedocs(
    sitename = "YFinance.jl",
    format = Documenter.HTML(
        analytics = "G-LFRFQ0X1VF",
        canonical = "https://eohne.github.io/YFinance.jl/stable/",
    ),
    modules = [YFinance],
    pages = [
        "Home" => "index.md",
        "API Reference" => [
            "Prices, Dividends & Splits" => "prices.md",
            "Fundamentals" => "fundamentals.md",
            "Options" => "options.md",
            "Quote Summary" => "quote_summary.md",
            "Search & News" => "search.md",
            "Configuration" => "configuration.md",
        ],
        "Types Reference" => "types.md",
    ]
)

deploydocs(;
    repo = "github.com/eohne/YFinance.jl",
    devurl = "dev",
    versions = ["stable" => "v^", "v#.#", "dev" => "dev"]
)
