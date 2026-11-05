#!/usr/bin/env bash
#

PROFILE='ARacconut2Admin'
#PROFILE='ARacconut1Admin'

tmp_file='/tmp/asdasdsdasdasdasd.json'
yellow='\033[0;33m'
red='\033[0;31m'
magenta='\033[0;35m'
clear='\033[0m'


source "$(dirname "${BASH_SOURCE[0]}")/layer-1.sh"


declare -i kol=0  # count inactive keys


[[ -z $1 ]] && { echo -e "\nERROR: Need one argument: IAM username. Exiting.\n"; exit 1; }

aws_username="$1"




f_list_all_user_keys "${aws_username}"

# echo -e "The color is: ${yellow}yellow${clear}!"



if [[ $kol -ge 1 ]]; then   # kol has amount of Inactive keys
    printf "${yellow}Is it OK to delete inactive key (y/n) ${clear} "
    read -p "" input
    if [[ ${input} = 'y' || ${input} = 'Y' ]]; then
        f_delete_inactive_user_key "${aws_username}"
        f_list_all_user_keys "${aws_username}"
        f_create_new_user_key "${aws_username}"
        f_list_all_user_keys "${aws_username}"
    else
        echo -e "\n..Nothing will be deleted. Exiting.\n"
    fi
else
    echo -e "\n..There are no any inactive key. You need to inactivate the oldest key and start again. Exiting.\n"
fi

