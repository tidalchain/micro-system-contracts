// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./interfaces/IWhiteList.sol";
import {DEPOSIT_ADDRESS} from "./Constants.sol";

contract WhiteList is IWhiteList {
    address public owner;

    mapping(address => bool) public override whiteList;
    mapping(address => bool) public override blackList;

    event AddWhiteList(address indexed whiteAddress);

    event RemoveWhiteList(address indexed whiteAddress);

    event AddBlackList(address indexed blackAddress);

    event RemoveBlackList(address indexed blackAddress);

    modifier onlyOwner() {
        require(msg.sender == owner, "This method require owner call flag");
        _;
    }

    modifier onlyDeposit() {
        require(msg.sender == DEPOSIT_ADDRESS, "This method require deposit call flag");
        _;
    }

    function initialize(address _owner) public {
        require(_owner != address(0), "Invalid params");
        owner = _owner;
    }

    function updateOwner(address _newOwner) public onlyOwner {
        require(_newOwner != address(0));
        owner = _newOwner;
    }

    function addWhiteList(address[] calldata whiteListes) external override onlyOwner {
        require(whiteListes.length > 0, "empty array");
        for (uint256 i = 0; i < whiteListes.length; i++) {
            whiteList[whiteListes[i]] = true;
            emit AddWhiteList(whiteListes[i]);
        }
    }

    function removeWhiteList(address[] calldata whiteListes) external override onlyOwner {
        require(whiteListes.length > 0, "empty array");
        for (uint256 i = 0; i < whiteListes.length; i++) {
            whiteList[whiteListes[i]] = false;
            emit RemoveWhiteList(whiteListes[i]);
        }
    }

    function removeWhiteAddress(address _whiteAddress) external override onlyDeposit {
        whiteList[_whiteAddress] = false;
        emit RemoveWhiteList(_whiteAddress);
    }

    function addBlackList(address[] calldata blackListes) external override onlyOwner {
        require(blackListes.length > 0, "empty array");
        for (uint256 i = 0; i < blackListes.length; i++) {
            blackList[blackListes[i]] = true;
            emit AddBlackList(blackListes[i]);
        }
    }

    function removeBlackList(address[] calldata blackListes) external override onlyOwner {
        require(blackListes.length > 0, "empty array");
        for (uint256 i = 0; i < blackListes.length; i++) {
            blackList[blackListes[i]] = true;
            emit RemoveBlackList(blackListes[i]);
        }
    }
}
