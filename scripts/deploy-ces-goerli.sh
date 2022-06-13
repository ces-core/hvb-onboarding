#!/bin/bash
set -eo pipefail

source "${BASH_SOURCE%/*}/common.sh"
# shellcheck disable=SC1091
source "${BASH_SOURCE%/*}/build-env-addresses.sh" ces-goerli >&2

[[ "$ETH_RPC_URL" && "$(seth chain)" == "goerli" ]] || die "Please set a goerli ETH_RPC_URL"

export ETH_GAS=6000000

# TODO: confirm if name/symbol is going to follow the RWA convention
# TODO: confirm with DAO at the time of mainnet deployment if OFH will indeed be 007
[[ -z "$NAME" ]] && NAME="RWA-009AT1"
[[ -z "$SYMBOL" ]] && SYMBOL="RWA009AT1"
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
[[ -z "$LETTER" ]] && LETTER="A"

# [[ -z "$MIP21_LIQUIDATION_ORACLE" ]] && MIP21_LIQUIDATION_ORACLE="0xDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF"
# TODO: confirm liquidations handling - no liquidations for the time being

ILK="${SYMBOL}-${LETTER}"
log "ILK: ${ILK}"
ILK_ENCODED=$(seth --to-bytes32 "$(seth --from-ascii "$ILK")")

# build it
make build

# tokenize it
[[ -z "$RWA_TOKEN" ]] && {
    log 'WARNING: `$RWA_TOKEN` not set. Deploying it...'
    TX=$(seth send --async "${RWA_TOKEN_FAB}" 'createRwaToken(string,string,address)' \"$NAME\" \"$SYMBOL\" "$MCD_PAUSE_PROXY")
    log "TX: $TX"

    RECEIPT="$(seth receipt $TX)"
    TX_STATUS="$(awk '/^status/ { print $2 }' <<<"$RECEIPT")"
    [[ "$TX_STATUS" != "1" ]] && die "Failed to create ${SYMBOL} token in tx ${TX}."

    RWA_TOKEN="$(seth call "$RWA_TOKEN_FAB" "tokenAddresses(bytes32)(address)" $(seth --from-ascii "$SYMBOL"))"
}
log "${SYMBOL}: ${RWA_TOKEN}"

[[ -z "$OPERATOR" ]] && OPERATOR=$(dapp create ForwardProxy) # using generic forward proxy for goerli
log "${SYMBOL}_${LETTER}_OPERATOR: ${OPERATOR}"

[[ -z "$MATE" ]] && MATE=$(dapp create ForwardProxy) # using generic forward proxy for goerli
log "${SYMBOL}_${LETTER}_MATE: ${MATE}"

# route it
[[ -z "$RWA_OUTPUT_CONDUIT" ]] && {
    RWA_OUTPUT_CONDUIT=$(dapp create RwaOutputConduit2 "$MCD_DAI")
    log "${SYMBOL}_${LETTER}_OUTPUT_CONDUIT: ${RWA_OUTPUT_CONDUIT}"

    # trust addresses for goerli
    seth send "$RWA_OUTPUT_CONDUIT" 'rely(address)' "$MCD_PAUSE_PROXY" &&
        seth send "$RWA_OUTPUT_CONDUIT" 'deny(address)' "$ETH_FROM"

} || {
    log "${SYMBOL}_${LETTER}_OUTPUT_CONDUIT: ${RWA_OUTPUT_CONDUIT}"
}

# join it
RWA_JOIN=$(dapp create AuthGemJoin "$MCD_VAT" "$ILK_ENCODED" "$RWA_TOKEN")
log "MCD_JOIN_${SYMBOL}_${LETTER}: ${RWA_JOIN}"
seth send "$RWA_JOIN" 'rely(address)' "$MCD_PAUSE_PROXY" &&
    seth send "$RWA_JOIN" 'deny(address)' "$ETH_FROM"

# urn it
RWA_URN=$(dapp create RwaUrn2 "$MCD_VAT" "$MCD_JUG" "$RWA_JOIN" "$MCD_JOIN_DAI" "$RWA_OUTPUT_CONDUIT")
log "${SYMBOL}_${LETTER}_URN: ${RWA_URN}"
seth send "$RWA_URN" 'rely(address)' "$MCD_PAUSE_PROXY" &&
    seth send "$RWA_URN" 'deny(address)' "$ETH_FROM"

# jar it
[[ -z "$RWA_JAR" ]] && {
    RWA_JAR=$(dapp create RwaJar "$MCD_JOIN_DAI" "$MCD_VOW")
    log "${SYMBOL}_${LETTER}_JAR: ${RWA_JAR}"
}

# price it
[[ -z "$MIP21_LIQUIDATION_ORACLE" ]] && {
    MIP21_LIQUIDATION_ORACLE=$(dapp create RwaLiquidationOracle "$MCD_VAT" "$MCD_VOW")
    log "MIP21_LIQUIDATION_ORACLE: ${MIP21_LIQUIDATION_ORACLE}"

    seth send "$MIP21_LIQUIDATION_ORACLE" 'rely(address)' "$MCD_PAUSE_PROXY" &&
        seth send "$MIP21_LIQUIDATION_ORACLE" 'deny(address)' "$ETH_FROM"
} || {
    log "MIP21_LIQUIDATION_ORACLE: ${MIP21_LIQUIDATION_ORACLE}"
}

# print it
cat <<JSON
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
    "${SYMBOL}_${LETTER}_OUTPUT_CONDUIT": "${RWA_OUTPUT_CONDUIT}",
    "${SYMBOL}_${LETTER}_OPERATOR": "${OPERATOR}",
    "${SYMBOL}_${LETTER}_MATE": "${MATE}"
}
JSON
