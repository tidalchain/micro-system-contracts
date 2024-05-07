// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./openzeppelin/utils/math/SafeMath.sol";
import "./interfaces/IDeposit.sol";
import "./interfaces/IAssignment.sol";
import "./libraries/DoubleEndedQueue.sol";

import {BATCH_EVENT_ADDRESS, DEPOSIT_ADDRESS} from "./Constants.sol";

contract Assignment is IAssignment {
    using SafeMath for uint256;

    using DoubleEndedQueue for DoubleEndedQueue.Uint256Deque;

    address private _owner;

    /// @dev not assignment batchNumber queue
    DoubleEndedQueue.Uint256Deque public batchNumberQueue;

    /// @dev scan batchNumberQueue count
    uint256 public scanCount;

    /// @dev  address => batchNumber => applyTime
    mapping(address => mapping(uint256 => uint256)) batchApplyTime;

    /// @dev  batch info
    mapping(uint256 => BatchInfo) public batchInfo;

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    modifier onlyBatchEvent() {
        require(msg.sender == BATCH_EVENT_ADDRESS, "only proof reward pool can call");
        _;
    }
    modifier onlyDeposit() {
        require(msg.sender == DEPOSIT_ADDRESS, "only deposit contract can call");
        _;
    }

    function initialize(address newOwner) public {
        require(owner() == address(0), "Has been initialized");
        require(newOwner != address(0), "Invalid newOwner");

        scanCount = 10;
        _transferOwnership(newOwner);
        // Initialize the data for the first batch during contract initialization，only first batch
        updateBatch(1, false);
    }

    /// @dev prover requests batch proof
    function proofApply(uint256 _batchNumber) external override {
        bool b = IDeposit(DEPOSIT_ADDRESS).canApplyForProof(msg.sender);
        require(b, "incorrect prover status");

        BatchInfo storage info = batchInfo[_batchNumber];
        require(info.batchStatus == BatchStatus.NotAssignment, "incorrect batch status");
        BatchApplyInfo[] storage applyInfoList = info.applyInfoList;

        // retrieve the most recent applyInfo as all prior ones are no longer valid
        BatchApplyInfo storage applyInfo = applyInfoList[applyInfoList.length - 1];

        // upon the first application for this batch, increment the application count
        if (batchApplyTime[msg.sender][_batchNumber] < applyInfo.applyStartTime) {
            IDeposit(DEPOSIT_ADDRESS).addApplyCount(msg.sender);
        }

        uint256 proverScore = IDeposit(DEPOSIT_ADDRESS).score(msg.sender);

        bool isProver = false;
        if (proverScore > applyInfo.maxScore) {
            applyInfo.maxScore = proverScore;
            applyInfo.prover = msg.sender;
            isProver = true;
        }
        batchApplyTime[msg.sender][_batchNumber] = block.timestamp;

        emit ProofApply(msg.sender, _batchNumber, isProver, applyInfoList.length - 1, proverScore);
    }

    /// @dev  assignment the previous batches
    /// @dev  put current batch into queue
    function assignment(uint256 _batchNumber) external override onlyBatchEvent {
        uint256 length = batchNumberQueue.length();
        if (length > scanCount) {
            length = scanCount;
        }
        uint256[] memory tmp = new uint256[](length);
        uint256 tmpLength = 0;
        // assignment the previous batches
        if (length > 0) {
            uint256 currentTime = block.timestamp;
            for (uint i = 0; i < length; i++) {
                uint256 batchNumber = batchNumberQueue.popFront();
                BatchInfo storage info = batchInfo[batchNumber];
                if (info.batchStatus == BatchStatus.NotAssignment) {
                    BatchApplyInfo[] storage applyInfoList = info.applyInfoList;
                    uint256 infoIndex = applyInfoList.length - 1;
                    BatchApplyInfo storage applyInfo = applyInfoList[infoIndex];
                    // if nobody proof,continue
                    if (applyInfo.prover == address(0) || applyInfo.maxScore == 0) {
                        tmp[tmpLength] = batchNumber;
                        tmpLength++;
                        continue;
                    }
                    info.batchStatus = BatchStatus.Assgimented;
                    applyInfo.startTime = currentTime;
                    //clear applyCount
                    IDeposit(DEPOSIT_ADDRESS).assignmentBatch(applyInfo.prover);
                    emit AssignmentBatch(applyInfo.prover, batchNumber, infoIndex, currentTime);
                }
            }
        }
        // put the batch that no one applies for back into the queue
        for (uint i = tmpLength; i >= 1; i--) {
            uint256 batchNumber = tmp[i - 1];
            batchNumberQueue.pushFront(batchNumber);
        }

        // put current batch into queue
        updateBatch(_batchNumber, false);
    }

    /// @dev The batch proof has been completed, and rewards will be issued
    function finishBatch(uint256 _batchNumber, address _prover, uint256 _time_taken) external override onlyBatchEvent {
        BatchInfo storage info = batchInfo[_batchNumber];
        if (info.batchStatus != BatchStatus.Assgimented) {
            return;
        }
        BatchApplyInfo[] storage applyInfoList = info.applyInfoList;

        BatchApplyInfo storage applyInfo = applyInfoList[applyInfoList.length - 1];
        if (applyInfo.prover != _prover) {
            return;
        }

        applyInfo.time_taken = _time_taken;
        info.batchStatus = BatchStatus.Finished;

        IDeposit(DEPOSIT_ADDRESS).proveBatch(_batchNumber, _prover, _time_taken);

        emit FinishBatch(_batchNumber);
    }

    function penalizeBatch(uint256 _batchNumber, uint256 _applyInfoIndex) external onlyDeposit {
        BatchInfo storage info = batchInfo[_batchNumber];
        require(info.batchStatus == BatchStatus.Assgimented, "incorrect batch status");

        BatchApplyInfo[] storage applyInfoList = info.applyInfoList;

        require(_applyInfoIndex + 1 <= applyInfoList.length, "out of index");
        BatchApplyInfo storage applyInfo = applyInfoList[_applyInfoIndex];

        applyInfo.hasPenalize = true;
        updateBatch(_batchNumber, true);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /// @dev modify the number of items retrieved from the queue each time
    function updateScanCount(uint256 _scanCount) external override onlyOwner {
        require(_scanCount > 0, "Invalid params");
        scanCount = _scanCount;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /// @return The batch info
    function getBatchApplyInfo(
        uint256 _batchNumber
    ) external view returns (BatchStatus, address, uint256, uint256, uint256, uint256) {
        BatchInfo memory info = batchInfo[_batchNumber];

        BatchApplyInfo memory applyInfo = info.applyInfoList[info.applyInfoList.length - 1];
        return (
            info.batchStatus,
            applyInfo.prover,
            applyInfo.startTime,
            applyInfo.time_taken,
            applyInfo.maxScore,
            applyInfo.applyStartTime
        );
    }

    /// @dev get batch history apply info
    function getBatchApplyHistory(
        uint256 _batchNumber,
        uint256 _applyInfoIndex
    ) external view returns (BatchApplyInfo memory) {
        BatchInfo memory info = batchInfo[_batchNumber];
        require(_applyInfoIndex < info.applyInfoList.length, "Out of index");
        return info.applyInfoList[_applyInfoIndex];
    }

    /// @return The queue length
    function getBatchQueueLength() external view override returns (uint256) {
        return batchNumberQueue.length();
    }

    /// @return The batchNumber in queue
    function getBatchNumber(uint256 index) external view override returns (uint256) {
        return batchNumberQueue.at(index);
    }

    /// @return The batchNumber list in queue
    function getBatchNumberList(uint256 start, uint256 limit) external view override returns (uint256[] memory) {
        return batchNumberQueue.getQueueList(start, limit);
    }

    /// @return Can the current protector be punished
    function canBePenalize(
        uint256 _batchNumber,
        address _prover,
        uint256 _applyInfoIndex
    ) external view returns (bool) {
        BatchInfo memory info = batchInfo[_batchNumber];
        if (info.batchStatus != BatchStatus.Assgimented) {
            return false;
        }
        BatchApplyInfo[] memory applyInfoList = info.applyInfoList;
        if (_applyInfoIndex + 1 > applyInfoList.length) {
            return false;
        }
        BatchApplyInfo memory applyInfo = applyInfoList[_applyInfoIndex];
        if (applyInfo.hasPenalize) {
            return false;
        }
        if (applyInfo.prover != _prover) {
            return false;
        }
        return true;
    }

    /// @dev  modify calculate score configs
    function updateBatch(uint256 _batchNumber, bool isPenalize) private {
        BatchInfo storage info = batchInfo[_batchNumber];
        if (info.batchStatus == BatchStatus.NotAssignment || info.batchStatus == BatchStatus.Finished) {
            return;
        }
        info.batchStatus = BatchStatus.NotAssignment;
        BatchApplyInfo memory applyInfo = BatchApplyInfo(address(0), 0, 0, 0, block.timestamp, false);
        info.applyInfoList.push(applyInfo);

        if (isPenalize) {
            batchNumberQueue.pushFront(_batchNumber);
        } else {
            batchNumberQueue.pushBack(_batchNumber);
        }

        emit NewBatch(_batchNumber);
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
