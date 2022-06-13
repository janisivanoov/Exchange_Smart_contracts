// SPDX-License-Identifier: NO LICENSE
pragma solidity >=0.8.11;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract Relay {
    uint256 public constant FEE_DENOMINATOR = 10000;

    function getTransferFee(
        address token,
        address to,
        uint256 amount
    ) public returns (uint256 diff, uint256 fee) {
        uint256 preBalance = IERC20(token).balanceOf(to);
        IERC20(token).transfer(to, amount);
        uint256 postBalance = IERC20(token).balanceOf(to);
        diff = postBalance - preBalance;
        fee = FEE_DENOMINATOR - (diff * FEE_DENOMINATOR) / amount;
    }
}
