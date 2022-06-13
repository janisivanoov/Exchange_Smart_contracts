// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11;

import './Convert.sol';
import './Call.sol';

import '@openzeppelin/contracts/utils/math/SafeMath.sol';

abstract contract ContextMixin {
    function msgSender()
        internal
        view
        returns (address payable sender)
    {
        if (msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly {
                sender := and(
                    mload(add(array, index)),
                    0xffffffffffffffffffffffffffffffffffffffff
                )
            }
        } else {
            sender = payable(msg.sender);
        }
        return sender;
    }
}

contract Initializable {
    bool inited = false;

    modifier initializer() {
        require(!inited, "already inited");
        _;
        inited = true;
    }
}

contract OuroborusRouter {
    using SafeMath for uint256;
    using Convert for uint256;
    using Call for address;

    event Log(bytes);

    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant PART_DENOMINATOR = 100;

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 swapFee
    ) internal pure returns (uint256) {
        // todo: reverse fee
        amountIn = amountIn.mul(FEE_DENOMINATOR.sub(swapFee));
        uint256 numerator = reserveOut.mul(amountIn);
        uint256 denominator = reserveIn.mul(FEE_DENOMINATOR).add(amountIn);
        return numerator.div(denominator);
    }

    function _quote(uint256 amountIn, uint256[] memory path)
        internal
        view
        returns (uint256[] memory amounts)
    {
        amounts = new uint256[](path.length);
        for (uint256 i; i < path.length; i++) {
            uint256 swapFee = path[i].swapFee();
            if (swapFee != 0) {
                (uint256 reserveIn, uint256 reserveOut) = path[i]
                    .addr()
                    .getReserves();

                if (path[i].rev()) {
                    (reserveIn, reserveOut) = (reserveOut, reserveIn);
                }

                uint256 part = path[i].part();
                uint256 src = path[i].src();
                amounts[i] = getAmountOut(
                    amounts[src].mul(part).div(PART_DENOMINATOR),
                    reserveIn,
                    reserveOut,
                    swapFee
                );

                uint256 tokenFee = path[i].tokenFee();
                amountIn += amounts[i].mul(tokenFee).div(FEE_DENOMINATOR);
            } else {
                // reverse fee
                amounts[i] = amountIn;
                amountIn = 0;
            }
        }
    }

    function swap(
        uint256 amountIn,
        uint256 amountOutMin,
        uint256[] memory path,
        address to
    ) external returns (uint256[] memory amounts) {
        amounts = _quote(amountIn, path);

        require(
            amounts[amounts.length - 1] >= amountOutMin,
            'OuroborusRouter: insufficient amount'
        );

        path[0].addr().transferFrom(msg.sender, address(this), amountIn);
        uint256 preBalance = path[path.length - 1].addr().balanceOf(to);

        for (uint256 i; i < path.length; i++) {
            if (path[i].swapFee() != 0) {
                uint256 src = path[i].src();
                // sourceToken
                path[src].addr().transfer(
                    address(uint160(path[i])),
                    // sourceAmount * part
                    amounts[src].mul(path[i].part()).div(PART_DENOMINATOR)
                );
                uint256 amount0Out;
                uint256 amount1Out = amounts[i];
                if (path[i].rev()) {
                    (amount0Out, amount1Out) = (amount1Out, amount0Out);
                }
                path[i].addr().swap(
                    amount0Out,
                    amount1Out,
                    address(this),
                    hex''
                );
            }
        }

        emit Log(
            abi.encode(
                path[path.length - 1].addr().balanceOf(address(this)),
                amounts[amounts.length - 1]
            )
        );
        // path[path.length - 1].addr().transfer(to, amounts[amounts.length - 1]);
        // emit Log(
        //     abi.encode(
        //         path[path.length - 1].addr().balanceOf(to),
        //         amounts[amounts.length - 1],
        //         preBalance
        //     )
        // );
        // require(
        //     path[path.length - 1].addr().balanceOf(to) >=
        //         preBalance.add(amounts[amounts.length - 1]),
        //     'OuroborusRouter: insufficient amount received'
        // );
    }

    function _swap(
        uint256 amountIn,
        uint256 amountOutMin,
        uint256[] memory path,
        address to
    ) internal returns (uint256[] memory amounts) {
        amounts = _quote(amountIn, path);

        require(
            amounts[amounts.length - 1] >= amountOutMin,
            'OuroborusRouter: insufficient amount'
        );

        path[0].addr().transferFrom(msg.sender, address(this), amountIn);
        uint256 preBalance = path[path.length - 1].addr().balanceOf(to);

        for (uint256 i; i < path.length; i++) {
            if (path[i].swapFee() != 0) {
                uint256 src = path[i].src();
                // sourceToken
                path[src].addr().transfer(
                    address(uint160(path[i])),
                    // sourceAmount * part
                    amounts[src].mul(path[i].part()).div(PART_DENOMINATOR)
                );
                uint256 amount0Out;
                uint256 amount1Out = amounts[i];
                if (path[i].rev()) {
                    (amount0Out, amount1Out) = (amount1Out, amount0Out);
                }
                path[i].addr().swap(
                    amount0Out,
                    amount1Out,
                    address(this),
                    hex''
                );
            }
        }

        emit Log(
            abi.encode(
                path[path.length - 1].addr().balanceOf(address(this)),
                amounts[amounts.length - 1]
            )
        );
    }

    function quote(uint256 amountIn, uint256[] memory path)
        external
        view
        returns (uint256[] memory)
    {
        return _quote(amountIn, path);
    }

    //META
    bytes32 private constant META_TRANSACTION_TYPEHASH = keccak256(
        bytes(
            "MetaTransaction(uint256 nonce,address from,bytes functionSignature)"
        )
    );
    event MetaTransactionExecuted(
        address userAddress,
        address payable relayerAddress,
        bytes functionSignature
    );
    mapping(address => uint256) nonces;

    struct MetaTransaction {
        uint256 nonce;
        address from;
        bytes functionSignature;
    }

    function executeMetaTransaction(
        address userAddress,
        bytes memory functionSignature,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    ) public payable returns (bytes memory) {
        MetaTransaction memory metaTx = MetaTransaction({
            nonce: nonces[userAddress],
            from: userAddress,
            functionSignature: functionSignature
        });
        require(
            verify(userAddress, metaTx, sigR, sigS, sigV),
            "Signer and signature do not match"
        );

        nonces[userAddress] = nonces[userAddress] + 1;

        emit MetaTransactionExecuted(
            userAddress,
            payable(msg.sender),
            functionSignature
        );

        (bool success, bytes memory returnData) = address(this).call(
            abi.encodePacked(functionSignature, userAddress)
        );
        require(success, "Function call not successful");

        return returnData;
    }

    function hashMetaTransaction(MetaTransaction memory metaTx)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    META_TRANSACTION_TYPEHASH,
                    metaTx.nonce,
                    metaTx.from,
                    keccak256(metaTx.functionSignature)
                )
            );
    }

    function getNonce(address user) public view returns (uint256 nonce) {
        nonce = nonces[user];
    }

    function verify(
        address signer,
        MetaTransaction memory metaTx,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    ) internal view returns (bool) {
        require(signer != address(0), "NativeMetaTransaction: INVALID_SIGNER");
        return
            signer ==
            ecrecover(
                toTypedMessageHash(hashMetaTransaction(metaTx)),
                sigV,
                sigR,
                sigS
            );
    }

    //GAS OPTIMIZING(EXAMPLES)
    function unsafe_inc(uint x) private pure returns (uint) {
        unchecked { return x + 1; }
    }

    function optionD() external {
        uint _totalFunds;
        uint[] memory _arrayFunds = arrayFunds;
        for (uint i =0; i < _arrayFunds.length; i = unsafe_inc(i)){
            _totalFunds = _totalFunds + _arrayFunds[i];
        }
        totalFunds = _totalFunds;
    }
}