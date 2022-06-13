// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11;

library Convert {
    function rev(uint256 pair) internal pure returns (bool) {
        return pair >> 255 != 0; // 1bit
    }

    function swapFee(uint256 pair) internal pure returns (uint256) {
        return (pair << 1) >> 248; // 1byte
    }

    function src(uint256 pair) internal pure returns (uint256) {
        return (pair << 9) >> 248; // 1byte
    }

    function part(uint256 pair) internal pure returns (uint256) {
        return (pair << 17) >> 248; // 1byte
    }

    function tokenFee(uint256 token) internal pure returns (uint256) {
        return (token << 25) >> 240; // 2byte
    }

    function addr(uint256 pairOrToken) internal pure returns (address) {
        return address(uint160((pairOrToken << 96) >> 96)); //20bytes
    }
}
