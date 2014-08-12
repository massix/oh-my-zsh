## Some useful functions I wrote to ease up my daily routines

COMPILPATHACTIVE=0
ENVIRONMENT_FILE=${HOME}/bin/var_env_toolchain.sh
NOCOMPILPATH=${PATH}
AGENT_ENV=${HOME}/.ssh/environment
export LOGGER_BIN=$(which logger)

## Activate the compilation path
function activate_compilation_path() 
{
  [[ ${COMPILPATHACTIVE} -eq 0 ]] && . ${ENVIRONMENT_FILE}
  export COMPILPATHACTIVE=1
  export RPS1="compilation path"
}

## Deactivate the compilation path
function deactivate_compilation_path()
{
  export PATH=${NOCOMPILPATH}
  export COMPILPATHACTIVE=0
  unset RPS1
}

## Bootstrap a component found in the project root
function bootstrap_component()
{
  export BRANCH_NAME=$(basename $(dirname $PWD))
  local GRANDPARENT COMMON_INCLUDE

  local DBG=''
  local PARENT=$(dirname $PWD)
  local YCM_TEMPLATE=${HOME}/.vim/bundle/YouCompleteMe/cpp/ycm/.ycm_extra_conf.py.in
  local CLANG_TAGS=${HOME}/dev/clang-tags/build/env.sh

  deactivate_compilation_path

  if [[ "x$1" == "x" ]]; then
    echo "Missing branch name"
    return
  elif [[ "x$1" != "x${BRANCH_NAME}" ]]; then
    echo "Branch name : ${BRANCH_NAME} differs from $1"
    return
  fi

  ${LOGGER_BIN} -t "bootstrap_component()" Bootstrapping for ${BRANCH_NAME}

  if [[ -e "${PWD}/bootstrap.sh" ]]; then
    ./bootstrap.sh \
      --toolchain-dir=/ke/local/toolchain3-x86_64-nptl \
      --kemake-dir=${PARENT}/ke-kemake || return
  else
    echo "Missing ./bootstrap.sh"
    return
  fi

  if [[ "x${DEBUG}" != "x" ]]; then
    DBG="--enable-debug"
    echo "Debug activated (passing flag ${DBG})"
    ${LOGGER_BIN} -t "bootstrap_component()" Using ${DBG}
  fi

  activate_compilation_path
  RPS1="$RPS1:$BRANCH_NAME"

  take .release
  GRANDPARENT=$(dirname $(dirname $PWD))

  $(dirname $PWD)/configure --with-toolchain-dir=/ke/local/toolchain3-x86_64-nptl --with-kemake-dir=${GRANDPARENT}/ke-kemake --with-common-lib=${GRANDPARENT}/ke-common/.release --with-common-include=${GRANDPARENT}/ke-common ${DBG}

  COMMON_INCLUDE=$(cat Makefile | grep 'COMMON_INCLUDE' | cut -d ' ' -f 3)
  echo "Common include : ${COMMON_INCLUDE}"

  echo "Sourcing variables for clang-tags"
  source ${CLANG_TAGS}
  export CLANG_TAGS_BIN=$(which clang-tags)
  export PROJECT_ROOT=${PARENT}
}

## Directly switch to a given project
function proj()
{
  if [[ -d ~/dev/$1 ]]; then
    cd ~/dev/$1
    export PROJECT_ROOT=$(pwd)
    export BRANCH_NAME=$1
    unset RPS1
    activate_compilation_path

    export RPS1="${RPS1}:${BRANCH_NAME}"
  else
    echo "Project $1 doesn't exist"
  fi
}

## Use the clang_tags binary to create clang tags
function generate_clang_tags_for_project()
{
  local RELEASE_DIR CLANG_TAGS_BIN ESCAPED_FOLDER MAKE_EXT

  local PAR1=''
  local PAR2=''
  local CLANG_TAGS=${HOME}/dev/clang-tags/build/env.sh
  local INCREMENTAL=0
  source ${CLANG_TAGS}

  if [[ "x$1" == "x" || "x${PROJECT_ROOT}" == "x" ]]; then
    echo "Missing project name (did you bootstrap_component the project?)"
    return
  fi

  if [[ -d "${PROJECT_ROOT}/$1" && -e "${PROJECT_ROOT}/$1/Makefile.am" ]]; then
    echo "Generating tags for ${PROJECT_ROOT}/$1"
    echo "Using branch name: ${BRANCH_NAME}"
    if [[ -d "${PROJECT_ROOT}/$1/tests/unit" ]]; then
      echo "Running checks too"
      local MAKE_EXT="check"
    fi
  else
    echo "Project ${PROJECT_ROOT}/$1 doesn't exist (Makefile.am missing or directory doesn't exist)"
    return
  fi

  if [[ -e "${PROJECT_ROOT}/$1/compile_commands.json" ]]; then
    echo "Compilation DB exists, doing incremental build"
    #INCREMENTAL=1
  fi

  # Strip folders until we don't fall in the right one
  PAR1=$(dirname ${PROJECT_ROOT}/$1)
  if [[ "${PAR1}" != "${PROJECT_ROOT}" ]]; then
    PAR2=$(dirname $PAR1)
  fi

  local RELEASE_DIR=${PAR1}/.release/
  local COMPONENT_NAME=$(basename $1)
  cd ${RELEASE_DIR}

  if [[ "x${PAR2}" != "x" ]]; then
    cd ${COMPONENT_NAME}
  fi

  local CLANG_TAGS_BIN=$(which clang-tags)
  [[ ${INCREMENTAL} -eq 0 ]] && make clean 
  ${CLANG_TAGS_BIN} trace make ${MAKE_EXT}

  if [[ -e "${PWD}/compile_commands.json" ]]; then
    if [[ ${INCREMENTAL} -eq 0 ]]; then 
      cp "${PWD}/compile_commands.json" "${PAR1}/${COMPONENT_NAME}"
    else
      cat "${PWD}/compile_commands.json" >> "${PAR1}/${COMPONENT_NAME}/compile_commands.json"
    fi
  fi

  # Moving the .ycm_extra_conf.py in the right place
  local ESCAPED_FOLDER=$(echo "${PAR1}/${COMPONENT_NAME}" | sed -e 's/[\/&]/\\&/g')

  cp ${HOME}/bin/ycm_template.py "${PAR1}/${COMPONENT_NAME}/.ycm_extra_conf.py"
  sed -i "s/\$TOBESET/${ESCAPED_FOLDER}/" ${PAR1}/${COMPONENT_NAME}/.ycm_extra_conf.py
}

## Activate the KE PATH
KE_PATH_ACTIVE=0
function activate_ke_path()
{
  if [[ ${KE_PATH_ACTIVE} -eq 0 ]]; then
    export PATH=${PATH}:/ke/bin:/ke/scripts
  fi

  KE_PATH_ACTIVE=1
}

## Prepare a development environment
function prepare_dev()
{
  local REPOS_TO_CLONE=(ke-common)
  local REPOS_DEFAULT=(ke-kemake ke-opinel)
  local BRANCH_NAME

	if [[ "x$1" == "x--help" || "x$1" == "x-h" ]]; then
		echo "$0 <branch_name> <repo1> [repo2 ... repon]"
		echo "   ke-common and ke-kemake are cloned by default"
		return
	fi


  if [[ "x$1" == "x" ]]; then
		echo "$0 <branch_name> <repo1> [repo2 ... repon]"
    echo "Missing branch name"
    return
  fi

	if [[ $# -lt 2 ]]; then
		echo "$0 <branch_name> <repo1> [repo2 ... repon]"
		echo "You have to clone at least one repo"
		return
	fi

  BRANCH_NAME=$1
	shift

  if [[ -d ${HOME}/dev/${BRANCH_NAME} ]]; then
    echo "A Branch with that name exists already"
    return
  fi

  take ${HOME}/dev/${BRANCH_NAME}

  for i; do
    bzr branch mel:${i} mel:${i}/${USER}/${BRANCH_NAME} || return
    bzr co mel:${i}/${USER}/${BRANCH_NAME} ${i} || return
  done

	for repo in ${REPOS_TO_CLONE}; do
    bzr branch mel:${repo} mel:${repo}/${USER}/${BRANCH_NAME} || return
    bzr co mel:${repo}/${USER}/${BRANCH_NAME} ${repo} || return
  done

  for repo in ${REPOS_DEFAULT}; do
    bzr branch mel:${repo}
  done
}

## Clean a given branch on the remote MEL
function clean_branch()
{
  local REPOS_TO_CLONE=(ke-common ke-kemake)
	BRANCH_NAME=$1
	shift

	for i; do
		echo "bzr remove-branch mel:${USER}/${i}/${BRANCH_NAME}"
	done

	for repo in ${REPOS_TO_CLONE}; do
		echo "bzr remove-branch mel:${USER}/${repo}/${BRANCH_NAME}"
  done

	unset REPOS_TO_CLONE
}

## Switch to the .release folder
function sw_release()
{
  local COMP_NAME=$(basename $PWD)

  if [[ -d ../.release/${COMP_NAME} ]]; then
    cd ../.release/${COMP_NAME}
  elif [[ -d ../../${COMP_NAME} ]]; then
    cd ../../${COMP_NAME}
  fi
}

## Start the SSH agent
function start_agent()
{
  if [[ "x$1" == "xforce" ]]; then
    rm -f ${AGENT_ENV}
    killall -9 ssh-agent
  fi

  if [[ -e ${AGENT_ENV} ]]; then
    . ${AGENT_ENV} &> /dev/null
    ssh-add &> /dev/null
    ssh-add ${HOME}/.ssh/id_rsa_kedev &> /dev/null
  else
    ssh-agent > ${AGENT_ENV}
    chmod 0600 ${AGENT_ENV}
    start_agent
  fi
}


## COMPLETION FUNCTIONS

_bootstrap_component()
{
  _arguments '1:branch name:(${BRANCH_NAME})'
}

_proj()
{
  _arguments '1:project name:->projects'
  case $state in
    projects)
      _files -W ~/dev -/
      ;;
  esac
}

_generate_clang_tags_for_project()
{
  _arguments '1:subproject:_files -W ${PROJECT_ROOT}/ -/'
}

_start_agent()
{
  _arguments '1:force:(force):'
}

_prepare_dev()
{
  _arguments '1: :' '*: :(ke-indexation ke-crawl ke-search)'
}


## Final compdefs

compdef _bootstrap_component bootstrap_component
compdef _proj proj
compdef _generate_clang_tags_for_project generate_clang_tags_for_project
compdef _start_agent start_agent
compdef _prepare_dev prepare_dev

