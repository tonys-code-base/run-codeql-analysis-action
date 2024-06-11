#!/bin/bash

shopt -s dotglob

export TERM=xterm-256color

RED_FG=$(tput setaf 1)
GREEN_FG=$(tput setaf 2)
YELLOW_FG=$(tput setaf 3)
BLUE_FG=$(tput setaf 117)
UNDERLINE=$(tput smul)
RESET=$(tput sgr0)

function create_codeql_db() {

    local DB_PATH="$1"
    local SRC="$2"
    local LANGUAGE_NAME="$3"
    local ARGS_COMPILE_LANG="$4"

    mkdir -p "${DB_PATH}/${LANGUAGE_NAME}"

    cql_create_db="codeql database create ${DB_PATH}/${LANGUAGE_NAME} --source-root=${SRC} --language=${LANGUAGE_NAME} ${ARGS_COMPILE_LANG}"

    if ! $cql_create_db; then
        exit 1
    fi

    cql_upgrade_db="codeql database upgrade "${DB_PATH}/${LANGUAGE_NAME}""

    if ! $cql_upgrade_db; then
        exit 1
    fi
}

function run_codeql_analyze() {
    local DB_PATH="$1"
    local LANGUAGE_NAME="$2"
    local QUERY_SUITE="$3"
    local SARIF_PATH="$4"

    cql_analyze_db="codeql database analyze ${DB_PATH}/${LANGUAGE_NAME} \
      ${QUERY_SUITE} \
        --sarif-category=${LANGUAGE_NAME} \
        --format=sarifv2.1.0 \
        --output=${SARIF_PATH} \
        --no-rerun \
        --sarif-include-query-help=always \
        --sublanguage-file-coverage \
        --sarif-add-snippets \
        --sarif-add-baseline-file-info \
        --verbosity=warnings \
        --threads=0"

    if ! $cql_analyze_db; then
        exit 1
    fi
}

function upload_sarif() {
    local GIT_ORG_REPO="${1}"
    local REF="${2}"
    local HASH="${3}"
    local SARIF="${4}"
    local SRC="${5}"

    cql_upload_sarif_cmd="codeql github upload-results \
        --repository=${GIT_ORG_REPO} \
        --ref=${REF} \
        --commit=${HASH} \
        --sarif=${SARIF} \
        --checkout-path=${SRC} \
        --github-url=https://github.com/ \
        --format=text \
        --quiet"

    if cql_sarif_log=$($cql_upload_sarif_cmd 2>&1); then
        echo -e "${BLUE_FG}Sarif file successfully uploaded to GitHub:${SARIF}${RESET}"
        echo -e "${BLUE_FG}${cql_sarif_log}${RESET}"
        cql_sarif_output_log=+="${cql_sarif_log}\n"
        echo -e "cql_sarif_output_log=${cql_sarif_output_log}" >>"GITHUB_OUTPUT"
    else
        echo -e "${RED_FG}Error: Failed trying to upload sarif:${SARIF}${RESET}"
        cql_sarif_output_log=+="${cql_sarif_log}\n"
        echo -e "${RED_FG}${cql_sarif_output_log}.${RESET}"
        exit 1
    fi

}

cd "${INPUT_CODEQL_HOME}" || exit 1

echo -e "${BLUE_FG}${UNDERLINE}Beginning CodeQL scan for the following target:${RESET}"
echo -e "${BLUE_FG}      • repository: ${INPUT_REPO}${RESET}"
echo -e "${BLUE_FG}      • ref       : ${INPUT_REF}${RESET}"

ROOT_WORKSPACE_PATH="${INPUT_CODEQL_HOME}/workspaces"

if test -e "${ROOT_WORKSPACE_PATH}/"; then
    rm -fr "${ROOT_WORKSPACE_PATH:?}"/*
fi

CODEQL_PROJECT_DB_PATH="${ROOT_WORKSPACE_PATH}/db"
CODEQL_PROJECT_RESULTS_PATH="${ROOT_WORKSPACE_PATH}/results"

mkdir -p "${ROOT_WORKSPACE_PATH}"
mkdir -p "${CODEQL_PROJECT_DB_PATH}"
mkdir -p "${CODEQL_PROJECT_RESULTS_PATH}"

if ! cd "${INPUT_CODEQL_HOME}"; then
    echo -e "${RED_FG}Could not cd into checked out repo. Exiting...${RESET}"
    exit 1
fi

echo -e "${BLUE_FG}CodeQL database path : ${CODEQL_PROJECT_DB_PATH}${RESET}"
echo -e "${BLUE_FG}CodeQL results path  : ${CODEQL_PROJECT_RESULTS_PATH}${RESET}"

if [[ -n "${LANGUAGE_TO_SCAN}" ]]; then
    readarray -d ',' -t discovered_langs < <(echo -n "${LANGUAGE_TO_SCAN}")
    echo -e "${BLUE_FG}Will run CodeQL scan for the following language(s) --> ${discovered_langs[*]}${RESET}"

else
    echo -e "${RED_FG}Input language(s) not provided.${RESET}"
    exit 1
fi

mapfile -t supported_langs \
    < <(
        jq -r '[.languages_supported[]
               | .name
               | ascii_downcase
               | if . == "typescript" then "javascript" else . end]
               | sort_by(.)|unique|.[]' \
            "${INPUT_GITHUB_ACTION_PATH}/config/codeql/supported_codeql_langs.json"
    )

mapfile -t supported_langs_compiled_true \
    < <(
        jq -r '.languages_supported[]
               | select(.can_compile == true)
               | .name
               | ascii_downcase' \
            "${INPUT_GITHUB_ACTION_PATH}/config/codeql/supported_codeql_langs.json"
    )

for lang in "${discovered_langs[@]}"; do
    if [[ "${supported_langs[*]}" =~ ${lang} ]]; then
        echo -e "${BLUE_FG}This action supports CodeQL scanning for \"${lang}\".${RESET}"

        if [[ -n "${INPUT_CODEQL_SCAN_TYPE}" ]]; then
            query_suite="$(
                jq -r \
                    --arg INPUT_CODEQL_SCAN_TYPE_jq "${INPUT_CODEQL_SCAN_TYPE}" \
                    --arg lang_jq "${lang}" \
                    '.qlpacks_qry_suites[$INPUT_CODEQL_SCAN_TYPE_jq]|.[$lang_jq]' \
                    "${INPUT_GITHUB_ACTION_PATH}/config/codeql/supported_codeql_langs.json"
            )"
        else
            default_suite=code-scanning
            query_suite="$(
                jq -r \
                    --arg INPUT_CODEQL_SCAN_TYPE_jq ${default_suite} \
                    --arg lang_jq "${lang}" \
                    '.qlpacks_qry_suites[$INPUT_CODEQL_SCAN_TYPE_jq]|.[$lang_jq]' \
                    "${INPUT_GITHUB_ACTION_PATH}/config/codeql/supported_codeql_langs.json"
            )"
        fi

        if [[ "${supported_langs_compiled_true[*]}" =~ ${lang} ]]; then

            echo -e "${BLUE_FG}Language, ${lang} is 'compilable'.${RESET}"

            if [[ "${INPUT_BUILD_MODE}" == "none" || "${INPUT_BUILD_MODE}" == "autobuild" ]]; then
                ARGS="--build-mode=${INPUT_BUILD_MODE}"
            elif [[ "${INPUT_BUILD_MODE}" == "manual" && -n "${INPUT_BUILD_CMD}" ]]; then
                ARGS="--build-mode=${INPUT_BUILD_MODE} --command=${INPUT_BUILD_CMD}"
            else
                ARGS='--build-mode=none'
            fi
            echo -e "${BLUE_FG}Will pass, \"${ARGS}\", to \"codeql database analyze\" phase.${RESET}"
        fi

        if [[ -n "${INPUT_CODEQL_CONFIG_FILE}" ]]; then
            echo -e "${BLUE_FG}CodeQL scan config file was provided as input: ${INPUT_CODEQL_CONFIG_FILE}${RESET}"
            if [ -f "${INPUT_CODEQL_CONFIG_FILE}" ]; then
                ARGS="${ARGS} --codescanning-config=${INPUT_CODEQL_CONFIG_FILE}"
            else
                echo -e "${RED_FG}Error: Config file does not exist: ${INPUT_CODEQL_CONFIG_FILE}.${RESET}"
                exit 1
            fi
        fi

        echo -e "${BLUE_FG}Scan will be performed using query suite: ${query_suite}.${RESET}"

        create_codeql_db "${CODEQL_PROJECT_DB_PATH}" "${INPUT_CODEQL_HOME}" "${lang}" "${ARGS}"

        SARIF_PATH="${CODEQL_PROJECT_RESULTS_PATH}/${lang}.sarif"

        run_codeql_analyze "${CODEQL_PROJECT_DB_PATH}" "${lang}" "${query_suite}" "${SARIF_PATH}"

        upload_sarif "${INPUT_REPO}" "${INPUT_REF}" "${INPUT_HASH}" "${SARIF_PATH}" "${INPUT_CODEQL_HOME}"

        echo -e "${GREEN_FG}CodeQL scan complete for:${RESET}"
        echo -e "${GREEN_FG}      • repository: ${INPUT_REPO}${RESET}"
        echo -e "${GREEN_FG}      • ref       : ${INPUT_REF}${RESET}"
        echo -e "${GREEN_FG}      • language  : ${lang}${RESET}"
    else
        echo -e "${YELLOW_FG}Scanning for language ${lang} is NOT currently supported...skipping.${lang}${RESET}"
    fi
done

cd "${INPUT_CODEQL_HOME}" || exit 1
rm -fr "${ROOT_WORKSPACE_PATH}"
