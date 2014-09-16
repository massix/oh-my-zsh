#!/bin/zsh

local tdl_command=~/bin/todo

function tdl() {
  local command=$1

  if ! test -x $tdl_command; then
    echo "install in ~/bin/todo"
    return 127
  fi

  if test -z $command; then
    ~/bin/todo count
    ~/bin/todo list
    return 0
  fi

  shift

  local params="$*"

  case $command in
    add|a) 
      $tdl_command insert "${params}"
      ;;
    addbody|ab)
      $tdl_command insert "$1" "$2"
      ;;
    del|d)
      $tdl_command delete ${params}
      ;;
    modify|m)
      local index=$1
      shift
      $tdl_command modify $index "$*"
      ;;
    modifybody|mb)
      local index=$1
      shift
      $tdl_command modify $index "$1" "$2"
      ;;
    *)
      echo "usage: $0 [add|addbody|del|modify|modifybody] <parameters>"
      ;;
  esac
}

tdl
