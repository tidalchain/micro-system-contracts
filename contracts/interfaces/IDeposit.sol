// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IOwnable.sol";

interface IDeposit is IOwnable {
    enum Status {
        UnDeposit,
        Normal,
        Frozen,
        Applying
    }

    struct ProverTokenDepositInfo {
        Status status;
        uint256 applyingTime;
        uint256 depositAmount;
        uint256 depositTime;
    }

    struct ProverBaseInfo {
        uint256 totalProofCount;
        uint256 proofCount;
        uint256 totalProofTime;
        uint256 latestProofTime;
        uint256 penalizeCount;
        uint256 applyCount;
        mapping(address => ProverTokenDepositInfo) tokenInfo;
    }

    event Deposit(address indexed prover, address indexed token, uint256 indexed amount);

    event Withdraw(address indexed prover, address indexed token, uint256 amount);

    event Penalize(
        address indexed prover,
        uint256 indexed batchNumber,
        uint256 indexed applyInfoIndex,
        address token,
        uint256 amount
    );

    event UpdateConfig(
        uint256 proofProportion,
        uint256 depositProportion,
        uint256 participateProportion,
        uint256 taskCompletedProportion
    );

    function deposit(address _token, uint256 _amount) external payable;

    function withdrawApply(address _token) external;

    function withdraw(address _token) external;

    function penalize(uint256 _batchNumber, address _prover, uint256 _applyInfoIndex) external;

    function proveBatch(uint256 _batchNumber, address _prover, uint256 _time_taken) external;

    function updateMinDepositAmount(address _token, uint256 _minDepositAmount) external;

    function updateMinDepositTime(address _token, uint256 _minDepositTime) external;

    function updateWaitingTime(uint256 _waitingTime) external;

    function updatePenalizeRatio(uint16 _penalizeRatio) external;

    function updateScoreConfig(
        uint256 _proofProportion,
        uint256 _depositProportion,
        uint256 _participateProportion,
        uint256 _taskCompletedProportion
    ) external;

    function updateParticipateCoefficient(uint16 _participateCoefficient) external;

    function addToken(address _token) external;

    function removeToken(address _token) external;

    function updateTokenEnable(address _token, bool _enable) external;

    function addApplyCount(address _prover) external;

    function assignmentBatch(address _prover) external;

    function mainToken() external view returns (address);

    function getMinDepositAmount(address _token) external view returns (uint256);

    function getMinDepositTime(address _token) external view returns (uint256);

    function getWaitingTime() external view returns (uint256);

    function score(address _prover) external view returns (uint256);

    function getScoreConfig() external view returns (uint256, uint256, uint256, uint256);

    function getProverBaseInfo(
        address _prover
    ) external view returns (Status, uint256, uint256, uint256, uint256, uint256, uint256);

    function getDepositAmount(address _prover, address _token) external view returns (uint256);

    function getDepositTime(address _prover, address _token) external view returns (uint256);

    function getApplyingTime(address _prover, address _token) external view returns (uint256);

    function getAllToken() external view returns (address[] memory);

    function tokenEnable(address _token) external view returns (bool);

    function getProverTokenDepositInfo(
        address _prover,
        address _token
    ) external view returns (ProverTokenDepositInfo memory);

    function canApplyForProof(address _prover) external view returns (bool);
}
