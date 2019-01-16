#!/usr/bin/env bash

set -e

## Project setup functions
circle_ci(){
  env_file='/etc/profile.d/circleci.sh'
  echo "export CIRCLECI=true" | sudo tee -a ${env_file} 1>/dev/null

  . ${env_file}
  variables_gen
}

variables_gen(){
  path_to_new_kali_shell_script='/vagrant/scripts/new-kali.sh'
  project_dir='/vagrant'
  # installing deps
  echo 'Installing dependencies...'
  sudo apt-get install -y jq screen dirmngr
  
  pushd ${project_dir}
  chmod +x ${path_to_new_kali_shell_script}
  ${path_to_new_kali_shell_script}
}

## base framework
selection_setup(){
  PROJECT=''
  projects_array=( "variables_gen" "circle_ci")
  project_index=0
}

selection(){
  for project in "${projects_array[@]}"; do
    printf "%d) %s\n" $project_index $project
    project_index=$(( $project_index + 1 ))
  done
  
  printf 'Please choose a project: '
  read project_num
  
  if [ $project_num -ge 0 ] && [ $project_num -lt $project_index ] ; then
    ${projects_array[$project_num]}
  else
    echo 'no project selected'
    echo 'to set this up again'
    echo 'please run: vagrant provision'
    cleanup
    exit 1
  fi
}

get_secret(){
  secrets_file='/vagrant/secrets.colon'
  export SECRET_KEY=$(grep $1 ${secrets_file} | cut -d ':' -f 3-)
  

}

cleanup(){
  sed -i 's,/vagrant/prov_vagrant/prov.sh,,' ~vagrant/.bashrc
  # if [[ ! -z $project_num ]] ; then
  #   echo 'Powering off machine so you have proper dev env, please do a vagrant up'
  #   sudo shutdown -h now
  # fi
}
check_done(){
  echo
  echo 'Will that be all? (Y/n)'
  read donez_ans
  donez_ans=$(echo $donez_ans | tr '[:upper:]' '[:lower:]')
  if [[ !($donez_ans == 'n') ]] ; then
    donez=false
    cleanup
  fi
}
donez=true
while $donez ; do
  sudo apt-get update
  sudo apt-get install -y git tmux screen
  # for spacing
  echo
  selection_setup
  selection
  check_done
done
