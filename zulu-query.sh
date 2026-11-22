#!/usr/bin/bash

set -euo pipefail

# Utility functions
msg() {
    printf "\e[1;34m:: %s\e[0m\n" "$1"
}

msg2() {
    printf "\e[1;32m==>\e[0m \e[1;34m%s\e[0m\n" "$1"
}

msg3() {
    printf "\e[1;32m ->\e[0m \e[1;34m%s\e[0m\n" "$1"
}

ask() {
    printf "\e[1;32m==>\e[0m %s\n" "$1"
}

note() {
    printf "\e[1;33m ->\e[0m %s\n" "$1"
}

pass() {
    printf "\e[1;32m==> %s\e[0m\n" "$1"
}

warn() {
    printf "\e[1;33m==> WARNING: %s\e[0m\n" "$1" >&2
}

err() {
    printf "\e[1;31m==> ERROR: %s\e[0m\n" "$1" >&2
}

# Dependency check
for cmd in curl jq; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        err "Missing required dependency '${cmd}'. Please install it first." >&2
        exit 1
    fi
done

# Prompt
msg "Capturing input target type..."

# Select API source
msg2 "Capturing API source..."
echo ""
echo "  1) Azul Zulu Official API"
echo "  2) Foojay Disco API (Discovery API)"
echo ""
read -rp "$(ask "Enter choice [1-2] (default=1): ")" API_CHOICE

case "${API_CHOICE}" in
    1|"") API_SOURCE="azul" ;;
    2) API_SOURCE="disco" ;;
    *) err "Invalid option. Exiting." >&2; exit 1 ;;
esac

# Select target CPU architecture
msg2 "Capturing target CPU architecture..."
echo ""
echo "  1) x64 (x86_64)"
echo "  2) x86 (x86_32)"
echo "  3) aarch64 (ARM64)"
echo "  4) arm (ARM32)"
echo ""
read -rp "$(ask "Enter choice [1-4] (default=1): ")" ARCH_CHOICE

case "${ARCH_CHOICE}" in
    1|"") ARCH="x64" ;;
    2) ARCH="x86" ;;
    3) ARCH="aarch64" ;;
    4) ARCH="arm" ;;
    *) err "Invalid option. Exiting." >&2; exit 1 ;;
esac

# Select Java major version
msg2 "Capturing Java major version..."
echo ""
echo "  1) Latest"
echo "  2) 25"
echo "  3) 21"
echo "  4) 17"
echo "  5) 11"
echo "  6) 8"
echo "  7) Custom"
echo ""
read -rp "$(ask "Enter choice [1-7] (default=1): ")" VER_CHOICE

case "${VER_CHOICE}" in
    1|"") JAVA_VERSION="" ;;
    2) JAVA_VERSION="25" ;;
    3) JAVA_VERSION="21" ;;
    4) JAVA_VERSION="17" ;;
    5) JAVA_VERSION="11" ;;
    6) JAVA_VERSION="8" ;;
    7)
        read -rp "$(ask "Enter custom Java major version: ")" CUSTOM_VER
        if [[ "${CUSTOM_VER}" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
            note "Attempt to use a custom version ${CUSTOM_VER} to match remote data."
            JAVA_VERSION="${CUSTOM_VER}"
        else
            err "Invalid version format. Exiting." >&2
            exit 1
        fi
        ;;
    *) err "Invalid option. Exiting." >&2; exit 1 ;;
esac

# Select package type
msg2 "Capturing package type..."
echo ""
echo "  1) JDK"
echo "  2) JDK FX"
echo "  3) JDK CRaC"
echo "  4) JRE"
echo "  5) JRE FX"
echo "  6) JRE CRaC"
echo ""
read -rp "$(ask "Enter choice [1-6] (default=1): ")" PKG_CHOICE

case "${PKG_CHOICE}" in
    1|"") PKG_TYPE="jdk"; JAVAFX="false"; CRAC="false" ;;
    2) PKG_TYPE="jdk"; JAVAFX="true";  CRAC="false" ;;
    3) PKG_TYPE="jdk"; JAVAFX="false"; CRAC="true"  ;;
    4) PKG_TYPE="jre"; JAVAFX="false"; CRAC="false" ;;
    5) PKG_TYPE="jre"; JAVAFX="true";  CRAC="false" ;;
    6) PKG_TYPE="jre"; JAVAFX="false"; CRAC="true"  ;;
    *) err "Invalid option. Exiting." >&2; exit 1 ;;
esac

# Select archive type
msg2 "Capturing archive type..."
echo ""
echo "  1) tar.gz"
echo "  2) zip"
echo "  3) deb"
echo "  4) rpm"
echo ""
read -rp "$(ask "Enter choice [1-4] (default=1): ")" ARCHIVE_CHOICE

case "${ARCHIVE_CHOICE}" in
    1|"") ARCHIVE="tar.gz" ;;
    2) ARCHIVE="zip" ;;
    3) ARCHIVE="deb" ;;
    4) ARCHIVE="rpm" ;;
    *) err "Invalid option. Exiting." >&2; exit 1 ;;
esac

# Prompt
pass "Selection complete."
echo "API: ${API_SOURCE}, Arch: $ARCH, Java: ${JAVA_VERSION:-latest}, Type: ${PKG_TYPE}, FX: ${JAVAFX}, CRaC: ${CRAC}"
msg "Fetching remote data..."

if [[ "${API_SOURCE}" == "azul" ]]; then

    # Azul Zulu Official API
    API_BASE="https://api.azul.com/metadata/v1/zulu/packages"
    QUERY="os=linux&arch=${ARCH}&archive_type=${ARCHIVE}&java_package_type=${PKG_TYPE}&javafx_bundled=${JAVAFX}&crac_supported=${CRAC}&release_status=ga&availability_types=CA&latest=true"

    if [[ -n "${JAVA_VERSION}" ]]; then
        QUERY="${QUERY}&java_version=${JAVA_VERSION}"
    fi

    RAW_RESP=$(curl -fsSL "${API_BASE}/?${QUERY}")
    PKG_INFO=$(printf '%s' "${RAW_RESP}" | jq -c '
        if type == "array" then
            sort_by(.java_version // []) | reverse | .[0] // empty
        else
            empty
        end
    ')

    if [[ -z "${PKG_INFO}" ]]; then
        err "No matching Zulu package found (API: azul, Arch: ${ARCH}, Java: ${JAVA_VERSION:-latest}, Type: ${PKG_TYPE}, FX: ${JAVAFX}, CRaC: ${CRAC})." >&2
        exit 1
    fi

    UUID=$(printf '%s' "${PKG_INFO}" | jq -r '.package_uuid // ""')
    FILE_NAME=$(printf '%s' "${PKG_INFO}" | jq -r '.name // ""')
    ZULU_VER=$(printf '%s' "${PKG_INFO}" | jq -r '(.distro_version // []) | (if .[-1] == 0 then .[:-1] else . end) | join(".")')
    JAVA_VER=$(printf '%s' "${PKG_INFO}" | jq -r '(.java_version // []) | join(".")')
    DOWNLOAD_URL=$(printf '%s' "${PKG_INFO}" | jq -r '.download_url // ""')

    # Fetch SHA-256 hash from package details
    SHA256=$(curl -fsSL "${API_BASE}/${UUID}" | jq -r '.sha256_hash // ""')
else

    # Foojay Disco API v3.0
    API_BASE="https://api.foojay.io/disco/v3.0/packages"
    QUERY="distro=zulu&operating_system=linux&libc_type=glibc&architecture=${ARCH}&archive_type=${ARCHIVE}&package_type=${PKG_TYPE}&javafx_bundled=${JAVAFX}&release_status=ga&latest=available"

    if [[ -n "${JAVA_VERSION}" ]]; then
        QUERY="${QUERY}&version=${JAVA_VERSION}"
    fi

    RAW_RESP=$(curl -fsSL "${API_BASE}?${QUERY}")
    PKG_INFO=$(printf '%s' "${RAW_RESP}" | jq -c --arg crac "${CRAC}" '
        (if type == "object" and (.result | type) == "array" then .result else [] end)
        | map(select(
            ((.filename // "") != "") and
            (
                ((.feature // [] | index("crac")) != null) or
                ((.filename // "") | ascii_downcase | contains("crac"))
            ) == ($crac == "true")
        ))
        | sort_by((.java_version // "") | gsub("\\+"; ".") | split(".") | map(tonumber? // 0))
        | reverse
        | .[0] // empty
    ')

    if [[ -z "${PKG_INFO}" ]]; then
        API_MSG=$(printf '%s' "${RAW_RESP}" | jq -r 'if type == "object" then (.message // empty) else empty end')
        if [[ -n "${API_MSG}" ]]; then
            err "Disco API message: ${API_MSG}" >&2
        else
            err "No matching Zulu package found (API: disco, Arch: ${ARCH}, Java: ${JAVA_VERSION:-latest}, Type: ${PKG_TYPE}, FX: ${JAVAFX}, CRaC: ${CRAC})." >&2
        fi
        exit 1
    fi

    FILE_NAME=$(printf '%s' "${PKG_INFO}" | jq -r '.filename // ""')
    ZULU_VER=$(printf '%s' "${PKG_INFO}" | jq -r '(.distribution_version // "") | split(".") | (if .[-1] == "0" then .[:-1] else . end) | join(".")')
    JAVA_VER=$(printf '%s' "${PKG_INFO}" | jq -r '.java_version // ""')
    PKG_INFO_URI=$(printf '%s' "${PKG_INFO}" | jq -r '.links.pkg_info_uri // ""')

    if [[ -z "${PKG_INFO}_URI" ]]; then
        err "Missing package detail URI in Disco API response." >&2
        exit 1
    fi

    # Fetch download URL and SHA-256 hash from package info URI
    PKG_DETAIL=$(curl -fsSL "${PKG_INFO_URI}" | jq -c '(if type == "object" and (.result | type) == "array" then .result[0] else empty end) // empty')
    if [[ -z "${PKG_DETAIL}" ]]; then
        err "Failed to retrieve package details from ${PKG_INFO_URI}." >&2
        exit 1
    fi

    DOWNLOAD_URL=$(printf '%s' "${PKG_DETAIL}" | jq -r '.direct_download_uri // ""')
    SHA256=$(printf '%s' "${PKG_DETAIL}" | jq -r '.checksum // ""')
fi

# Check if any fields are empty
if [[ -z "${FILE_NAME}" || -z "${ZULU_VER}" || -z "${JAVA_VER}" || -z "${SHA256}" || -z "${DOWNLOAD_URL}" ]]; then
    note "Incomplete package metadata, empty fields detected."
fi

# Prompt
pass "Data retrieved successfully."

# Output data
cat <<EOF
File Name: ${FILE_NAME}
Zulu Version: ${ZULU_VER}
Java Version: ${JAVA_VER}
SHA-256: ${SHA256}
Download URL: ${DOWNLOAD_URL}
EOF
