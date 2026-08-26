# ollama_tailnet: proxy the host's Ollama onto the tailnet as
# ollama.<tailnet>.ts.net via a tailscale sidecar container (OrbStack docker).
# The sidecar joins the tailnet as its own node named "ollama" and
# reverse-proxies HTTPS 443 to the host's Ollama; node identity persists in
# the ts-ollama-state volume so login is one-time. Runs in the foreground —
# ctrl-c stops the proxy.
function ollama_tailnet --description "Serve Ollama on the tailnet as ollama.<tailnet>.ts.net — ctrl-c to stop"
    set -l cmd up
    if test (count $argv) -gt 0
        set cmd $argv[1]
    end

    set -l ctr ts-ollama

    function __ollama_tailnet_say -S -a msg
        set_color -o cyan
        echo -n "🦙 ollama"
        set_color normal
        echo " · $msg"
    end

    if not command -q docker
        __ollama_tailnet_say "docker CLI not found (install OrbStack)" >&2
        return 1
    end

    switch $cmd
        case up
            # OrbStack provides the docker engine; start it if needed.
            if not docker info >/dev/null 2>&1
                if command -q orbctl
                    __ollama_tailnet_say "starting OrbStack"
                    orbctl start
                    or return
                    for i in (seq 30)
                        docker info >/dev/null 2>&1
                        and break
                        sleep 1
                    end
                end
                if not docker info >/dev/null 2>&1
                    __ollama_tailnet_say "docker engine is not running" >&2
                    return 1
                end
            end

            # Ollama must listen on all interfaces: the container reaches the
            # host via host.docker.internal, and a 127.0.0.1-bound server is
            # unreachable from Docker.
            if not curl -sf --max-time 2 http://127.0.0.1:11434/api/version >/dev/null
                __ollama_tailnet_say "starting ollama serve (logs: /tmp/ollama-serve.log)"
                OLLAMA_HOST=0.0.0.0:11434 nohup ollama serve >/tmp/ollama-serve.log 2>&1 &
                disown
                for i in (seq 20)
                    curl -sf --max-time 2 http://127.0.0.1:11434/api/version >/dev/null
                    and break
                    sleep 0.5
                end
                if not curl -sf --max-time 2 http://127.0.0.1:11434/api/version >/dev/null
                    __ollama_tailnet_say "ollama failed to start, see /tmp/ollama-serve.log" >&2
                    return 1
                end
            end

            # Serve config applied by containerboot on startup:
            # https://ollama.<tailnet>.ts.net -> host ollama.
            set -l cfgdir ~/.config/ollama-tailnet
            mkdir -p $cfgdir
            echo '{
  "TCP": { "443": { "HTTPS": true } },
  "Web": {
    "${TS_CERT_DOMAIN}:443": {
      "Handlers": { "/": { "Proxy": "http://host.docker.internal:11434" } }
    }
  }
}' >$cfgdir/serve.json

            # Replace any stale sidecar; node identity lives in the volume.
            docker rm -f $ctr >/dev/null 2>&1

            set -l authkey_args
            if set -q TS_AUTHKEY
                set authkey_args -e "TS_AUTHKEY=$TS_AUTHKEY"
            end

            docker run -d --rm --name $ctr \
                -e TS_HOSTNAME=ollama \
                -e TS_STATE_DIR=/var/lib/tailscale \
                -e TS_SERVE_CONFIG=/config/serve.json \
                $authkey_args \
                -v ts-ollama-state:/var/lib/tailscale \
                -v $cfgdir:/config \
                tailscale/tailscale >/dev/null
            or return

            # Wait for the node to come up, surfacing the login URL if needed.
            set -l state ""
            set -l shown_login false
            for i in (seq 120)
                set state (docker exec $ctr tailscale status --json 2>/dev/null | string match -rg '"BackendState":\s*"([^"]+)"')[1]
                test "$state" = Running
                and break
                if test "$state" = NeedsLogin; and test $shown_login = false
                    set -l url (docker logs $ctr 2>&1 | string match -r 'https://login\.tailscale\.com/\S+' | tail -1)
                    if test -n "$url"
                        __ollama_tailnet_say "one-time login needed: $url"
                        set shown_login true
                    end
                end
                sleep 1
            end
            if test "$state" != Running
                __ollama_tailnet_say "sidecar never came up (docker logs $ctr)" >&2
                docker rm -f $ctr >/dev/null 2>&1
                return 1
            end

            set -l suffix (docker exec $ctr tailscale status --json 2>/dev/null | string match -rg '"MagicDNSSuffix":\s*"([^"]+)"')[1]
            if test -n "$suffix"
                __ollama_tailnet_say "serving https://ollama.$suffix/v1 — ctrl-c to stop"
            else
                __ollama_tailnet_say "serving on tailnet node 'ollama' — ctrl-c to stop"
            end

            # Tear the sidecar down on ctrl-c, latte-style: fish fires the
            # SIGINT event when the foreground docker-wait dies, and function
            # execution unwinds, so cleanup lives in the handler.
            function __ollama_tailnet_sigint --on-signal SIGINT --inherit-variable ctr
                docker rm -f $ctr >/dev/null 2>&1
                set_color -o cyan
                echo -n "🦙 ollama"
                set_color normal
                echo " · proxy stopped (ollama still running locally — pkill -x ollama to stop it)"
                functions -e __ollama_tailnet_sigint
            end

            docker wait $ctr >/dev/null 2>&1
            if functions -q __ollama_tailnet_sigint
                functions -e __ollama_tailnet_sigint
                __ollama_tailnet_say "proxy stopped"
            end
        case down
            docker rm -f $ctr >/dev/null 2>&1
            __ollama_tailnet_say "proxy stopped (ollama still running locally — pkill -x ollama to stop it)"
        case status
            docker exec $ctr tailscale serve status
        case '*'
            __ollama_tailnet_say "usage: ollama_tailnet [up|down|status]" >&2
            return 1
    end
end
