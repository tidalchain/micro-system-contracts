// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./openzeppelin/token/ERC20/IERC20.sol";
import "./openzeppelin/utils/Address.sol";
import "./openzeppelin/utils/math/SafeMath.sol";
import "./interfaces/IDeposit.sol";
import "./interfaces/IWhiteList.sol";
import "./interfaces/IBatchReward.sol";
import "./interfaces/IAssignment.sol";
import "./libraries/TransferHelper.sol";

import {BATCH_EVENT_ADDRESS, ASSIGNMENT_ADDRESS, WHITE_LIST_ADDRESS, BATCH_REWARD_ADDRESS, RECEVING_ADDRESS} from "./Constants.sol";

contract Deposit is IDeposit {
    using SafeMath for uint256;

    address private _owner;

    address public admin;

    /// @dev deposit token to be prover
    address public override mainToken;

    /// @dev waiting time after withdrawal application
    uint256 waitingTime;

    /// @dev calculate score , proof proportion config
    uint256 public proofProportion;

    /// @dev calculate score , deposit proportion config
    uint256 public depositProportion;

    /// @dev calculate score , articipate proportion config
    uint256 public participateProportion;

    /// @dev calculate score , task completed proportion config
    uint256 public taskCompletedProportion;

    /// @dev participate coefficient ,defalut 24
    uint16 public participateCoefficient;

    /// @dev remit penalize count
    uint16 remitPenalizeCount;

    /// @dev penalize ratio
    uint16 penalizeRatio;

    /// @dev base denominator
    uint16 constant denominator = 10000;

    /// @dev total proof count
    uint256 totalProofCount;
    /// @dev  total proof time
    uint256 totalProofTime;

    address[] public tokens;

    /// @dev  token is allowed to deposit
    mapping(address => bool) public tokenEnable;

    /// @dev  prover base info
    mapping(address => ProverBaseInfo) public proverBaseInfo;

    /// @dev token  min deposit amount
    mapping(address => uint256) public tokenMinDepositAmount;

    /// @dev token  min deposit time
    mapping(address => uint256) public tokenMinDepositTime;

    /// @dev token has deposited amount
    mapping(address => uint256) public tokenTotalDeposit;

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "This method require owner call flag");
        _;
    }

    modifier onlyAssignment() {
        require(msg.sender == ASSIGNMENT_ADDRESS, "only assignment can call");
        _;
    }
    modifier scoreConfigCheck(
        uint256 _proofProportion,
        uint256 _depositProportion,
        uint256 _participateProportion,
        uint256 _taskCompletedProportion
    ) {
        require(_proofProportion >= 0 && _proofProportion < 10000, "score config Invalid params");
        require(_depositProportion >= 0 && _depositProportion < 10000, "score config Invalid params");
        require(_participateProportion >= 0 && _participateProportion < 10000, "score config Invalid params");
        require(_taskCompletedProportion >= 0 && _taskCompletedProportion < 10000, "score config Invalid params");

        _;
    }

    function initialize(address newOwner, address _admin) public {
        require(owner() == address(0), "Has been initialized");
        require(newOwner != address(0), "Invalid newOwner");
        require(_admin != address(0), "Invalid _admin");

        admin = _admin;
        tokenMinDepositAmount[address(0)] = 1000 * 10 ** 18;
        tokenMinDepositTime[address(0)] = 2592000;
        waitingTime = 86400;
        remitPenalizeCount = 1;
        penalizeRatio = 500;
        participateCoefficient = 24;

        tokens.push(address(0));
        tokenEnable[address(0)] = true;
        setScoreConfig(4000, 3000, 2000, 1000);
        _transferOwnership(newOwner);
    }

    /// @dev deposit tokens to obtain the permission to prove batches
    function deposit(address _token, uint256 _amount) external payable override {
        require(_amount > 0, "Invalid params");
        require(!Address.isContract(msg.sender), "only eoa");

        require(IWhiteList(WHITE_LIST_ADDRESS).whiteList(msg.sender), "only white list");
        require(!IWhiteList(WHITE_LIST_ADDRESS).blackList(msg.sender), "in black list");

        require(tokenEnable[_token], "token cannot depost ");

        ProverBaseInfo storage baseInfo = proverBaseInfo[msg.sender];

        ProverTokenDepositInfo storage tokenInfo = baseInfo.tokenInfo[_token];
        require(tokenInfo.status != Status.Applying, "incorrect status");
        uint256 depositAmount = tokenInfo.depositAmount;

        if (_token == address(0)) {
            require(_amount == msg.value, "Insufficient account balance");
        } else {
            require(IERC20(_token).balanceOf(msg.sender) >= _amount, "Insufficient account balance");
            TransferHelper.safeTransferFrom(_token, msg.sender, address(this), _amount);
        }

        uint256 minDepositAmount = tokenMinDepositAmount[_token];
        require(depositAmount.add(_amount) >= minDepositAmount, "less than min deposit");

        if (depositAmount == 0) {
            tokenInfo.depositTime = block.timestamp;
        }

        tokenInfo.depositAmount += _amount;
        tokenInfo.status = Status.Normal;

        tokenTotalDeposit[_token] += _amount;
        emit Deposit(msg.sender, _token, _amount);
    }

    /// @dev An application must be submitted prior to withdrawing token.
    function withdrawApply(address _token) external override {
        ProverBaseInfo storage baseInfo = proverBaseInfo[msg.sender];

        ProverTokenDepositInfo storage tokenInfo = baseInfo.tokenInfo[_token];
        uint256 minDepositTime = tokenMinDepositTime[_token];
        require(tokenInfo.depositAmount > 0, "not deposit");
        require(block.timestamp >= tokenInfo.depositTime.add(minDepositTime), "unexpired");
        tokenInfo.applyingTime = block.timestamp;
        tokenInfo.status = Status.Applying;
    }

    /// @dev after waitingTime,withdraw token
    function withdraw(address _token) external override {
        ProverBaseInfo storage baseInfo = proverBaseInfo[msg.sender];

        ProverTokenDepositInfo storage tokenInfo = baseInfo.tokenInfo[_token];
        require(tokenInfo.status == Status.Applying, "apply first");
        require(block.timestamp >= tokenInfo.applyingTime.add(waitingTime), "unexpired");

        uint256 depositAmount = tokenInfo.depositAmount;
        transferToken(_token, msg.sender, depositAmount);

        tokenInfo.status = Status.UnDeposit;
        tokenInfo.applyingTime = 0;
        tokenInfo.depositAmount = 0;
        tokenInfo.depositTime = 0;

        emit Withdraw(msg.sender, _token, depositAmount);
    }

    /// @dev penalize the prover who violates the rules by timing out or failing to provide proof.
    function penalize(uint256 _batchNumber, address _prover, uint256 _applyInfoIndex) external override onlyAdmin {
        bool b = IAssignment(ASSIGNMENT_ADDRESS).canBePenalize(_batchNumber, _prover, _applyInfoIndex);

        uint256 penalizeAmount = 0;

        ProverBaseInfo storage baseInfo = proverBaseInfo[_prover];
        baseInfo.penalizeCount += 1;
        if (baseInfo.penalizeCount > remitPenalizeCount) {
            //penalize
            ProverTokenDepositInfo storage tokenInfo = baseInfo.tokenInfo[mainToken];
            penalizeAmount = calPenalizeAmount(tokenInfo);
            transferToken(mainToken, RECEVING_ADDRESS, penalizeAmount);
            tokenInfo.depositAmount -= penalizeAmount;
            uint256 minDepositAmount = tokenMinDepositAmount[mainToken];
            if (tokenInfo.depositAmount < minDepositAmount) {
                tokenInfo.status = Status.Frozen;
            }
        }
        IAssignment(ASSIGNMENT_ADDRESS).penalizeBatch(_batchNumber, _applyInfoIndex);
        emit Penalize(_prover, _batchNumber, _applyInfoIndex, mainToken, penalizeAmount);
    }

    /// @dev The batch proof has been completed, and rewards will be issued
    function proveBatch(uint256 _batchNumber, address _prover, uint256 _time_taken) external override onlyAssignment {
        totalProofCount++;
        totalProofTime += _time_taken;

        ProverBaseInfo storage baseInfo = proverBaseInfo[_prover];

        baseInfo.proofCount++;
        baseInfo.totalProofTime += _time_taken;
        baseInfo.latestProofTime = _time_taken;

        uint256 proof_coefficient = baseInfo.totalProofTime.mul(denominator).div(baseInfo.proofCount).div(_time_taken);

        IBatchReward(BATCH_REWARD_ADDRESS).payRewards(_prover, _batchNumber, proof_coefficient);
    }

    /// @dev  modify token min deposit amount
    function updateMinDepositAmount(address _token, uint256 _minDepositAmount) external override onlyOwner {
        require(_minDepositAmount > 0, "Invalid params");
        tokenMinDepositAmount[_token] = _minDepositAmount;
    }

    /// @dev  modify token min deposit time
    function updateMinDepositTime(address _token, uint256 _minDepositTime) external override onlyOwner {
        require(_minDepositTime >= 0, "Invalid params");
        tokenMinDepositTime[_token] = _minDepositTime;
    }

    /// @dev  modify the waiting time between withdrawal application and actual withdrawal
    function updateWaitingTime(uint256 _waitingTime) external override onlyOwner {
        require(_waitingTime >= 0, "Invalid params");
        waitingTime = _waitingTime;
    }

    /// @dev modify Penalize ratio
    function updatePenalizeRatio(uint16 _penalizeRatio) external override onlyOwner {
        require(_penalizeRatio > 0 && _penalizeRatio <= denominator, "Invalid params");
        penalizeRatio = _penalizeRatio;
    }

    /// @dev  modify calculate score configs
    function updateScoreConfig(
        uint256 _proofProportion,
        uint256 _depositProportion,
        uint256 _participateProportion,
        uint256 _taskCompletedProportion
    ) external override onlyOwner {
        setScoreConfig(_proofProportion, _depositProportion, _participateProportion, _taskCompletedProportion);
    }

    /// @dev modify calculate participate score coefficient
    function updateParticipateCoefficient(uint16 _participateCoefficient) external override onlyOwner {
        require(_participateCoefficient > 0, "Invalid params");

        participateCoefficient = _participateCoefficient;
    }

    /// @dev add new token
    function addToken(address _token) external override onlyOwner {
        for (uint i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            if (token == _token) {
                revert("token exist");
            }
        }
        tokens.push(_token);
        tokenEnable[_token] = true;
    }

    /// @dev remove token
    function removeToken(address _token) external override onlyOwner {
        for (uint i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            if (token == _token) {
                address lastestToken = tokens[tokens.length - 1];
                tokens[i] = lastestToken;
                tokens.pop();
                return;
            }
        }
    }

    /// @dev modify admin
    function updateAdmin(address _admin) external onlyOwner {
        require(_admin != address(0), "Invalid params");
        admin = _admin;
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

    /// @dev modify main token
    function updateMainToken(address _token) external onlyOwner {
        require(tokenEnable[_token], "token must enable");
        mainToken = _token;
    }

    /// @dev modify token enable
    function updateTokenEnable(address _token, bool _enable) external override onlyOwner {
        tokenEnable[_token] = _enable;
    }

    /// @dev add prover apply count
    function addApplyCount(address _prover) external onlyAssignment {
        proverBaseInfo[_prover].applyCount++;
    }

    /// @dev clear prover apply count and add proof count
    function assignmentBatch(address _prover) external onlyAssignment {
        proverBaseInfo[_prover].applyCount = 0;
        proverBaseInfo[_prover].totalProofCount += 1;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /// @return The token min deposit amount
    function getMinDepositAmount(address _token) external view override returns (uint256) {
        return tokenMinDepositAmount[_token];
    }

    /// @return The token min deposit time
    function getMinDepositTime(address _token) external view override returns (uint256) {
        return tokenMinDepositTime[_token];
    }

    /// @return The waiting time between withdrawal application and actual withdrawal
    function getWaitingTime() external view override returns (uint256) {
        return waitingTime;
    }

    /// @return Prover current score
    function score(address _prover) external view override returns (uint256) {
        uint256 proverScore = calScore(_prover);
        return proverScore;
    }

    /// @return The configs to calculate score
    function getScoreConfig() external view override returns (uint256, uint256, uint256, uint256) {
        return (proofProportion, depositProportion, participateProportion, taskCompletedProportion);
    }

    /// @return The prover base info
    function getProverBaseInfo(
        address _prover
    ) external view override returns (Status, uint256, uint256, uint256, uint256, uint256, uint256) {
        ProverBaseInfo storage baseInfo = proverBaseInfo[_prover];

        ProverTokenDepositInfo storage tokenInfo = baseInfo.tokenInfo[mainToken];
        Status status = tokenInfo.status;
        uint256 totalTask = baseInfo.totalProofCount;
        uint256 completedTask = baseInfo.proofCount;
        uint256 failedTask = baseInfo.penalizeCount;
        uint256 unProcessedTask = totalTask.sub(completedTask).sub(failedTask);

        uint256 latestProof = baseInfo.latestProofTime;
        uint256 avgProofTime = 0;
        if (completedTask > 0) {
            avgProofTime = baseInfo.totalProofTime.div(completedTask);
        }

        return (status, totalTask, completedTask, failedTask, unProcessedTask, latestProof, avgProofTime);
    }

    /// @return The amount of tokens staked by the prover
    function getDepositAmount(address _prover, address _token) external view override returns (uint256) {
        return proverBaseInfo[_prover].tokenInfo[_token].depositAmount;
    }

    /// @return The time of tokens staked by the prover
    function getDepositTime(address _prover, address _token) external view override returns (uint256) {
        return proverBaseInfo[_prover].tokenInfo[_token].depositTime;
    }

    /// @return The withdraw applying time of tokens staked by the prover
    function getApplyingTime(address _prover, address _token) external view override returns (uint256) {
        return proverBaseInfo[_prover].tokenInfo[_token].applyingTime;
    }

    function getAllToken() external view returns (address[] memory) {
        return tokens;
    }

    /// @return The detail of tokens staked by the prover
    function getProverTokenDepositInfo(
        address _prover,
        address _token
    ) external view override returns (ProverTokenDepositInfo memory) {
        ProverBaseInfo storage baseInfo = proverBaseInfo[_prover];
        ProverTokenDepositInfo storage tokenInfo = baseInfo.tokenInfo[_token];
        return tokenInfo;
    }

    /// @dev can Prover apply for proof
    function canApplyForProof(address _prover) external view returns (bool) {
        ProverBaseInfo storage baseInfo = proverBaseInfo[_prover];
        // only check mainToken
        ProverTokenDepositInfo storage tokenInfo = baseInfo.tokenInfo[mainToken];
        return tokenInfo.status == Status.Normal;
    }

    /// @dev  modify calculate score configs
    function setScoreConfig(
        uint256 _proofProportion,
        uint256 _depositProportion,
        uint256 _participateProportion,
        uint256 _taskCompletedProportion
    ) private scoreConfigCheck(_proofProportion, _depositProportion, _participateProportion, _taskCompletedProportion) {
        proofProportion = _proofProportion;
        depositProportion = _depositProportion;
        participateProportion = _participateProportion;
        taskCompletedProportion = _taskCompletedProportion;
    }

    /// @dev  calculate prover score
    function calScore(address _prover) private view returns (uint256) {
        ProverBaseInfo storage baseInfo = proverBaseInfo[_prover];

        ProverTokenDepositInfo storage tokenInfo = baseInfo.tokenInfo[mainToken];

        uint256 proofScore = calProofScore(baseInfo);

        uint256 depositScore = calDepositScore(tokenInfo);

        uint256 participateScore = calParticipateScore(baseInfo);

        uint256 taskCompletedScore = calTaskCompletedScore(baseInfo);

        uint256 totalScore = proofScore.add(depositScore).add(participateScore).add(taskCompletedScore);

        return totalScore;
    }

    /// @dev  transfer token
    function transferToken(address _token, address _receiver, uint256 _amount) private {
        if (_amount == 0) {
            return;
        }

        if (_token == address(0)) {
            TransferHelper.safeTransferFIL(_receiver, _amount);
        } else {
            TransferHelper.safeTransfer(_token, _receiver, _amount);
        }
        tokenTotalDeposit[_token] -= _amount;
    }

    /// @dev  calculate prover penalize amount
    function calPenalizeAmount(ProverTokenDepositInfo storage tokenInfo) private returns (uint256) {
        uint256 penalizeAmount = tokenInfo.depositAmount.mul(penalizeRatio).div(denominator);
        return penalizeAmount;
    }

    /// @dev  calculate prover proof score
    function calProofScore(ProverBaseInfo storage baseInfo) private view returns (uint256) {
        uint256 proofScore = proofProportion;
        if (totalProofCount > 0 && baseInfo.proofCount > 0) {
            proofScore = proofScore.mul(totalProofTime).mul(baseInfo.proofCount).div(totalProofCount).div(
                baseInfo.totalProofTime
            );
        }

        return proofScore;
    }

    /// @dev  calculate prover deposit score
    function calDepositScore(ProverTokenDepositInfo storage tokenInfo) private view returns (uint256) {
        uint256 depositScore = 0;
        if (tokenInfo.depositAmount > 0) {
            depositScore = depositProportion.mul(tokenInfo.depositAmount).div(tokenTotalDeposit[mainToken]);
        }
        return depositScore;
    }

    /// @dev  calculate prover participate score
    function calParticipateScore(ProverBaseInfo storage baseInfo) private view returns (uint256) {
        uint256 participateScore = participateProportion.mul(baseInfo.applyCount).div(participateCoefficient);
        return participateScore;
    }

    /// @dev  calculate prover taskCompleted score
    function calTaskCompletedScore(ProverBaseInfo storage baseInfo) private view returns (uint256) {
        uint256 taskCompletedScore = 0;
        if (baseInfo.totalProofCount > 0) {
            taskCompletedScore = taskCompletedProportion.mul(baseInfo.proofCount).div(baseInfo.totalProofCount);
        }
        return taskCompletedScore;
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
