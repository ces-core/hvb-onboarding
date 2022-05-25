#!/bin/bash
set -eo pipefail

source "${BASH_SOURCE%/*}/common.sh"

MCD_FORK="$1"

[[ "$ETH_RPC_URL" && "$(seth chain)" == "goerli" ]] || die "Please set a goerli ETH_RPC_URL"

# shellcheck disable=SC1091
source "${BASH_SOURCE%/*}/build-env-addresses.sh" $MCD_FORK >/dev/null 2>&1

#-1. Approve DSChief to pull MKR from the wallet
MAX_UINT256=$(seth --max-uint)
seth send "$MCD_GOV" "approve(address,uint256)" "$MCD_ADM" $MAX_UINT256

#0. call `chief.lock()` to lock MKR in the chief
# Nikolaj had previously locked 1MM MKR to an empty slate
MKR_VOTE_THRESHOLD=$(seth --to-wei "1500000 ether")
seth send "$MCD_ADM" "lock(uint256)" $MKR_VOTE_THRESHOLD

exit_code=0

#1. Deploy the Spell if required

[ -z "${SPELL_ADDRESS:=$2}" ] && {
  declare -A spell_contracts

  spell_contracts[ces-goerli]='src/spells/CESFork_GoerliRwaSpell.sol:CESFork_RwaSpell'
  spell_contracts[goerli]='src/spells/GoerliRwaSpell.sol:RwaSpell'

  SPELL_ADDRESS=$(dapp create "${spell_contracts[$MCD_FORK]}")
  dapp verify-contract "${spell_contracts[$MCD_FORK]}" "$SPELL_ADDRESS" || exit_code=1
}

#2. call `chief.vote()` and pass in the spell address
seth send "$MCD_ADM" "vote(address[])" "[${SPELL_ADDRESS}]"

#3. call `chief.lift()` and pass in the spell address
seth send "$MCD_ADM" "lift(address)" "$SPELL_ADDRESS"

#4. call `spell.schedule()` and wait...
seth send "$SPELL_ADDRESS" "schedule()"
sleep 120s

#5. call `spell.cast()`
seth send "$SPELL_ADDRESS" "cast()"

exit $exit_code
