// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./IOwnable.sol";

interface IRecevingAddress is IOwnable {
    function withdraw(address _token) external;
}
