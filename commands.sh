#!/bin/bash
read -r nick chan BOT_NICK msg 
function count {
  pgrep -c -u griffins sleepecho.sh
}

target_chan="#robots"
odds=$((16 + 4 * `count`))
sleep_scale=1800 # 30 min
sleep_min=1 #30 min
sleep_add=40 #20 hr
min_len=24
max_len=200
ignore='^(!|%|\+|m[aeiou]th|infoobot|remind me|zb )'
ignorenick="^(zb|icinga|jackson|notify)"
interesting="(`tr '\n' '|' < interesting.txt | sed 's/|$//'`)"
caps="[A-Z]{4}"

#DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
#BOT_NICK="$(grep -P "BOT_NICK=.*" ${DIR}/bot.sh | cut -d '=' -f 2- | tr -d '"')"

function debug {
  echo "$@" 1>&2
}

function say { 
  echo "PRIVMSG $chan :$1" > ${BOT_NICK}.io
}

priv=1

if [ "$chan" = "$BOT_NICK" ] ; then chan="$nick";priv=0 ; fi

run() {
  output=`<<<$1 sed "$NICKS_SED"`
  time=$(( ( $RANDOM % $sleep_add + $sleep_min ) * $sleep_scale ))
  debug "will echo in $time s: $output"
  if grep -qiP "\001ACTION" <<<"$1"; then
    output="$output"
  else
    output="...$output"
  fi
  ./sleepecho.sh $time "PRIVMSG $target_chan :$output" > ${BOT_NICK}.io &
}

name="echo(bot)?"


runCmd() {
  case "`<<<"$1" tr '[:upper:]' '[:lower:]'`" in
    ""|help) say "Echobot." ;;
    ignore) say "I ignore messages with /$ignore/ and nicks with /$ignorenick/" ;;
    waiting) say `count` ;;
    clear) say "Clearing `count`"; pkill -u griffins sleepecho.sh ;;
    restart) screen -r echobot -X kill ;;
    source) say "https://github.com/gstone271/echobot" ;;
   # *) say "$nick: Unrecognized command $cmd" ;;
    *) say "$msg" ;;
  esac
}

if grep -qiP "^${name}_[a-zA-Z]" <<<"$msg"; then
  runCmd `cut -d '_' -f 2- <<<"$msg" | cut -d ' ' -f 1`

elif grep -qiP "^!${name} " <<<"$msg"; then
  runCmd "`cut -d ' ' -f 2- <<<"$msg"`"

elif grep -qiP "^!${name}" <<<"$msg"; then
  runCmd ""

else
  summon=0;
  if grep -qiP "^${name} " <<<"$msg"; then 
    debug "Summoned"
    summon=1
    msg=`cut -d ' ' -f 2- <<<"$msg"`
    odds=$(($odds / 4))
  fi
  if [ $summon -eq 1 ] || [ ${#msg} -ge $min_len -a ${#msg} -le $max_len ] && grep -qiP -v "$ignore" <<<"$msg" && grep -qiP -v "$ignorenick" <<<"$nick"; then
    debug "valid: $msg"
    if grep -qP "$caps" <<<"$msg" || grep -qiP "$interesting" <<<"$msg"; then
      debug "Interesting `grep -iP --color=always "$interesting" <<<"$msg"`"
      odds=$(($odds / 2))
    fi
    if [ $(( $RANDOM % $odds)) -eq 0 ]; then
      run "$msg"
    fi
  fi
fi
