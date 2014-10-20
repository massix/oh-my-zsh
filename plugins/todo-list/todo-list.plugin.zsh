#!/bin/zsh

local tdl_command=$(which hali)
local tdl_db=${HOME}/Dropbox/todo.bin

local tdl_personal_db=${HOME}/Dropbox/personal.bin
local tdl_work_db=${HOME}/Dropbox/work.bin
local tdl_generic_db=${HOME}/Dropbox/todo.bin
local tdl_todo_list_db=${HOME}/Dropbox/todo-list.bin

function personal_todo() {
  local action=""
  if [[ $1 == "" ]]; then
    action="list"
  fi

  $tdl_command $action $@ --tododb $tdl_personal_db
}

function work_todo() {
  local action=""
  if [[ $1 == "" ]]; then
    action="list"
  fi

  $tdl_command $action $@ --tododb $tdl_work_db
}

function generic_todo() {
  local action=""
  if [[ $1 == "" ]]; then
    action="list"
  fi

  $tdl_command $action $@ --tododb $tdl_generic_db
}

function todo_todo() {
  local action=""
  if [[ $1 == "" ]]; then
    action="list"
  fi

  $tdl_command $action $@ --tododb $tdl_todo_list_db
}

alias ptdl=personal_todo
alias wtdl=work_todo
alias tdl=generic_todo
alias ttdl=todo_todo
