push!(LOAD_PATH, "../src/")
using YFinance
using Documenter

makedocs(
    sitename="YFinance.jl",
    format=Documenter.HTML(
        analytics="G-LFRFQ0X1VF",
        canonical="https://eohne.github.io/YFinance.jl/dev/",
    ),
    modules=[YFinance],
    pages=[
        "Home" => "index.md",
        "API Reference" => [
            "Prices" => "prices.md",
            "Dividends & Splits" => "dividends_splits.md",
            "Fundamentals" => "fundamentals.md",
            "Quote Summary" => "quote_summary.md",
            "Options" => "options.md",
            "Search" => "search.md",
            "News" => "news.md",
            "Proxy" => "proxy.md",
            "All Functions" => "api.md",
        ],
        "Examples" => [
            "DataFrames & Tables" => "dataframes.md",
            "Plotting" => "plotting.md",
        ],
        "Changelog" => "changelog.md",
    ],
)

deploydocs(;
    repo="github.com/eohne/YFinance.jl",
    devurl="dev",
    versions=["stable" => "v^", "v#.#", "dev" => "dev"],
)