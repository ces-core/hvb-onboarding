# Repaying DAI to get `RWA009`

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

2. Transfer DAI to the URN

   ```bash
   DAI_AMOUNT=$(seth --to-wei 1000 ETH)
   seth send "$MCD_DAI" "transfer(address,uint)" "$URN" $DAI_AMOUNT
   ```

3. Wipe the debt from the urn

   ```bash
   seth send "$URN" "wipe(uint)" $DAI_AMOUNT
   ```

4. Free the gem from the urn [optional]

   ```bash
   TOKEN_AMOUNT=$(seth --to-wei '.01' ETH)
   seth send "$URN" "free(uint)" $TOKEN_AMOUNT
   ```

## Using `ForwardProxy` (dev environment only)

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

2. Transfer DAI to the URN

   ```bash
   DAI_AMOUNT=$(seth --to-wei 1000 ETH)
   seth send "$OPERATOR" "_(address)" "$MCD_DAI"
   seth send "$OPERATOR" "transfer(address,uint)" "$URN" $DAI_AMOUNT
   ```

3. Wipe the debt from the urn

   ```bash
   seth send "$OPERATOR" "_(address)" "$URN"
   seth send "$OPERATOR" "wipe(uint)" $DAI_AMOUNT
   ```

4. Free the gem from the urn

   ```bash
   TOKEN_AMOUNT=$(seth --to-wei '.01' ETH)
   seth send "$OPERATOR" "free(uint)" $TOKEN_AMOUNT
   ```
