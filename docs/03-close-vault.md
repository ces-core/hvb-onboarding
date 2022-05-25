# Closing the vault

⚠️ Replace the `SYMBOL` variable below accordingly.

## Using Authorized Wallets

1. Read from the proper environment variables:

   ```bash
   SYMBOL="RWA009"
   ```

   ```bash
   var_expand() {
       if [ "$#" -ne 1 ] || [ -z "${1-}" ]; then
           printf 'var_expand: expected one non-empty argument\n' >&2;
       return 1;
           fi
       eval printf '%s' "\"\${$1?}\""
   }

   ILK="${SYMBOL}_A"
   TOKEN=$(var_expand "${SYMBOL}")
   OPERATOR=$(var_expand "${ILK}_OPERATOR")
   MATE=$(var_expand "${ILK}_MATE")
   OUTPUT_CONDUIT=$(var_expand "${ILK}_OUTPUT_CONDUIT")
   URN=$(var_expand "${ILK}_URN")
   ```

2. Estimate the amount required to make the full repayment
   // TODO as we don't ahve input conduit we can close a vault in one transaction.

   **ℹ️ NOTICE:** You might want to &ldquo;overestimate&rdquo; `REPAYMENT_DATE` below so you will send more DAI than it is actually needed to close the vault. Any outstanding DAI after `close()` is called will be automatically sent to the output conduit.

   ```bash
   REPAYMENT_DATE=$(date -d "+7 days" +%s) # i.e.: 7 days from now as UNIX timestamp
   DAI_AMOUNT=$(seth call "$RWA_URN_PROXY_ACTIONS" "estimateWipeAllWad(address, uint)" \
       "$URN" $REPAYMENT_DATE)
   ```

3. Transfer DAI to the URN

   ```bash
   seth send "$MCD_DAI" "transfer(address, uint)" "$URN" $DAI_AMOUNT
   ```

4. Close the vault with the help of `RWA_URN_PROXY_ACTIONS`

   ```bash
   seth send "$RWA_URN_PROXY_ACTIONS" "close(address)" $URN
   ```

   The step above will:

   - Wipe all the debt from the urn
   - Free all the collateral token (`RWA009`) from the urn
   - Send the `RWA009` token to `msg.sender`
   - Transfer any remaining DAI to the `OUTPUT_CONDUIT`

5. Pick the DAI recipient

   ```bash
   seth send "$OPERATOR" "_(address)" "$OUTPUT_CONDUIT"
   seth send "$OPERATOR" "pick(address)" "$OPERATOR"
   ```

6. Push DAI to the recipient

   ```bash
   seth send "$MATE" "_(address)" "$OUTPUT_CONDUIT"
   seth send "$MATE" "push()"
   ```

## Using `ForwardProxy` (dev environment only)

⚠️ Replace the `SYMBOL` variable below accordingly.

1. Read from the proper environment variables:

   ```bash
   SYMBOL="RWA009"
   ```

   ```bash
   var_expand() {
       if [ "$#" -ne 1 ] || [ -z "${1-}" ]; then
           printf 'var_expand: expected one non-empty argument\n' >&2;
       return 1;
           fi
       eval printf '%s' "\"\${$1?}\""
   }

   ILK="${SYMBOL}_A"
   TOKEN=$(var_expand "${SYMBOL}")
   OPERATOR=$(var_expand "${ILK}_OPERATOR")
   MATE=$(var_expand "${ILK}_MATE")
   OUTPUT_CONDUIT=$(var_expand "${ILK}_OUTPUT_CONDUIT")
   URN=$(var_expand "${ILK}_URN")
   ```

2. Estimate the amount required to make the full repayment

   **ℹ️ NOTICE:** You might want to &ldquo;overestimate&rdquo; `REPAYMENT_DATE` below so you will send more DAI than it is actually needed to close the vault. Any outstanding DAI after `close()` is called will be automatically sent to the output conduit.

   ```bash
   REPAYMENT_DATE=$(date -d "+7 days" +%s) # i.e.: 7 days from now as UNIX timestamp
   DAI_AMOUNT=$(seth call "$RWA_URN_PROXY_ACTIONS" "estimateWipeAllWad(address, uint)" \
       "$URN" $REPAYMENT_DATE)
   ```

3. Transfer DAI to the URN

   ```bash
   seth send "$OPERATOR" "_(address)" "$MCD_DAI"
   seth send "$OPERATOR" "transfer(address, uint)" "$URN" $DAI_AMOUNT
   ```

4. Close the vault with the help of `RWA_URN_PROXY_ACTIONS`

   ```bash
   seth send "$OPERATOR" "_(address)" "$RWA_URN_PROXY_ACTIONS"
   seth send "$OPERATOR" "close(address)" $URN
   ```

   The step above will:

   - Wipe all the debt from the urn
   - Free all the collateral token (`RWA008`) from the urn
   - Send the `RWA008` token to `msg.sender`
   - Transfer any remaining DAI to the `OUTPUT_CONDUIT`

5. Pick the DAI recipient

   ```bash
   seth send "$OPERATOR" "_(address)" "$OUTPUT_CONDUIT"
   seth send "$OPERATOR" "pick(address)" "$OPERATOR"
   ```

6. Push DAI to the recipient

   ```bash
   seth send "$MATE" "_(address)" "$OUTPUT_CONDUIT"
   seth send "$MATE" "push()"
   ```
