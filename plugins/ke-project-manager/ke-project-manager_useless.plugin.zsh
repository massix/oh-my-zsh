#####################################################################
# KE Project Manager                                                #
# Just a handy plugin for oh-my-zsh to use at work                  #
# Copyright 2014 Massimo Gengarelli <mgengarelli.ext@orange.com>    #
#####################################################################

function naughty_notifier()
{
  if test $NAUGHTY_NOTIFIER_ENABLED -eq 0; then
    return;
  fi

  # Only run this if we're under awesome wm
  local text=$1
  if which awesome-client > /dev/null; then
    if pgrep awesome > /dev/null; then
      echo "naughty.notify({ text = \"$text\", timeout = 10 })" | $(which awesome-client)
    fi
  fi
}

function infinite_fortune()
{
  local prev_fortune next_fortune r
  local reload
  next_fortune=$(fortune $@)
  prev_fortune=$next_fortune

  reload=1
  while true; do
    unset r
    clear
    if [[ $reload -eq 2 ]]; then
      prev_fortune=$next_fortune
      next_fortune=$(fortune $@)
      echo $next_fortune
    elif [[ $reload -eq 1 ]]; then
      echo $next_fortune
      reload=2
    else
      echo $prev_fortune
      reload=1
    fi

    read -q -t60 r
    case $r in
      q)
        break
        ;;
      p)
        reload=0
        ;;
      c)
        clear   # Panic mode, boss incoming.
        htop
        reload=0
        ;;
    esac
  done
}

## Start the SSH agent
function start_agent()
{
  local agent_env=${HOME}/.ssh/environment
  if [[ "x$1" == "xforce" ]]; then
    rm -f ${agent_env}
    killall -9 ssh-agent
  fi

  if [[ -e ${agent_env} ]]; then
    . ${agent_env} &> /dev/null
    if ! test -e $SSH_AUTH_SOCK; then
      start_agent force
      return
    fi
    ssh-add &> /dev/null
    ssh-add ${HOME}/.ssh/id_rsa_kedev &> /dev/null
  else
    ssh-agent > ${agent_env}
    chmod 0600 ${agent_env}
    start_agent
  fi
}
