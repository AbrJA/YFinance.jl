# Proxy Settings

Proxy settings allow you to route all Yahoo Finance requests through an HTTP proxy. This is useful in corporate environments or when geographic restrictions apply.

Settings are applied globally to the internal session and take effect on the next request.

## Functions

````@docs
create_proxy_settings
clear_proxy_settings
````

## Usage

```julia
# Set proxy (unauthenticated)
create_proxy_settings("http://proxy.example.com:8080")

# Set proxy (with authentication)
create_proxy_settings("http://proxy.example.com:8080", "username", "password")

# Clear proxy settings (revert to direct connection)
clear_proxy_settings()
```

## Environment Variables

`Downloads.jl` (libcurl) also respects the standard `HTTP_PROXY` and `HTTPS_PROXY` environment variables. If you have these set in your environment, requests may already be routed through your proxy without calling `create_proxy_settings`.

## Notes

- After changing proxy settings, the session is automatically re-initialized on the next request
- Proxy authentication uses HTTP Basic auth (base64-encoded credentials)
- The proxy setting is stored in the thread-safe `YahooSession` singleton
