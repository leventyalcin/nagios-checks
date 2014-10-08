#!/bin/bash
#
#title              : check_phpfpm_socket_health.sh
#author             : Levent Yalcin <leventyalcin [a] gmail com>
#date               : 20140711
#description        : Nagios check for php-fpm sockets

POOLD="$1"
: ${POOLD:="/etc/php5/fpm/pool.d"}

ERR_SOCKET=""
SOCKETS=0

for i in $(ls -1 ${POOLD}/*.conf 2>/dev/null); do
    SOCKET_FILE=$(sed -n 's/.*listen *= *\([^ ]*.*\)/\1/p' "${i}")
    if  [ -n "${SOCKET_FILE}" ] && \
        [ $(echo /dev/null | socat UNIX:$SOCKET_FILE - 2>/dev/null) ]
    then
        ERR_SOCKET="${ERR_SOCKET} ${i}"
    fi
    [ -n "${SOCKET_FILE}" ] && let SOCKETS+=1
done

if [ -n "$ERR_SOCKET" ]; then 
    echo "CRITICAL - Failed socket(s) : ${i}"
    exit 2
elif [ $SOCKETS -eq 0 ]; then
    echo "WARNING - There is no defined socket under ${POOLD}"
    exit 1
else
    echo "OK - All (${SOCKETS}) sockets seem happy"
    exit 0
fi
