#!/usr/bin/env bash
#

# ----------------------------------------------------------------------------------------------------------------
f_list_all_user_keys() {

    f_username="$1"
    aws iam list-access-keys \
        --user-name "${f_username}" \
        --profile "${PROFILE}" \
    > "${tmp_file}"

    echo ""

    while read -r cur_key cur_status cur_create_date
    do
        if [[ ${cur_status} = 'Inactive' ]]; then
            echo -e "-- ${cur_key} - Status: ${red}${cur_status}${no_color} - CreateDate: ${cur_create_date}"
            k_inactive=$(( k_inactive + 1 ))
        else
            echo -e "-- ${cur_key} - Status: ${magenta}${cur_status}${no_color} - CreateDate: ${cur_create_date}"
            k_active=$(( k_active + 1 ))
        fi

        aws iam get-access-key-last-used \
            --access-key-id "${cur_key}" \
            --profile "${PROFILE}"

        echo ""
    done < <(jq -r '.AccessKeyMetadata[] | .AccessKeyId + " " + .Status + " " + .CreateDate' "${tmp_file}")

    echo -e "..Active key:   ${red}${k_active}${no_color}"
    echo -e "..Inactive key: ${red}${k_inactive}${no_color}\n"
}
# ----------------------------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------------------------
# Finds the OLDEST Inactive key (by CreateDate) in "${tmp_file}" (created by f_list_all_user_keys).
# Sets: oldest_inactive_key (empty if the user has no Inactive key).
f_find_oldest_inactive_user_key() {
    oldest_inactive_key=""
    local oldest_inactive_date="" cur_key cur_status cur_create_date

    while read -r cur_key cur_status cur_create_date
    do
        if [[ ${cur_status} = 'Inactive' ]]; then
            if [[ -z ${oldest_inactive_date} || ${oldest_inactive_date} > ${cur_create_date} ]]; then
                oldest_inactive_date=${cur_create_date}
                oldest_inactive_key=${cur_key}
            fi
        fi
    done < <(jq -r '.AccessKeyMetadata[] | .AccessKeyId + " " + .Status + " " + .CreateDate' "${tmp_file}")
}

# Deletes ONE key: $1 = IAM username, $2 = access key ID (the oldest Inactive key).
# Any other Inactive key is left in place, so it can still be re-activated.
f_delete_inactive_user_key() {
    local f_username="$1" f_key="$2"

    echo -e "\n${red}..Deleting Inactive AWS Key: ${f_key}.${no_color}\n"

    aws iam delete-access-key \
        --access-key-id "${f_key}" \
        --user-name "${f_username}" \
        --profile "${PROFILE}"

    echo -e "\n${red}..Inactive AWS Key: ${f_key}${no_color} was deleted.\n"
}
# ----------------------------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------------------------
f_create_new_user_key() {
    
    f_username="$1"

    echo -e "\n..Creating a new AWS Key for user ${f_username}."
    # The new SecretAccessKey is kept only in this variable (memory), never written to disk.
    new_key_json=$(aws iam create-access-key \
        --user-name "${f_username}" \
        --profile "${PROFILE}")

    printf '%s\n' "${new_key_json}"
    printf '%s\n' "${new_key_json}" | jq -r '."AccessKey" | ."AccessKeyId" + "," + ."SecretAccessKey"'
    new_key_json=""
}
# ----------------------------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------------------------
f_find_oldest_active_user_key() {

    # reusing "${tmp_file}"" file created by function: "f_list_all_user_keys"
    oldest_date=""
    while read -r cur_key cur_status cur_create_date
    do
        if [[ -z ${oldest_date} ]]; then
            oldest_date=${cur_create_date}
            oldest_key=${cur_key}
            oldest_status=${cur_status}
        else
            if [[ ${oldest_date} > ${cur_create_date} ]]; then
            oldest_date=${cur_create_date}
            oldest_key=${cur_key}
            oldest_status=${cur_status}
            fi
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
