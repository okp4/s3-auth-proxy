#! /bin/bash

set -euo pipefail

if [ $# != 4 ]; then
    echo "Usage: $0 [vc_file] [signer] [sender_addr] [dataverse_addr]"
    exit 1
fi

BASEDIR=$(dirname "$0")

mkdir -p "${BASEDIR}"/tmp

# Sign the verifiable credential
axoned --keyring-backend test --keyring-dir "${BASEDIR}"/../example credential sign --from "$2" "$1" > "${BASEDIR}"/tmp/vc-signed.jsonld

# Convert the jsonld VC to N-Quads
jsonld toRdf -q "${BASEDIR}"/tmp/vc-signed.jsonld > "${BASEDIR}"/tmp/vc.nq

# Submit the VC to the dataverse
TX_HASH=$(axoned tx wasm execute --from "$3" "$4" --gas 20000000000 --yes -ojson \
    "{\"submit_claims\":{\"metadata\":\"$(base64 < "${BASEDIR}"/tmp/vc.nq)\"}}" \
    | jq -r '.txhash')

# Wait for the tx to pass
axoned query event-query-tx-for "$TX_HASH" > /dev/null || true

echo "Submitted claim '$1', tx: '$TX_HASH'"

rm -rf "${BASEDIR}"/tmp
