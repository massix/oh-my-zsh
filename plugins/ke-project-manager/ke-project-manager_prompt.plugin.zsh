#####################################################################
# KE Project Manager                                                #
# Just a handy plugin for oh-my-zsh to use at work                  #
# Copyright 2014 Massimo Gengarelli <mgengarelli.ext@orange.com>    #
#####################################################################

function ke_prompt_info_cp() {
  if [[ $COMPILPATHACTIVE -eq 1 ]]; then
    echo "$ZSH_THEME_KE_PROMPT_PREFIX%{$fg[red]%}cp$ZSH_THEME_KE_PROMPT_SUFFIX "
  fi
}

function ke_prompt_info_branch() {
  if [[ "x${BRANCH_NAME}" != "x" ]]; then
    echo "$ZSH_THEME_KE_PROMPT_PREFIX%{$fg[red]%}$BRANCH_NAME$ZSH_THEME_KE_PROMPT_SUFFIX "
  fi
}

function ke_prompt_info_opinel() {
  local opinel_file=${PROJECT_ROOT}/ke-search/.bzr/opinel_env
  if [[ -f ${opinel_file} ]]; then
    echo "$ZSH_THEME_KE_OPI_PROMPT_PREFIX%{$fg[red]%}$(cat $opinel_file)$ZSH_THEME_KE_OPI_PROMPT_SUFFIX "
  fi
}


