#!/bin/bash
cd `dirname $0`

BOT_NICK="echobot"
KEY="$(cat ./config.txt)"

nanos=1000000000
interval=$(( $nanos * 50 / 100 ))
declare -i prevdate
prevdate=0

#TODO place this fuction between tail -f and openssl
#for this bot it's not needed
function send {
    while read -r line; do
      newdate=`date +%s%N`
      if [ $prevdate -gt $newdate ]; then sleep `bc -l <<< "($prevdate - $newdate) / $nanos"`; newdate=`date +%s%N`; fi
      prevdate=$newdate+$interval
      echo "-> $1"
      echo "$line" >> ${BOT_NICK}.io
    done <<< "$1"
}

nickCheckInterval=600 #seconds
nextNickCheck=$((`date +%s` + $nickCheckInterval))
allNicks=""
export NICKS_SED=""

rm ${BOT_NICK}.io
mkfifo ${BOT_NICK}.io
tail -f ${BOT_NICK}.io | openssl s_client -connect irc.cat.pdx.edu:6697 | while [[ -z "$started" ]] || read -r irc ; do
    if [[ -z "$started" ]] ; then
        send "NICK $BOT_NICK" 
        send "USER 0 0 0 :$BOT_NICK"
        send "JOIN #robots $KEY"
        started="yes"
        read -r irc
    fi
    if <<<"$irc" cut -d ' ' -f 1 | grep -q "PING" ; then
        send "PONG"
        date=`date +%s`
        if [ $nextNickCheck -lt $date ]; then allNicks=""; send "NAMES #robots"; nextNickCheck=$(($date + $nickCheckInterval)); fi 
    elif <<<"$irc" cut -d ' ' -f 2 | grep -q "PRIVMSG" ; then 
#:nick!user@host.cat.pdx.edu PRIVMSG #bots :This is what an IRC protocol PRIVMSG looks like!
        nick="$(<<<"$irc" cut -d ':' -f 2- | cut -d '!' -f 1)"
        chan="$(<<<"$irc" cut -d ' ' -f 3)"
        if [ "$chan" = "$BOT_NICK" ] ; then chan="$nick" ; fi 
        msg="$(<<<"$irc" cut -d ' ' -f 4- | cut -c 2- | tr -d "\r\n")"
        echo "$(date) | $chan <$nick>: $msg"
        var="$(echo "$nick" "$chan" "$BOT_NICK" "$msg" | ./commands.sh)"
        if [ ! -z "$var" ] ; then
            send "$var"
        fi
    elif <<<"$irc" cut -d ":" -f 2 | grep -q "353" ; then
#:iss.cat.pdx.edu 353 irctest @ #robots :irctest uelen28 Apollo el_seano +zb bloc sten1ai spooklozgne +videocats gilben mensi Nascha manta +mathbot uelen...
      allNicks="$allNicks $(echo -n "$irc" | cut -d ':' -f 3- | tr -d "\r\n+@")"
    elif <<<"$irc" cut -d ":" -f 2 | grep -q "366" ; then
#End of nicks list
      echo "Got nicks $allNicks"
      NICKS_SED=$(for nick in $allNicks; do echo "s/$nick/$(<<<$nick tr 'aeiostl' '43105+|')/gI"; done)
      #echo "Nicks sed: `<<<"$NICKS_SED" tr '\n' ';'`"
    
    fi
done
