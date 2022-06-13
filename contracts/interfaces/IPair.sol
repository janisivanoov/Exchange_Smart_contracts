// SPDX-License-Identifier: NO LICENSE
pragma solidity >=0.8.11;

interface IPair {
    function getReserves()
        external
        view
        returns (
            uint112,
            uint112,
            uint32
        );

    function token0() external view returns (address);

    function token1() external view returns (address);

    function swap(
        uint256,
        uint256,
        address,
        bytes memory
    ) external;
}
