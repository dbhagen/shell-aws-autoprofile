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
  local AWSPROFILE_CONFIG_PATH
  AWSPROFILE_CONFIG_PATH="$(awsprofile_find_config)"
  if [ ! -e "${AWSPROFILE_CONFIG_PATH}" ]; then
    echo "No .awsprofile file found"
    return 1
  fi
  AWSPROFILE_CONFIG_PROFILE="$(command head -n 1 "${AWSPROFILE_CONFIG_PATH}" | command tr -d '\r')" || command printf ''
  if [ -z "${AWSPROFILE_CONFIG_PROFILE}" ]; then
    echo "Warning: empty .awsprofile file found at \"${AWSPROFILE_CONFIG_PATH}\""
    return 2
  fi
  #echo "Found '${AWSPROFILE_CONFIG_PATH}' with profile <${AWSPROFILE_CONFIG_PROFILE}>"
  export AWS_PROFILE="${AWSPROFILE_CONFIG_PROFILE}"
}

awsprofile_config_profile
if [ ${ZSH[-5,-1]} == "oh-my-zsh" ]; then
    chpwd_functions+=(awsprofile_config_profile)
else
    add-zsh-hook chpwd awsprofile_config_profile
fi