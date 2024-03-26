#! /bin/bash

set -eu

if [ $# != 4 ]; then
    echo "Usage: $0 [vc_file] [signer] [sender_addr] [dataverse_addr]"
    exit 1
fi

BASEDIR=$(dirname $0)

mkdir -p ${BASEDIR}/tmp

# Sign the verifiable credential
okp4d --keyring-backend test --keyring-dir ${BASEDIR}/../example credential sign --from $2 $1 > ${BASEDIR}/tmp/vc-signed.jsonld

# Convert the jsonld VC to N-Quads
jsonld toRdf -q ${BASEDIR}/tmp/vc-signed.jsonld > ${BASEDIR}/tmp/vc.nq

# Submit the VC to the dataverse
okp4d tx wasm execute --from $3 $4 --gas 20000000000 \
    "{\"submit_claims\":{\"metadata\":\"$(cat ${BASEDIR}/tmp/vc.nq | base64)\"}}"

rm -rf tmp
