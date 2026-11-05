#!/usr/bin/env bash
#
# Bulk rotation of AWS IAM access keys for service users.
#
# Usage:   ./main-bulk-rotate-iam-keys.sh <info-file> <action>
#
#   <info-file>  one "iam_username|aws_cli_profile" per line ('#' = comment)
#   <action>     list        show keys, status, create date and last use
#                inactivate  inactivate the oldest key (only if 2 are active)
#                delete      delete the oldest inactive key
#                create      create a second key (only if the user has 1 key)
#
# It can be started from any directory. The <info-file> path is relative to the
# directory you start it from (or absolute); tmp/ and layer-*.sh are found next
# to this script.
# Each change asks for confirmation (y/n) before it is made.

# shellcheck disable=SC2034  # variables below are used by the sourced layer-*.sh files

# Stop on any failed command (e.g. a failed `aws` call), on unset variables,
# and on failures inside pipelines. -E lets the ERR trap fire inside functions.
set -Eeuo pipefail
trap 'echo -e "\nERROR: command failed (exit code $?) at ${BASH_SOURCE[0]}:${LINENO}. Stopping.\n" >&2' ERR


# --- Settings ----------------------------------------------------------------
# Folder of this script (also when started through a symlink), used for layer-*.sh and tmp/.
script_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# These variables are used by the sourced layer-*.sh files.
mkdir -p "${script_dir}/tmp"
tmp_file_without_comments="${script_dir}/tmp/tmp_file_without_comments.txt"  # info file without comment lines

# Private temp file for the last `aws iam list-access-keys` output: created with
# a random name, readable only by the current user, and removed on exit
# (normal end, error, Ctrl-C or kill).
umask 077
tmp_file=$(mktemp "${TMPDIR:-/tmp}/iam-keys.XXXXXXXXXX")
trap 'rm -f -- "${tmp_file}"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# --- Colors (used by the layer-*.sh functions) -------------------------------
yellow='\033[0;33m'
red='\033[0;31m'
magenta='\033[0;35m'
no_color='\033[0m'

# --- Load functions ----------------------------------------------------------
# shellcheck source=layer-1-main-logic.sh
source "${script_dir}/layer-1-main-logic.sh"
# shellcheck source=layer-2-aws-logic.sh
source "${script_dir}/layer-2-aws-logic.sh"

# --- Key counters ------------------------------------------------------------
# Reset for every user inside the layer-1-main-logic.sh loops and filled by
# f_list_all_user_keys (layer-2-aws-logic.sh).
declare -i k_active=0    # number of Active keys
declare -i k_inactive=0  # number of Inactive keys


# --- Check arguments ---------------------------------------------------------
usage() {
    cat >&2 <<'EOF'

Usage: main-bulk-rotate-iam-keys.sh <info-file> <action>

  <info-file>  File with one "iam_username|aws_cli_profile" per line
  <action>     list | inactivate | delete | create

EOF
}

if [[ $# -ne 2 ]]; then
    echo "ERROR: expected 2 arguments, got $#." >&2
    usage
    exit 1
fi

info_file="$1"
action="$2"

if [[ ! -f "${info_file}" ]]; then
    echo -e "\nERROR: info file (${info_file}) does not exist. Exiting.\n" >&2
    exit 1
fi
echo -e "\nInfo file (${info_file}) found.\n"


# --- Pick the action ---------------------------------------------------------
case "${action}" in
    list)
        message="List keys for users from the info file."
        ;;
    inactivate)
        message="Inactivate the oldest key for users from the info file."
        ;;
    delete)
        message="Delete the oldest inactive key for users from the info file."
        ;;
    create)
        message="Create a new key for users from the info file."
        ;;
    *)
        echo "ERROR: unknown action '${action}'." >&2
        usage
        exit 1
        ;;
esac


# --- Run ---------------------------------------------------------------------
f_remove_comments_from_info_csv_file   # fills ${tmp_file_without_comments}
echo "${message}"
f_process_many_keys "${action}"
