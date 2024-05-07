// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IAccountCodeStorage} from "./interfaces/IAccountCodeStorage.sol";
import {INonceHolder} from "./interfaces/INonceHolder.sol";
import {IContractDeployer} from "./interfaces/IContractDeployer.sol";
import {IKnownCodesStorage} from "./interfaces/IKnownCodesStorage.sol";
import {IImmutableSimulator} from "./interfaces/IImmutableSimulator.sol";
import {IEthToken} from "./interfaces/IEthToken.sol";
import {IL1Messenger} from "./interfaces/IL1Messenger.sol";
import {ISystemContext} from "./interfaces/ISystemContext.sol";
import {ICompressor} from "./interfaces/ICompressor.sol";
import {IComplexUpgrader} from "./interfaces/IComplexUpgrader.sol";
import {IBootloaderUtilities} from "./interfaces/IBootloaderUtilities.sol";

/// @dev All the system contracts introduced by micro have their addresses
/// started from 2^15 in order to avoid collision with Ethereum precompiles.
uint160 constant SYSTEM_CONTRACTS_OFFSET = 0x8000; // 2^15

/// @dev All the system contracts must be located in the kernel space,
/// i.e. their addresses must be below 2^16.
uint160 constant MAX_SYSTEM_CONTRACT_ADDRESS = 0xffff; // 2^16 - 1

address constant ECRECOVER_SYSTEM_CONTRACT = address(0x01);
address constant SHA256_SYSTEM_CONTRACT = address(0x02);
address constant ECADD_SYSTEM_CONTRACT = address(0x06);
address constant ECMUL_SYSTEM_CONTRACT = address(0x07);

/// @dev The maximal possible address of an L1-like precompie. These precompiles maintain the following properties:
/// - Their extcodehash is EMPTY_STRING_KECCAK
/// - Their extcodesize is 0 despite having a bytecode formally deployed there.
uint256 constant CURRENT_MAX_PRECOMPILE_ADDRESS = 0xff;

address payable constant BOOTLOADER_FORMAL_ADDRESS = payable(address(SYSTEM_CONTRACTS_OFFSET + 0x01));
IAccountCodeStorage constant ACCOUNT_CODE_STORAGE_SYSTEM_CONTRACT = IAccountCodeStorage(
    address(SYSTEM_CONTRACTS_OFFSET + 0x02)
);
INonceHolder constant NONCE_HOLDER_SYSTEM_CONTRACT = INonceHolder(address(SYSTEM_CONTRACTS_OFFSET + 0x03));
IKnownCodesStorage constant KNOWN_CODE_STORAGE_CONTRACT = IKnownCodesStorage(address(SYSTEM_CONTRACTS_OFFSET + 0x04));
IImmutableSimulator constant IMMUTABLE_SIMULATOR_SYSTEM_CONTRACT = IImmutableSimulator(
    address(SYSTEM_CONTRACTS_OFFSET + 0x05)
);
IContractDeployer constant DEPLOYER_SYSTEM_CONTRACT = IContractDeployer(address(SYSTEM_CONTRACTS_OFFSET + 0x06));

// A contract that is allowed to deploy any codehash
// on any address. To be used only during an upgrade.
address constant FORCE_DEPLOYER = address(SYSTEM_CONTRACTS_OFFSET + 0x07);
IL1Messenger constant L1_MESSENGER_CONTRACT = IL1Messenger(address(SYSTEM_CONTRACTS_OFFSET + 0x08));
address constant MSG_VALUE_SYSTEM_CONTRACT = address(SYSTEM_CONTRACTS_OFFSET + 0x09);

IEthToken constant ETH_TOKEN_SYSTEM_CONTRACT = IEthToken(address(SYSTEM_CONTRACTS_OFFSET + 0x0a));

address constant KECCAK256_SYSTEM_CONTRACT = address(SYSTEM_CONTRACTS_OFFSET + 0x10);

ISystemContext constant SYSTEM_CONTEXT_CONTRACT = ISystemContext(payable(address(SYSTEM_CONTRACTS_OFFSET + 0x0b)));

IBootloaderUtilities constant BOOTLOADER_UTILITIES = IBootloaderUtilities(address(SYSTEM_CONTRACTS_OFFSET + 0x0c));

address constant EVENT_WRITER_CONTRACT = address(SYSTEM_CONTRACTS_OFFSET + 0x0d);

ICompressor constant COMPRESSOR_CONTRACT = ICompressor(address(SYSTEM_CONTRACTS_OFFSET + 0x0e));

IComplexUpgrader constant COMPLEX_UPGRADER_CONTRACT = IComplexUpgrader(address(SYSTEM_CONTRACTS_OFFSET + 0x0f));

address constant DEPOSIT_ADDRESS = address(SYSTEM_CONTRACTS_OFFSET + 0x100);

address constant FEE_POOL_ADDRESS = payable(address(SYSTEM_CONTRACTS_OFFSET + 0x101));

address constant BATCH_EVENT_ADDRESS = address(SYSTEM_CONTRACTS_OFFSET + 0x102);

address constant DAO_ADDRESS = payable(address(SYSTEM_CONTRACTS_OFFSET + 0x103));

address constant BATCH_EVENT_CALLER_ADDRESS = payable(address(SYSTEM_CONTRACTS_OFFSET + 0x104));

address constant WHITE_LIST_ADDRESS = address(SYSTEM_CONTRACTS_OFFSET + 0x105);

address constant BATCH_REWARD_ADDRESS = address(SYSTEM_CONTRACTS_OFFSET + 0x106);

address constant RECEVING_ADDRESS = address(SYSTEM_CONTRACTS_OFFSET + 0x107);

address constant ASSIGNMENT_ADDRESS = address(SYSTEM_CONTRACTS_OFFSET + 0x108);

/// @dev If the bitwise AND of the extraAbi[2] param when calling the MSG_VALUE_SIMULATOR
/// is non-zero, the call will be assumed to be a system one.
uint256 constant MSG_VALUE_SIMULATOR_IS_SYSTEM_BIT = 1;

/// @dev The maximal msg.value that context can have
uint256 constant MAX_MSG_VALUE = 2 ** 128 - 1;

/// @dev Prefix used during derivation of account addresses using CREATE2
/// @dev keccak256("microCreate2")
bytes32 constant CREATE2_PREFIX = 0xe6de713314dd702f158c6b28692295beae4939dc7462115ade76e955e783a18d;
/// @dev Prefix used during derivation of account addresses using CREATE
/// @dev keccak256("microCreate")
bytes32 constant CREATE_PREFIX = 0x941ec1d171e571dac4e07b960434c6ad80cf4cdb9fbaa20916c35f2e179e0203;

/// @dev Each state diff consists of 156 bytes of actual data and 116 bytes of unused padding, needed for circuit efficiency.
uint256 constant STATE_DIFF_ENTRY_SIZE = 272;

/// @dev While the "real" amount of pubdata that can be sent rarely exceeds the 110k - 120k, it is better to
/// allow the operator to provide any reasonably large value in order to avoid unneeded constraints on the operator.
uint256 constant MAX_ALLOWED_PUBDATA_PER_BATCH = 520000;

enum SystemLogKey {
    L2_TO_L1_LOGS_TREE_ROOT_KEY,
    TOTAL_L2_TO_L1_PUBDATA_KEY,
    STATE_DIFF_HASH_KEY,
    PACKED_BATCH_AND_L2_BLOCK_TIMESTAMP_KEY,
    PREV_BATCH_HASH_KEY,
    CHAINED_PRIORITY_TXN_HASH_KEY,
    NUMBER_OF_LAYER_1_TXS_KEY,
    EXPECTED_SYSTEM_CONTRACT_UPGRADE_TX_HASH_KEY
}

/// @dev The number of leaves in the L2->L1 log Merkle tree.
/// While formally a tree of any length is acceptable, the node supports only a constant length of 2048 leaves.
uint256 constant L2_TO_L1_LOGS_MERKLE_TREE_LEAVES = 2048;

/// @dev The length of the derived key in bytes inside compressed state diffs.
uint256 constant DERIVED_KEY_LENGTH = 32;
/// @dev The length of the enum index in bytes inside compressed state diffs.
uint256 constant ENUM_INDEX_LENGTH = 8;
/// @dev The length of value in bytes inside compressed state diffs.
uint256 constant VALUE_LENGTH = 32;

/// @dev The length of the compressed initial storage write in bytes.
uint256 constant COMPRESSED_INITIAL_WRITE_SIZE = DERIVED_KEY_LENGTH + VALUE_LENGTH;
/// @dev The length of the compressed repeated storage write in bytes.
uint256 constant COMPRESSED_REPEATED_WRITE_SIZE = ENUM_INDEX_LENGTH + VALUE_LENGTH;

/// @dev The position from which the initial writes start in the compressed state diffs.
uint256 constant INITIAL_WRITE_STARTING_POSITION = 4;

/// @dev Each storage diffs consists of the following elements:
/// [20bytes address][32bytes key][32bytes derived key][8bytes enum index][32bytes initial value][32bytes final value]
/// @dev The offset of the deriived key in a storage diff.
uint256 constant STATE_DIFF_DERIVED_KEY_OFFSET = 52;
/// @dev The offset of the enum index in a storage diff.
uint256 constant STATE_DIFF_ENUM_INDEX_OFFSET = 84;
/// @dev The offset of the final value in a storage diff.
uint256 constant STATE_DIFF_FINAL_VALUE_OFFSET = 124;
