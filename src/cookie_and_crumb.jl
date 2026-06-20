"""
    _rand_header()

Chooses a random header.
"""
function _rand_header()
    return rand(HEADERS)
end;

"""
    get_cookie()

Retrieves cookies from "https://fc.yahoo.com".
"""
function get_cookie()
    headers = _make_headers(; cookies=Dict{String,String}())
    resp = _request("https://fc.yahoo.com"; headers=headers, timeout=10, throw_on_error=false)
    cookies = _parse_set_cookie(resp.headers)
    return cookies
end;

"""
    get_crumb()

Passess the request header and the cookies to "https://query2.finance.yahoo.com/v1/test/getcrumb" and retrieves the crumb. 
If the global _HEADER or _COOKIE variables are not defined they are created.
"""
function get_crumb()
    if (@isdefined _HEADER) && (@isdefined _COOKIE)
        nothing
    else
        _set_cookies_and_crumb()
    end
    headers = _make_headers(; cookies=_COOKIE)
    resp = _request("https://query2.finance.yahoo.com/v1/test/getcrumb"; headers=headers, timeout=10, throw_on_error=false)
    res = String(resp.body)
    if isequal(res,"")
        @warn "Crumb could not be retrieved. Certain data items will not be available!"
    end
    return res
end;

"""
    _renew_cookies_and_crumb()

Renews both the cookies and the crumb.
"""
function _renew_cookies_and_crumb()
    if @isdefined _HEADER
       global _COOKIE = get_cookie()
       global _CRUMB = get_crumb()
    else
        global _HEADER = _rand_header()
        global _COOKIE = get_cookie()
        global _CRUMB = get_crumb()
    end
end;


"""
    _set_cookies_and_crumb()

Checks if the global _COOKIE and _CRUMB variables are set if not it creates them. 
"""
function _set_cookies_and_crumb()
    if @isdefined _HEADER
        nothing
    else 
       global _HEADER = _rand_header()
    end
    if @isdefined _COOKIE 
        nothing
    else
        global _COOKIE = get_cookie()
    end
    if @isdefined _CRUMB 
        nothing
    else
        global _CRUMB = get_crumb()
    end
end;
