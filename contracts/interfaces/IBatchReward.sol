// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./IOwnable.sol";

interface IBatchReward is IOwnable {
    struct BatchRewardDetail {
        address server;
        address prover;
        uint256 elapsedTime;
        uint256 serverReward;
        uint256 proverReward;
        uint256 totalReward;
    }

    event PayToSever(address indexed server, uint256 indexed batchNumer, uint256 indexed reward);

    event PayToProver(address indexed prover, uint256 indexed batchNumer, uint256 indexed reward);

    function calRewards(uint256 _batchNumber, address _server) external;

    function payRewards(address _prover, uint256 _batchNumer, uint256 _proof_coefficient) external;

    function proverRewards(address _prover) external view returns (uint256);

    function updateBatchRewardRate(uint256 _batchRewardRate) external;

    function updateProverBaseReward(uint256 _proverBaseReward) external;

    function updateProverProofRewardRate(uint256 _proverProofRewardRate) external;

    function updateProverRewardLimit(uint256 _proverRewardLimit) external;

    function updateToken(address _token) external;
}
