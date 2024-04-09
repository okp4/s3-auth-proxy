# S3 auth proxy

> S3 proxy ensuring authentication and authorization layer based on OKP4.

[![version](https://img.shields.io/github/v/release/okp4/s3-auth-proxy?style=for-the-badge&logo=github)](https://github.com/okp4/s3-auth-proxy/releases)
[![lint](https://img.shields.io/github/actions/workflow/status/okp4/s3-auth-proxy/lint.yml?branch=main&label=lint&style=for-the-badge&logo=github)](https://github.com/okp4/s3-auth-proxy/actions/workflows/lint.yml)
[![build](https://img.shields.io/github/actions/workflow/status/okp4/s3-auth-proxy/build.yml?branch=main&label=build&style=for-the-badge&logo=github)](https://github.com/okp4/s3-auth-proxy/actions/workflows/build.yml)
[![test](https://img.shields.io/github/actions/workflow/status/okp4/s3-auth-proxy/test.yml?branch=main&label=test&style=for-the-badge&logo=github)](https://github.com/okp4/s3-auth-proxy/actions/workflows/test.yml)
[![codecov](https://img.shields.io/codecov/c/github/okp4/s3-auth-proxy?style=for-the-badge&token=6NL9ICGZQS&logo=codecov)](https://codecov.io/gh/okp4/s3-auth-proxy)
[![conventional commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow.svg?style=for-the-badge&logo=conventionalcommits)](https://conventionalcommits.org)
[![semantic-release](https://img.shields.io/badge/%20%20%F0%9F%93%A6%F0%9F%9A%80-semantic--release-e10079.svg?style=for-the-badge)](https://github.com/semantic-release/semantic-release)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg?style=for-the-badge)](https://github.com/okp4/.github/blob/main/CODE_OF_CONDUCT.md)
[![License](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg?style=for-the-badge)](https://opensource.org/licenses/BSD-3-Clause)

## Prerequisites

- Be sure you have [Golang](https://go.dev/doc/install) installed.
- [Docker](https://docs.docker.com/engine/install/) as well if you want to use the Makefile.

## Build

```sh
make build
```

## Example

Hereafter is presented an example using this proxy locally, providing all the needed elements to feed a local dataverse and interact with it.

Through this example, we'll have a [Minio](https://github.com/minio/minio) instance declared as a digital storage service with an attached governance allowing usage in a specific zone. And a dataset representing a single file with a governance allowing the same zone and a specific orchestration service, the dataset will use the minio as storage service.

We'll see how we can submit an execution order to set the file accessible through the proxy by being authenticated as the orchestration service.

### Prerequistes

Some tools are needed in order to run the example:

- [docker](https://docs.docker.com/engine/install/)
- [okp4d](https://github.com/okp4/okp4d)
- [jsonld](https://github.com/digitalbazaar/jsonld-cli)

The local chain must be running with our [contracts](https://github.com/okp4/contracts) stored.

The local configuration of `okp4d` in `$OKP4D_HOME/config/client.toml` shall be self-sufficient to sign and broadcast transaction without additional command flags (e.g. `--chain-id`, `--keyring-backend`, etc..)

### Steps

#### Instantiate Smart contracts

For each contract instantiation, keep the contract addresses, as they will be required for future interactions. You can inspect the transaction hash generated by the broadcasting process with `okp4d query tx $TX_HASH` and look for the events section.

Let's begin with the objectarium:

```bash
okp4d tx wasm instantiate $OBJECTARIUM_CODE_ID \
    --label "my-prologtarium" \
    --from $MY_WALLET_ADDR \
    --admin $MY_WALLET_ADDR \
    --gas 1000000 \
    '{"bucket":"my-prologtarium"}'
```

Now let's create the law-stones containing the minio & dataset prolog governance codes:

```bash
okp4d tx wasm instantiate $LAW_STONE_CODE_ID \
    --label "minio-gov" \
    --from local \
    --admin local \
    --gas 100000000 \
    "{\"program\":\"$(cat example/s3-gov.pl | base64)\", \"storage_address\": \"$OBJECTARIUM_ADDR\"}"
okp4d tx wasm instantiate 2 \
    --label "data-gov" \
    --from local \
    --admin local \
    --gas 100000000 \
    "{\"program\":\"$(cat example/data-gov.pl | base64)\", \"storage_address\": \"$OBJECTARIUM_ADDR\"}"
```

Finally, the dataverse:

```bash
okp4d tx wasm instantiate $DATAVERSE_CODE_ID \
    --label "my-local-dataverse" \
    --from $MY_WALLET_ADDR \
    --admin $MY_WALLET_ADDR \
    --gas 1000000 \
    "{\"name\":\"my-local-dataverse\",\"triplestore_config\":{\"code_id\":\"$COGNITARIUM_CODE_ID\",\"limits\":{}}}"
```

#### Declare resources

Now let's declare the storage service and the dataset in the dataverse: we'll have for each one two verifiable credentials, one for the description and one referencing the governance. Then, another one will be needed to express that the dataset is served by our minio storage service, providing its protected proxy URL. Those verifiable credentials are available here:

- [example/vc-s3-desc.jsonld](example/vc-s3-desc.jsonld)
- [example/vc-s3-gov.jsonld](example/vc-s3-gov.jsonld)
- [example/vc-data-desc.jsonld](example/vc-data-desc.jsonld)
- [example/vc-data-gov.jsonld](example/vc-data-gov.jsonld)
- [example/vc-publish.jsonld](example/vc-publish.jsonld)

Before submitting them we need to update the law stone addresses related to the governances in the [example/vc-s3-gov.jsonld](example/vc-s3-gov.jsonld) and [example/vc-data-gov.jsonld](example/vc-data-gov.jsonld) credentials.

Those VCs are not signed. For that we'll need to have some cryptographic keys to act as the issuers of those verifiable credentials. To facilitate this, we provide a keyring located at [example/keyring-test](example/keyring-test).
You can list the keys with `okp4d --keyring-backend test --keyring-dir example keys list` if needed.

To sign and submit the verifiable credentials we have a simple script that you can use:

```bash
./scripts/setup.sh $MY_WALLET_ADDR $DATAVERSE_ADDR
```

#### Run the infrastructure

Here we need to run the minio and deploy our dataset on it. For that, we provide a [docker-compose.yml](docker-compose.yml): it will run a MinIO instance accessible at `http://localhost:9000`.For demonstration purposes, this setup will make the `README` file of this project available as part of the dataset at `http://localhost:9000/test/README.md`.
You can start the compose with:

```bash
docker compose up
```

Now we'll run the proxy through which we'll connect to the dataverse with:

```bash
./target/dist/s3-auth-proxy start --listen-addr 0.0.0.0:8080 \
    --jwt-secret-key 1d5be173d43385b984ef8c73fe4fb9e5ca5a31466f20bf8a250d06eec5f3079b \
    --s3-endpoint localhost:9000 \
    --s3-access-key minioadmin \
    --s3-secret-key minioadmin \
    --s3-insecure \
    --grpc-no-tls \
    --dataverse-addr $DATAVERSE_ADDR \
    --svc-id did:key:zQ3shbn6v6Mwtc6nSe5LnBmBY44seFqdRKXtf5eH8tQknZCcw
```

#### Order an execution

For this step, we'll act ourselves as the initiator of the execution order, and the orchestration service that'll fulfill the order, to demonstrate the interactions with the proxy.

Let's create the execution order, and the execution containing the status and the parameters:

```bash
./scripts/order-exec.sh $MY_WALLET_ADDR $DATAVERSE_ADDR
```

#### Access the dataset

At this point, submitting an authentication verifiable credential signed with the orchestration service keys we should be able to access the dataset, let's forge this credential:

```bash
./scripts/issue-auth-cred.sh > vc-auth.jsonld
```

And then issue an authentication request to obtain an access token:

```bash
curl -s -X POST -T ./vc-auth.jsonld http://localhost:8080/auth
```

Now we should be able to get through the proxy authorization layer with our access token:

```bash
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8080/test/README.md
```

#### Terminate the execution

We just need to submit a credential expressing an execution status of delivered:

```bash
./scripts/end-exec.sh $MY_WALLET_ADDR $DATAVERSE_ADDR
```

At this point we're not anymore capable to access the dataset.
