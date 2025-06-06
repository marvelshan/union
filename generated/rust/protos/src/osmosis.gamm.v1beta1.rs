#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct MsgExitPoolResponse {
    #[prost(message, repeated, tag = "1")]
    pub token_out: ::prost::alloc::vec::Vec<super::super::super::cosmos::base::v1beta1::Coin>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct MsgExitSwapExternAmountOutResponse {
    #[prost(string, tag = "1")]
    pub share_in_amount: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct MsgExitSwapShareAmountInResponse {
    #[prost(string, tag = "1")]
    pub token_out_amount: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct MsgJoinPoolResponse {
    #[prost(string, tag = "1")]
    pub share_out_amount: ::prost::alloc::string::String,
    #[prost(message, repeated, tag = "2")]
    pub token_in: ::prost::alloc::vec::Vec<super::super::super::cosmos::base::v1beta1::Coin>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct MsgJoinSwapExternAmountInResponse {
    #[prost(string, tag = "1")]
    pub share_out_amount: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct MsgJoinSwapShareAmountOutResponse {
    #[prost(string, tag = "1")]
    pub token_in_amount: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct MsgSwapExactAmountInResponse {
    #[prost(string, tag = "1")]
    pub token_out_amount: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct MsgSwapExactAmountOut {
    #[prost(string, tag = "1")]
    pub sender: ::prost::alloc::string::String,
    #[prost(message, repeated, tag = "2")]
    pub routes: ::prost::alloc::vec::Vec<super::super::poolmanager::v1beta1::SwapAmountOutRoute>,
    #[prost(string, tag = "3")]
    pub token_in_max_amount: ::prost::alloc::string::String,
    #[prost(message, optional, tag = "4")]
    pub token_out: ::core::option::Option<super::super::super::cosmos::base::v1beta1::Coin>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct MsgSwapExactAmountOutResponse {
    #[prost(string, tag = "1")]
    pub token_in_amount: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct ParamsResponse {
    #[prost(message, optional, tag = "1")]
    pub params: ::core::option::Option<Params>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct Pool {
    #[prost(string, tag = "1")]
    pub address: ::prost::alloc::string::String,
    #[prost(uint64, tag = "2")]
    pub id: u64,
    #[prost(message, optional, tag = "3")]
    pub pool_params: ::core::option::Option<PoolParams>,
    /// This string specifies who will govern the pool in the future.
    /// Valid forms of this are:
    /// {token name},{duration}
    /// {duration}
    /// where {token name} if specified is the token which determines the
    /// governor, and if not specified is the LP token for this pool.duration is
    /// a time specified as 0w,1w,2w, etc. which specifies how long the token
    /// would need to be locked up to count in governance. 0w means no lockup.
    /// TODO: Further improve these docs
    #[prost(string, tag = "4")]
    pub future_pool_governor: ::prost::alloc::string::String,
    /// sum of all LP tokens sent out
    #[prost(message, optional, tag = "5")]
    pub total_shares: ::core::option::Option<super::super::super::cosmos::base::v1beta1::Coin>,
    /// These are assumed to be sorted by denomiation.
    /// They contain the pool asset and the information about the weight
    #[prost(message, repeated, tag = "6")]
    pub pool_assets: ::prost::alloc::vec::Vec<PoolAsset>,
    /// sum of all non-normalized pool weights
    #[prost(string, tag = "7")]
    pub total_weight: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct PoolRecordWithCfmmLink {
    #[prost(string, tag = "1")]
    pub denom0: ::prost::alloc::string::String,
    #[prost(string, tag = "2")]
    pub denom1: ::prost::alloc::string::String,
    #[prost(uint64, tag = "3")]
    pub tick_spacing: u64,
    #[prost(string, tag = "4")]
    pub exponent_at_price_one: ::prost::alloc::string::String,
    #[prost(string, tag = "5")]
    pub spread_factor: ::prost::alloc::string::String,
    #[prost(uint64, tag = "6")]
    pub balancer_pool_id: u64,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryCalcExitPoolCoinsFromSharesResponse {
    #[prost(message, repeated, tag = "1")]
    pub tokens_out: ::prost::alloc::vec::Vec<super::super::super::cosmos::base::v1beta1::Coin>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryCalcJoinPoolNoSwapSharesResponse {
    #[prost(message, repeated, tag = "1")]
    pub tokens_out: ::prost::alloc::vec::Vec<super::super::super::cosmos::base::v1beta1::Coin>,
    #[prost(string, tag = "2")]
    pub shares_out: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryCalcJoinPoolSharesResponse {
    #[prost(string, tag = "1")]
    pub share_out_amount: ::prost::alloc::string::String,
    #[prost(message, repeated, tag = "2")]
    pub tokens_out: ::prost::alloc::vec::Vec<super::super::super::cosmos::base::v1beta1::Coin>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryCfmmConcentratedPoolLinksResponse {
    #[prost(message, optional, tag = "1")]
    pub migration_records: ::core::option::Option<MigrationRecords>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryConcentratedPoolIdLinkFromCfmmResponse {
    #[prost(uint64, tag = "1")]
    pub concentrated_pool_id: u64,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryNumPoolsResponse {
    #[prost(uint64, tag = "1")]
    pub num_pools: u64,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryPoolParamsResponse {
    #[prost(message, optional, tag = "1")]
    pub params: ::core::option::Option<super::super::super::google::protobuf::Any>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryPoolTypeResponse {
    #[prost(string, tag = "1")]
    pub pool_type: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryPoolsResponse {
    #[prost(message, repeated, tag = "1")]
    pub pools: ::prost::alloc::vec::Vec<super::super::super::google::protobuf::Any>,
    /// pagination defines the pagination in the response.
    #[prost(message, optional, tag = "2")]
    pub pagination:
        ::core::option::Option<super::super::super::cosmos::base::query::v1beta1::PageResponse>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryPoolsWithFilterRequest {
    /// String of the coins in single string separated by comma. Ex)
    /// 10uatom,100uosmo
    #[prost(string, tag = "1")]
    pub min_liquidity: ::prost::alloc::string::String,
    #[prost(string, tag = "2")]
    pub pool_type: ::prost::alloc::string::String,
    #[prost(message, optional, tag = "3")]
    pub pagination:
        ::core::option::Option<super::super::super::cosmos::base::query::v1beta1::PageRequest>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryPoolsWithFilterResponse {
    #[prost(message, repeated, tag = "1")]
    pub pools: ::prost::alloc::vec::Vec<super::super::super::google::protobuf::Any>,
    /// pagination defines the pagination in the response.
    #[prost(message, optional, tag = "2")]
    pub pagination:
        ::core::option::Option<super::super::super::cosmos::base::query::v1beta1::PageResponse>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QuerySwapExactAmountInResponse {
    #[prost(string, tag = "1")]
    pub token_out_amount: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QuerySwapExactAmountOutResponse {
    #[prost(string, tag = "1")]
    pub token_in_amount: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryTotalLiquidityRequest {}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryTotalLiquidityResponse {
    #[prost(message, repeated, tag = "1")]
    pub liquidity: ::prost::alloc::vec::Vec<super::super::super::cosmos::base::v1beta1::Coin>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryTotalSharesResponse {
    #[prost(message, optional, tag = "1")]
    pub total_shares: ::core::option::Option<super::super::super::cosmos::base::v1beta1::Coin>,
}
/// ===================== MsgExitPool
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct MsgExitPool {
    #[prost(string, tag = "1")]
    pub sender: ::prost::alloc::string::String,
    #[prost(uint64, tag = "2")]
    pub pool_id: u64,
    #[prost(string, tag = "3")]
    pub share_in_amount: ::prost::alloc::string::String,
    #[prost(message, repeated, tag = "4")]
    pub token_out_mins: ::prost::alloc::vec::Vec<super::super::super::cosmos::base::v1beta1::Coin>,
}
/// ===================== MsgExitSwapExternAmountOut
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct MsgExitSwapExternAmountOut {
    #[prost(string, tag = "1")]
    pub sender: ::prost::alloc::string::String,
    #[prost(uint64, tag = "2")]
    pub pool_id: u64,
    #[prost(message, optional, tag = "3")]
    pub token_out: ::core::option::Option<super::super::super::cosmos::base::v1beta1::Coin>,
    #[prost(string, tag = "4")]
    pub share_in_max_amount: ::prost::alloc::string::String,
}
/// ===================== MsgExitSwapShareAmountIn
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct MsgExitSwapShareAmountIn {
    #[prost(string, tag = "1")]
    pub sender: ::prost::alloc::string::String,
    #[prost(uint64, tag = "2")]
    pub pool_id: u64,
    #[prost(string, tag = "3")]
    pub token_out_denom: ::prost::alloc::string::String,
    #[prost(string, tag = "4")]
    pub share_in_amount: ::prost::alloc::string::String,
    #[prost(string, tag = "5")]
    pub token_out_min_amount: ::prost::alloc::string::String,
}
/// ===================== MsgJoinPool
/// This is really MsgJoinPoolNoSwap
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct MsgJoinPool {
    #[prost(string, tag = "1")]
    pub sender: ::prost::alloc::string::String,
    #[prost(uint64, tag = "2")]
    pub pool_id: u64,
    #[prost(string, tag = "3")]
    pub share_out_amount: ::prost::alloc::string::String,
    #[prost(message, repeated, tag = "4")]
    pub token_in_maxs: ::prost::alloc::vec::Vec<super::super::super::cosmos::base::v1beta1::Coin>,
}
/// ===================== MsgJoinSwapExternAmountIn
/// TODO: Rename to MsgJoinSwapExactAmountIn
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct MsgJoinSwapExternAmountIn {
    #[prost(string, tag = "1")]
    pub sender: ::prost::alloc::string::String,
    #[prost(uint64, tag = "2")]
    pub pool_id: u64,
    #[prost(message, optional, tag = "3")]
    pub token_in: ::core::option::Option<super::super::super::cosmos::base::v1beta1::Coin>,
    /// repeated cosmos.base.v1beta1.Coin tokensIn = 5 [
    ///    (gogoproto.moretags) = "yaml:\"tokens_in\"",
    ///    (gogoproto.nullable) = false
    /// ];
    #[prost(string, tag = "4")]
    pub share_out_min_amount: ::prost::alloc::string::String,
}
/// ===================== MsgJoinSwapShareAmountOut
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct MsgJoinSwapShareAmountOut {
    #[prost(string, tag = "1")]
    pub sender: ::prost::alloc::string::String,
    #[prost(uint64, tag = "2")]
    pub pool_id: u64,
    #[prost(string, tag = "3")]
    pub token_in_denom: ::prost::alloc::string::String,
    #[prost(string, tag = "4")]
    pub share_out_amount: ::prost::alloc::string::String,
    #[prost(string, tag = "5")]
    pub token_in_max_amount: ::prost::alloc::string::String,
}
/// ===================== MsgSwapExactAmountIn
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct MsgSwapExactAmountIn {
    #[prost(string, tag = "1")]
    pub sender: ::prost::alloc::string::String,
    #[prost(message, repeated, tag = "2")]
    pub routes: ::prost::alloc::vec::Vec<super::super::poolmanager::v1beta1::SwapAmountInRoute>,
    #[prost(message, optional, tag = "3")]
    pub token_in: ::core::option::Option<super::super::super::cosmos::base::v1beta1::Coin>,
    #[prost(string, tag = "4")]
    pub token_out_min_amount: ::prost::alloc::string::String,
}
/// =============================== CalcExitPoolCoinsFromShares
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryCalcExitPoolCoinsFromSharesRequest {
    #[prost(uint64, tag = "1")]
    pub pool_id: u64,
    #[prost(string, tag = "2")]
    pub share_in_amount: ::prost::alloc::string::String,
}
/// =============================== CalcJoinPoolNoSwapShares
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryCalcJoinPoolNoSwapSharesRequest {
    #[prost(uint64, tag = "1")]
    pub pool_id: u64,
    #[prost(message, repeated, tag = "2")]
    pub tokens_in: ::prost::alloc::vec::Vec<super::super::super::cosmos::base::v1beta1::Coin>,
}
/// =============================== CalcJoinPoolShares
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryCalcJoinPoolSharesRequest {
    #[prost(uint64, tag = "1")]
    pub pool_id: u64,
    #[prost(message, repeated, tag = "2")]
    pub tokens_in: ::prost::alloc::vec::Vec<super::super::super::cosmos::base::v1beta1::Coin>,
}
/// =============================== EstimateSwapExactAmountIn
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QuerySwapExactAmountInRequest {
    #[prost(string, tag = "1")]
    pub sender: ::prost::alloc::string::String,
    #[prost(uint64, tag = "2")]
    pub pool_id: u64,
    #[prost(string, tag = "3")]
    pub token_in: ::prost::alloc::string::String,
    #[prost(message, repeated, tag = "4")]
    pub routes: ::prost::alloc::vec::Vec<super::super::poolmanager::v1beta1::SwapAmountInRoute>,
}
/// =============================== EstimateSwapExactAmountOut
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QuerySwapExactAmountOutRequest {
    #[prost(string, tag = "1")]
    pub sender: ::prost::alloc::string::String,
    #[prost(uint64, tag = "2")]
    pub pool_id: u64,
    #[prost(message, repeated, tag = "3")]
    pub routes: ::prost::alloc::vec::Vec<super::super::poolmanager::v1beta1::SwapAmountOutRoute>,
    #[prost(string, tag = "4")]
    pub token_out: ::prost::alloc::string::String,
}
/// =============================== NumPools
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryNumPoolsRequest {}
/// =============================== Params
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct ParamsRequest {}
/// =============================== Pool
/// Deprecated: please use the alternative in x/poolmanager
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryPoolRequest {
    #[prost(uint64, tag = "1")]
    pub pool_id: u64,
}
/// =============================== PoolLiquidity
/// Deprecated: please use the alternative in x/poolmanager
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryTotalPoolLiquidityRequest {
    #[prost(uint64, tag = "1")]
    pub pool_id: u64,
}
/// =============================== PoolParams
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryPoolParamsRequest {
    #[prost(uint64, tag = "1")]
    pub pool_id: u64,
}
/// =============================== PoolType
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryPoolTypeRequest {
    #[prost(uint64, tag = "1")]
    pub pool_id: u64,
}
/// =============================== Pools
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryPoolsRequest {
    /// pagination defines an optional pagination for the request.
    #[prost(message, optional, tag = "2")]
    pub pagination:
        ::core::option::Option<super::super::super::cosmos::base::query::v1beta1::PageRequest>,
}
/// =============================== QueryCFMMConcentratedPoolLinks
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryCfmmConcentratedPoolLinksRequest {}
/// =============================== QueryConcentratedPoolIdLinkFromCFMM
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryConcentratedPoolIdLinkFromCfmmRequest {
    #[prost(uint64, tag = "1")]
    pub cfmm_pool_id: u64,
}
/// =============================== TotalShares
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryTotalSharesRequest {
    #[prost(uint64, tag = "1")]
    pub pool_id: u64,
}
/// BalancerToConcentratedPoolLink defines a single link between a single
/// balancer pool and a single concentrated liquidity pool. This link is used to
/// allow a balancer pool to migrate to a single canonical full range
/// concentrated liquidity pool position
/// A balancer pool can be linked to a maximum of one cl pool, and a cl pool can
/// be linked to a maximum of one balancer pool.
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct BalancerToConcentratedPoolLink {
    #[prost(uint64, tag = "1")]
    pub balancer_pool_id: u64,
    #[prost(uint64, tag = "2")]
    pub cl_pool_id: u64,
}
/// CreateConcentratedLiquidityPoolsAndLinktoCFMMProposal is a gov Content type
/// for creating concentrated liquidity pools and linking it to a CFMM pool.
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct CreateConcentratedLiquidityPoolsAndLinktoCfmmProposal {
    #[prost(string, tag = "1")]
    pub title: ::prost::alloc::string::String,
    #[prost(string, tag = "2")]
    pub description: ::prost::alloc::string::String,
    #[prost(message, repeated, tag = "3")]
    pub pool_records_with_cfmm_link: ::prost::alloc::vec::Vec<PoolRecordWithCfmmLink>,
}
/// Deprecated: please use the alternative in x/poolmanager
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryPoolResponse {
    #[prost(message, optional, tag = "1")]
    pub pool: ::core::option::Option<super::super::super::google::protobuf::Any>,
}
/// Deprecated: please use the alternative in x/poolmanager
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QueryTotalPoolLiquidityResponse {
    #[prost(message, repeated, tag = "1")]
    pub liquidity: ::prost::alloc::vec::Vec<super::super::super::cosmos::base::v1beta1::Coin>,
}
/// For example: if the existing DistrRecords were:
/// \[(Balancer 1, CL 5), (Balancer 2, CL 6), (Balancer 3, CL 7)\]
/// And an UpdateMigrationRecordsProposal includes
/// \[(Balancer 2, CL 0), (Balancer 3, CL 4), (Balancer 4, CL 10)\]
/// This would leave Balancer 1 record, delete Balancer 2 record,
/// Edit Balancer 3 record, and Add Balancer 4 record
/// The result MigrationRecords in state would be:
/// \[(Balancer 1, CL 5), (Balancer 3, CL 4), (Balancer 4, CL 10)\]
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct UpdateMigrationRecordsProposal {
    #[prost(string, tag = "1")]
    pub title: ::prost::alloc::string::String,
    #[prost(string, tag = "2")]
    pub description: ::prost::alloc::string::String,
    #[prost(message, repeated, tag = "3")]
    pub records: ::prost::alloc::vec::Vec<BalancerToConcentratedPoolLink>,
}
/// GenesisState defines the gamm module's genesis state.
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct GenesisState {
    #[prost(message, repeated, tag = "1")]
    pub pools: ::prost::alloc::vec::Vec<super::super::super::google::protobuf::Any>,
    /// will be renamed to next_pool_id in an upcoming version
    #[prost(uint64, tag = "2")]
    pub next_pool_number: u64,
    #[prost(message, optional, tag = "3")]
    pub params: ::core::option::Option<Params>,
    #[prost(message, optional, tag = "4")]
    pub migration_records: ::core::option::Option<MigrationRecords>,
}
/// MigrationRecords contains all the links between balancer and concentrated
/// pools
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct MigrationRecords {
    #[prost(message, repeated, tag = "1")]
    pub balancer_to_concentrated_pool_links:
        ::prost::alloc::vec::Vec<BalancerToConcentratedPoolLink>,
}
/// Parameters for changing the weights in a balancer pool smoothly from
/// a start weight and end weight over a period of time.
/// Currently, the only smooth change supported is linear changing between
/// the two weights, but more types may be added in the future.
/// When these parameters are set, the weight w(t) for pool time `t` is the
/// following:
///    t <= start_time: w(t) = initial_pool_weights
///    start_time < t <= start_time + duration:
///      w(t) = initial_pool_weights + (t - start_time) *
///        (target_pool_weights - initial_pool_weights) / (duration)
///    t > start_time + duration: w(t) = target_pool_weights
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct SmoothWeightChangeParams {
    /// The start time for beginning the weight change.
    /// If a parameter change / pool instantiation leaves this blank,
    /// it should be generated by the state_machine as the current time.
    #[prost(message, optional, tag = "1")]
    pub start_time: ::core::option::Option<super::super::super::google::protobuf::Timestamp>,
    /// Duration for the weights to change over
    #[prost(message, optional, tag = "2")]
    pub duration: ::core::option::Option<super::super::super::google::protobuf::Duration>,
    /// The initial pool weights. These are copied from the pool's settings
    /// at the time of weight change instantiation.
    /// The amount PoolAsset.token.amount field is ignored if present,
    /// future type refactorings should just have a type with the denom & weight
    /// here.
    #[prost(message, repeated, tag = "3")]
    pub initial_pool_weights: ::prost::alloc::vec::Vec<PoolAsset>,
    /// The target pool weights. The pool weights will change linearly with respect
    /// to time between start_time, and start_time + duration. The amount
    /// PoolAsset.token.amount field is ignored if present, future type
    /// refactorings should just have a type with the denom & weight here.
    ///
    /// Intermediate variable for the 'slope' of pool weights. This is equal to
    /// (target_pool_weights - initial_pool_weights) / (duration)
    /// TODO: Work out precision, and decide if this is good to add
    /// repeated PoolAsset poolWeightSlope = 5 [
    ///   (gogoproto.moretags) = "yaml:\"pool_weight_slope\"",
    ///   (gogoproto.nullable) = false
    /// ];
    #[prost(message, repeated, tag = "4")]
    pub target_pool_weights: ::prost::alloc::vec::Vec<PoolAsset>,
}
/// Params holds parameters for the incentives module
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct Params {
    #[prost(message, repeated, tag = "1")]
    pub pool_creation_fee:
        ::prost::alloc::vec::Vec<super::super::super::cosmos::base::v1beta1::Coin>,
}
/// Pool asset is an internal struct that combines the amount of the
/// token in the pool, and its balancer weight.
/// This is an awkward packaging of data,
/// and should be revisited in a future state migration.
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct PoolAsset {
    /// Coins we are talking about,
    /// the denomination must be unique amongst all PoolAssets for this pool.
    #[prost(message, optional, tag = "1")]
    pub token: ::core::option::Option<super::super::super::cosmos::base::v1beta1::Coin>,
    /// Weight that is not normalized. This weight must be less than 2^50
    #[prost(string, tag = "2")]
    pub weight: ::prost::alloc::string::String,
}
/// PoolParams defined the parameters that will be managed by the pool
/// governance in the future. This params are not managed by the chain
/// governance. Instead they will be managed by the token holders of the pool.
/// The pool's token holders are specified in future_pool_governor.
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct PoolParams {
    #[prost(string, tag = "1")]
    pub swap_fee: ::prost::alloc::string::String,
    /// N.B.: exit fee is disabled during pool creation in x/poolmanager. While old
    /// pools can maintain a non-zero fee. No new pool can be created with non-zero
    /// fee anymore
    #[prost(string, tag = "2")]
    pub exit_fee: ::prost::alloc::string::String,
    #[prost(message, optional, tag = "3")]
    pub smooth_weight_change_params: ::core::option::Option<SmoothWeightChangeParams>,
}
/// QuerySpotPriceRequest defines the gRPC request structure for a SpotPrice
/// query.
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QuerySpotPriceRequest {
    #[prost(uint64, tag = "1")]
    pub pool_id: u64,
    #[prost(string, tag = "2")]
    pub base_asset_denom: ::prost::alloc::string::String,
    #[prost(string, tag = "3")]
    pub quote_asset_denom: ::prost::alloc::string::String,
    /// DEPRECATED
    #[deprecated]
    #[prost(bool, tag = "4")]
    pub with_swap_fee: bool,
}
/// QuerySpotPriceResponse defines the gRPC response structure for a SpotPrice
/// query.
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct QuerySpotPriceResponse {
    /// String of the Dec. Ex) 10.203uatom
    #[prost(string, tag = "1")]
    pub spot_price: ::prost::alloc::string::String,
}
/// ReplaceMigrationRecordsProposal is a gov Content type for updating the
/// migration records. If a ReplaceMigrationRecordsProposal passes, the
/// proposal’s records override the existing MigrationRecords set in the module.
/// Each record specifies a single connection between a single balancer pool and
/// a single concentrated pool.
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct ReplaceMigrationRecordsProposal {
    #[prost(string, tag = "1")]
    pub title: ::prost::alloc::string::String,
    #[prost(string, tag = "2")]
    pub description: ::prost::alloc::string::String,
    #[prost(message, repeated, tag = "3")]
    pub records: ::prost::alloc::vec::Vec<BalancerToConcentratedPoolLink>,
}
/// SetScalingFactorControllerProposal is a gov Content type for updating the
/// scaling factor controller address of a stableswap pool
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, :: prost :: Message)]
pub struct SetScalingFactorControllerProposal {
    #[prost(string, tag = "1")]
    pub title: ::prost::alloc::string::String,
    #[prost(string, tag = "2")]
    pub description: ::prost::alloc::string::String,
    #[prost(uint64, tag = "3")]
    pub pool_id: u64,
    #[prost(string, tag = "4")]
    pub controller_address: ::prost::alloc::string::String,
}
impl ::prost::Name for BalancerToConcentratedPoolLink {
    const NAME: &'static str = "BalancerToConcentratedPoolLink";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for CreateConcentratedLiquidityPoolsAndLinktoCfmmProposal {
    const NAME: &'static str = "CreateConcentratedLiquidityPoolsAndLinktoCFMMProposal";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for GenesisState {
    const NAME: &'static str = "GenesisState";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for MigrationRecords {
    const NAME: &'static str = "MigrationRecords";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for MsgExitPool {
    const NAME: &'static str = "MsgExitPool";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for MsgExitPoolResponse {
    const NAME: &'static str = "MsgExitPoolResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for MsgExitSwapExternAmountOut {
    const NAME: &'static str = "MsgExitSwapExternAmountOut";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for MsgExitSwapExternAmountOutResponse {
    const NAME: &'static str = "MsgExitSwapExternAmountOutResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for MsgExitSwapShareAmountIn {
    const NAME: &'static str = "MsgExitSwapShareAmountIn";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for MsgExitSwapShareAmountInResponse {
    const NAME: &'static str = "MsgExitSwapShareAmountInResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for MsgJoinPool {
    const NAME: &'static str = "MsgJoinPool";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for MsgJoinPoolResponse {
    const NAME: &'static str = "MsgJoinPoolResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for MsgJoinSwapExternAmountIn {
    const NAME: &'static str = "MsgJoinSwapExternAmountIn";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for MsgJoinSwapExternAmountInResponse {
    const NAME: &'static str = "MsgJoinSwapExternAmountInResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for MsgJoinSwapShareAmountOut {
    const NAME: &'static str = "MsgJoinSwapShareAmountOut";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for MsgJoinSwapShareAmountOutResponse {
    const NAME: &'static str = "MsgJoinSwapShareAmountOutResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for MsgSwapExactAmountIn {
    const NAME: &'static str = "MsgSwapExactAmountIn";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for MsgSwapExactAmountInResponse {
    const NAME: &'static str = "MsgSwapExactAmountInResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for MsgSwapExactAmountOut {
    const NAME: &'static str = "MsgSwapExactAmountOut";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for MsgSwapExactAmountOutResponse {
    const NAME: &'static str = "MsgSwapExactAmountOutResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for Params {
    const NAME: &'static str = "Params";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for ParamsRequest {
    const NAME: &'static str = "ParamsRequest";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for ParamsResponse {
    const NAME: &'static str = "ParamsResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for Pool {
    const NAME: &'static str = "Pool";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for PoolAsset {
    const NAME: &'static str = "PoolAsset";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for PoolParams {
    const NAME: &'static str = "PoolParams";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for PoolRecordWithCfmmLink {
    const NAME: &'static str = "PoolRecordWithCFMMLink";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryCalcExitPoolCoinsFromSharesRequest {
    const NAME: &'static str = "QueryCalcExitPoolCoinsFromSharesRequest";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryCalcExitPoolCoinsFromSharesResponse {
    const NAME: &'static str = "QueryCalcExitPoolCoinsFromSharesResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryCalcJoinPoolNoSwapSharesRequest {
    const NAME: &'static str = "QueryCalcJoinPoolNoSwapSharesRequest";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryCalcJoinPoolNoSwapSharesResponse {
    const NAME: &'static str = "QueryCalcJoinPoolNoSwapSharesResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryCalcJoinPoolSharesRequest {
    const NAME: &'static str = "QueryCalcJoinPoolSharesRequest";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryCalcJoinPoolSharesResponse {
    const NAME: &'static str = "QueryCalcJoinPoolSharesResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryCfmmConcentratedPoolLinksRequest {
    const NAME: &'static str = "QueryCFMMConcentratedPoolLinksRequest";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryCfmmConcentratedPoolLinksResponse {
    const NAME: &'static str = "QueryCFMMConcentratedPoolLinksResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryConcentratedPoolIdLinkFromCfmmRequest {
    const NAME: &'static str = "QueryConcentratedPoolIdLinkFromCFMMRequest";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryConcentratedPoolIdLinkFromCfmmResponse {
    const NAME: &'static str = "QueryConcentratedPoolIdLinkFromCFMMResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryNumPoolsRequest {
    const NAME: &'static str = "QueryNumPoolsRequest";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryNumPoolsResponse {
    const NAME: &'static str = "QueryNumPoolsResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryPoolParamsRequest {
    const NAME: &'static str = "QueryPoolParamsRequest";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryPoolParamsResponse {
    const NAME: &'static str = "QueryPoolParamsResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryPoolRequest {
    const NAME: &'static str = "QueryPoolRequest";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryPoolResponse {
    const NAME: &'static str = "QueryPoolResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryPoolTypeRequest {
    const NAME: &'static str = "QueryPoolTypeRequest";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryPoolTypeResponse {
    const NAME: &'static str = "QueryPoolTypeResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryPoolsRequest {
    const NAME: &'static str = "QueryPoolsRequest";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryPoolsResponse {
    const NAME: &'static str = "QueryPoolsResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryPoolsWithFilterRequest {
    const NAME: &'static str = "QueryPoolsWithFilterRequest";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryPoolsWithFilterResponse {
    const NAME: &'static str = "QueryPoolsWithFilterResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QuerySpotPriceRequest {
    const NAME: &'static str = "QuerySpotPriceRequest";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QuerySpotPriceResponse {
    const NAME: &'static str = "QuerySpotPriceResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QuerySwapExactAmountInRequest {
    const NAME: &'static str = "QuerySwapExactAmountInRequest";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QuerySwapExactAmountInResponse {
    const NAME: &'static str = "QuerySwapExactAmountInResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QuerySwapExactAmountOutRequest {
    const NAME: &'static str = "QuerySwapExactAmountOutRequest";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QuerySwapExactAmountOutResponse {
    const NAME: &'static str = "QuerySwapExactAmountOutResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryTotalLiquidityRequest {
    const NAME: &'static str = "QueryTotalLiquidityRequest";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryTotalLiquidityResponse {
    const NAME: &'static str = "QueryTotalLiquidityResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryTotalPoolLiquidityRequest {
    const NAME: &'static str = "QueryTotalPoolLiquidityRequest";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryTotalPoolLiquidityResponse {
    const NAME: &'static str = "QueryTotalPoolLiquidityResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryTotalSharesRequest {
    const NAME: &'static str = "QueryTotalSharesRequest";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for QueryTotalSharesResponse {
    const NAME: &'static str = "QueryTotalSharesResponse";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for ReplaceMigrationRecordsProposal {
    const NAME: &'static str = "ReplaceMigrationRecordsProposal";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for SetScalingFactorControllerProposal {
    const NAME: &'static str = "SetScalingFactorControllerProposal";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for SmoothWeightChangeParams {
    const NAME: &'static str = "SmoothWeightChangeParams";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
impl ::prost::Name for UpdateMigrationRecordsProposal {
    const NAME: &'static str = "UpdateMigrationRecordsProposal";
    const PACKAGE: &'static str = "osmosis.gamm.v1beta1";
    fn full_name() -> ::prost::alloc::string::String {
        ::prost::alloc::format!("osmosis.gamm.v1beta1.{}", Self::NAME)
    }
}
