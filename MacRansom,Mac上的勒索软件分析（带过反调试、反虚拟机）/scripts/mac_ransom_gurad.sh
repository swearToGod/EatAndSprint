#!/bin/bash
# Program:
#   mac ransom guard
# History:
#   2017/08/19  Kiba    First release


# Files
MALWARE=~/Library/.FS_Store
PLIST=~/Library/LaunchAgents/com.apple.finder.plist

# Ransom software file and process check
function RansomCheck
{
    launchctl remove com.apple.finder
    [ -e "${MALWARE}" ] && echo "Backup ${MALWARE} to ${MALWARE}.bk" && mv -f ${MALWARE} ${MALWARE}.bk 
    [ -e "${PLIST}" ] && echo "Backup ${PLIST} to ${PLIST}.bk" && mv -f ${PLIST} ${PLIST}.bk
    pgrep -x .FS_Store && echo "killall .FS_Store" && killall -9 -v .FS_Store
}

echo "Hit CTRL+C to stop"
while :
do
    RansomCheck
    sleep 1
done
