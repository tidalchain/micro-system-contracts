// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IBatchEvent {
    function onCommitBatch(uint256 _batchNumber, bytes32 _batchHash, address _sender) external;

    function onProveBatch(
        uint256 _batchNumber,
        bytes32 _batchHash,
        address _sender,
        address _prover,
        uint256 _timeTaken
    ) external;

    function onExecuteBatch(uint256 _batchNumber, bytes32 _batchHash, address _sender) external;
}
