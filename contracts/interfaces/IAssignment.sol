// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IOwnable.sol";

interface IAssignment is IOwnable {
    enum BatchStatus {
        UnGenerated,
        NotAssignment,
        Assgimented,
        Finished
    }
    struct BatchApplyInfo {
        address prover;
        uint256 startTime;
        uint256 time_taken;
        uint256 maxScore;
        uint256 applyStartTime;
        bool hasPenalize;
    }

    struct BatchInfo {
        BatchStatus batchStatus;
        BatchApplyInfo[] applyInfoList;
    }

    event NewBatch(uint256 indexed batchNumber);

    event AssignmentBatch(address prover, uint256 batchNumber, uint256 applyInfoIndex, uint256 startTime);

    event FinishBatch(uint256 indexed batchNumber);

    event ProofApply(
        address indexed prover,
        uint256 indexed batchNumber,
        bool indexed isProver,
        uint256 applyInfoIndex,
        uint256 score
    );

    function proofApply(uint256 _batchNumber) external;

    function assignment(uint256 _batchNumber) external;

    function finishBatch(uint256 _batchNumber, address _prover, uint256 _time_taken) external;

    function penalizeBatch(uint256 _batchNumber, uint256 _applyInfoIndex) external;

    function updateScanCount(uint256 _scanCount) external;

    function getBatchQueueLength() external view returns (uint256);

    function getBatchNumber(uint256 index) external view returns (uint256);

    function getBatchNumberList(uint256 start, uint256 limit) external view returns (uint256[] memory);

    function canBePenalize(uint256 _batchNumber, address _prover, uint256 _applyInfoIndex) external view returns (bool);
}
