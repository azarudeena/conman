#!/usr/local/bin/bash

set -e
set -o pipefail

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>>log.out 2>&1


usage () {
    cat << EOF
    Options:
      -y YAML configuration file path
      -i identity file for ssh configuration
      -u Username for the host
      -h host ips or DNS name, Multiple hosts can also be provide refer below
      -f full path to script file to be executed in the hosts
      -c commands to be executed in the hosts, Ex: 'ps;ls -ltr; df /'
      -I packages to install Ex: vim,apache2
      -R packages to remove Ex: vim,nano
      -s state:service to be maintained service to be the name of the service. state: desired state; Valid values: start, stop, restart, enable, disable Ex: start:apache2,disable:sshd,stop:redis

      Usage :
        ./conman.sh -u <username> -h <hostips> -f <path to scriptfile>";
        Ex: ./conman.sh -u alice -h x.x.x.x -f /here/this-file.sh -c 'pwd;ls;'

      For multiple hosts
        ./conman.sh -u alice -h x.x.x.x -h x.x.x.x -f /here/this-file.sh
EOF
    abort ""
  }

abort () {
    echo >&2 "$@"
    exit 1
}

file=""
parseOptions(){
  file="$1"

  if [[ -e "$file" ]] && [[ $(yq e 'true' "$file") ]]; then
      hostsaddr=$(yq e ".hosts.name" "$file");
      user=$(yq e ".hosts.user" "$file");

      while IFS= read -r value; do
          installPk+=($value)
      done < <(yq e ".hosts.package.install[].name" "$file")

      while IFS= read -r value; do
          removePk+=($value)
      done < <(yq e ".hosts.package.remove[].name" "$file")

      service=($(yq e ".hosts.service" "$file"))

  else
    echo "file doesn't exist or Invalid file"
    usage;
  fi
}

installpackageOpts (){
  installOpts="$1";
  IFS=','
  read -r -a installPk <<< "${installOpts}"
}

removepackageOpts (){
  removeOpts="$1";
  IFS=','
  read -r -a removePk <<< "${removeOpts}"
}

parseServOpts (){
  serviceOpts="$1";
  IFS=','
  read -r -a service <<< "${serviceOpts}"
}

while getopts 'y:i:h:u:f:c:I:R:s:' flag; do
  case "${flag}" in
    y) parseOptions "${OPTARG}" ;; # yaml configuration
    i) identity="${OPTARG}" ;; # identity file for the
    h) hostsaddr="${OPTARG}" ;;  # array of hosts
    u) user="${OPTARG}" ;; # User name of the remote system
    f) script="${OPTARG}";; # Script to execute in remote system
    c) command+=" ${OPTARG}" ;; # commands to be executed
    I) installpackageOpts "${OPTARG}" ;; # packages to install
    R) removepackageOpts "${OPTARG}" ;; # packages to remove
    s) parseServOpts "${OPTARG}" ;; # services options
    *) usage ;;
  esac
done


if [ ! "$hostsaddr" ]
then
    usage
else
  IFS=','
  read -r -a hosts <<< "${hostsaddr}"
fi


checkStat() {
  if [ "$1" -eq 0 ]; then
    echo "$2 SUCCESSFUL"
  else
    echo "$2 FAILED"
  fi
}

makeServiceCmds(){
  opts="$1"
  if [ "$opts" ]; then
     for servState in "${opts[@]}"; do
        declare -a serv=($(echo "$servState" | tr ":" " "))
        if [ $serv != null ]; then
          echo "sudo systemctl ${serv[0]} ${serv[1]}" >> .config.sh
        fi
    done
  fi
}


for host in "${hosts[@]}"; do
  count=0
  ADDR="";
  if [ ! "$user" ]; then
      ADDR="${host}"
  else
    ADDR="${user}"@"${host}"
  fi

  if [ "$identity" ]; then
      ADDR="-i $identity "$ADDR
  fi

  if [  "$removePk" ]; then
      for packageR in "${removePk[@]}"; do
       echo "sudo apt-get -y remove ${packageR}" >> .config.sh
      done
  fi

  if [ "$installPk" ]; then
      for packageI in "${installPk[@]}"; do
        echo "sudo apt-get -y install ${packageI}" >> .config.sh
      done
  fi

if [ -e "$file" ]; then
  content=$(yq e ".hosts.files.content" "$file" )
  if [  $content != null ]; then
      contentconfigArrLen=$(yq e ".hosts.files.content | length" "$file")
      for((i=$contentconfigArrLen-1 ; i >= 0; i--));do
        name=$(yq e ".hosts.files.content[${i}].name" "$file")
        path=$(yq e ".hosts.files.content[${i}].path" "$file")
        text=$(yq e ".hosts.files.content[${i}].text" "$file")
        f=EOF
    cat >>.config.sh<< EOF
sudo cat <<EOF > $path/$name
  $text
$f
EOF
        notifyService=($(yq e ".hosts.files.content[${i}].service" "$file"))
        makeServiceCmds $notifyService
      done
  fi

  config=$(yq e ".hosts.files.config" "$file" )
  if [ $config != null  ]; then
    fileConfigArrlen=$(yq e ".hosts.files.config | length" "$file")
    for((i=$fileConfigArrlen-1 ; i >= 0 ;  i--)); do
      name=$(yq e ".hosts.files.config[${i}].name" "$file")
      path=$(yq e ".hosts.files.config[${i}].path" "$file")
      owner=$(yq e ".hosts.files.config[${i}].owner" "$file")
      group=$(yq e ".hosts.files.config[${i}].group" "$file")
      mode=$(yq e ".hosts.files.config[${i}].mode" "$file")
      echo "if [ -e $path/$name ]; then" >> .config.sh
      echo "fileConfigs"
      if [ $owner ] && [ $group ]; then
        echo "sudo chown $owner:$group $path/$name" >> .config.sh
      fi
      if [ $mode ]; then
        echo "sudo chmod $mode $path/$name" >> .config.sh

      fi
      echo "fi" >> .config.sh

      notifyService=($(yq e ".hosts.files.config[${i}].service" "$file"))
      makeServiceCmds $notifyService
      done
  fi

fi

  makeServiceCmds $service

  if [ "$command" ]; then
    echo "$command" >> .config.sh
  fi

  if [ "$script" ]; then
    ssh "$ADDR" 'bash -s' < "${script}" && echo "OK"
    checkStat $? "${script} file execution"
  fi

  if [ -e .config.sh ]; then
    ssh "$ADDR" 'bash -s' < ./.config.sh && echo "OK"
    checkStat $? "$host config"
    cat .config.sh >> .back
    rm .config.sh
  fi

done