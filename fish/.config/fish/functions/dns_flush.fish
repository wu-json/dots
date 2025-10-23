function dns_flush
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
end
