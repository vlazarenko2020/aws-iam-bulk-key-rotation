#!/usr/bin/env bash
#

# ----------------------------------------------------------------------------------------------------------------
f_remove_comments_from_info_csv_file() {
    : > "${tmp_file_without_comments}"   # prepare an empty temp file for the lines without comments
    while IFS= read -u 4 -r line; do

        # -- Clean the line: drop Windows '\r' and leading/trailing whitespace.
        line="${line%$'\r'}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        # -- Blank line: skip silently.
        if [[ -z "${line}" ]]; then
            continue
        fi

        printf "${red}----- Line from info file: ${line}${no_color}\n"
        # -- Don't process commented line started with #
        first_char="${line:0:1}"
        if [[ ${first_char} == '#' ]]; then
            echo "----- Skipping commented line."
            continue
        fi
        # ------

        # -- The line must be "iam_username|aws_cli_profile": exactly one '|'.
        #    (Without this check, `cut` returns the whole line for both fields.)
        delimiters="${line//[^|]/}"         # This command takes the current line, strips out every single character that is not a pipe, and assigns whatever is left to the delimiters variable.
        if [[ "${delimiters}" != '|' ]]; then
            echo "ERROR: expected exactly one '|' (iam_username|aws_cli_profile). Skipping this line from info file (${info_file})."
            continue
        fi

        aws_username=$(echo "$line" | cut -d'|' -f1)
        aws_profile=$(echo "$line" | cut -d'|' -f2)

        if [ -z "$aws_username" ]; then
            echo "ERROR: aws_username is empty. Skipping this line from info file (${info_file})."
            continue
        fi
        if [ -z "$aws_profile" ]; then
            echo "ERROR: aws_cli_profile is empty. Skipping this line from info file (${info_file})."
            continue
        fi

        printf '%s\n' "${line}" >> "${tmp_file_without_comments}"

    done 4<"${info_file}"
}
# ----------------------------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------------------------
# One loop for all actions: $1 = list | inactivate | delete | create
f_process_many_keys() {
    local action="$1" step_title line aws_username aws_profile k_total input

    case "${action}" in
        list)       step_title="Listing existing keys step." ;;
        inactivate) step_title="Inactivate the oldest key step." ;;
        delete)     step_title="Delete the oldest inactive key step." ;;
        create)     step_title="Create a new key step." ;;
    esac

    while IFS= read -u 4 -r line; do  # reading just-created tmp files without commented lines

        printf "\n${red}-----------------------------------------------------------------------\n${no_color}"
        printf "${red}----- ${step_title}${no_color}\n"
        printf "${red}----- Line from info file: ${line}${no_color}\n"
        printf "${red}-----------------------------------------------------------------------\n${no_color}"
        IFS='|' read -r aws_username aws_profile <<< "${line}"
        echo "----- IAM username:       ${aws_username}"
        echo "-----    AWS CLI profile: ${aws_profile}"

        PROFILE=$aws_profile   # -- functions use this variable for --profile
        k_inactive=0   # reset: number of Inactive keys (set by f_list_all_user_keys)
        k_active=0     # reset: number of Active keys (set by f_list_all_user_keys)
        f_list_all_user_keys "${aws_username}"    # sets "$k_active" and "$k_inactive" (number of Active and Inactive keys)
        k_total=$(( k_inactive + k_active ))

        case "${action}" in

            list)
                ;;   # listing was already done above

            inactivate)
                if [[ $k_active -eq 2 ]]; then   # a user can have at most 2 keys
                    f_find_oldest_active_user_key   # reuses "${tmp_file}" created by f_list_all_user_keys
                    echo -e "\n${red}..The oldest Active AWS Key: ${oldest_key} (${oldest_status}).${no_color}\n"
                    printf "${yellow}Is it OK to inactivate the oldest Active Key (y/n) ${no_color} "
                    read -r -p "" input
                    if [[ ${input} = 'y' || ${input} = 'Y' ]]; then
                        f_inactivate_oldest_active_user_key "${aws_username}" "${oldest_key}"
                    else
                        echo -e "\n..Nothing was inactivated for ${aws_username}. Moving on.\n"
                    fi
                elif [[ $k_total -eq 0 ]]; then
                    echo -e "\n..The user has no keys. Nothing to inactivate.\n"
                elif [[ $k_active -eq 0 ]]; then
                    echo -e "\n..The user has no Active keys (${k_inactive} Inactive). Nothing to inactivate.\n"
                elif [[ $k_total -eq 1 ]]; then
                    echo -e "\n..You have only one key. Nothing to inactivate.\n"
                else
                    echo -e "\n..The user has 1 Active and 1 Inactive key. Only 2 Active keys can be inactivated. Delete the Inactive key first if needed.\n"
                fi
                ;;

            delete)
                if [[ $k_inactive -ge 1 ]]; then
                    f_find_oldest_inactive_user_key   # sets "$oldest_inactive_key"; reuses "${tmp_file}"
                    echo -e "\n${red}..The oldest Inactive AWS Key: ${oldest_inactive_key}.${no_color}\n"
                    printf "${yellow}Is it OK to delete the oldest Inactive Key (y/n) ${no_color} "
                    read -r -p "" input
                    if [[ ${input} = 'y' || ${input} = 'Y' ]]; then
                        # deletes only the oldest Inactive key; another Inactive key is kept
                        f_delete_inactive_user_key "${aws_username}" "${oldest_inactive_key}"
                    else
                        echo -e "\n..Nothing was deleted for ${aws_username}. Moving on.\n"
                    fi
                else
                    echo -e "\n..The user has no Inactive key. Nothing to delete.\n"
                fi
                ;;

            create)
                if [[ $k_total -eq 1 ]]; then
                    printf "${yellow}Is it OK to create (add) a New Key (y/n) ${no_color} "
                    read -r -p "" input
                    if [[ ${input} = 'y' || ${input} = 'Y' ]]; then
                        f_create_new_user_key "${aws_username}"
                    else
                        echo -e "\n..Nothing was created for ${aws_username}. Moving on.\n"
                    fi
                elif [[ $k_total -eq 0 ]]; then
                    echo -e "\n..The user has no keys. Nothing to rotate: this step only adds a second key when exactly one exists.\n"
                else
                    echo -e "\n..The user has two keys (active plus inactive). Cannot add a third key. Inactivate and delete the oldest key first.\n"
                fi
                ;;
        esac

    done 4<"${tmp_file_without_comments}"
}
# ----------------------------------------------------------------------------------------------------------------
