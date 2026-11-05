#!/usr/bin/env bash
#

#PROFILE='ARacconut2Admin'
PROFILE='ARacconut1Admin'

tmp_file='/tmp/asdasdsdasdasdasd.json'
yellow='\033[0;33m'
red='\033[0;31m'
magenta='\033[0;35m'
clear='\033[0m'


source "$(dirname "${BASH_SOURCE[0]}")/layer-1.sh"


[[ -z $1 ]] && { echo -e "\nERROR: Need one argument: IAM username. Exiting.\n"; exit 1; }

aws_username="$1"



f_list_all_user_keys "${aws_username}"



if [[ $kol -eq 0 ]]; then   # kol has amount of Inactive keys

    f_find_oldest_active_user_key

    if [[ ${oldest_status} = 'Active' ]]; then
        echo -e "\n${red}..The oldest Active AWS Key: ${oldest_key} (${oldest_status}).${clear}\n"
    fi

    printf "${yellow}Is it OK to inactive the oldest Active Key (y/n) ${clear} "
    read -p "" input

    if [[ ${input} = 'y' || ${input} = 'Y' ]]; then
        f_inactivate_oldest_active_user_key "${aws_username}" "${oldest_key}"
        f_list_all_user_keys "${aws_username}"
    else
        echo -e "\n..Nothing was inactivated. Exiting.\n"
    fi

else
    echo -e "\n..You already have an ${red}inactive${clear} key. Nothing to do. Exiting.\n"
fi
