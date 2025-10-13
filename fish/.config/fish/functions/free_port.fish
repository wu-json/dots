function free_port
    kill -9 $(lsof -ti:$argv)
end
