#####################################################################
# KE Project Manager                                                #
# Just a handy plugin for oh-my-zsh to use at work                  #
# Copyright 2014 Massimo Gengarelli <mgengarelli.ext@orange.com>    #
#####################################################################

function _ke_project_manager()
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
        {deploy,dc}':Deploy binaries to given machines'
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
        deploy|dc)
          _arguments '2:machines:($machines)'
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
      atlas|ats|indexer|idx|deploy|dc)
        _arguments '*:binary:_files'
        ;;
      ctags|ct)
        _arguments '*:enable checks:(check nocheck)'
        ;;
      esac
    ;;
  esac
}

compdef _ke_project_manager ke_project_manager

