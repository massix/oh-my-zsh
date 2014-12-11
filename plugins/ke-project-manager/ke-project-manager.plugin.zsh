#####################################################################
# KE Project Manager                                                #
# Just a handy plugin for oh-my-zsh to use at work                  #
# Copyright 2014 Massimo Gengarelli <mgengarelli.ext@orange.com>    #
#####################################################################

# Global variables
export COMPILPATHACTIVE=
export BRANCH_NAME=
export PROJECT_ROOT=
export NOCOMPILPATH=${PATH}
export OPINEL_ENV=

# Bump this everytime we re-merge in master
export KPM_VERSION="1.0.4"

# Set this to where your projects are
export REPOSITORY=${HOME}/dev

# Set this to where your ycm_template file is
export YCM_TEMPLATE_FILE=${HOME}/bin/ycm_template.py

# Set to 0 if you don't want to use the naughty notifier
export NAUGHTY_NOTIFIER_ENABLED=1

# Set the array of the machines you want to target using the the deploy_component method
local -a atlas_conso_qualif indexer_conso_qualif machines
atlas_conso_qualif=(atlas001.conso.qualif.bloc01.ke.p.fti.net atlas002.conso.qualif.bloc01.ke.p.fti.net)
indexer_conso_qualif=(indexer001.search.qualif.bloc01.ke.p.fti.net)

# Preprod machines
thalie_search_preprod=(thalie001.search.preprod.bloc01.ke.p.fti.net \
                       thalie002.search.preprod.bloc01.ke.p.fti.net)
merger_search_preprod=(merger001.search.preprod.gen01.ke.p.fti.net \
                       merger002.search.preprod.gen01.ke.p.fti.net \
                       merger003.search.preprod.gen01.ke.p.fti.net)
atlas_search_preprod=(atlas-connector001.tr01.search.preprod.bloc01.ke.p.fti.net \
                      atlas-connector002.tr01.search.preprod.bloc01.ke.p.fti.net \
                      atlas-connector003.tr01.search.preprod.bloc01.ke.p.fti.net)
sto_crawl_qualif=(sto004.crawl.vqualif.gen01.ke.p.fti.net)

# Update this to match the arrays you want to use
machines=(atlas_conso_qualif indexer_conso_qualif thalie_search_preprod merger_search_preprod atlas_search_preprod sto_crawl_qualif)

# Load the functions file
source $(dirname $0)/ke-project-manager_helpers.plugin.zsh

# Load the useless functions file
source $(dirname $0)/ke-project-manager_useless.plugin.zsh

# Load the prompt's information file
source $(dirname $0)/ke-project-manager_prompt.plugin.zsh

# Load the completion file for ZSH
source $(dirname $0)/ke-project-manager_completion.plugin.zsh

function __kpm_usage()
{
  echo "KE Projects Wrapper for ZSH"
  echo "usage: k <command> [subcommand] : following is a list of commands"
  echo "    h | help                                            Print this help"
  echo "   cp | compilation_path (activate/deactivate)          (de)activate compilation path"
  echo "    p | proj <project_name>                             Switch to given project"
  echo "   bs | bootstrap <branch_name>                         Bootstrap current folder"
  echo "   ct | ctags <project> [nochecks]                      Generate clang-tags for project"
  echo "   cc | clang <project> [nochecks]                      Generate clang-complete for project"
  echo "  dev | prepare_dev <branch-name> [repos]               Prepare development environment"
  echo "   cb | clean_branch <branch-name> [repos]              Clean a given branch (gives commands)"
  echo "  bun | create_bundles [repos]                          Create bundles for given repos"
  echo "    r | root                                            Go to project's root"
  echo "    i | info                                            Print informations on project"
  echo "   sp | subproject <subproject>                         Quickly switch to a subproject"
  echo "    d | diff [color]                                    Run a bzr (c)diff on all subprojects"
  echo "    e | env <opinel_env>                                Set opinel environment"
  echo "    o | opinel [opinel commands]                        Opinel wrapper with --env= set"
  echo "   dc | deploy <machines> <remote_path> <binaries..>    Deploy binaries to given machines at given path"
}

function ke_project_manager()
{
  local command
  local -a singles

  # These commands don't have any mandatory option
  singles=(r root d diff i info)

  [[ -z "$1" ]] && __kpm_usage && return 127

  command="$1"
  shift

  # Verify if the information provided are correct
  [[ "${singles[(i)${command}]}" -gt ${#singles} ]] && [[ -z $1 ]] && __kpm_usage && return 127

  case ${command} in
    compilation_path|cp)
      __compilation_path $1
      ;;
    proj|p)
      __proj $1
      ;;
    bootstrap|bs)
      __bootstrap_component $@
      ;;
    ctags|ct)
      __generate_clang_tags_for_project $1 $2
      ;;
    clang|cc)
        __generate_clang_complete_for_project $1 $2
      ;;
    prepare_dev|dev)
      __prepare_dev $@
      ;;
    clean_branch|cb)
      __clean_branch $@
      ;;
    create_bundles|bun)
      __create_bundles $@
      ;;
    root|r)
      cd ${PROJECT_ROOT}
      ;;
    info|i)
      __project_info
      ;;
    subproject|sp)
      cd ${PROJECT_ROOT}/$1
      ;;
    diff|d)
      __diff_project $1
      ;;
    env|e)
      __set_opinel_environment $1
      ;;
    opinel|o)
      __opinel_wrapper $@
      ;;
    deploy|dc)
      local machines_array=$1
      shift
      __deploy_component $machines_array $@
      ;;
  esac
}


# Just a couple of useful alias
alias k=ke_project_manager
alias kpm=ke_project_manager

# Notify the user that we're ready to go !
echo "KE Project Manager version ${KPM_VERSION} loaded"

