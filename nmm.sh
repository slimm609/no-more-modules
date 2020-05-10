#!/usr/bin/env bash
# no more modules - syncs submodules into the repo rather than linking them.
#

set -Eeuo pipefail

# get the root of the directory
_Repo=$(git rev-parse --show-toplevel)

declare -A _ModulePath
declare -A _ModuleSrc
declare -A _ModuleBranch
declare -A _ModuleCommit

# Load config file, it won't exist for nested calls
[[ -s "${_Repo}/nmm.conf" ]] && source "${_Repo}/nmm.conf"

# Display help
_Help() {
  echo "$(basename "$0") help"
  echo -e "  --help \t\t Display Help"
  echo -e "  --list \t\t List all modules"
  echo -e "  --syncall \t\t Sync all repos"
  echo -e "  --sync=<value>\t Sync single module by name"
  exit 1
}

# sync a module into singualrity,  This is a function similar to git submodules
# but does not treat it like submodules, but rather syncs the code into the destination folder.
_ModuleSync() {
  local module=${1}
  local temp=$(mktemp -d)
  if [[ ! ${_ModulePath[$module]+a} ]] && [[ ! ${_ModuleSrc[$module]+a} ]]; then
    echo "Error: Module source/path not configured or does not exist"
    exit 1
  fi

  mkdir -p "${_Repo}"/$(dirname ${_ModulePath[$module]})
  cd ${temp}
  # if a commit id exist, we can't shallow clone because we won't have that id
  if [[ ${_ModuleCommit[$module]+a} ]]; then
    git clone --branch ${_ModuleBranch[$module]:-master} --single-branch ${_ModuleSrc[$module]}
    cd $(basename ${_ModuleSrc[$module]#*/} .git)
    git checkout ${_ModuleCommit[$module]}
  else
    git clone --depth 1 --branch ${_ModuleBranch[$module]:-master} --single-branch ${_ModuleSrc[$module]}
    cd $(basename ${_ModuleSrc[$module]#*/} .git)
  fi
  if [[ -s .gitmodules ]]; then
    for submodule in $(git config -f .gitmodules -l | awk '{split($0, a, /=/); split(a[1], b, /\./); print b[2]}' | uniq); do
      path=$(git config -f .gitmodules -l | awk '{split($0, a, /=/); split(a[1], b, /\./); print b[2], b[3], a[2]}' | grep "${submodule}" | awk '{if ($2 == "path") print $3;}')
      url=$(git config -f .gitmodules -l | awk '{split($0, a, /=/); split(a[1], b, /\./); print b[2], b[3], a[2]}' | grep "${submodule}" | awk '{if ($2 == "url") print $3;}')
      branch=$(git config -f .gitmodules -l | awk '{split($0, a, /=/); split(a[1], b, /\./); print b[2], b[3], a[2]}' | grep "${submodule}" | awk '{if ($2 == "branch") print $3;}')
      commit_id=$(git submodule | awk -v mod="${submodule}" '{if ($2 == mod) print $1}' | sed 's/-//g')
      ${_Repo}/nmm.sh _ModuleSyncNested $path $url $(pwd) ${branch:-master} ${commit_id}
    done
  fi
  rm -rf .git/ .gitmodules "${_Repo}"/${_ModulePath[$module]}
  cp -rf . "${_Repo}"/${_ModulePath[$module]}
  rm -rf ${temp}
  cat <<EOF >"${_Repo}"/${_ModulePath[$module]}/README.nmm
  Synced with No More Modules,  Files added to these directories will be lost
  on next update
EOF
}

# list all modules added to the config
_ModulesList() {
  for module in "${!_ModuleSrc[@]}"; do
    echo "$module"
  done
  exit 0
}

# Sync all modules listed in config
_ModulesSyncAll() {
  for module in "${!_ModuleSrc[@]}"; do
    echo "Syncing ${module}"
    ${_Repo}/nmm.sh _ModuleSync ${module}
  done
  exit 0
}


# handles nested submodules. 
_ModuleSyncNested() {
  local path=${1}
  local url=${2}
  local targetdir=${3}
  local branch=${4}
  local commit_id=${5}
  local temp=$(mktemp -d)
  mkdir -p ${targetdir}/$(dirname $path)
  cd ${temp}
  git clone --branch $branch --single-branch ${url}
  cd $(basename ${url#*/} .git)
  git checkout ${commit_id}
  if [[ -s .gitmodules ]]; then
    for submodule in $(git config -f .gitmodules -l | awk '{split($0, a, /=/); split(a[1], b, /\./); print b[2]}' | uniq); do
      path=$(git config -f .gitmodules -l | awk '{split($0, a, /=/); split(a[1], b, /\./); print b[2], b[3], a[2]}' | grep "${submodule}" | awk '{if ($2 == "path") print $3;}')
      url=$(git config -f .gitmodules -l | awk '{split($0, a, /=/); split(a[1], b, /\./); print b[2], b[3], a[2]}' | grep "${submodule}" | awk '{if ($2 == "url") print $3;}')
      branch=$(git config -f .gitmodules -l | awk '{split($0, a, /=/); split(a[1], b, /\./); print b[2], b[3], a[2]}' | grep "${submodule}" | awk '{if ($2 == "branch") print $3;}')
      commit_id=$(git submodule | awk -v mod="${submodule}" '{if ($2 == mod) print $1}' | sed 's/-//g')
      ${_Repo}/nmm.sh _ModuleSyncNested $path $url $(pwd) ${branch:-master} ${commit_id}
    done
  fi
  rm -rf .git/ .gitmodules
  cp -rf . ${targetdir}/$path
  rm -rf ${temp}
}


if [[ $# -eq 0 ]]; then
 # Call help
  _Help
fi

# Handle if calling itself for submodules
if [[ "${1}" =~ ^_.* ]]; then
  eval "${@}"
fi

# Process user options
optspec=":h-:"
while getopts "$optspec" optchar; do
    case "${optchar}" in
        -)
            case "${OPTARG}" in
                list)
                    _ModulesList
                    ;;
                syncall)
                    _ModulesSyncAll
                    ;;
                sync=*)
                    module=${OPTARG#*=}
                    _ModuleSync ${module}
                    ;;
                *)
                    _Help
                    ;;
            esac;;
        *)
            _Help
            ;;
    esac
done
