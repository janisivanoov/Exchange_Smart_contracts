// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {UniswapV2Factory} from '../uniswap/UniswapV2Factory.sol';

contract ERC20 is IERC20 {
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public constant FEE_DENOMINATOR = 10000;

    // fees not in reverse
    uint256 public transferFee;
    uint256 public sellFee;
    uint256 public buyFee;

    address public swapPair;

    struct InitParams {
        string name;
        string symbol;
        uint256 initialSupply;
        uint256 transferFee;
        // params used for sell-buy fees
        address baseToken;
        address swapFactory;
        uint256 sellFee;
        uint256 buyFee;
    }

    constructor(InitParams memory params) {
        _mint(msg.sender, params.initialSupply);
        transferFee = params.transferFee;

        if (params.baseToken != address(0)) {
            sellFee = params.sellFee;
            buyFee = params.buyFee;

            swapPair = UniswapV2Factory(params.swapFactory).createPair(
                address(this),
                params.baseToken
            );
        }
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _applyFee(uint256 amount, uint256 fee)
        internal
        pure
        returns (uint256)
    {
        return (amount * (FEE_DENOMINATOR - fee)) / FEE_DENOMINATOR;
    }

    function _transferFrom(
        address from,
        address to,
        uint256 amount
    ) internal {
        require(balanceOf[from] >= amount, 'insufficient balance');
        balanceOf[from] -= amount;

        address _swapPair = swapPair;
        if (from != _swapPair && to != _swapPair) {
            balanceOf[to] += _applyFee(amount, transferFee);
        } else if (from == _swapPair) {
            balanceOf[to] += _applyFee(amount, buyFee);
        } else if (to == _swapPair) {
            balanceOf[to] += _applyFee(amount, sellFee);
        }

        emit Transfer(from, to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        require(allowance[from][to] >= amount, 'insufficient allowance');
        allowance[from][to] -= amount;
        _transferFrom(from, to, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transferFrom(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] += amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
}
