function tabby_up
    tabby serve \
        --device metal \
        --model StarCoder-1B \
        --chat-model Qwen2-1.5B-Instruct \
        --port 8085
end
