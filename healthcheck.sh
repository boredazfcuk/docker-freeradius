#!/bin/bash

if [ "$(netstat -plnu4 | grep -c 0.0.0.0:1812)" -ne 1 ]; then
   echo "Freeradius not listening on port 1812"
   exit 1
fi

if [ "$(hostname -i 2>/dev/null | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | wc -l)" -eq 0 ]; then
   echo "NIC missing"
   exit 1
fi

echo "Freeradius listening on port 1812"
exit 0