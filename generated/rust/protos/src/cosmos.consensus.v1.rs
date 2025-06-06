/// ConsensusMsgParams is the Msg/Params request type. This is a consensus message that is sent from cometbft.
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct ConsensusMsgParams {
    /// params defines the x/consensus parameters to be passed from comet.
    ///
    /// NOTE: All parameters must be supplied.
    #[prost(message, optional, tag = "1")]
    pub version: ::core::option::Option<super::super::super::cometbft::types::v1::VersionParams>,
    #[prost(message, optional, tag = "2")]
    pub block: ::core::option::Option<super::super::super::cometbft::types::v1::BlockParams>,
    #[prost(message, optional, tag = "3")]
    pub evidence: ::core::option::Option<super::super::super::cometbft::types::v1::EvidenceParams>,
    #[prost(message, optional, tag = "4")]
    pub validator:
        ::core::option::Option<super::super::super::cometbft::types::v1::ValidatorParams>,
    #[deprecated]
    #[prost(message, optional, tag = "5")]
    pub abci: ::core::option::Option<super::super::super::cometbft::types::v1::AbciParams>,
    #[prost(message, optional, tag = "6")]
    pub synchrony:
        ::core::option::Option<super::super::super::cometbft::types::v1::SynchronyParams>,
    #[prost(message, optional, tag = "7")]
    pub feature: ::core::option::Option<super::super::super::cometbft::types::v1::FeatureParams>,
}
/// ConsensusMsgParamsResponse defines the response structure for executing a
/// ConsensusMsgParams message.
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct ConsensusMsgParamsResponse {}
/// MsgUpdateParams is the Msg/UpdateParams request type.
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct MsgUpdateParams {
    /// authority is the address that controls the module (defaults to x/gov unless overwritten).
    #[prost(string, tag = "1")]
    pub authority: ::prost::alloc::string::String,
    /// params defines the x/consensus parameters to update.
    /// VersionsParams is not included in this Msg because it is tracked
    /// separarately in x/upgrade.
    ///
    /// NOTE: All parameters must be supplied.
    #[prost(message, optional, tag = "2")]
    pub block: ::core::option::Option<super::super::super::cometbft::types::v1::BlockParams>,
    #[prost(message, optional, tag = "3")]
    pub evidence: ::core::option::Option<super::super::super::cometbft::types::v1::EvidenceParams>,
    #[prost(message, optional, tag = "4")]
    pub validator:
        ::core::option::Option<super::super::super::cometbft::types::v1::ValidatorParams>,
    /// Since: cosmos-sdk 0.50
    #[deprecated]
    #[prost(message, optional, tag = "5")]
    pub abci: ::core::option::Option<super::super::super::cometbft::types::v1::AbciParams>,
    /// Since: cosmos-sdk 0.51
    #[prost(message, optional, tag = "6")]
    pub synchrony:
        ::core::option::Option<super::super::super::cometbft::types::v1::SynchronyParams>,
    #[prost(message, optional, tag = "7")]
    pub feature: ::core::option::Option<super::super::super::cometbft::types::v1::FeatureParams>,
}
/// MsgUpdateParamsResponse defines the response structure for executing a
/// MsgUpdateParams message.
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct MsgUpdateParamsResponse {}
/// QueryParamsRequest defines the request type for querying x/consensus parameters.
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryParamsRequest {}
/// QueryParamsResponse defines the response type for querying x/consensus parameters.
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryParamsResponse {
    /// params are the tendermint consensus params stored in the consensus module.
    /// Please note that `params.version` is not populated in this response, it is
    /// tracked separately in the x/upgrade module.
    #[prost(message, optional, tag = "1")]
    pub params: ::core::option::Option<super::super::super::cometbft::types::v1::ConsensusParams>,
}
impl ::prost::Name for ConsensusMsgParams {
    const NAME: &'static str = "ConsensusMsgParams";
    const PACKAGE: &'static str = "cosmos.consensus.v1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("cosmos.consensus.v1.{}", Self::NAME)
    }
}
impl ::prost::Name for ConsensusMsgParamsResponse {
    const NAME: &'static str = "ConsensusMsgParamsResponse";
    const PACKAGE: &'static str = "cosmos.consensus.v1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("cosmos.consensus.v1.{}", Self::NAME)
    }
}
impl ::prost::Name for MsgUpdateParams {
    const NAME: &'static str = "MsgUpdateParams";
    const PACKAGE: &'static str = "cosmos.consensus.v1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("cosmos.consensus.v1.{}", Self::NAME)
    }
}
impl ::prost::Name for MsgUpdateParamsResponse {
    const NAME: &'static str = "MsgUpdateParamsResponse";
    const PACKAGE: &'static str = "cosmos.consensus.v1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("cosmos.consensus.v1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryParamsRequest {
    const NAME: &'static str = "QueryParamsRequest";
    const PACKAGE: &'static str = "cosmos.consensus.v1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("cosmos.consensus.v1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryParamsResponse {
    const NAME: &'static str = "QueryParamsResponse";
    const PACKAGE: &'static str = "cosmos.consensus.v1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("cosmos.consensus.v1.{}", Self::NAME)
    }
}
