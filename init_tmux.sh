#!/bin/bash

IFS_orig=${IFS}

run_cmd()
{
    cmd="$1"

    IFS=';'
    i=0
    for c in $cmd
    do
        tmux selectp -t $i
        [ "${c:0:4}" == tmux ] && sh -c "$c -t "$SESSION:"" \
        || sh -c "tmux send-keys -t "$SESSION:" $c"

        let i++
    done
    IFS=${IFS_orig}

    tmux selectp -t 0
}

layout()
{
    layout="$1"

    IFS=';'
    for l in $layout
    do
        unset hv percent
        hv=`cut -sd= -f 1 <<< "$l"`
        percent=`cut -sd= -f 2 <<< "$l"`

        [ -n "$percent" ] && p="-p $percent" || unset p

        if [ "$hv" == '|' ]; then
            tmux splitw -h $p -t $SESSION:
        elif [ "$hv" == '-' ]; then
            tmux splitw -v $p -t $SESSION:
        fi
    done
    IFS=${IFS_orig}
}

init()
{
    local has_session="no"

    for wi in "${!WINDOWS[@]}"
    do
        w="${WINDOWS[$wi]}"
        [ "$has_session" == "no" ] && tmux new -s "$SESSION" -n "$w" -d \
        || tmux neww -n "$w" -t "$SESSION":
        has_session="yes"

        layout "${LAYOUT[$wi]}"

        run_cmd "${COMMAND[$wi]}"
    done

    tmux selectw -t 0
}

get_session_name()
{
    SESSION="main"

    if head -n1 $CONFIG_FILE | grep -q '\[.*\]'; then
        SESSION=`head -n1 $CONFIG_FILE | grep -o '\[.*\]'`

        SESSION=${SESSION%]}
        SESSION=${SESSION#[}
    fi
}

get_config_file()
{
    for CONFIG_FILE in {.,$HOME}/{,.}init_tmux.config
    do
	[ -f "$CONFIG_FILE" ] && return 0
    done

    return 1
}

get_config()
{
    get_config_file || return 1

    get_session_name

    if head -n1 $CONFIG_FILE | grep -q '\[.*\]'; then
        sed '1d' $CONFIG_FILE | tr -s ' ' > /tmp/$CONFIG_FILE.$$
    else
        tr -s ' ' < $CONFIG_FILE > /tmp/$CONFIG_FILE.$$
    fi

    IFS=$'\n'
    i=0
    for w in `awk -F ' : ' '{print $1}' /tmp/$CONFIG_FILE.$$`
    do
        WINDOWS[$i]="$w"
        let i++
    done

    i=0
    for l in `awk -F ' : ' '{print $2}' /tmp/$CONFIG_FILE.$$`
    do
        LAYOUT[$i]="$l"
        let i++
    done

    i=0
    for c in `awk -F ' : ' '{print $3}' /tmp/$CONFIG_FILE.$$`
    do
        COMMAND[$i]="$c"
        let i++
    done
    IFS=${IFS_orig}

    rm /tmp/$CONFIG_FILE.$$
}


get_config
if [[ $? -ne 0 ]]; then
    echo "Can not get config file or bad config file"
    exit
fi

tmux has-session -t $SESSION 2> /dev/null
HAS_SESSION="$?"

if [[ $# -gt 0 ]]
then
    arg=$1

    case $arg in
        "status") tmux ls ; exit
        ;;
        "exit")
        [ "$HAS_SESSION" -eq 0 ] && tmux kill-session -t $SESSION \
        || echo "No such session"
        exit
        ;;
    esac
fi

[ $HAS_SESSION -ne 0 ] && init

tmux has-session -t $SESSION 2> /dev/null \
&& tmux at -t $SESSION
