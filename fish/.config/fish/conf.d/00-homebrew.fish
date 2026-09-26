if command -q brew
    brew shellenv fish | source
else
    for brew_path in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew
        if test -x $brew_path
            $brew_path shellenv fish | source
            break
        end
    end
end
