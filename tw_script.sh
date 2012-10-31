#!/bin/bash
### NOTE: Our password in this file is "qwertyuiop".  Change it to what it's supposed to be.

## MAKE THIS DIRECTORY!  I just put it in my home directory, but I guess you can put it wherever you are going to be running this from.
TWLOGDIR="twlogs"; # No Trailing Slash

function rdo() { ssh -T "$1".myhostcenter.com \ "sudo su - root" ; }

## Starts a named Screen session "TW" on all servers that have 'tw' as red or yellow
function tw_all()
{
  ## I use a PHP script to get a list of servers that have "red" or "yellow" TW status.  You can use it if you want, or script your own BASH one like Randall has. =D
  servers=`/home/jalbanese/get_bb.php tw 0 "$@"` ;
  if [ $servers = '0' ]; then
    echo "# No *.myhostcenter.com servers have 'tw' alerts" ;
  else
    echo "# Doing TW Stuff on:" ;
    echo "# $servers" ;
    for i in $servers ; do tw_do $i ; done ;
  fi
}

## Outputs running tw procs.
function tw_running()
{
  TWPID=$(echo "ps aux | egrep 'twCheck|twConf'" | rdo $1 | grep -v egrep | awk '{print $2}');
  if [[ $TWPID > 1 ]]; then echo "1"; else echo "0"; fi;
}

## Checks to see if a Screen session named TW exists on a server.
function tw_scr_exists()
{
  ACTIVESCREENS=$(echo "screen -ls | head -n -2 | awk 'NR>1 {print \$1}'" | rdo $1 | tr '.' ' ' | awk '{print $2}') ;
  SCR_FOUND="0"; for i in $ACTIVESCREENS; do if [[ "$i" == "TW" ]]; then SCR_FOUND="1" ; fi ; done ;
  echo "$SCR_FOUND" ;
}

## Starts a named Screen session "TW" on a specified server unless it already exists
## Starts TripWire in the "TW" Screen if TW is not already running
function tw_init()
{
  if [[ "$(tw_scr_exists $1)" == "0" ]]; then echo "### -- Creating Screen \"TW\"" ; echo "screen -dm -S TW -t TW" | rdo $1 ; fi ;
  if [[ "$(tw_running $1)" == "0" ]]; then tw_start $1 ; fi ;
}

## Sends the Check and Confirm commands to a specified server for the TW named screen
function tw_start()
{
  SOMETHING="1";
  echo "### -- Starting Tripwire Check and Confirm" ;
  echo 'screen -S TW -p 0 -X stuff "twCheck.sh && twConfirm.sh
"' | rdo $1 ;
}

## Checks to see if the TW screen on the specified server has vi open.
## -- Uses "hardcopy" screen command to create a file, check the first line of that file, then delete the file.
function tw_vi_check()
{
  echo 'screen -S TW -p 0 -X hardcopy vi_check' | rdo $1 ;
  CONTENTS=$(echo "head -n1 vi_check" | rdo $1);
  NEEDLE="Tripwire(R)" ;
  if [[ $CONTENTS == *"$NEEDLE"* ]]; then echo "1" ; else echo "0" ; fi ;
  echo 'rm -f vi_check' | rdo $1 ;
}

## If vi is displayed, show command for quitting
function tw_check_proceed() { if [[ $(tw_vi_check $1) == "1" ]]; then tw_proceed $1 ; fi ; }

## Quits vi in the TW screen on a specified server
function tw_proceed()
{
  SOMETHING="1";
  echo "### -- twConfirm.sh has finished running." ;
  tw_log $1 ;
  echo "### -- Quitting vi and acknowledging changes." ;
  echo "screen -S TW -p 0 -X stuff $':q!\n'" | rdo $1 ;
  sleep 5 ;
  if [[ $i == cp38 ]] ; then sleep 3 ; fi ; ## cp38 sometimes takes a while -- sleep some extra
  if [[ $i == cp39 ]] ; then sleep 3 ; fi ; ## cp39 same as cp38
  if [[ $i == cpanel* ]] ; then sleep 10 ; fi ; ## Sleep extra long for cpanel servers.
  echo "screen -S TW -p 0 -X stuff $'qwertyuiop\n'" | rdo $1 ;
}

## Takes the exiting TW File from Temp, downloads it to your home directory, and changes the name.
## Note: Adds read permission to log file on server, but then removes that permission.
function tw_log()
{
  ### Get newest log file, in case there is more than one (as is true on some servers)
  TMPFILE=$(echo "ls -t /tmp | grep twtemp | head -1" | rdo $1);
  ### Make it downloadable by anyone, download it, restore it back to root only.
  echo "chmod o+r /tmp/$TMPFILE ;" | rdo $1 && scp $1.myhostcenter.com:/tmp/$TMPFILE $TWLOGDIR"/" && echo "chmod o-r /tmp/$TMPFILE" | rdo $1 ;
  ### Rename it
  TSTAMP=$(date | awk '{printf "%s.%s.%s_%s",$6,$2,$3,$4}' | sed 's/:/_/g')
  mv $TWLOGDIR"/"$TMPFILE $TWLOGDIR"/"$1"_"$TSTAMP".tw.log" ;
  ### And we're done
  echo "### -- Log saved to your log directory as "$1"_"$TSTAMP".tw.log" ;
}

function tw_do()
{
  SOMETHING="0";
  echo "### $1:" ;
  tw_init $1 ;
  tw_check_proceed $1 ;
  if [[ $SOMETHING == "0" ]] ; then echo "### -- TW Still Running..." ; fi ;
}

### qic == Quick Log Check
### Greps out the lines beginning with [*] so that you can see what was modified, and investigate further if necessary.
function tw_qlc()
{
  MAX_TVS=10; ## Change this if you want to display files that have more than 10 violations.
  for file in $(ls -d $TWLOGDIR/*) ;
  do
    SVR=$(echo "$file" | sed -E 's/^(.+)_201[2-9]\..+$/\1/'); ## sed's the server name out of the file name
    TVS=$(cat $file | grep 'Total violations found:' | awk '{print $NF}'); ## awk's the number of violations from the file
    echo "## $file -- Total: $TVS" ;
    if [ $TVS -gt $MAX_TVS ] ;
    then
      echo "Omitting Violation List -- too large.  See file." ;
    else 
      cat $file | grep '^\[x\]';
    fi ;
  done ;
}

