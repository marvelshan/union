use core::fmt::Debug;

use alloy_sol_types::SolValue;
use bob_light_client_types::{
    header::{L2Header, OutputRootProof},
    ClientStateV1, Header,
};
use evm_storage_verifier::{verify_account_storage_root, verify_storage_proof};
use unionlabs::{
    ethereum::{keccak256, slot::Slot},
    primitives::{H256, U256},
};

// Arbitrary finalization enforced in parallel of the L1 finality.
pub const FINALIZATION_PERIOD_SECONDS: u64 = 60;

#[derive(thiserror::Error, Debug, PartialEq, Clone)]
pub enum Error {
    #[error("invalid l2 oracle account proof")]
    InvalidL2OracleAccountProof(#[source] evm_storage_verifier::error::Error),
    #[error("invalid output proposal storage proof")]
    InvalidOutputProposalStorageProof(#[source] evm_storage_verifier::error::Error),
    #[error("output root proof hash mismatch: actual={actual}, expected={expected}")]
    OutputRootHashMismatch { actual: H256, expected: H256 },
    #[error("invalid ibc contract account proof")]
    InvalidIbcContractProof(#[source] evm_storage_verifier::error::Error),
    #[error("the l2 header is not finalized")]
    HeaderNotFinalized,
}

pub fn verify_header(
    client_state: &ClientStateV1,
    header: &Header,
    l1_state_root: H256,
    current_timestamp: u64,
    l2_finalization_period_seconds: u64,
) -> Result<(), Error> {
    // Verify that the header is finalized.
    let finalization_timestamp = header.l2_header.timestamp + l2_finalization_period_seconds;
    if current_timestamp < finalization_timestamp {
        return Err(Error::HeaderNotFinalized);
    }

    // Verify that the L2OutputOracle (https://github.com/ethereum-optimism/optimism/blob/v1.7.2/packages/contracts-bedrock/src/L1/L2OutputOracle.sol#L22) is part of the L1 root.
    verify_account_storage_root(
        l1_state_root,
        &client_state.l2_oracle_address,
        &header.l2_oracle_account_proof.proof,
        &header.l2_oracle_account_proof.storage_root,
    )
    .map_err(Error::InvalidL2OracleAccountProof)?;

    // Verify that the provided l2 header hash matches the block hash within the
    // output root proof.
    verify_l2_header_is_related_to_output_root_proof(&header.output_root_proof, &header.l2_header)?;

    let output_root_proof_hash = compute_output_root_proof_hash(&header.output_root_proof);

    // The stored value is an [OutputProposal](https://github.com/ethereum-optimism/optimism/blob/99a53381019d3571359d989671ccf70f8d69dfd9/packages/contracts-bedrock/src/libraries/Types.sol#L13)
    // Index of the OutputProposal.outputRoot in the [l2Outputs](https://github.com/ethereum-optimism/optimism/blob/99a53381019d3571359d989671ccf70f8d69dfd9/packages/contracts-bedrock/src/L1/L2OutputOracle.sol#L22)
    let output_proposal_slot =
        compute_output_proposal_slot(client_state.l2_oracle_l2_outputs_slot, header.output_index);

    // Verify that the OutputProposal.outputRoot matches the provided OutputRootProof.
    verify_storage_proof(
        header.l2_oracle_account_proof.storage_root,
        output_proposal_slot,
        &rlp::encode(&output_root_proof_hash),
        &header.l2_oracle_l2_outputs_slot_proof.proof,
    )
    .map_err(Error::InvalidOutputProposalStorageProof)?;

    // Verify that the ibc account root is part of the L2 root.
    verify_account_storage_root(
        header.l2_header.state_root,
        &client_state.ibc_contract_address,
        &header.l2_ibc_account_proof.proof,
        &header.l2_ibc_account_proof.storage_root,
    )
    .map_err(Error::InvalidIbcContractProof)?;

    Ok(())
}

pub fn compute_output_proposal_slot(l2_outputs_slot: U256, index: u32) -> U256 {
    let offset = Slot::Offset(l2_outputs_slot);
    // The size in slots of the OutputProposal structures, (sizeof(bytes32) + 2*sizeof(u128) / sizeof(u256)) = 2
    // https://github.com/ethereum-optimism/optimism/blob/99a53381019d3571359d989671ccf70f8d69dfd9/packages/contracts-bedrock/src/libraries/Types.sol#L13
    let output_proposal_size = 2;
    Slot::StructArray(&offset, output_proposal_size, index.into()).slot()
}

// https://github.com/ethereum-optimism/optimism/blob/99a53381019d3571359d989671ccf70f8d69dfd9/packages/contracts-bedrock/src/libraries/Hashing.sol#L114
pub fn compute_output_root_proof_hash(output_root_proof: &OutputRootProof) -> H256 {
    keccak256(
        (
            output_root_proof.version,
            output_root_proof.state_root,
            output_root_proof.message_passer_storage_root,
            output_root_proof.latest_block_hash,
        )
            .abi_encode_params(),
    )
}

pub fn verify_l2_header_is_related_to_output_root_proof(
    output_root_proof: &OutputRootProof,
    l2_header: &L2Header,
) -> Result<(), Error> {
    let block_hash = l2_header.hash();
    if block_hash == output_root_proof.latest_block_hash {
        Ok(())
    } else {
        Err(Error::OutputRootHashMismatch {
            actual: block_hash,
            expected: output_root_proof.latest_block_hash,
        })
    }
}

#[cfg(test)]
mod tests {
    use bob_light_client_types::{header::Nullable, ClientStateV1, Header};
    use hex_literal::hex;
    use ibc_union_spec::ClientId;
    use unionlabs::encoding::{DecodeAs, Json};

    use super::*;

    #[test]
    fn test_update_ok() {
        // Outputs slot is 3
        // OutputIndex 700 = L2 Block 15141600 (0xE70AE0)
        // Slot index = 87903029871075914254377627908054574944891091886930582284385770809450030038483
        // We pick L1 Block 22151979 (0x152032B)
        let client_state = ClientStateV1 {
            chain_id: 0u32.into(),
            latest_height: 0,
            l1_client_id: ClientId!(1),
            l2_oracle_address: hex!("dDa53E23f8a32640b04D7256e651C1db98dB11C1").into(),
            l2_oracle_l2_outputs_slot: 3u32.into(),
            frozen_height: 0,
            // dummy ibc contract
            ibc_contract_address: hex!("4200000000000000000000000000000000000015").into(),
        };
        let header = Header::decode_as::<Json>(
            r#"{
    "l1_height": 0,
    "l2_oracle_account_proof": {
        "storage_root": "0xf2b58813e78b8606c00322b8e4771a2d007a4d3cc91eb4c93cc149a7fb20f826",
        "proof": [
            "0xf90211a076b6b7be50d013711b99530b4833910faf3e11b3c89c3dea64e58071845f7b63a0e08c6457818c1bb6b293efcb15e7aa859665a0d2eb4b047a53901c0a6256c8aaa0093dc6eeed43e2135a88de2873eb665f726c55e200c5041403212cde1f13b374a0e377a9a07f29300e0cc6ba82e9eeaf600baafc80783f984220a71fa953a61510a0f05ff7f2d78d1f50731de0bc76395adde4bbf1c38d8738cd830e207bdf3bb9fda0808be5be4969a60e639b25e78855d4e4f5d3c86d1fe12e0c4ee7f968d4d46b34a0544672e9ee18f15e8cb3dcb5fc9fb139774842b442e333dad3a22577b5af0e8aa044df7fa9eca7c75f64702fa250f5d9cf3b5506ad5a47f22b73ce30ea3ff8b8e9a0a7a74a67eceb18d24cbba8a172c5eb0753868a557c5ca382b558a23e9ea13289a0384778743602ed9675e0a79390f3e522482eaeecddd24ad3139c43452a796eefa0dc362cff49a2aafa8ad5d1f7014b5d25f4635c3bdecdc3225167d085df2469caa0c5a309c40bcd49c3b59ad957531062332d5d9ca2b3239aafb267a409112e2681a0fa6766d07d69a65d245b8787b74456c4ae1b947f16d8d0629bcc032dd56b17cba064f994ef549ce5ebc906009266420e044bdfae64e358f4f4023ce6b02baa7befa0ef167e79c86544ca0d0dbef57993dfdfbc25b1855c080615a37d6ad78accd777a0c3138ae72211f8bce6ed9ce2dd1ec00fc046470e3dede3dce288db7e1828a53180",
            "0xf90211a0930f3c39f379bb6da196245cceb2cd58878f8a4ff75dfeed39f90433551f939da0faa88a0aad7de86f8b2da055852b7447a5da02f75755ca64ba9c4ee8dd61e024a0dd4076f2a08ab4aac864dc8925c01db0dda5b69af213fc2ccf9ad12ce9a5e0b5a0557fd504900fa93294fe6668a7b0f7f2fb9aa3a184a25c8c59d8ee3728583e51a0c520bca0b27d27450facf41b446d660201c3884d9b863127b01e31988948ad1ea0c90b3b89559d35a8ebbc353e83396eed2b3b939c28652b460a0df60b89d48bc0a0cc7efa6d3d6109543569ef059c08ceecb45a51fde8be266ffc61abcdcf022244a0be9e03152979a46c5b407bc27f11cf602b160bfb36d60f75b931c8c033d53b3ba0233b76402c0c6fc2285ac8308f0e27777d6826606273ce82fbd88bc1eeaf265da0b874f4d8b117174b21bcc36638a482d298cfd79372a92237fcdd0190bbb64ddfa0b3e247c0b802c00f71ba1a5d0989d57192711e86e80942143e03e94705c6f6e7a05916e29377fafd7dd49c74260fd3754e4a6efd3bee17e2f3f7ac121eadea9adca06d3b141aec604b5c7b7810862215bed1ab5bd80813ec495b77985a7589456546a04f0b1199f6f81d6db33ab29ee7d960f10e294b1898952971b8d7c9771da4a6e8a0449b9f738cc7e4f7ae14d92018a084508484fe2f1e9b3a72a295440f7b1d9ed1a0f607e27228ab4e9a12df388df0a08985df432a44afff905c411bcdd5bda01a9680",
            "0xf90211a00b7c8e43e59accda937ba44b4d45ff8d882404611a035de8a6b1704580fed363a065e42e77ffb454286642f649dd299ba383849a9531b6154575557029e24a4865a09616cfe5e311b36f1065c82d40ead11f7d6ad5608db90354885dce4d3bd09f9ea07e5d9c170cfbfe24eca1ab2fa2320aac5d3f0fac2578d2dc3057745560f762c0a0b40909e0900c94bc3b23277a02235790067e4b004244751929d6ccd4e2854440a096e165539d27e298730133e323454bef07d6f02dabded90126c4c7341c4690f6a0951dc0b98b31b9374c2b89a845e151cb0554628b6714b805fe9f8e1d1b0ff4bba096e9b980f2689deb3dad1bcb3a570d2af899235c178a78e3dff0dcdc9260851ea00e641ee6872a12b8494c8ded2896f7fca9a3c59f6d8e79a51176119f040fa383a0c0d77a2cebb83492bb519dd1df742e1e192794aa6c88c62b59abf15db04f01e1a00849259d6266468dd0d1e760ea0c775c5a522c09cfc8f990e0892e6b1f71481ea0e9d2dee7b3a66dc4fe23f4880cf1dee8aa41158c43f339af391c70e8e42156aca0eefcb9fc571f2670633e45fec325b5e6d2dce112c5b5b5e9e4ee031a763d8f76a02abf6d448d0ac92187d996c306db071271bc707dd49fe12a487f85e79b493bfda0ccef1f3840cc06393b88ff45f24e282f95437dd6305c15d954974f4be75366fda0c156e7881384d0d1dbf5036f478ab4e7cae070212f365bdec5b94677932cf3dc80",
            "0xf90211a0147b22ce58264f8a957e7db66f8f90dd71ee6e9192c697695ba80f6d79e1b47aa08a7450be4fd61eada6800a61032e8855861bea1cc1f0636bd71100e1e59589cea086e65c6e25beff759c13a09bc0848743f712fceb3526afa0b6dbd271eeb26542a0a1fb95f47fce454d71137b43e7b252c97f54e0bf406f77f7c5bc6860906f75e0a0a30f11772dc0387708c872868b3313b77d679897617981e4b873285ab46209c4a036ea0dceabc6feb5ea970cc8293d9c2c0524695564a2879479b68a97a44e43f1a0cbef44e1f148828c490b608f519580e2f9abb2f599a31b93053f2877f2b3cc92a0247957bba6cfa80e09161c01161ca2b71a6b878ebc0f33393a0c61c3bc8a28b4a096f0ee6de9480679bb89c47bf66cc0cbd1930c9008998c655e8c5e66b3abdae1a0728580a9a9f6ff4f4e9b83a02d5a60461a0a74f0be3d2c89f0eca7ebed88ebbea05d778dab78f221912d6bf586e97cf1ce52e31d893640a580bfabc12fda6bb24da044c243708c51fc65e0d3d659b7d88be454cc402b0f1270b9d03bb592ecc0ada1a0c9028a6e6c8a81fd10c06b83727acfc7dbb8dcade0e10d646782e03431f5c0eca0dbec5e107ea063b7bc50b028425f45dc32e9395c4f37f955df8325a2b9b74909a0a564305f9c27b1f48ba331f6be2272f86ace051d576e25d29189567614080b38a0fb72b83b58230ced2e790ddb48a1c68d9aa719cbd5208d8a6b4fa26da748276d80",
            "0xf90211a0575c3456a4c72ce94e1673811c6756d67e6b23e292bcfbcc81511601315f63d8a05c6c0b632b7e2ff431d3d79a929043354c0f8302b1db5d3a107c993ed869fd48a059f72726a2642ccb3145eed73122b96b0201c8a9af93387f44a389bc6f7cc66ea04ba18e15c2eb61d9cca111181ae9ed06d7c94bd016042427d654e0a612260381a0631e9a06dd549f9a2c0549d4dd6eb4b20b50eb4e59d557a33a7fbeaa194fbd7ba06d4f6ceee48736c216f893c19f479a9cc6ddb5a36d41cc3046135a363f02eaaea0955548a6993ba1af1aa64ff5c9b97f50796b833dd5ae2d04ffa8bb7c631f774ea0dc8634761a9e6e50e050cb1e71205a5e3e36657966d14dbd5f00069e0d9836d8a09cd324e1f9614d59208e933860a826e352093eedb02b507f4badafbbae737215a0d115417ea93e5cbaf687826364c90ccb76d0877db16acdb80ea095bdc47d0969a0393887629ccbe1e4c157544b46fde7b99202e14640079d52c4246ca8ebe7087aa0fa81f9219a169f084b8fdf9d574470ace52f80df70b54aa8cc84c25b4c2ed01aa0beacae693c96d29317f61caeb97e3fbc1232ea9dab0f24ea11e17343732947f4a0f717126cc6e172f390efbe84bd6de0474733d9b9f6eff33084e86e3bb286d48ea072c18752a0505680f721ead7824660a6f41d2e0918928bef051d55246bfb9363a05e5ccbff6b86a8956d3a0ad0c3ba8eddbd118d675c856a8b98b77ea529fb266580",
            "0xf90211a08f5774d9b7319d5acea5f2b7e115d7a6ecafd34aeb214dde4f9fda2e5eb8cdd9a0848e6e25fe86554ff6d180154cc9dd06a40695ca95d1e92e695e39f4764c39eea06dd009ab185719a2ed51ec3eda1f9c7047438db798449a0dacfa206a2bc375bda0846284e1bf9103786621dae350cb0b16e6fa04808c623b9165c25ed95684d02da034b88519dbdd9f6cfa5facc56956368f7d8653e3083d6160c897d0d49e4ce090a013669c719006b02cb4482a78073b589a0ca64e023b5e860936b6f80a69a8cf3ca04025ce7c23118c1bb7323493132b3f2cc4ef9c539798b48bed61294093e1e84fa0e67adae29661ad0fbe4974603ae6831a240acea7592a8a560cdc5e11cb8731aba04e32799794710e4a477722ab26ac665b873971d950bb70df0dde1fe6d07d869da02bcdba52ed020547eca2d58c4eb9dde16d6c2fa1ef4e1e56e336fd03e61082c0a0e968f30a7493a5eb6ce2bdd69603d3b2aa1f5bc97540ad709d8f98b47d28e345a0598d02646dfc07efbe5b942a0451b971dfe89ec213f57f51ea6991d33e4c7222a043650fd6e662fd1af1f94f58920e9e477405eeaef97759fac7917387b0e2f31ba0147b8ca5d01ac18092c61fecff82975266862b9949bcbcc893c213a4cebd716ea00b13937692c5ea0e4c94ed77c6e1360d66508d17fa2a88cf0d06e679cc09ee9aa0536e80bf299075fa62354ea087a45100c3794697a5b0a99296a1db72a367f69280",
            "0xf901318080a0c29eaa96d7f2d04a6fd5b4236d8dec3af1ac0583df3c155819f667b9d940d6c1a0e726d6d81ba53d76ca5561b457413e07d398a9cd37c7c956e32673011849bee2a0fd3154269d3075d7460939dff1a1189d044a8b0424e288c8721ab2dd7a6d7bb2a0de7d68297ee442a5731210d702f4828095c5702107f17284d107a0e50b9b43f9a0ee7af38d5ebe1f311ea0177de088658492ee136fa3b3856741eed764c88c97f0a089213749331f0aab25b9123dcea64329685f91dc43aecd325b757b5f897542bba06a64e023c433685f763a25db45f3d891c995a5c1642a37fb8e5cedd8239f2544808080a0777db72d6be1edf3f062875ed84db6ea0c954742847efb75bba703aad0995816a0875c3f900f4f49c3642cd970c7d3ff810861c63bdd5494371352e3a24a4b8216808080",
            "0xf8669d3fe01873f77f0e6f4fe83491493b940eb20e9b45435448867d156c58fab846f8440180a0f2b58813e78b8606c00322b8e4771a2d007a4d3cc91eb4c93cc149a7fb20f826a01f958654ab06a152993e7a0ae7b6dbb0d4b19265cc9337b8789fe1353bd9dc35"
        ]
    },
    "l2_oracle_l2_outputs_slot_proof": {
        "key": "87903029871075914254377627908054574944891091886930582284385770809450030038483",
        "value": "61317240197875763845342316676708396006808071189912838440639621893252563032088",
        "proof": [
            "0xf90211a0ee7bb65b2c9175c216c083d515100393d3df1c5d1562ba5430b47a2378bbf7a3a0bd4a0a1aa2a30cf33d2ac72811cbe94a4a740d684ed2e47d8b5467045d260a53a0da9802b89e3754905bdd88b9832877d626622521f88f9f14848efe66d4d4c14ba02baa24f0a677fdae54fc9bca721fd436d9b875404220df81b2b7ee06bf5a6331a037d3d942345dfb91f4b74860f7e7a1bcd4d185119bbbc04a0bf39435a45c968ba03687127d2db93c28e4e21f443441c49a88f7293315adc5b0c2d3261a9bd5de7ca07b939900521adc1cf79c95487243c1a483b7362635a5aa7abf9a368608f63b5ba0355d76aae5d8399e676cb39dabab9f6a81ff6d5bba87d303f702b2c53c4ac868a06ebf06ab13df08b75d11f7e671845539ae5fe7dd62d09776a9a9103fc297b088a0f24c675feedbe5a4c9340cd59c4fdb4f3f2a0ae34ac0b443f02b20f695e0e009a0ca770e1eeb6929ccd2cfc5dcbfd165d62f8010ee3eba2dabf1a16f3a0d6cff1da070f8b17957a7a5ea617d0623f9a64770dc14d1bbb7f0820ce976c23167cb9544a09608141e473b8359375b743859d9e454a52466a55e873f97c8a94338fdbb8b2aa0b79ac241efdaec57825f7e12b55cffdebd6dc6b4d9e20fc4d96ad60d3af44479a0c8a862878ee2f6d9ccf9bfc3a3cfe31c49c1a4757ec1f052890ccf2d3b903c2ca02a03ce7aa3aa7933acc369697df4478fab3704f46829bc48470f869b4ee9286a80",
            "0xf90211a0be06d2b8b88d9cbca69c1fd2a8f48176368b68c99ede0109d2b654a13785f227a03db7fc796776cd408216c8697be93157b1815b0a0be1d58b90e2c704e42195b2a034d744826d89ee782d95f43e58a79dcd934bd4d54bb2b957f2fa0deb03398f4aa02f059dceb315247ade49e6c390c6a818ba941c06370961da9c92257c26114d94a0f7e79218c397372d59009ea9a2fdefb840fe4c3fdaae6bab7830b080b06bf417a02577f5795148100c00113934385b43a818d491d4d1fa6a78242e5a1c2fc2cec4a03c8258002d732b18d72967a0b92544c5dac6c7f25c217aab0279fa041a56020aa0b05afe3c732a6be4f225080e76dde7c0455134ee58e04b9f85974d8680366787a0fa824cf006b5a43aac08d5233e76237a1edd95367124cbb606e9a43625a65261a054a65b05882bf76f5b0f93a75db990494aea9a5fec98871e7336afef81430fada027f1c6b07763472f57315161db4512f7f7d1c2e22fcd0146c79852c2056d6217a0526618d01851360666050b3e1083986115b18d9efedc578e8e18eb97dbc05424a0e3d68752629ab80360cb14d601b9019a412b0947c881dc1fad4362337462ddcea02dc7d14762b6b0e2933e966b47f495af6b7679a124d9be48a1b74e64aabf74cea0d912e0ff7815df596240257235875d4a9a0149cd4b57a6cae54e32cce7c148fca0cbad8e7c96fb3753a51476c4aa453de88b7e65d8d541a3251f4915beccaa956c80",
            "0xf8f1a00eae270fcc55c900f7ad161629804422c9b51284b833e8d91a61fbbf6c41740580a067e1fa51b8fb56279ecff934cbd4faeef6fe32d1bac44aa86dd607fb6eb14305a0b7060bdc7a3b406ee71007816b9b03c553a49142bc6de7cce936cc55e060a9928080a0e457751e198ad9a2b6d75a554bc85769d5fdd3f0c1797d19ca7b024a857656dca06f3a854c360536ee61c5dfd3dc502b58e79fd023311a5d9285d5d588f4f55e948080a0fbd8c01580c727c7a0024aa3ef5db83ea45d12c042e7fb61ee6dd3465eb62ac78080a0c21a3237e936bed514b20d8cf1ad6bff228b6a908821fd8929118788e41eaeab808080",
            "0xf8429f325db3f3a8d58cefbf340d53bbbeba5dba871452a1bc4c05a39f71535aa892a1a0879053fcd9f48d6d07976a124e11dd08ef67040079dae95a883cf13282d75818"
        ]
    },
    "l2_ibc_account_proof": {
        "storage_root": "0x478630675576d2e16a8b52a5f70ece26ae27dae4eb1a807a5c6fbf507d040ea3",
        "proof": [
            "0xf90211a044f2a50390056a16e8aa78f501de0b8d2463b249842980612e5107a4fa8d3791a0b9be30d2f00e992b922b2e4903e6f3ac7dc2c02873ca2ca9c7e362b69b5a87a3a01cfb6d916f279ff92bd2204d8523f691d86dd705f85ee69aa0b452a067c06023a060a4dc9ba7049da0c365f87831d923f98db737d2fa88f0c8e6c08f8f21aa7186a029e590c220a884936853d6797ab18cdaf54314da63825b9affaf7ad0a01edcaca0756282ff4ba3e0dbe28a9e8fd01b20f86d2c138783f0cf976ab7a7242674680ca092db23506db49cc54531360d2e7c08caea8b02d0ed2e5dd24baed7ce4936e80ba0f4bf8a451e744a5d5448f680b10983b61b9eb4f100749764a3831d160992971ca09d1829bb6e3287e1067238bba60e4f9d5de36caee83738759a28a229c8986da7a0c8592ccb2238e75e6d30d044a44570b4503ce5d8d934c4a9b3fec64bdade2f74a088fe1c94736efc9b423171824da15fa7c2f44890ba422bcc304602c64c7d2a5aa0e677ee1569d1e5b2480e0bf0e0aa227c7fcb8c448b9ed4275abb74f547092e17a09764a3044ac6626e09e212966f544e61ff960cba435a32d505c6244fa84d1dd5a00b5c09632b2e3c5f9eab7ee595868c6153216b4898df337a0c55f0aab13a34cfa07d6fbc61d091a640c820ba2600229de86b2f4f5d9914a0bc42f6065daae8ac95a0716bf200631bf75877f84368c8f91682e565f4b5ffacf40e5534aa8df60ac52380",
            "0xf90211a079bac9e8daca81dcc0475303e8a1cfe0846fa5eeab50b6d7613e1ef530bdbc03a034b1834638df7a50543cf02bc77e5a06015c48608ea128a3292a96b558426c2aa0be3702b0b746b698d3540a6c3523f313159ac28e40a3a73e4ff10e0e76a7d33ea08175f119dc00858f0a0473d7ad0c47c2818d00361731c4680ee2ed85e51b6478a0f78b1e23c79c669d1ce34aa8614fb649bfaed04331d19513da80d22492ddfe61a0ed6fc02d8eddf5639011b0ee6056886a7d0865aaad74ade0438bfc006c9d9bd1a02218c9921bda4835b2d2f005c53d2423e94444b704faf97cbed71d96ee944074a046447661c6f7e89ee6242ca288ba649943016dfb77c31a9cb7c208a8dab972a8a00cb325c57a6f50e65dcd5123eb9631f6f265bfa758f336217c801033443864e2a069aed626ca445bd0779ab1af257b8b0b48f6199c4ab8aa2423b682c54e41a2aaa0d76b374e6898ec497fa3f02d9a8e57d852256d57361c8c84e6869d845979a654a0e25c8a95c385af6fc46ab5d18f02e54c1de22287317233245c7d698b6e8ec79ea00d79fc5aaa0ae1b09e6d9ffb8e7d159f36c8dbbed1810e2b94b090dd1a6722eca0d9075f435dec929fb51447220eac105ca144f2214aff07cd5bf174d0ad71b953a0f9f8e34927b7012bc08ca2371dba63ccedd706dfac575e67a749fd9d9ca88c83a050baa6801acae2fe8aa82e36ed556a71491d452d5148b38a169933749510f0b280",
            "0xf90211a0b26fd72f0671d939fe579b00f904ece3f3e11052e1353ccb08d40596cd8c37cfa0de1b219c970ed502f9066767199fd779aa0111a05a707c452dbe88278feb38ada07385e72c8fab24b0cb0d160b4e678d03f7670210935e15c5533a3da9730c03e4a0af344c4cdfcbac2f74fcbb8a7e764c424c5b07c78aca719a7d7386847ab49246a0f55c95a55a237afe85c8828a3c234ccbe3f74437d33db34ed1e4f5cbc05bab1ea05f71f0f6c77123743d902f33add9cd804fdb6d9f9c3bf608b67c3451f243dba9a07730cc664853b1b06f04afadc123dbfe7eb940c5d276aa7297fe4d5c0d26c757a05bb5f29aa99712ace174c58c25f4266448180f0ac84e42eee315f715955dee62a0e6f26df62a7c1679b67aa27781133c149979a89bd3deb7790712bf9681f29b15a0824ec79254289dbced96c2f4e0adbde3f7a3d04b2ab9e3e3383853716f63cbaba0a00ede5826f0c588fb7608f615b71304c73587adbb1ad52690a3a4657dec1dd2a0da0d1848f6849b7f93a7d343e6cdcb302e6e80ea516dc2f56d38973d0cedcaa3a01beb75f595db3b03c27c4fbca2d8537dc75771aec904fd7de2918fb40255ab40a094ead3112f0c63e06c5aad4f4826f4c52e849512c0ba6775ee79200421f61b70a04f56c574108d95ac37b4294df0046e7f774561e5dfa0f84b9a2ae137df5b8a8aa0d44183572f633538235bc1122ada27e255c8a730e3b5e9943492e9d39f2652c280",
            "0xf90211a01fe6d631f49dd9d7d22bfe02caad536fb00a97c5f7e337135cd33781a0f41736a0b4dd1ef85ae978bdb3f122e7a305a35154bd6854f94da066c5f42d680ee5a3cda0bf7248843fe53ca60bf2d2ad0dd65000c010438c9b67af881456685462e90165a0de83f0083e85a39a3e4700f7d461505c53bd0e4426b7c34f973073fbf897dc9ba0a4d9f473853c1321f81da7a718d3570450dfd30c0309df79feb4400cc96fbeb3a07072ccc825fd83cd8753fec60fb3548b72daf25ef39397e8753bcdf0440290d0a0f2cc2f4087d1d9b15aa25ae2455fa6cbe9ba1191de440e61ded4e293af05eccca09d3a1abbb3f3ba8b999e1950369ea25af5e86a5c9a01c3ec444fd7580c94c637a0f85f4c78792d02583368afb766c4a47b8a1d936e89fb05b12b4949882fa8c96ea080d8f115a32d3e4efcaef7180c90ee41eb7e71f618969ee218092b089bb171a2a03997f1335609342964c04c4ef463eae4994f668bd0fbc6ab3fb49e8a1cbf5cdfa00c23352be11fbdf58f94718d8512476fe31b8ba20879d97d01c67619d50cfcbda0d342b627fb70ae3626e32ed7b22736bca2d23de8553893adb182b5d39de5c386a0327632cf4cd91ba6d58c9561d268dd7dcc1d7de46fe608ab42592edc1ecbf289a0e67e46a3f714f52ee138c40d9e671908a75eec64015496968bd57c47750808eca03de709e90421533104ef54ce589969d5b9e01157f26acdbc02269328296b33c580",
            "0xf89180a0f62b7996d2c28ae34564023261fc3609e0dd6d078fb43d13375035b74613e7e5808080808080a02ce31115e0dabd1f36351aa9eec42f840c6733a707936b87dcc1f79b932686e28080a0becf235dd342bad04f5a56a158914087c65e0a68289701625e3b640a3ece42a78080a0f3683f328e58c7f1536f7426810a62f2b217a918030d67c22fbefa76d83e92228080",
            "0xf8679e3b2b05f896ff0105268980868fa165a0822afb78240802859cc07e175bebb846f8448080a0478630675576d2e16a8b52a5f70ece26ae27dae4eb1a807a5c6fbf507d040ea3a0fa8c9db6c6cab7108dea276f4cd09d575674eb0852c0fa3187e59e98ef977998"
          ]
    },
    "l2_header": {
        "base_fee_per_gas": "0x0fc",
        "extra_data": "0x00000000fa00000006",
        "logs_bloom": "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "parent_hash": "0xcc106c0125e5ae7eea82f03e2d8113b9e95bb32553e9b64db3476210622b39d1",
        "receipts_root": "0xbc30cff881a86b158a91003aa2bb56d786fa66bd43ced4be2f4ea3801e3a0cc8",
        "state_root": "0x6bb1bdba41ee6ce02d343cc776c8bed3eb3e275b9e1532eda25fb754654c7879",
        "timestamp": "0x67e648e3",
        "transactions_root": "0x5b1b4aceaaf160a80a786adbee5448dee4de8efc62a67f0b05b1be6dbabc82d8",
        "withdrawals_root": "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
        "gas_limit": "0x01c9c380",
        "gas_used": "0xab6f",
        "sha3_uncles": "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
        "miner": "0x4200000000000000000000000000000000000011",
        "nonce": "0x0000000000000000",
        "number": "0xe70ae0",
        "difficulty": "0x0",
        "mix_hash": "0x1918e090ad5b6e2aef5cc28e03be90ad4d6e963d20ff6795195d828a0617a69a",
        "blob_gas_used": "0x0",
        "excess_blob_gas": "0x0",
        "parent_beacon_block_root": "0xd4f46ae1d3c63013523ecc2a08ecf88fe8e396144476b445afc417719a0fd1e8"
    },
    "output_index": 700,
    "output_root_proof": {
        "version": "0x0000000000000000000000000000000000000000000000000000000000000000",
        "state_root": "0x6bb1bdba41ee6ce02d343cc776c8bed3eb3e275b9e1532eda25fb754654c7879",
        "message_passer_storage_root": "0x4ea4000885c81d7e9cd3421f424db8bef47f6276fa88c1ebf9edca4e8aa7a1a3",
        "latest_block_hash": "0x32d25f30907f1df525076177a37a76dadee37499b698c85e9c2ed12c8761aea9"
    }
}"#
            .as_bytes(),
        )
        .unwrap();

        let l1_state_root =
            hex!("67bca5ce21aa5c48991a9aa2705371bd015fab01402dbcd2818c0b2cb19d5a6b").into();

        let r1 = verify_header(
            &client_state,
            &header,
            l1_state_root,
            header.l2_header.timestamp + FINALIZATION_PERIOD_SECONDS,
            FINALIZATION_PERIOD_SECONDS,
        );

        assert_eq!(r1, Ok(()));

        let r2 = verify_header(
            &client_state,
            &header,
            l1_state_root,
            header.l2_header.timestamp + FINALIZATION_PERIOD_SECONDS - 1,
            FINALIZATION_PERIOD_SECONDS,
        );

        assert_eq!(r2, Err(Error::HeaderNotFinalized));
    }

    #[test]
    fn test_verify_l2_header_is_related_to_output_root_proof() {
        verify_l2_header_is_related_to_output_root_proof(
            &OutputRootProof {
                version: hex!("0000000000000000000000000000000000000000000000000000000000000000")
                    .into(),
                state_root: hex!(
                    "2ef85f4dfdbe515eb89fb7be3a156ea476483a17225039e5352bc72c9d9b5626"
                )
                .into(),
                message_passer_storage_root: hex!(
                    "61f529e3532e620cdd166738d3c6ccf05f9fe70b9d943a45f9183c34f730a4be"
                )
                .into(),
                latest_block_hash: hex!(
                    "ab1325306c1a2dea55f29320e30d76e43e99a167d4e74e9a5e9c18bad5127564"
                )
                .into(),
            },
            &L2Header {
                parent_hash: hex!(
                    "885d2dc6e52bda916b3ca9dcca29c1048b3d29e7258467a0c195c240020fef0c"
                )
                .into(),
                sha3_uncles: hex!(
                    "1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"
                )
                .into(),
                miner: hex!("4200000000000000000000000000000000000011").into(),
                state_root: hex!(
                    "2ef85f4dfdbe515eb89fb7be3a156ea476483a17225039e5352bc72c9d9b5626"
                )
                .into(),
                transactions_root: hex!(
                    "8b6c76337a74cf1447e0ff1143606bcca0896d2e842dda04958e709bf55270be"
                )
                .into(),
                receipts_root: hex!(
                    "351a05348a16ac245a8f9d8358f65f43f47bae4a1848e147a368b61ff3d86370"
                )
                .into(),
                logs_bloom: Box::new(hex!("00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000").into()),
                difficulty: 0_u64.into(),
                number: 16632000_u64.into(),
                gas_limit: 30000000,
                gas_used: 43887,
                timestamp: 1746125987,
                extra_data: hex!("00000000fa00000006").into(),
                mix_hash: hex!("8b8f9d75ccac014aae0e18afbcc54bc2c6e9e3aba801c81bdc359fb7e0b7f414")
                    .into(),
                nonce: hex!("0000000000000000").into(),
                base_fee_per_gas: 252_u64.into(),
                withdrawals_root: hex!(
                    "56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421"
                )
                .into(),
                blob_gas_used: 0,
                excess_blob_gas: 0,
                parent_beacon_block_root: hex!(
                    "a4052c2062dd55cd35cd70061fbfd403863f1a08ac41df04f686fbf0460dd879"
                )
                .into(),
                requests_hash: Nullable::from(None),
            },
        )
        .unwrap();
    }
}
