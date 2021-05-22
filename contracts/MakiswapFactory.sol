// SPDX-License-Identifier: MIT

pragma solidity >=0.5.16;

import './interfaces/IMakiswapFactory.sol';
import './libs/MakiswapPair.sol';

contract MakiswapFactory is IMakiswapFactory {
    bytes32 public constant INIT_CODE_PAIR_HASH = keccak256(abi.encodePacked(type(MakiswapPair).creationCode));

    address public feeTo;
    address public feeToSetter = msg.sender;
    address public migrator;
    uint256 public totalPairs = 0;
    address[] public allPairs;

    mapping(address => mapping(address => address)) public getPair;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    event SetFeeTo(address indexed user, address indexed feeTo);
    event SetMigrator(address indexed user, address indexed migrator);
    event FeeToSetter(address indexed user, address indexed feeToSetter);

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'Makiswap: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'Makiswap: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'Makiswap: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(MakiswapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        MakiswapPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        totalPairs++;
        emit PairCreated(token0, token1, pair, totalPairs);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'Makiswap: FORBIDDEN');
        feeTo = _feeTo;
        emit SetFeeTo(msg.sender, feeTo);
    }

    function setMigrator(address _migrator) external {
        require(msg.sender == feeToSetter, 'Makiswap: FORBIDDEN');
        migrator = _migrator;
        emit SetMigrator(msg.sender, migrator);

    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'Makiswap: FORBIDDEN');
        feeToSetter = _feeToSetter;
        emit FeeToSetter(msg.sender, feeToSetter);
    }

}
