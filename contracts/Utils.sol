// SPDX-License-Identifier: NO LICENSE
pragma solidity >=0.8.11;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import './interfaces/IPair.sol';
import './Relay.sol';

contract Utils is Relay {
    address public immutable relay;

    constructor() {
        // some tokens may check that the're transferred to contract,
        // but that's fine because we ARE transfing to contract except end token
        relay = address(new Relay());
    }

    function getTokens(address pair)
        external
        view
        returns (address token0, address token1)
    {
        token0 = IPair(pair).token0();
        token1 = IPair(pair).token1();
    }

    struct Fees {
        uint256 swap;
        uint256 gas01;
        uint256 gas10;
        uint256 transfer0;
        uint256 buy0;
        uint256 sell0;
        uint256 transfer1;
        uint256 buy1;
        uint256 sell1;
    }

    // transfer token0 from pair and sync
    function getFees(address pair) external returns (Fees memory fees) {
        address tokenIn = IPair(pair).token0();
        uint256 amountIn = IERC20(tokenIn).balanceOf(address(this));

        // transfer token0 to pair (sell0)
        (amountIn, fees.sell0) = getTransferFee(tokenIn, pair, amountIn);
        // swap token0 to token1 (swap)
        (amountIn, fees.swap, fees.gas01) = getSwapFee(
            pair,
            amountIn,
            false,
            0
        );

        // now tokenIn is token1
        tokenIn = IPair(pair).token1();
        // get buy1 as diff of expected and received amounts
        (amountIn, fees.buy1) = getFeeByBalance(
            tokenIn,
            address(this),
            amountIn
        );
        // transfer token1 to relay and get fee
        (amountIn, fees.transfer1) = getTransferFee(tokenIn, relay, amountIn);
        // transfer token1 to pair (sell1)
        (amountIn, fees.sell1) = Relay(relay).getTransferFee(
            tokenIn,
            pair,
            amountIn
        );
        // swap token1 to token0
        (amountIn, , fees.gas10) = getSwapFee(pair, amountIn, true, fees.swap);

        // now tokenIn is token0
        tokenIn = IPair(pair).token0();
        // get buy0 as diff of expected and received amounts
        (amountIn, fees.buy0) = getFeeByBalance(
            tokenIn,
            address(this),
            amountIn
        );
        // transfer token0 to relay to get transfer0
        (, fees.transfer0) = getTransferFee(tokenIn, relay, amountIn);
    }

    function getFeeByBalance(
        address token,
        address owner,
        uint256 expectedAmount
    ) internal view returns (uint256 realAmount, uint256 fee) {
        realAmount = IERC20(token).balanceOf(owner);
        fee = FEE_DENOMINATOR - (realAmount * FEE_DENOMINATOR) / expectedAmount;
    }

    function getSwapFee(
        address pair,
        uint256 amountIn,
        bool rev,
        uint256 swapFee
    )
        internal
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        (uint256 reserveIn, uint256 reserveOut, ) = IPair(pair).getReserves();
        if (rev) {
            (reserveIn, reserveOut) = (reserveOut, reserveIn);
        }
        for (; swapFee < 50; swapFee++) {
            uint256 amount0Out;
            uint256 amount1Out = getAmountOut(
                amountIn,
                reserveIn,
                reserveOut,
                swapFee
            );
            if (rev) {
                (amount0Out, amount1Out) = (amount1Out, amount0Out);
            }
            uint256 gasUsed = gasleft();
            try IPair(pair).swap(amount0Out, amount1Out, address(this), hex'') {
                return (amount1Out + amount0Out, swapFee, gasUsed - gasleft());
            } catch {}
        }
        revert('Helper: swap fee not reached');
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 swapFee
    ) internal pure returns (uint256) {
        amountIn = amountIn * (FEE_DENOMINATOR - swapFee);
        uint256 numerator = reserveOut * amountIn;
        uint256 denominator = reserveIn * FEE_DENOMINATOR + amountIn;
        return numerator / denominator;
    }
}
