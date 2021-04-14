// SPDX-License-Identifier: MIT

pragma solidity =0.5.16;

import "makiswap-core/contracts/interfaces/IMakiswapFactory.sol";
import "makiswap-core/contracts/MakiswapPair.sol";

contract MakiswapFactory is IMakiswapFactory {
    address public feeTo;
    address public feeToSetter;
    address public migrator;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event V2PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function pairCodeHash() external pure returns (bytes32) {
        return keccak256(type(MakiswapPair).creationCode);
    }

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair)
    {
        require(tokenA != tokenB, "MakiswapV2: IDENTICAL_ADDRESSES");
        (address token0, address token1) =
            tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "MakiswapV2: ZERO_ADDRESS");
        require(
            getPair[token0][token1] == address(0),
            "MakiswapV2: PAIR_EXISTS"
        ); // single check is sufficient
        bytes memory bytecode = type(MakiswapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        MakiswapPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "MakiswapV2: FORBIDDEN");
        feeTo = _feeTo;
    }

    function setMigrator(address _migrator) external {
        require(msg.sender == feeToSetter, "MakiswapV2: FORBIDDEN");
        migrator = _migrator;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, "MakiswapV2: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }
}
