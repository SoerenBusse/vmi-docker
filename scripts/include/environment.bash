function GetSecretFromEnvironment() {
    echo "${!1}"
}

function ValidateEnvironmentVariables() {
    # Check whether all required environment variables are set
    for required_env in "$@"; do
        if [[ -z "${!required_env}" ]]; then
            LogError "Missing environment variable ${required_env}" true
        fi
    done
}
