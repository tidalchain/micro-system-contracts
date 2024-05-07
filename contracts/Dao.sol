// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./openzeppelin/token/ERC20/IERC20.sol";
import "./libraries/TransferHelper.sol";
import "./interfaces/IDao.sol";

contract Dao is IDao {
    address private _owner;

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function initialize(address newOwner) public {
        require(owner() == address(0), "Has been initialized");
        require(newOwner != address(0), "Invalid params");
        _transferOwnership(newOwner);
    }

    function withdraw(address _token) external onlyOwner {
        uint256 balance = 0;
        if (_token == address(0)) {
            balance = address(this).balance;
            TransferHelper.safeTransferFIL(_owner, balance);
        } else {
            balance = IERC20(_token).balanceOf(address(this));
            TransferHelper.safeTransfer(_token, _owner, balance);
        }
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

    fallback() external payable {}

    receive() external payable {}

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
