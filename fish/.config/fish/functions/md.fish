function md --description "Open a markdown file in a pretty terminal reader"
    if not command -q glow
        echo "glow is not installed. Run: brew install glow" >&2
        return 1
    end
    glow --pager $argv
end
