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
                # OrbStack containers can reach the host's localhost, so Ollama
                # doesn't need to be exposed to the LAN.
                OLLAMA_HOST=127.0.0.1:11434 nohup ollama serve >/tmp/ollama-serve.log 2>&1 &
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

            set -l id (docker run -d --rm --name $ctr \
                -e TS_HOSTNAME=ollama \
                -e TS_STATE_DIR=/var/lib/tailscale \
                -e TS_SERVE_CONFIG=/config/serve.json \
                $authkey_args \
                -v ts-ollama-state:/var/lib/tailscale \
                -v $cfgdir:/config \
                $image)
            or return

            # Ctrl-c goes to the foreground process, not to fish, so a fish
            # signal handler would never run. Instead, docker attach stays in
            # the foreground from the start and forwards ctrl-c to the
            # container, which exits and is removed by --rm. The startup
            # checks run in a separate background process meanwhile.
            # Everything uses the container ID, not the name, so a second
            # `up` in another terminal can't be removed by this one's cleanup.
            fish --no-config -c 'source $argv[1]; ollama_tailnet __wait $argv[2]' \
                (functions --details ollama_tailnet) $id &
            set -l waiter $last_pid
            disown $waiter

            docker attach --sig-proxy=true $id >/dev/null 2>&1
            kill $waiter 2>/dev/null
            docker rm -f $id >/dev/null 2>&1
            __ollama_tailnet_say "proxy stopped (ollama still running locally — pkill -x ollama to stop it)"
        case __wait
            # Internal: startup checks for `up`, given the container ID. On
            # failure, removing the container ends `up`'s docker attach.
            set -l id $argv[2]
            if test -z "$id"
                __ollama_tailnet_say "__wait is internal to ollama_tailnet up" >&2
                return 1
            end

            function __ollama_tailnet_fail -S -a msg
                __ollama_tailnet_say $msg >&2
                docker logs --tail 5 $id 2>&1 | sed 's/^/    /' >&2
                docker rm -f $id >/dev/null 2>&1
            end

            set -l state ""
            set -l shown_login false
            for i in (seq 120)
                set state (docker exec $id tailscale status --json 2>/dev/null | string match -rg '"BackendState":\s*"([^"]+)"')[1]
                test "$state" = Running
                and break
                if test "$state" = NeedsLogin; and test $shown_login = false
                    set -l url (docker logs $id 2>&1 | string match -r 'https://login\.tailscale\.com/\S+' | tail -1)
                    if test -n "$url"
                        __ollama_tailnet_say "one-time login needed: $url"
                        set shown_login true
                    end
                end
                sleep 1
            end
            if test "$state" != Running
                __ollama_tailnet_fail "container never came up. Last log lines:"
                return 1
            end

            # CertDomains is null, not missing, when HTTPS is disabled.
            set -l self (docker exec $id tailscale status --json --peers=false 2>/dev/null | string collect)
            if not string match -rq '"CertDomains":\s*\[\s*"' -- $self
                __ollama_tailnet_fail "HTTPS certificates are off for this tailnet. Enable them in the Tailscale admin console (DNS page), then rerun."
                return 1
            end

            set -l served false
            for i in (seq 10)
                if docker exec $id tailscale serve status --json 2>/dev/null | string match -q '*"Web"*'
                    set served true
                    break
                end
                sleep 1
            end
            if test $served = false
                __ollama_tailnet_fail "serve config was not applied. Last log lines:"
                return 1
            end

            # Tailscale renames the node (e.g. ollama-1) if "ollama" is taken.
            set -l dns (string match -rg '"DNSName":\s*"([^"]+?)\.?"' -- $self)[1]
            __ollama_tailnet_say "serving https://$dns/v1 — ctrl-c to stop"
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
