# Proxy Configuration

## `set_proxy!`

Configure an HTTP proxy for all Yahoo Finance requests.

```@docs
set_proxy!
```

## `clear_proxy!`

Remove proxy configuration and revert to direct connections.

```@docs
clear_proxy!
```

### Examples

```julia
# Simple proxy
set_proxy!("http://proxy.example.com:8080")

# Authenticated proxy
set_proxy!("http://proxy.example.com:8080", "username", "password")

# Remove proxy
clear_proxy!()
```

!!! warning "Security"
    Proxy credentials are stored in memory using Base64 encoding (HTTP Basic Auth).
    Ensure your proxy connection uses HTTPS if transmitting over untrusted networks.
