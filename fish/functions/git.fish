function git
    # intercept: git commit -ai → ai-commit-message
    if test (count $argv) -ge 2 && test "$argv[1]" = commit
        for arg in $argv
            if test "$arg" = -ai || test "$arg" = --ai
                ai-commit-message --timing --http
                return
            end
        end
    end

    command git $argv
end
