function git
    set -l translated_argv
    set -l cmd $argv[1]
    if math (count $argv) '>' 1 >/dev/null
        set argv $argv[2..-1]
    else
        set argv
    end

    for arg in $argv
        if begin
            echo $arg | grep '^\d*$' >/dev/null ^&1
            and math $arg '<=' (count $c) >/dev/null
        end
            set translated_argv $translated_argv $c[$arg]
        ## TODO: elsif here for n..m format
        else
            set translated_argv $translated_argv $arg
        end
    end

    function __print_formatted_status
        set -l detect_label '^\s+[a-z ]*?:\s+'
        set -l status_output (command git status $translated_argv)
        set -l git_status_code $status
        # I'm gonna try and make this a state-machine.
        set -l state starting
        for line in $status_output
            switch $line
            case 'Changes to be committed*' # state-change indicator
                echo $line
                set state staged
            case 'Changes not staged for commit*' # state-change indicator
                echo $line
                set state unstaged
            case 'Untracked files*' # state-change indicator
                echo $line
                set state untracked
            case '  (use "*' # who needs these?? Not I
            case 'On branch*' '' 'Your branch is*' 'no changes added*' # unaffected by state and do not affect state
                echo $line
            case '*' # inspect state and do some magic
                # split the line into the label ("deleted", "modified",
                # etc.) and the filename. Untracked files don't have a label,
                # so just use the leading whitespace.
                set -l label
                set -l filename
                switch $state
                case staged unstaged
                    set label (echo $line | ack -o $detect_label)
                    set filename (echo $line | sed -E 's/'$detect_label'//')
                case untracked
                    set label (echo $line | ack -o '^\s+')
                    set filename (echo $line | sed -E 's/^\s+//')
                end

                set -l file_color
                switch $state
                case staged
                    set file_color green
                case unstaged
                    set file_color yellow
                case untracked
                    set file_color red
                end

                switch $label
                case '*renamed:*'
                    set -l old (echo $filename | sed 's/ -> .*//')
                    set -l new (echo $filename | sed 's/.* -> //')
                    echo -n $label'['(contains -i $old $c)'] '
                    set_color $file_color
                    echo -n $old
                    set_color normal
                    echo -n ' -> ['(contains -i $new $c)'] '
                    set_color $file_color
                    echo -n $new
                    set_color normal
                    echo ''
                case '*'
                    echo -n $label'['(contains -i $filename $c)'] '
                    set_color $file_color
                    echo -n $filename
                    set_color normal
                    echo ''
                end
            end
        end

        return $git_status_code
    end

    switch $cmd
    case 'status'
        acquire_git_changes
        __print_formatted_status
        return $status
    case '*'
        command git $cmd $translated_argv
        return $status
    end

end