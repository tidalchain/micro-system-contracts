// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./openzeppelin/token/ERC20/IERC20.sol";
import "./openzeppelin/utils/math/Math.sol";
import "./interfaces/IBatchEvent.sol";
import "./interfaces/IAssignment.sol";
import "./interfaces/IFeePool.sol";
import "./interfaces/IWhiteList.sol";
import "./interfaces/IBatchReward.sol";
import "./libraries/FixedPointMath.sol";
import {BOOTLOADER_FORMAL_ADDRESS, SYSTEM_CONTEXT_CONTRACT, ASSIGNMENT_ADDRESS, FEE_POOL_ADDRESS, BATCH_EVENT_CALLER_ADDRESS, BATCH_REWARD_ADDRESS} from "./Constants.sol";

contract BatchEvent is IBatchEvent {
    using Math for uint256;

    modifier onlyBootloader() {
        require(msg.sender == BOOTLOADER_FORMAL_ADDRESS);
        _;
    }

    modifier onlyCaller() {
        require(msg.sender == BATCH_EVENT_CALLER_ADDRESS);
        _;
    }

    function onCreateBatch(uint256 _batchNumber, address _miner) public onlyBootloader {
        IBatchReward(BATCH_REWARD_ADDRESS).calRewards(_batchNumber, _miner);
        IAssignment(ASSIGNMENT_ADDRESS).assignment(_batchNumber);
    }

    function onCommitBatch(uint256 _batchNumber, bytes32 _batchHash, address _sender) public onlyCaller {
        if (SYSTEM_CONTEXT_CONTRACT.getBatchHash(_batchNumber) != _batchHash) {
            return;
        }

        IFeePool(FEE_POOL_ADDRESS).checkAndPayRewards(uint64(block.timestamp));
    }

    function onProveBatch(
        uint256 _batchNumber,
        bytes32 _batchHash,
        address _sender,
        address _prover,
        uint256 _timeTaken
    ) public onlyCaller {
        if (SYSTEM_CONTEXT_CONTRACT.getBatchHash(_batchNumber) != _batchHash) {
            return;
        }

        IAssignment(ASSIGNMENT_ADDRESS).finishBatch(_batchNumber, _prover, _timeTaken);
    }

    function onExecuteBatch(uint256 _batchNumber, bytes32 _batchHash, address _sender) public onlyCaller {
        if (SYSTEM_CONTEXT_CONTRACT.getBatchHash(_batchNumber) != _batchHash) {
            return;
        }
    }
}
