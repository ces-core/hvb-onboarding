#!/bin/bash
#
# bash scripts/deploy-mainnet.sh

set -eo pipefail

source "${BASH_SOURCE%/*}/common.sh"
# shellcheck disable=SC1091
source "${BASH_SOURCE%/*}/build-env-addresses.sh" mainnet >&2

[[ "$ETH_RPC_URL" && "$(seth chain)" == "ethlive" ]] || die "Please set a mainnet ETH_RPC_URL"
[[ -z "$MIP21_LIQUIDATION_ORACLE" ]] || die 'Please set the MIP21_LIQUIDATION_ORACLE env var'

# TODO: confirm for mainnet deployment
export ETH_GAS=6000000

# TODO: confirm if name/symbol is going to follow the RWA convention
# TODO: confirm with DAO at the time of mainnet deployment if OFH will indeed be 007
[[ -z "$NAME" ]] && NAME="RWA-009"
[[ -z "$SYMBOL" ]] && SYMBOL="RWA009"
#
# WARNING (2021-09-08): The system cannot currently accomodate any LETTER beyond
# "A".  To add more letters, we will need to update the PIP naming convention
# to include the letter.  Unfortunately, while fixing this on-chain and in our
# code would be easy, RWA001 integrations may already be using the old PIP
# naming convention.  So, before we can have new letters we must:
# 1. Change the existing PIP naming convention
# 2. Change all the places that depend on that convention (this script included)
# 3. Make sure all integrations are ready to accomodate that new PIP name.
# ! TODO: check with team/PE if this is still the case
#
[[ -z "$LETTER" ]] && LETTER="A";

ILK="${SYMBOL}-${LETTER}"
ILK_ENCODED=$(seth --to-bytes32 "$(seth --from-ascii ${ILK})")

# build it
make build

# tokenize it
[[ -z "$RWA_TOKEN" ]] && {
    log 'WARNING: `$RWA_TOKEN` not set. Deploying it...'
    TX=$(seth send --async "${RWA_TOKEN_FAB}" 'createRwaToken(string,string,address)' \"$NAME\" \"$SYMBOL\" "$MCD_PAUSE_PROXY")
    log "TX: $TX"

    RECEIPT="$(seth receipt $RWA_TOKEN_CREATE_TX)"
    TX_STATUS="$(awk '/^status/ { print $2 }' <<<"$RECEIPT")"
    [[ "$TX_STATUS" != "1" ]] && die "Failed to create ${SYMBOL} token in tx ${TX}."

    RWA_TOKEN="$(seth call "$RWA_TOKEN_FAB" "tokenAddresses(bytes32)(address)" $(seth --from-ascii "$SYMBOL"))"
}

# route it
[[ -z "$DESTINATION_ADDRESS" ]] && die "DESTINATION_ADDRESS is not set"

# join it
RWA_JOIN=$(dapp create AuthGemJoin "$MCD_VAT" "$ILK_ENCODED" "$RWA_TOKEN")
seth send "$RWA_JOIN" 'rely(address)' "$MCD_PAUSE_PROXY" &&
    seth send "$RWA_JOIN" 'deny(address)' "$ETH_FROM"

# urn it
RWA_URN=$(dapp create RwaUrn2 "$MCD_VAT" "$MCD_JUG" "$RWA_JOIN" "$MCD_JOIN_DAI" "$DESTINATION_ADDRESS")
seth send "$RWA_URN" 'rely(address)' "$MCD_PAUSE_PROXY" &&
    seth send "$RWA_URN" 'deny(address)' "$ETH_FROM"

# jar it
[[ -z "$RWA_JAR" ]] && {
    RWA_JAR=$(dapp create RwaJar "$MCD_JOIN_DAI" "$MCD_VOW")
    log "${SYMBOL}_${LETTER}_JAR: ${RWA_JAR}"
}

# print it
cat << JSON
{
    "MIP21_LIQUIDATION_ORACLE": "${MIP21_LIQUIDATION_ORACLE}",
    "RWA_TOKEN_FAB": "${RWA_TOKEN_FAB}",
    "SYMBOL": "${SYMBOL}",
    "NAME": "${NAME}",
    "ILK": "${ILK}",
    "${SYMBOL}": "${RWA_TOKEN}",
    "MCD_JOIN_${SYMBOL}_${LETTER}": "${RWA_JOIN}",
    "${SYMBOL}_${LETTER}_URN": "${RWA_URN}",
    "${SYMBOL}_${LETTER}_JAR": "${RWA_JAR}",
    "${SYMBOL}_${LETTER}_OUTPUT_CONDUIT": "${DESTINATION_ADDRESS}"
}
JSON
