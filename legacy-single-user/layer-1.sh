#!/usr/bin/env bash
#
# Self-contained AWS layer for the legacy single-user scripts in this folder
# (step-1-delete-inactive-create-key.sh, step-2-inactivate-oldest-key.sh).
# It does NOT depend on the layer-*.sh files in the repository root.
#
# Variables expected from the calling script:
#   PROFILE   AWS CLI profile
#   tmp_file  file for the last `aws iam list-access-keys` output
#   yellow, red, magenta, clear   colors ('clear' resets the color)
#
# Variables set here:
#   kol                          number of Inactive keys of the last listed user
#   oldest_key, oldest_status    set by f_find_oldest_active_user_key

# ----------------------------------------------------------------------------------------------------------------
f_list_all_user_keys() {

    f_username="$1"
    local k_active=0
    kol=0

    aws iam list-access-keys \
        --user-name "${f_username}" \
        --profile "${PROFILE}" \
    > "${tmp_file}"

    echo ""

    while read -r cur_key cur_status cur_create_date
    do
        if [[ ${cur_status} = 'Inactive' ]]; then
            echo -e "-- ${cur_key} - Status: ${red}${cur_status}${clear} - CreateDate: ${cur_create_date}"
            kol=$(( kol + 1 ))
        else
            echo -e "-- ${cur_key} - Status: ${magenta}${cur_status}${clear} - CreateDate: ${cur_create_date}"
            k_active=$(( k_active + 1 ))
        fi

        aws iam get-access-key-last-used \
            --access-key-id "${cur_key}" \
            --profile "${PROFILE}"

        echo ""
    done < <(jq -r '.AccessKeyMetadata[] | .AccessKeyId + " " + .Status + " " + .CreateDate' "${tmp_file}")

    echo -e "..Active key:   ${red}${k_active}${clear}"
    echo -e "..Inactive key: ${red}${kol}${clear}\n"
}
# ----------------------------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------------------------
# Deletes ALL Inactive keys of the user in "${tmp_file}" (legacy behavior).
f_delete_inactive_user_key() {

    while read -r cur_key cur_status
    do
        if [[ ${cur_status} = 'Inactive' ]]; then
            echo -e "\n${red}..Deleting Inactive AWS Key: ${cur_key} (${cur_status}).${clear}\n"

            aws iam delete-access-key \
                --access-key-id "${cur_key}" \
                --user-name "$1" \
                --profile "${PROFILE}"

            echo -e "\n${red}..Inactive AWS Key: ${cur_key} (${cur_status}).${clear} was deleted.\n"
        fi
    done < <(jq -r '.AccessKeyMetadata[] | .AccessKeyId + " " + .Status' "${tmp_file}")

}
# ----------------------------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------------------------
f_create_new_user_key() {

    f_username="$1"

    echo -e "\n..Creating a new AWS Key for user ${f_username}."
    # The new SecretAccessKey is kept only in this variable, never written to disk.
    new_key_json=$(aws iam create-access-key \
        --user-name "${f_username}" \
        --profile "${PROFILE}")

    printf '%s\n' "${new_key_json}"
    printf '%s\n' "${new_key_json}" | jq -r '."AccessKey" | ."AccessKeyId" + "," + ."SecretAccessKey"'
    new_key_json=""
}
# ----------------------------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------------------------
# Finds the oldest key (by CreateDate) in "${tmp_file}". Sets: oldest_key, oldest_status.
f_find_oldest_active_user_key() {

    local oldest_date="" cur_key cur_status cur_create_date
    oldest_key=""
    oldest_status=""

    while read -r cur_key cur_status cur_create_date
    do
        if [[ -z ${oldest_date} || ${oldest_date} > ${cur_create_date} ]]; then
            oldest_date=${cur_create_date}
            oldest_key=${cur_key}
            oldest_status=${cur_status}
        fi
    done < <(jq -r '.AccessKeyMetadata[] | .AccessKeyId + " " + .Status + " " + .CreateDate' "${tmp_file}")

}
# ----------------------------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------------------------
f_inactivate_oldest_active_user_key() {
    f_aws_username="$1"
    f_oldest_key="$2"

    aws iam update-access-key \
        --access-key-id "${f_oldest_key}" \
        --status Inactive \
        --user-name "${f_aws_username}" \
        --profile "${PROFILE}"

}
# ----------------------------------------------------------------------------------------------------------------
