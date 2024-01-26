### Thanks to @laggardkernel for his code for CHPWD in BASH. https://gist.github.com/laggardkernel/6cb4e1664574212b125fbfd115fe90a4

# create a PROPMT_COMMAND equivalent to store chpwd functions
CHPWD_COMMAND=""

_chpwd_hook() {
  shopt -s nullglob

  local f

  # run commands in CHPWD_COMMAND variable on dir change
  if [[ "$PREVPWD" != "$PWD" ]]; then
    local IFS=$';'
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

awsprofile_find_up() {
  local path_
  path_="${PWD}"
  while [ "${path_}" != "" ] && [ ! -f "${path_}/${1-}" ]; do
    path_=${path_%/*}
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

awsprofile_config_profile() {
  export AWSPROFILE_CONFIG_PROFILE=''
  export AWSREGION_CONFIG_REGION=''
  local AWSPROFILE_CONFIG_PATH
  AWSPROFILE_CONFIG_PATH="$(awsprofile_find_config)"
  if [ ! -e "${AWSPROFILE_CONFIG_PATH}" ]; then
    echo "No .awsprofile file found"
    return 1
  fi
  AWSPROFILE_CONFIG_PROFILE="$(command sed -n 1p "${AWSPROFILE_CONFIG_PATH}" | command tr -d '\r')" || command printf ''
  AWSREGION_CONFIG_REGION="$(command sed -n 2p "${AWSPROFILE_CONFIG_PATH}" | command tr -d '\r')" || command printf ''
  if grep -q none "$AWSPROFILE_CONFIG_PATH"; then
    if [[ -z "${AWSPROFILE_IGNORE_EXPLICIT_NONE_PROFILE}"] && ["$AWSPROFILE_IGNORE_EXPLICIT_NONE_PROFILE" = true ]]; then
      echo "explicit 'none' profile found in .awsprofile file, unsetting profile"
    fi
    AWSPROFILE_CONFIG_PROFILE=''
  elif [ -z "${AWSPROFILE_CONFIG_PROFILE}" ]; then
    echo "Warning: empty .awsprofile file found at \"${AWSPROFILE_CONFIG_PATH}\""
    return 2
  fi
  export AWS_PROFILE="${AWSPROFILE_CONFIG_PROFILE}"
  if [ -n "${AWSREGION_CONFIG_REGION}" ]; then
    export AWS_REGION="${AWSREGION_CONFIG_REGION}"
  fi
}

if [ "${0:${#0}-4:4}" = "bash" ]; then
  CHPWD_COMMAND="${CHPWD_COMMAND:+$CHPWD_COMMAND;}awsprofile_config_profile"
elif [ "${0[-3,-1]}" = "zsh" ]; then
  if [ "${ZSH[-9,-1]}" = "oh-my-zsh" ]; then
    chpwd_functions+=(awsprofile_config_profile)
  else
    add-zsh-hook chpwd awsprofile_config_profile
  fi
fi
awsprofile_config_profile
