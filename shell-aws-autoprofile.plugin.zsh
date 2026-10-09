### Thanks to @laggardkernel for his code for CHPWD in BASH. https://gist.github.com/laggardkernel/6cb4e1664574212b125fbfd115fe90a4

# Bash-only prompt machinery; guarded so nothing here runs under zsh.
if [ -n "${BASH_VERSION:-}" ]; then
  # create a PROPMT_COMMAND equivalent to store chpwd functions
  CHPWD_COMMAND=""

  _chpwd_hook() {
    local f

    # run commands in CHPWD_COMMAND variable on dir change
    if [[ "$PREVPWD" != "$PWD" ]]; then
      local IFS=$';'
      # CHPWD_COMMAND is a deliberate ; -separated function list: word
      # splitting on IFS is the dispatch mechanism, so the unquoted expansion
      # below is intentional
      # shellcheck disable=SC2086
      for f in $CHPWD_COMMAND; do
        "$f"
      done
      unset IFS
    fi
    # refresh last working dir record
    export PREVPWD="$PWD"
  }

  # add `;` after _chpwd_hook if PROMPT_COMMAND is not empty
  PROMPT_COMMAND="_chpwd_hook${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

awsprofile_find_up() {
  local path_ parent_
  path_="${PWD}"
  # hardening: a slash-free relative PWD (only possible via an override; a real cd
  # always yields an absolute path) would never shorten and loop forever
  case "${path_}" in
    /*) ;;
    *) path_="$(command pwd -P)" ;;
  esac
  while [ "${path_}" != "" ] && [ ! -f "${path_}/${1-}" ]; do
    parent_="${path_%/*}"
    if [ "${parent_}" = "${path_}" ]; then
      break
    fi
    path_="${parent_}"
  done
  echo "${path_}"
}

awsprofile_find_config() {
  local dir
  dir="$(awsprofile_find_up '.awsprofile')"
  if [ -e "${dir}/.awsprofile" ]; then
    echo "${dir}/.awsprofile"
  else
    if [ -e "${HOME}/.awsprofile" ]; then
      echo "${HOME}/.awsprofile"
    else
      echo "No AWS profile found."
    fi
  fi
}

# trim leading and trailing whitespace from the given value
awsprofile_trim() {
  local value="${1-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "${value}"
}

awsprofile_config_profile() {
  export AWSPROFILE_CONFIG_PROFILE=''
  export AWSREGION_CONFIG_REGION=''
  local AWSPROFILE_CONFIG_PATH
  AWSPROFILE_CONFIG_PATH="$(awsprofile_find_config)"
  if [ ! -e "${AWSPROFILE_CONFIG_PATH}" ]; then
    echo "No .awsprofile file found"
    return 1
  fi
  AWSPROFILE_CONFIG_PROFILE="$(awsprofile_trim "$(command sed -n 1p "${AWSPROFILE_CONFIG_PATH}" | command tr -d '\r')")" || command printf ''
  AWSREGION_CONFIG_REGION="$(awsprofile_trim "$(command sed -n 2p "${AWSPROFILE_CONFIG_PATH}" | command tr -d '\r')")" || command printf ''
  # explicit 'none' must match the parsed line-1 profile exactly, not any
  # occurrence of the substring "none" anywhere in the file
  if [ "${AWSPROFILE_CONFIG_PROFILE}" = "none" ]; then
    if [ "${AWSPROFILE_IGNORE_EXPLICIT_NONE_PROFILE:-}" != "true" ]; then
      echo "explicit 'none' profile found in .awsprofile file, unsetting profile"
    fi
    AWSPROFILE_CONFIG_PROFILE=''
  elif [ -z "${AWSPROFILE_CONFIG_PROFILE}" ]; then
    echo "Warning: empty .awsprofile file found at \"${AWSPROFILE_CONFIG_PATH}\""
    return 2
  fi
  if [ -n "${AWSPROFILE_CONFIG_PROFILE}" ]; then
    export AWS_PROFILE="${AWSPROFILE_CONFIG_PROFILE}"
  else
    # explicit 'none' unsets AWS_PROFILE rather than exporting it empty
    unset AWS_PROFILE
  fi
  if [ -n "${AWSREGION_CONFIG_REGION}" ]; then
    export AWS_REGION="${AWSREGION_CONFIG_REGION}"
  fi
}

# register the per-directory re-evaluation hook with the running shell
if [ -n "${BASH_VERSION:-}" ]; then
  CHPWD_COMMAND="${CHPWD_COMMAND:+$CHPWD_COMMAND;}awsprofile_config_profile"
elif [ -n "${ZSH_VERSION:-}" ]; then
  if [ -n "${ZSH:-}" ] && [ -e "${ZSH}/oh-my-zsh.sh" ]; then
    chpwd_functions+=(awsprofile_config_profile)
  else
    autoload -Uz add-zsh-hook
    add-zsh-hook chpwd awsprofile_config_profile
  fi
fi
awsprofile_config_profile
