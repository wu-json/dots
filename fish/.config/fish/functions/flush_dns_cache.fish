function flush_dns_cache
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
end
