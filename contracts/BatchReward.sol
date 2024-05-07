// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./openzeppelin/token/ERC20/IERC20.sol";
import "./openzeppelin/utils/Address.sol";
import "./openzeppelin/utils/math/SafeMath.sol";
import "./interfaces/IWhiteList.sol";
import "./interfaces/ISystemContext.sol";
import "./interfaces/IBatchReward.sol";
import "./libraries/TransferHelper.sol";

import {DEPOSIT_ADDRESS, BATCH_EVENT_ADDRESS, WHITE_LIST_ADDRESS, BATCH_REWARD_ADDRESS} from "./Constants.sol";

contract BatchReward is IBatchReward {
    using SafeMath for uint256;
    address private _owner;

    address private token;

    uint256 public payToServerTime;

    uint256 public commitBatchTime;

    uint256 public batchRewardRate;

    uint256 public proverBaseReward;

    uint256 public proverProofRewardRate;

    uint256 public proverRewardLimit;

    uint256 public unClaimedRewards;

    /// per batch reward detail
    mapping(uint256 => BatchRewardDetail) public batchRewardDetail;

    mapping(address => uint256) public serverRewards;
    mapping(address => uint256) public proverRewards;

    /// @dev base denominator
    uint256 constant denominator = 10000;

    modifier onlyBatchEvent() {
        require(msg.sender == BATCH_EVENT_ADDRESS, "only proof reward pool can call");
        _;
    }

    modifier onlyDeposit() {
        require(msg.sender == DEPOSIT_ADDRESS, "only proof reward pool can call");
        _;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function initialize(
        address newOwner,
        address _token,
        uint256 _payToServerTime,
        uint256 _batchRewardRate,
        uint256 _proverBaseReward,
        uint256 _proverProofRewardRate
    ) public {
        require(owner() == address(0), "Has been initialized");
        require(_token != address(0), "Invalid _token");
        require(newOwner != address(0), "Invalid newOwner");

        token = _token;
        payToServerTime = _payToServerTime;
        batchRewardRate = _batchRewardRate;
        proverBaseReward = _proverBaseReward;
        proverProofRewardRate = _proverProofRewardRate;
        proverRewardLimit = 8000;
        commitBatchTime = block.timestamp;
        _transferOwnership(newOwner);
    }

    function calRewards(uint256 _batchNumber, address _server) external override onlyBatchEvent {
        if (_batchNumber <= 1) {
            return;
        }

        uint256 elapsedTime = block.timestamp.sub(commitBatchTime);

        uint256 totalReward = elapsedTime.mul(batchRewardRate);

        uint256 contractBalance = IERC20(token).balanceOf(address(this));
        if (unClaimedRewards.add(totalReward) > contractBalance) {
            return;
        }

        BatchRewardDetail storage detail = batchRewardDetail[_batchNumber];
        if (detail.server != address(0x0)) {
            return;
        }
        detail.server = _server;
        detail.elapsedTime = elapsedTime;
        detail.totalReward = totalReward;
        unClaimedRewards += totalReward;
        commitBatchTime = block.timestamp;
    }

    function payRewards(
        address _prover,
        uint256 _batchNumer,
        uint256 _proof_coefficient
    ) external override onlyDeposit {
        BatchRewardDetail storage detail = batchRewardDetail[_batchNumer];
        detail.prover = _prover;

        if (block.timestamp > payToServerTime) {
            uint256 proverReward = (
                proverProofRewardRate.mul(_proof_coefficient).div(denominator).add(proverBaseReward)
            ).mul(detail.elapsedTime);
            uint256 limitReward = detail.totalReward.mul(proverRewardLimit).div(denominator);
            if (proverReward > limitReward) {
                proverReward = limitReward;
            }
            detail.proverReward = proverReward;
            detail.serverReward = detail.totalReward.sub(proverReward);
        } else {
            detail.prover = _prover;
            detail.proverReward = detail.totalReward;
        }

        transferToken(detail);
    }

    function updateBatchRewardRate(uint256 _batchRewardRate) external onlyOwner {
        require(_batchRewardRate > 0, "Invalid params");
        batchRewardRate = _batchRewardRate;
    }

    function updateProverBaseReward(uint256 _proverBaseReward) external onlyOwner {
        require(_proverBaseReward > 0, "Invalid params");
        proverBaseReward = _proverBaseReward;
    }

    function updateProverProofRewardRate(uint256 _proverProofRewardRate) external onlyOwner {
        require(_proverProofRewardRate > 0, "Invalid params");
        proverProofRewardRate = _proverProofRewardRate;
    }

    function updateProverRewardLimit(uint256 _proverRewardLimit) external onlyOwner {
        require(_proverRewardLimit > 0, "Invalid params");
        proverRewardLimit = _proverRewardLimit;
    }

    /// @dev modify reward token
    function updateToken(address _token) external onlyOwner {
        require(IERC20(_token).balanceOf(address(this)) >= unClaimedRewards, "Insufficient token balance");
        token = _token;
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

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    function getToken() public view virtual returns (address) {
        return token;
    }

    function transferToken(BatchRewardDetail storage detail) private {
        if (detail.serverReward > 0) {
            TransferHelper.safeTransfer(token, detail.server, detail.serverReward);
        }
        if (detail.proverReward > 0) {
            TransferHelper.safeTransfer(token, detail.prover, detail.proverReward);
        }

        unClaimedRewards -= detail.totalReward;
        serverRewards[detail.server] += detail.serverReward;
        proverRewards[detail.prover] += detail.proverReward;
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
