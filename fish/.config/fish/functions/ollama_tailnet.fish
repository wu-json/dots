# Serves the host's Ollama at https://ollama.<tailnet>.ts.net. A Tailscale
# container joins the tailnet as its own "ollama" node and proxies to the host.
# Its login is saved in the ts-ollama-state volume, so you only log in once.
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

            # The container applies this on startup: HTTPS on 443 -> host Ollama.
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

            # Docker never updates :latest on its own. If the pull fails
            # (e.g. offline), the cached image is used.
            set -l image tailscale/tailscale:latest
            __ollama_tailnet_say "checking for tailscale image updates"
            if not docker pull --quiet $image >/dev/null 2>&1
                __ollama_tailnet_say "pull failed, using cached image" >&2
            end

            # Safe to replace: the node's identity lives in the volume.
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
                $image >/dev/null
            or return

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

            # Ctrl-c goes to the foreground process, not to fish, so a fish
            # signal handler would never run. docker attach forwards it to the
            # container, which exits and is removed by --rm.
            docker attach --sig-proxy=true $ctr >/dev/null 2>&1
            docker rm -f $ctr >/dev/null 2>&1
            __ollama_tailnet_say "proxy stopped (ollama still running locally — pkill -x ollama to stop it)"
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
