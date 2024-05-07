// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IWhiteList {
    function whiteList(address user) external view returns (bool);

    function blackList(address user) external view returns (bool);

    function addWhiteList(address[] calldata whiteListes) external;

    function removeWhiteAddress(address whiteListes) external;

    function removeWhiteList(address[] calldata _whiteAddress) external;

    function addBlackList(address[] calldata blackListes) external;

    function removeBlackList(address[] calldata blackListes) external;
}
