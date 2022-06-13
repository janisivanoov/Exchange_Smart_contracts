// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11;

library Call {
    function balanceOf(address token, address owner)
        internal
        view
        returns (uint256)
    {
        bytes memory data = abi.encodeWithSignature(
            'balanceOf(address)',
            owner
        );
        bool success;
        (success, data) = token.staticcall(data);
        require(success, 'OuroborusRouter: balanceOf() failed');
        return abi.decode(data, (uint256));
    }

    function getReserves(address pair)
        internal
        view
        returns (uint112 reserve0, uint112 reserve1)
    {
        bytes memory data = abi.encodeWithSignature('getReserves()');
        bool success;
        (success, data) = pair.staticcall(data);
        require(success, 'OuroborusRouter: getReserves() failed');
        (reserve0, reserve1, ) = abi.decode(data, (uint112, uint112, uint32));
    }

    function transfer(
        address token,
        address to,
        uint256 amount
    ) internal {
        bytes memory data = abi.encodeWithSignature(
            'transfer(address,uint256)',
            to,
            amount
        );
        bool success;
        (success, data) = token.call(data);
        require(success, 'OuroborusRouter: transfer() failed');
    }

    function transferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bytes memory data = abi.encodeWithSignature(
            'transferFrom(address,address,uint256)',
            from,
            to,
            amount
        );
        (bool success, ) = token.call(data);
        require(success, 'OuroborusRouter: transferFrom() failed');
    }

    function swap(
        address pair,
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes memory data
    ) internal {
        data = abi.encodeWithSignature(
            'swap(uint256,uint256,address,bytes)',
            amount0Out,
            amount1Out,
            to,
            data
        );
        (bool success, ) = pair.call(data);
        require(success, 'OuroborusRouter: swap() failed');
    }
}
