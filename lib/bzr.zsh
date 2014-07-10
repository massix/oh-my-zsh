## Bazaar integration
## Just works with the GIT integration just add $(bzr_prompt_info) to the PROMPT
function bzr_prompt_info() {
  while [[ ${PWD} != "/" ]]; do
    if [[ -d ".bzr" ]]; then
      BZR_CB=`cat .bzr/branch/branch.conf | grep bound_location | awk -F / '{print $9}'`
      if [[ "x${BZR_CB}" == "x" ]]; then
        BZR_CB="unknown branch"
      fi
      BZR_CB="bzr::${BZR_CB}"
      [[ -n `bzr status` ]] && BZR_DIRTY="%{$fg[red]%} ·%{$fg[blue]%}"
      echo "$ZSH_THEME_GIT_PROMPT_PREFIX$BZR_CB$BZR_DIRTY$ZSH_THEME_GIT_PROMPT_SUFFIX"
      break;
    fi

    cd ..

  done
}
