## Some useful functions I wrote to ease up my daily routines

COMPILPATHACTIVE=0
ENVIRONMENT_FILE=${HOME}/bin/var_env_toolchain.sh
NOCOMPILPATH=${PATH}
AGENT_ENV=${HOME}/.ssh/environment
OPINEL_ENV=
export LOGGER_BIN=$(which logger)

## Ok this is not really *THAT* helpful
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
  local -a REPOS_DEFAULT
  local -a REPOS_TO_CLONE
  local BRANCH_NAME
  REPOS_TO_CLONE=(ke-common)
  REPOS_DEFAULT=(ke-kemake ke-opinel)

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
  local -a REPOS_TO_CLONE
  
  REPOS_TO_CLONE=(ke-common ke-kemake)
	local BRANCH_NAME=$1
	shift

  [[ "x${BRANCH_NAME}" == "x" ]] && echo "You must provide a branch name" && return 127

	for i; do
		echo bzr remove-branch mel:${i}/${USER}/${BRANCH_NAME}
	done

	for repo in ${REPOS_TO_CLONE}; do
		echo bzr remove-branch mel:${repo}/${USER}/${BRANCH_NAME}
  done

  echo rm -fr ~/dev/${BRANCH_NAME}
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

function create_bundles()
{
  [[ "x${PROJECT_ROOT}" == "x" ]] && echo "PROJECT_ROOT is not set" && return 127

  for i; do
    pushd -q ${PROJECT_ROOT}/${i}
    bzr bundle mel:${i} . > ${PROJECT_ROOT}/${i}-bundle.diff
    popd -q
  done
}

function project_info()
{
  set_opinel_environment
  local STATUS folders
  [[ "x${PROJECT_ROOT}" == "x" ]] && echo "PROJECT_ROOT is not set" && return 127
  echo "Project path    : ${PROJECT_ROOT}"
  echo "Branch  name    : ${BRANCH_NAME}"
  echo "Opinel schroot  : ${OPINEL_ENV}"
  echo

  pushd -q $(pwd)  
  pushd -q ${PROJECT_ROOT}


  ## Get status of subcomponents
  for folders in $(find . -maxdepth 1 -type d -iname "ke-*"); do
    pushd -q ${folders}
    STATUS="clean"
    [[ -n `bzr status` ]] && STATUS="dirty"
    echo "${(r:15:: :)${folders[1,20]}} : ${STATUS}"
    popd -q
  done

  popd -q
}

function diff_project()
{
  local diff_command="diff"
  [[ "x$1" == "xcolor" ]] && diff_command="cdiff"
  [[ "x${PROJECT_ROOT}" == "x" ]] && echo "PROJECT_ROOT is not set" && return 127

  pushd -q $PROJECT_ROOT
  for folders in $(find . -maxdepth 1 -type d -iname "ke-*"); do
    pushd -q ${folders}
    [[ -n `bzr status` ]] && bzr ${diff_command}
    popd -q
  done

  popd -q
}

function set_opinel_environment()
{
  local opienv_file=${PROJECT_ROOT}/ke-search/.bzr/opinel_env
  [[ "x${PROJECT_ROOT}" == "x" ]] && echo "PROJECT_ROOT is not set" && return 127
  if [[ "x$1" == "x" ]]; then
    if [[ -e ${opienv_file} ]]; then
      OPINEL_ENV=$(cat ${opienv_file})
    fi
  else
    OPINEL_ENV=$1
    echo ${OPINEL_ENV} > ${opienv_file}
  fi
}

function opinel_wrapper()
{
  set_opinel_environment || return 127
  [[ "x${OPINEL_ENV}" == "x" ]] && echo "Couldn't guess opinel environment" && return 127

  if [[ -d ${PROJECT_ROOT}/ke-opinel ]]; then
    ${PROJECT_ROOT}/ke-opinel/src/opinel --env=${OPINEL_ENV} $@
  fi
}

function compile_component()
{
  [[ "x${PROJECT_ROOT}" == "x" ]] && echo "PROJECT_ROOT is not set" && return 127
  if [[ -d ${PROJECT_ROOT}/$1 ]]; then
    pushd -q ${PROJECT_ROOT}/$1
    sw_release
    if [[ "x${OPINEL_ENV}" != "x" ]]; then
      make && make deb-main-deploy
    else
      make
    fi
    popd -q
  fi
}

local -a atlas indexer
atlas=(atlas001.conso.qualif.bloc01.ke.p.fti.net atlas002.conso.qualif.bloc01.ke.p.fti.net)
indexer=(indexer001.search.qualif.bloc01.ke.p.fti.net)

function deploy_component()
{
  local -a machines_array
  local -a binaries binaries_basename remote_ports
  local remote_port_start=9100
  machines_array=$1
  shift

  binaries=()
  binaries_basename=()

  for i; do
    binaries+=$i
    binaries_basename+=$(basename $i)
  done

  for m in ${(P)${machines_array}}; do
    echo "Targetting machine $fg_bold[blue]${m}$reset_color"
    local i=1
    for b in ${binaries}; do
      echo -n "  Deploying ${(r:70:: :)${b[1,70]}} "
      ssh $m "nc -d -l $remote_port_start > /ke/bin/${binaries_basename[$i]} &"
      cat $b | nc $m $remote_port_start
      local md5sum_local=$(md5sum $b | awk '{print $1}')
      local md5sum_remote=$(ssh $m "md5sum /ke/bin/${binaries_basename[$i]}" | awk '{print $1}')

      if [[ $md5sum_local != $md5sum_remote ]]; then
        echo "[$fg_bold[red]KO$reset_color]"
        echo -e "local  md5sum: $fg_bold[red]${md5sum_local}$reset_color\nremote md5sum: $fg_bold[red]${md5sum_remote}$reset_color\n"
        return 127
      else
        echo "[$fg_bold[green]OK$reset_color]"
      fi
      (( i = i + 1 ))
    done
    echo "-----> everything done for machine $fg_bold[blue]${m}$reset_color"
    echo
  done

}

## Wrapper around all the functions
function k() {
  local command param firstparam secondparam thirdparam
  local -a singles
  singles=(xr xroot xd xdiff xi xinfo)

  command="$1"
  param="$2"

  firstparam="$3"
  secondparam="$4"
  thirdparam="$5"
  
  [[ "x${command}" == "x" ]] && _k_usage && return 127


  ## The parameters defined in ${singles} don't have a mandatory option
  [[ "${singles[(i)x${command}]}" -gt ${#singles} ]] && [[ "x${param}" == "x" ]] && _k_usage && return 127

  case ${command} in
    compilation_path|cp)
      case ${param} in
        (activate)
          activate_compilation_path
          ;;
        (deactivate)
          deactivate_compilation_path
          ;;
      esac
      ;;
    proj|p)
      proj ${param}
      ;;
    bootstrap|bs)
      bootstrap_component ${param}
      ;;
    ctags|ct)
      generate_clang_tags_for_project ${param}
      ;;
    prepare_dev|dev)
      shift
      prepare_dev $@
      ;;
    clean_branch|cb)
      shift
      clean_branch $@
      ;;
    create_bundles|bun)
      shift
      create_bundles $@
      ;;
    root|r)
      cd ${PROJECT_ROOT}
      ;;
    info|i)
      project_info
      ;;
    subproject|sp)
      cd ${PROJECT_ROOT}/${param}
      ;;
    diff|d)
      diff_project ${param}
      ;;
    env|e)
      set_opinel_environment ${param}
      ;;
    opinel|o)
      shift
      opinel_wrapper $@
      ;;
    compile|cc)
      compile_component ${param}
      ;;
    atlas|ats)
      shift
      deploy_component atlas $@
      ;;
    indexer|idx)
      shift
      deploy_component indexer $@
      ;;
  esac
}

_k_usage() {
  echo "KE Projects Wrapper for ZSH"
  echo "usage: k <command> [subcommand] : following is a list of commands"
  echo "    h | help                                      Print this help"
  echo "   cp | compilation_path (activate/deactivate)    (de)activate compilation path"
  echo "    p | proj <project_name>                       Switch to given project"
  echo "   bs | bootstrap <branch_name>                   Bootstrap current folder"
  echo "   ct | ctags <project>                           Generate clang-tags for project"
  echo "  dev | prepare_dev <branch-name> [repos]         Prepare development environment"
  echo "   cb | clean_branch <branch-name> [repos]        Clean a given branch (gives commands)"
  echo "  bun | create_bundles [repos]                    Create bundles for given repos"
  echo "    r | root                                      Goes to project's root"
  echo "    i | info                                      Prints informations on project"
  echo "   sp | subproject <subproject>                   Quickly switch to a subproject"
  echo "    d | diff [color]                              Run a bzr (c)diff on all subprojects"
  echo "    e | env <opinel_env>                          Set opinel environment"
  echo "    o | opinel [opinel commands]                  Opinel wrapper with --env= set"
  echo "   cc | compile <component>                       Compiles the given component"
  echo "  ats | atlas <binaries>                          Deploy binaries to atlas machines"
  echo "  idx | indexer <binaries>                        Deploy binaries to index machines"
}

## COMPLETION FUNCTIONS

_k()
{
  typeset -A opt_args

  _arguments -C \
    '1:command:->cmds' \
    '2:subcommand:->scmds' \
    '*:: :->args'

  case $state in
    cmds)
      local -a commands
      commands=(
        {compilation_path,cp}':Compilation path enable or disable'
        {proj,p}':Switch to given project'
        {bootstrap,bs}':Bootstrap current folder'
        {ctags,ct}':Generate clang tags for given component'
        {prepare_dev,pd}':Preparate development environment'
        {clean_branch,cb}':Give commands to clean a branch'
        {create_bundles,bun}':Create bundles for given repos'
        {root,r}':Goes to project root'
        {info,i}':Gives informations on project'
        {help,h}':Print help'
        {subproject,sp}':Quickly switch to a subproject'
        {diff,d}':Run a bzr (c)diff on all subprojects'
        {env,e}':Set opinel environment'
        {opinel,o}':Opinel wrapper with --env= set'
        {compile,cc}':Compiles the given component'
        {atlas,ats}':Deploy binaries to atlas machines'
        {indexer,idx}':Deploy binaries to index machines'
      )

      _describe -t commands 'command' commands && ret=0
    ;;
    scmds)
      case $line[1] in
        compilation_path|cp)
          integer NORMARG
          _arguments -C -n \
            '2:Activates or deactivates the compilation path:(activate deactivate)'
        ;;
        proj|p)
          _arguments '2:project name:_files -W ~/dev -/'
        ;;
        bootstrap|bs)
          _arguments '2:branch name:(${BRANCH_NAME})'
        ;;
        ctags|ct)
          _arguments '2:subproject:_files -W ${PROJECT_ROOT}/ -/'
        ;;
        prepare_dev|pd)
          _arguments '2:branch name:'
        ;;
        clean_branch|cb)
          _arguments '2:branch name:$(${BRANCH_NAME})'
        ;;
      create_bundles|bun)
          _arguments '*:repos:_files -W ${PROJECT_ROOT} -/'
        ;;
      subproject|sp)
          _arguments '2:subproject:_files -W ${PROJECT_ROOT}/ -/'
      ;;
      diff|d)
        _arguments '2:color:(color)'
      ;;
      compile|cc)
        _arguments '2:subproject:_files -W ${PROJECT_ROOT}/ -/'
      ;;
      atlas|ats|indexer|idx)
        _arguments '2:binary:_files'
        ;;
      esac
    ;;
    args)
      case $line[1] in
        prepare_dev|pd|clean_branch|cb)
          _arguments '*:repos to clone:(ke-indexation ke-crawl ke-search)'
          ;;
      create_bundles|bun)
          _arguments '*:repos:_files -W ${PROJECT_ROOT} -/'
        ;;
      atlas|ats|indexer|idx)
        _arguments '*:binary:_files'
        ;;
      esac
    ;;
  esac
}


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
  _arguments '1:force:(force)'
}

_prepare_dev()
{
  _arguments '1:branch name:' '*:repos to clone:(ke-indexation ke-crawl ke-search)'
}


## Final compdefs

compdef _bootstrap_component bootstrap_component
compdef _proj proj
compdef _generate_clang_tags_for_project generate_clang_tags_for_project
compdef _start_agent start_agent
compdef _prepare_dev prepare_dev
compdef _k k

