#####################################################################
# KE Project Manager                                                #
# Just a handy plugin for oh-my-zsh to use at work                  #
# Copyright 2014 Massimo Gengarelli <mgengarelli.ext@orange.com>    #
#####################################################################

function __compilation_path()
{
  local environment_file=${HOME}/bin/var_env_toolchain.sh

  case $1 in
    activate)
      [[ ${COMPILPATHACTIVE} -eq 0 ]] && . ${environment_file}
      export COMPILPATHACTIVE=1
      ;;
    deactivate)
      export PATH=${NOCOMPILPATH}
      export COMPILPATHACTIVE=0
      ;;
  esac
}

function __proj()
{
  if test -d ${REPOSITORY}/$1; then
    cd ${REPOSITORY}/$1
    export PROJECT_ROOT=$(pwd)
    export BRANCH_NAME=$1
    ke_project_manager cp activate
  else
    echo "Unable to find $1 in ~/dev"
  fi
}

function __bootstrap_component()
{
  local given_branch="$1"
  local debug_enabled="$2"

  local grandparent common_include debug_flag
  local parent=$(dirname $PWD)

  ke_project_manager compilation_path deactivate

  if test -z ${given_branch}; then
    echo "Missing branch name"
    return
  elif test "x${given_branch}" != "x${BRANCH_NAME}"; then
    echo "Branch name : ${BRANCH_NAME} differs from ${given_branch}"
    return
  fi

  if test -e "${PWD}/bootstrap.sh"; then
    ./bootstrap.sh \
      --toolchain-dir=/ke/local/toolchain3-x86_64-nptl \
      --kemake-dir=${parent}/ke-kemake || return
  else
    echo "Missing ./bootstrap.sh"
    return
  fi

  if test "x${debug_enabled}" = "xdebug"; then
    debug_flag="--enable-debug"
    echo "Debug activated (passing flag ${debug_flag})"
  fi

  ke_project_manager compilation_path activate

  take .release
  grandparent=$(dirname $(dirname $PWD))

  $(dirname $PWD)/configure --with-toolchain-dir=/ke/local/toolchain3-x86_64-nptl --with-kemake-dir=${grandparent}/ke-kemake --with-common-lib=${grandparent}/ke-common/.release --with-common-include=${grandparent}/ke-common ${debug_flag}

  common_include=$(cat Makefile | grep 'common_include' | cut -d ' ' -f 3)

  naughty_notifier "Bootstrapped ${BRANCH_NAME}:${parent}"
}

## Use the clang_tags binary to create clang tags
function __generate_clang_tags_for_project()
{
  local start_dir=$(pwd)
  local release_dir clang_tags_bin escaped_folder make_ext
  local bear_bin

  local first_level=''
  local second_level=''
  local incremental_build=0


  if test "x$1" = "x" -o "x${PROJECT_ROOT}" = "x"; then
    echo "Missing project name (did you bootstrap_component the project?)"
    return
  fi

  if test -d "${PROJECT_ROOT}/$1" -a -e "${PROJECT_ROOT}/$1/Makefile.am"; then
    if test -d "${PROJECT_ROOT}/$1/tests/unit" -a "x$2" != "xnocheck"; then
      echo "Compiling unitary tests"
      local make_ext="check"
    fi
  else
    echo "Project ${PROJECT_ROOT}/$1 doesn't exist (Makefile.am missing or directory doesn't exist)"
    return
  fi

  if test -e "${PROJECT_ROOT}/$1/compile_commands.json"; then
    echo "Compilation DB exists, doing incremental build"
    incremental_build=1
  fi

  # Strip folders until we don't fall in the right one
  first_level=$(dirname ${PROJECT_ROOT}/$1)
  if [[ "${first_level}" != "${PROJECT_ROOT}" ]]; then
    second_level=$(dirname $first_level)
  fi

  local release_dir=${first_level}/.release/
  local component_name=$(basename $1)
  cd ${release_dir}

  if [[ "x${second_level}" != "x" ]]; then
    cd ${component_name}
  fi

  if test -e "$(pwd)/compile_commands.json"; then
    mv "$(pwd)/compile_commands.json" "$(pwd)/compile_commands.old.json"
  fi

  bear_bin=${HOME}/env/Bear/bin/bear
  [[ ${incremental_build} -eq 0 ]] && make clean
  LD_LIBRARY_PATH=${HOME}/env/libconfig/lib ${bear_bin} -- make ${make_ext}

  if test -e "$(pwd)/compile_commands.json"; then
    if ! test ${incremental_build} -eq 0; then
      mv "$(pwd)/compile_commands.json" "$(pwd)/compile_commands.new.json"
      cat "$(pwd)/compile_commands.new.json" "$(pwd)/compile_commands.old.json" | jq -s add > $(pwd)/compile_commands.json
    fi
  fi

  # Moving the .ycm_extra_conf.py in the right place
  local escaped_folder=$(echo "${first_level}/${component_name}" | sed -e 's/[\/&]/\\&/g')

  cp ${YCM_TEMPLATE_FILE} "${first_level}/${component_name}/.ycm_extra_conf.py"
  sed -i "s/\$TOBESET/${escaped_folder}/" ${first_level}/${component_name}/.ycm_extra_conf.py

  # Create symbolic link for compile_commands.json
  ln -sf "$(pwd)/compile_commands.json" "${first_level}/${component_name}/"

  cd ${start_dir}
  naughty_notifier "Tags for ${BRANCH_NAME}:${component_name} created successfully"
}

## Prepare a development environment
function __prepare_dev()
{
  local -a repos_default
  local -a repos_to_clone
  local branch_name

  repos_to_clone=(ke-common)
  repos_default=(ke-kemake ke-opinel)

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

  branch_name=$1
	shift

  if [[ -d ${HOME}/dev/${branch_name} ]]; then
    echo "A Branch with that name exists already"
    return
  fi

  take ${HOME}/dev/${branch_name}

  for i; do
    bzr branch mel:${i} mel:${i}/${USER}/${branch_name} || return
    bzr co mel:${i}/${USER}/${branch_name} ${i} || return
  done

	for repo in ${repos_to_clone}; do
    bzr branch mel:${repo} mel:${repo}/${USER}/${branch_name} || return
    bzr co mel:${repo}/${USER}/${branch_name} ${repo} || return
  done

  for repo in ${repos_default}; do
    bzr branch mel:${repo}
  done

  naughty_notifier "Everything is ready for ${branch_name}"
}

## Clean a given branch on the remote MEL
function __clean_branch()
{
  local -a cloned_repos

  cloned_repos=(ke-common ke-kemake)
	local BRANCH_NAME=$1
	shift

  [[ "x${BRANCH_NAME}" == "x" ]] && echo "You must provide a branch name" && return 127

	for i; do
		echo bzr remove-branch mel:${i}/${USER}/${BRANCH_NAME}
	done

	for repo in ${cloned_repos}; do
		echo bzr remove-branch mel:${repo}/${USER}/${BRANCH_NAME}
  done

  echo rm -fr ~/dev/${BRANCH_NAME}
}

## Create BZR bundles for given repos
function __create_bundles()
{
  [[ "x${PROJECT_ROOT}" == "x" ]] && echo "PROJECT_ROOT is not set" && return 127
  local start_dir=$(pwd)

  for i; do
    cd ${PROJECT_ROOT}/${i}
    bzr bundle mel:${i} . > ${PROJECT_ROOT}/${i}-bundle.diff
    cd ..
  done

  cd ${start_dir}
}

function __set_opinel_environment()
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


## Give informations on the project
function __project_info()
{
  __set_opinel_environment
  local bzr_status folders
  local old_pwd=$(pwd)
  [[ "x${PROJECT_ROOT}" == "x" ]] && echo "PROJECT_ROOT is not set" && return 127
  echo "Project path    : ${PROJECT_ROOT}"
  echo "Branch  name    : ${BRANCH_NAME}"
  echo "Opinel schroot  : ${OPINEL_ENV}"
  echo

  cd ${PROJECT_ROOT}


  ## Get bzr_status of subcomponents
  for folders in $(find . -maxdepth 1 -type d -iname "ke-*"); do
    cd ${folders}
    bzr_status="clean"
    [[ -n `bzr status` ]] && bzr_status="dirty"
    echo "${(r:15:: :)${folders[1,20]}} : ${bzr_status}"
    cd .. 
  done

  cd ${old_pwd}
}

## Diff the whole project
function __diff_project()
{
  local diff_command="diff"
  [[ "x$1" == "xcolor" ]] && diff_command="cdiff"
  [[ "x${PROJECT_ROOT}" == "x" ]] && echo "PROJECT_ROOT is not set" && return 127
  local old_pwd=$(pwd)

  cd ${PROJECT_ROOT}
  for folders in $(find . -maxdepth 1 -type d -iname "ke-*"); do
    cd ${folders}
    [[ -n `bzr status` ]] && bzr ${diff_command}
    cd ..
  done

  cd ${old_pwd}
}

## Wrapper for opinel
function __opinel_wrapper()
{
  __set_opinel_environment || return 127
  [[ "x${OPINEL_ENV}" == "x" ]] && echo "Couldn't guess opinel environment" && return 127

  if test -d ${PROJECT_ROOT}/ke-opinel; then
    ${PROJECT_ROOT}/ke-opinel/src/opinel --env=${OPINEL_ENV} $@
  fi
}

## Deploy a component on a machine
function __deploy_component()
{
  local -a machines_array
  local -a binaries binaries_basename remote_ports
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
      cat $b | ssh $m "cat - > /ke/bin/${binaries_basename[$i]}"
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

  naughty_notifier "Deployment of binaries is over"
}


