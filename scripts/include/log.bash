function LogDebug() {
    local message=$1

    if [[ -n $2 ]]; then
        local context=$2
        echo -e "\e[92m[DEBUG]\e[39m [${context}] ${message}"
    else
        echo -e "\e[92m[DEBUG]\e[39m ${message}"
    fi
}

function LogInfo() {
    local message=$1

    if [[ -n $2 ]]; then
        local context=$2
        echo -e "\e[94m[INFO]\e[39m  [${context}] ${message}"
    else
        echo -e "\e[94m[INFO]\e[39m  ${message}"
    fi
}

function LogError() {
    local message=$1
    local exit=${2:false}

    echo -e "\e[91m[ERROR]\e[39m ${message}"

    if $exit; then
        exit 1
    fi
}
