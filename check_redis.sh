#!/bin/bash
#
#title              : check_redis.sh
#author             : Levent Yalcin <leventyalcin [a] gmail com>
#date               : 20140910
#description        : Nagios check for redis

for arg
do
    delim=""
    case "$arg" in
    #translate --gnu-long-options to -g (short options)
        --host) args="${args}-H ";;
        --port) args="${args}-P ";;
        --critical) args="${args}-c ";;
        --warning) args="${args}-w ";;
        --password) args="${args}-p ";;
        --socket) args="${args}-s ";;
        --mem-warn) args="${args}-m ";;
        --mem-crit) args="${args}-M ";;
        #pass through anything else
        *) [[ "${arg:0:1}" == "-" ]] || delim="\""
            args="${args}${delim}${arg}${delim} ";;
    esac
done
 
#Reset the positional parameters to the short options
eval set -- $args
 
while getopts ":H::w::c:P:p:s:m:M:" option 2>/dev/null
do
    case $option in
        H)
            readonly HOST="${OPTARG}"
        ;;
        P)
            PORT="${OPTARG}"
        ;;
        w)
            readonly WARN="${OPTARG}"
        ;;
        c)
            readonly CRIT="${OPTARG}"
        ;;
        p)
            readonly PASSWORD="${OPTARG}"
        ;;
        s)
            readonly SOCKET="${OPTARG}"
        ;;
        m)
            readonly MEM_WARN="${OPTARG}"
        ;;
        M)
            readonly MEM_CRIT="${OPTARG}"
        ;;
        \?) 
            echo "Invalid option: -$OPTARG" 
            exit 3
        ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 3
        ;;
        *) 
            echo $OPTARG is an unrecognized option
            exit 3
        ;;
    esac
done

function usage (){
    echo "$0 
        -H Hostname 
        -P Port 
        -s Socket
        -p Password
        -c Crital (connected clients) 
        -w Warning (connected clients)
        -M Critical (memory bytes)
        -m Warning (memory bytes)"
    exit 3
}

function crit(){
    echo $1
    exit 2
}
function warn(){
    echo $1
    exit 1
}
function unknown(){
    echo $1
    exit 3
}
function ok(){
    echo $1
    exit 0
}

[ -z $HOST ] && usage 
REDIS_CMD="redis-cli -h ${HOST}"
[ -n "${PORT}" ] && REDIS_CMD="${REDIS_CMD} -p ${PORT}"
[ -n $PASSWORD ] && REDIS_CMD="${REDIS_CMD} -a ${PASSWORD}"
# socket overrides hostname and port
[ -n $SOCKET ] && REDIS_CMD="${REDIS_CMD} -s ${SOCKET}"

METRICS="uptime_in_days|connected_clients|blocked_clients|used_memory|used_memory_peak|used_memory_rss|mem_fragmentation_ratio"
METRICS="${METRICS}|total_connections_received|total_commands_processed|rejected_connections"

STATS=$(echo 'INFO' | $REDIS_CMD 2>/dev/null)
CONN=$(echo "${STATS}" | grep connected_clients | cut  -d ':' -f 2 | sed -e 's/\r//g')
MEM=$(echo "${STATS}" | grep used_memory | cut  -d ':' -f 2 | sed -e 's/\r//g')
VAL=$(echo "${STATS}" | egrep "${METRICS}" | tr ':' '=' | tr '\n' '; '| sed -e 's/\r//g')

[ -z "${STATS}" ] && crit "Redis inaccessible"
[ -n "${CRIT}" ] && [ $CONN -gt $CRIT ] && crit "Redis connections - ${CONN}>${CRIT}"
[ -n "${MEM_CRIT}" ] && [ $MEM -gt $MEM_CRIT ] && crit "Redis memory usage ${MEM}>${MEM_CRIT}"
[ -n "${WARN}" ] && [ $CONN -gt $WARN ] && warn "Redis connections - ${CONN}>${WARN}" 
[ -n "${MEM_WARN}" ] && [ $MEM -gt $MEM_WARN ] && warn "Redis memory usage ${MEM}>${MEM_WARN}"

ok "OK - | ${VAL}" 

