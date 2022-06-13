// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11;

import './OuroborusRouter.sol';
import {UniswapV2Factory, UniswapV2Pair} from './uniswap/UniswapV2Factory.sol';
import './token/ERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import './libraries/RevertReasonParser.sol';
import './Utils.sol';

contract Tests {
    using SafeMath for uint256;
    OuroborusRouter router;
    Utils utils;

    ERC20 tokenA;
    ERC20 tokenB;
    ERC20 tokenC;

    address pairAB1;
    address pairAB2;
    address pairBC1;
    address pairAC1;

    event GasLeft(uint256 amount);
    event Log(bytes m);

    constructor() {
        router = new OuroborusRouter();
        utils = new Utils();

        UniswapV2Factory factory1 = new UniswapV2Factory(address(0));
        UniswapV2Factory factory2 = new UniswapV2Factory(address(0));

        tokenA = new ERC20(
            ERC20.InitParams('A', 'A', 10**30, 0, address(0), address(0), 0, 0)
        );

        // TODO: fix router to handle transfer fees
        tokenB = new ERC20(
            ERC20.InitParams(
                'B',
                'B',
                10**30,
                100,
                address(tokenA),
                address(factory1),
                1000,
                300
            )
        );
        // A:B = 2:1
        pairAB1 = factory1.getPair(address(tokenA), address(tokenB));
        tokenA.transfer(pairAB1, 10**19);
        tokenB.transfer(pairAB1, 10**19 * 2);
        UniswapV2Pair(pairAB1).sync();

        pairAB2 = factory2.createPair(address(tokenA), address(tokenB));
        tokenA.transfer(pairAB2, 10**19);
        tokenB.transfer(pairAB2, 10**19 * 2);
        UniswapV2Pair(pairAB2).sync();

        tokenC = new ERC20(
            ERC20.InitParams('C', 'C', 10**30, 0, address(0), address(0), 0, 0)
        );
        // B:C = 3:2
        pairBC1 = factory1.createPair(address(tokenB), address(tokenC));
        tokenB.transfer(pairBC1, 10**19 * 3);
        tokenC.transfer(pairBC1, 10**19 * 2);
        UniswapV2Pair(pairBC1).sync();

        // A:C = 2/1*2/3=4/3
        pairAC1 = factory1.createPair(address(tokenA), address(tokenC));
        tokenA.transfer(pairAC1, 10**19 * 4);
        tokenC.transfer(pairAC1, 10**19 * 3);
        UniswapV2Pair(pairAC1).sync();

        tokenA.approve(address(router), ~uint256(0));
        tokenB.approve(address(router), ~uint256(0));
        tokenC.approve(address(router), ~uint256(0));
    }

    function encodePair(
        bool rev,
        uint256 swapFee,
        uint256 src,
        uint256 part,
        uint256 tokenFee,
        address addr
    ) internal pure returns (uint256 r) {
        r |= uint256(rev ? 1 : 0) << 255;
        r |= swapFee << 247;
        r |= src << 239;
        r |= part << 231;
        r |= tokenFee << 215;
        r |= uint160(addr);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 swapFee
    ) internal pure returns (uint256) {
        uint256 feeDenominator = 10000;
        amountIn = amountIn.mul(feeDenominator.sub(swapFee));
        uint256 numerator = reserveOut.mul(amountIn);
        uint256 denominator = reserveIn.mul(feeDenominator).add(amountIn);
        return numerator.div(denominator);
    }

    function getAmountOut(
        address pair,
        address tokenIn,
        uint256 amountIn,
        uint256 swapFee
    ) internal view returns (uint256) {
        address token0 = UniswapV2Pair(pair).token0();
        (uint256 reserveIn, uint256 reserveOut, ) = UniswapV2Pair(pair)
            .getReserves();
        if (token0 != tokenIn) {
            (reserveIn, reserveOut) = (reserveOut, reserveIn);
        }
        return getAmountOut(amountIn, reserveIn, reserveOut, swapFee);
    }

    function runTest(string memory signature) internal {
        bytes memory data = abi.encodeWithSignature(signature);
        bool success;
        (success, data) = address(this).call(data);
        signature = string(abi.encodePacked(signature, ': '));
        if (!success) {
            revert(RevertReasonParser.parse(data, signature));
        }
    }

    function runTests() external {
        runTest('testQuoteAB()');
        runTest('testQuoteABC()');
        runTest('testQuoteSplitAB()');
        runTest('testQuoteSplitABCAC()');

        runTest('testSwapAB()');
        // runTest('testSwapABC()');

        runTest('testUtils()');
    }

    function testUtils() external {
        address tokenIn = UniswapV2Pair(pairAB1).token0();
        IERC20(tokenIn).transfer(address(utils), 10**16);
        Utils.Fees memory fees = utils.getFees(pairAB1);
        emit Log(abi.encode(fees));
    }

    function testQuoteAB() external {
        uint256[] memory path = new uint256[](3);
        path[0] = uint160(address(tokenA));
        bool rev = UniswapV2Pair(pairAB1).token0() != address(tokenA);
        path[1] = encodePair(rev, 30, 0, 100, 10000, pairAB1);
        path[2] = uint160(address(tokenB));
        uint256[] memory amounts = router.quote(10**18, path);
        emit Log(abi.encode(amounts));
        // sanity
        require(amounts.length == 3, 'amounts.length != 3');
        uint256 amountOut = getAmountOut(pairAB1, address(tokenA), 10**18, 30);
        // emit Log(abi.encode(amountOut));
        // emit Log(abi.encode(amounts[1] == amountOut));
        require(
            amounts[1] == amountOut,
            'amounts[1] != getAmountOut(amounts[0], ...)'
        );
        require(amounts[2] == amounts[1], 'amounts[2] != amounts[1]');
    }

    function testQuoteABC() external {
        uint256[] memory path = new uint256[](5);
        path[0] = uint160(address(tokenA));
        bool rev = UniswapV2Pair(pairAB1).token0() != address(tokenA);
        path[1] = encodePair(rev, 30, 0, 100, 10000, pairAB1);
        path[2] = uint160(address(tokenB));
        rev = UniswapV2Pair(pairBC1).token0() != address(tokenB);
        path[3] = encodePair(rev, 30, 2, 100, 9000, pairBC1);
        path[4] = uint160(address(tokenC));
        uint256[] memory amounts = router.quote(10**18, path);
        emit Log(abi.encode(amounts));
        uint256 amountOut = getAmountOut(
            pairBC1,
            address(tokenB),
            amounts[2],
            30
        );
        // emit Log(abi.encode(amountOut));
        // emit Log(abi.encode(amounts[3] == amountOut));

        require(
            amounts[3] == amountOut,
            'amounts[3] != getAmountOut(amounts[2], ...)'
        );
        require(
            amounts[4] == (amounts[3] * 9000) / 10000,
            'amounts[4] != amounts[3] * fee'
        );
    }

    function testQuoteSplitAB() external {
        uint256[] memory path = new uint256[](4);
        path[0] = uint160(address(tokenA));

        bool rev = UniswapV2Pair(pairAB1).token0() != address(tokenA);
        path[1] = encodePair(rev, 30, 0, 70, 10000, pairAB1);

        rev = UniswapV2Pair(pairAB2).token0() != address(tokenA);
        path[2] = encodePair(rev, 30, 0, 30, 10000, pairAB2);

        path[3] = uint160(address(tokenB));

        uint256[] memory amounts = router.quote(10**18, path);
        emit Log(abi.encode(amounts));

        uint256 amountOut = getAmountOut(
            pairAB1,
            address(tokenA),
            (10**18 * 70) / 100,
            30
        );
        require(
            amounts[1] == amountOut,
            'amounts[1] != getAmountOut(amounts[0] * 0.7, ...)'
        );
        amountOut = getAmountOut(
            pairAB2,
            address(tokenA),
            (10**18 * 30) / 100,
            30
        );
        require(
            amounts[2] == amountOut,
            'amounts[2] != getAmountOut(amounts[0] * 0.3, ...)'
        );
        require(
            amounts[1] + amounts[2] == amounts[3],
            'amounts[1] + amounts[2] != amounts[3]'
        );
    }

    function testQuoteSplitABCAC() external {
        uint256[] memory path = new uint256[](7);
        path[0] = uint160(address(tokenA));

        bool rev = UniswapV2Pair(pairAB1).token0() != address(tokenA);
        path[1] = encodePair(rev, 30, 0, 70, 10000, pairAB1);

        rev = UniswapV2Pair(pairAB2).token0() != address(tokenA);
        path[2] = encodePair(rev, 30, 0, 30, 10000, pairAB2);

        path[3] = uint160(address(tokenB));
        // --- tested part ---

        rev = UniswapV2Pair(pairBC1).token0() != address(tokenB);
        path[4] = encodePair(rev, 30, 3, 100, 9000, pairBC1);

        rev = UniswapV2Pair(pairAC1).token0() != address(tokenA);
        path[5] = encodePair(rev, 30, 0, 50, 10000, pairAC1);

        path[6] = uint160(address(tokenC));

        uint256[] memory amounts = router.quote(10**18, path);
        emit Log(abi.encode(amounts));

        uint256 amountOut = getAmountOut(
            pairBC1,
            address(tokenB),
            amounts[3],
            30
        );
        require(
            amounts[4] == amountOut,
            'amounts[4] != getAmountOut(amounts[3], ...)'
        );
        amountOut = getAmountOut(
            pairAC1,
            address(tokenA),
            (amounts[0] * 50) / 100,
            30
        );
        require(
            amounts[5] == amountOut,
            'amunts[5] != getAmountOut(amounts[0] * 0.5, ...)'
        );
        require(
            (amounts[4] * 9000) / 10000 + amounts[5] == amounts[6],
            'amounts[4] * 0.9 + amounts[5] != amounts[6]'
        );
    }

    function testSwapAB() external {
        uint256[] memory path = new uint256[](3);
        path[0] = uint160(address(tokenA));
        bool rev = UniswapV2Pair(pairAB1).token0() != address(tokenA);
        path[1] = encodePair(rev, 30, 0, 100, 9700, pairAB1);
        path[2] = uint160(address(tokenB));
        uint256[] memory amounts = router.quote(10**18, path);
        router.swap(10**18, amounts[amounts.length - 1], path, address(this));
    }

    function testSwapABC() external {
        uint256[] memory path = new uint256[](5);
        path[0] = uint160(address(tokenA));
        bool rev = UniswapV2Pair(pairAB1).token0() != address(tokenA);
        path[1] = encodePair(rev, 30, 0, 100, 10000, pairAB1);
        path[2] = uint160(address(tokenB));
        rev = UniswapV2Pair(pairBC1).token0() != address(tokenB);
        path[3] = encodePair(rev, 30, 2, 100, 9000, pairBC1);
        path[4] = uint160(address(tokenC));
        uint256[] memory amounts = router.quote(10**18, path);
        router.swap(10**18, amounts[amounts.length - 1], path, address(this));
    }
}
