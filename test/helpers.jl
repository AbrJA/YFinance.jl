# ─── Test Helpers ─────────────────────────────────────────────────────────────

"""Retry an API call up to `n` times with increasing delay."""
function with_retry(f; retries=3, delay=5.0)
    for i in 1:retries
        try
            result = f()
            if !isnothing(result)
                return result
            end
        catch e
            i == retries && rethrow()
        end
        i < retries && sleep(delay * i)
    end
    return f()
end

"""Check if Yahoo Finance API is currently accessible."""
function api_available()
    try
        p = get_prices("AAPL", range="1d")
        return !isempty(p)
    catch
        return false
    end
end
