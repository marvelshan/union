use std::{
    fmt::Debug,
    num::{NonZeroU64, ParseIntError},
};

use ethermint_light_client_types::ClientState;
use ics23::ibc_api::SDK_SPECS;
use jsonrpsee::{
    core::{async_trait, RpcResult},
    types::ErrorObject,
    Extensions,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use tendermint_light_client_types::{ConsensusState, Fraction};
use tracing::{error, instrument};
use unionlabs::{
    ibc::core::{client::height::Height, commitment::merkle_root::MerkleRoot},
    option_unwrap,
    primitives::{Bytes, H160},
    result_unwrap, ErrorReporter,
};
use voyager_sdk::{
    anyhow, ensure_null,
    plugin::ClientBootstrapModule,
    primitives::{ChainId, ClientType},
    rpc::{
        json_rpc_error_to_error_object, types::ClientBootstrapModuleInfo,
        ClientBootstrapModuleServer,
    },
};

#[tokio::main(flavor = "multi_thread")]
async fn main() {
    Module::run().await
}

#[derive(Debug, Clone)]
pub struct Module {
    pub chain_id: ChainId,

    pub cometbft_client: cometbft_rpc::Client,
    pub chain_revision: u64,

    pub ibc_handler_address: H160,
    pub store_key: Bytes,
    pub key_prefix_storage: Bytes,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Config {
    pub rpc_url: String,
    pub ibc_handler_address: H160,
    pub store_key: Bytes,
    pub key_prefix_storage: Bytes,
}

impl ClientBootstrapModule for Module {
    type Config = Config;

    async fn new(config: Self::Config, info: ClientBootstrapModuleInfo) -> anyhow::Result<Self> {
        let cometbft_client = cometbft_rpc::Client::new(config.rpc_url).await?;

        let chain_id = cometbft_client
            .status()
            .await?
            .node_info
            .network
            .to_string();

        info.ensure_chain_id(&chain_id)?;
        info.ensure_client_type(ClientType::ETHERMINT)?;

        let chain_revision = chain_id
            .split('-')
            .next_back()
            .ok_or_else(|| ChainIdParseError {
                found: chain_id.clone(),
                source: None,
            })?
            .parse()
            .map_err(|err| ChainIdParseError {
                found: chain_id.clone(),
                source: Some(err),
            })?;

        Ok(Self {
            cometbft_client,
            chain_id: ChainId::new(chain_id),
            chain_revision,
            ibc_handler_address: config.ibc_handler_address,
            store_key: config.store_key,
            key_prefix_storage: config.key_prefix_storage,
        })
    }
}

#[derive(Debug, thiserror::Error)]
#[error("unable to parse chain id: expected format `<chain>-<revision-number>`, found `{found}`")]
pub struct ChainIdParseError {
    found: String,
    #[source]
    source: Option<ParseIntError>,
}

// in order to support as many tendermint-ish forks as possible, we define only the bare minimum required here to get the unbonding_period field (since that's all we use anyways)
//
// both of these fields use field tag 7:
// max_voting_power_ratio: https://github.com/sei-protocol/sei-cosmos/blob/7780ddba9e56ac67ff4ef339508bf0c047d4a488/proto/cosmos/staking/v1beta1/staking.proto#L292
// jailed_validator_threshold: https://github.com/unionlabs/cosmos-sdk/blob/0f0e36772bd6be187544eb55d022ad92dd91ece1/proto/cosmos/staking/v1beta1/staking.proto#L326

#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct MinimalQueryParamsResponse {
    #[prost(message, optional, tag = "1")]
    pub params: ::core::option::Option<MinimalParams>,
}

#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct MinimalParams {
    /// unbonding_time is the time duration of unbonding.
    #[prost(message, optional, tag = "1")]
    pub unbonding_time: Option<protos::google::protobuf::Duration>,
}

impl Module {
    #[must_use]
    pub fn make_height(&self, height: u64) -> Height {
        Height::new_with_revision(self.chain_revision, height)
    }
}

#[async_trait]
impl ClientBootstrapModuleServer for Module {
    #[instrument(skip_all, fields(chain_id = %self.chain_id))]
    async fn self_client_state(
        &self,
        _: &Extensions,
        height: Height,
        config: Value,
    ) -> RpcResult<Value> {
        ensure_null(config)?;

        let commit = self
            .cometbft_client
            .commit(Some(height.height().try_into().unwrap()))
            .await
            .unwrap();

        let params = self
            .cometbft_client
            .grpc_abci_query::<_, MinimalQueryParamsResponse>(
                "/cosmos.staking.v1beta1.Query/Params",
                &protos::cosmos::staking::v1beta1::QueryParamsRequest {},
                Some(i64::try_from(height.height()).unwrap().try_into().unwrap()),
                false,
            )
            .await
            .map_err(json_rpc_error_to_error_object)?
            .value
            .unwrap()
            .params
            .unwrap();

        let height = commit.signed_header.header.height;

        let unbonding_period = std::time::Duration::new(
            params
                .unbonding_time
                .clone()
                .unwrap()
                .seconds
                .try_into()
                .unwrap(),
            params
                .unbonding_time
                .clone()
                .unwrap()
                .nanos
                .try_into()
                .unwrap(),
        );

        Ok(serde_json::to_value(ClientState {
            tendermint_client_state: tendermint_light_client_types::ClientState {
                chain_id: self.chain_id.to_string(),
                // https://github.com/cometbft/cometbft/blob/da0e55604b075bac9e1d5866cb2e62eaae386dd9/light/verifier.go#L16
                trust_level: Fraction {
                    numerator: 1,
                    denominator: const { option_unwrap!(NonZeroU64::new(3)) },
                },
                // https://github.com/cosmos/relayer/blob/23d1e5c864b35d133cad6a0ef06970a2b1e1b03f/relayer/chains/cosmos/provider.go#L177
                trusting_period: unionlabs::google::protobuf::duration::Duration::new(
                    (unbonding_period * 85 / 100).as_secs().try_into().unwrap(),
                    (unbonding_period * 85 / 100)
                        .subsec_nanos()
                        .try_into()
                        .unwrap(),
                )
                .unwrap(),
                unbonding_period: unionlabs::google::protobuf::duration::Duration::new(
                    unbonding_period.as_secs().try_into().unwrap(),
                    unbonding_period.subsec_nanos().try_into().unwrap(),
                )
                .unwrap(),
                // https://github.com/cosmos/relayer/blob/23d1e5c864b35d133cad6a0ef06970a2b1e1b03f/relayer/chains/cosmos/provider.go#L177
                max_clock_drift: const {
                    result_unwrap!(unionlabs::google::protobuf::duration::Duration::new(
                        60 * 10,
                        0
                    ))
                },
                frozen_height: None,
                latest_height: Height::new_with_revision(
                    self.chain_revision,
                    height.inner().try_into().expect("is within bounds; qed;"),
                ),
                proof_specs: SDK_SPECS.into(),
                upgrade_path: vec!["upgrade".into(), "upgradedIBCState".into()],
                contract_address: Default::default(),
            },
            store_key: self.store_key.clone(),
            key_prefix_storage: self.key_prefix_storage.clone(),
            ibc_contract_address: self.ibc_handler_address,
        })
        .unwrap())
    }

    /// The consensus state on this chain at the specified `Height`.
    #[instrument(skip_all, fields(chain_id = %self.chain_id))]
    async fn self_consensus_state(
        &self,
        _: &Extensions,
        height: Height,
        config: Value,
    ) -> RpcResult<Value> {
        ensure_null(config)?;

        let commit = self
            .cometbft_client
            .commit(Some(height.height().try_into().unwrap()))
            .await
            .map_err(|e| {
                ErrorObject::owned(
                    -1,
                    format!("error fetching commit: {}", ErrorReporter(e)),
                    None::<()>,
                )
            })?;

        Ok(serde_json::to_value(&ConsensusState {
            root: MerkleRoot {
                hash: commit.signed_header.header.app_hash.into_encoding(),
            },
            next_validators_hash: commit.signed_header.header.next_validators_hash,
            timestamp: commit.signed_header.header.time,
        })
        .unwrap())
    }
}
