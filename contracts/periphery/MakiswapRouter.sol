// SPDX-License-Identifier: MIT

pragma solidity =0.6.6;

import "makiswap-core/contracts/interfaces/IMakiswapFactory.sol";
import "maki-swap-lib/contracts/utils/TransferHelper.sol";
import "maki-swap-periphery/contracts/libraries/MakiswapLibrary.sol";
import "maki-swap-periphery/contracts/interfaces/IMakiswapRouter02.sol";
import "maki-swap-lib/contracts/math/SafeMath.sol";
import "makiswap-core/contracts/interfaces/IHRC20.sol";

contract MakiswapRouter is IMakiswapRouter02 {
    using SafeMath for uint256;

    address public factory;

    address public WHT;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "MakiswapRouter: EXPIRED");
        _;
    }

    constructor(address _factory, address _WHT) public {
        factory = _factory;
        WHT = _WHT;
    }

    receive() external payable {
        assert(msg.sender == WHT); // only accept HT via fallback from the WHT contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        if (IMakiswapFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IMakiswapFactory(factory).createPair(tokenA, tokenB);
        }
        (uint256 reserveA, uint256 reserveB) =
            MakiswapLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal =
                MakiswapLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(
                    amountBOptimal >= amountBMin,
                    "MakiswapRouter: INSUFFICIENT_B_AMOUNT"
                );
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal =
                    MakiswapLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(
                    amountAOptimal >= amountAMin,
                    "MakiswapRouter: INSUFFICIENT_A_AMOUNT"
                );
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        virtual
        override
        ensure(deadline)
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        (amountA, amountB) = _addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );
        address pair = MakiswapLibrary.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IMakiswapPair(pair).mint(to);
    }

    function addLiquidityHT(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountHTMin,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (
            uint256 amountToken,
            uint256 amountHT,
            uint256 liquidity
        )
    {
        (amountToken, amountHT) = _addLiquidity(
            token,
            WHT,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountHTMin
        );
        address pair = MakiswapLibrary.pairFor(factory, token, WHT);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWHT(WHT).deposit{value: amountHT}();
        assert(IWHT(WHT).transfer(pair, amountHT));
        liquidity = IMakiswapPair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountHT)
            TransferHelper.safeTransferHT(msg.sender, msg.value - amountHT);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        public
        virtual
        override
        ensure(deadline)
        returns (uint256 amountA, uint256 amountB)
    {
        address pair = MakiswapLibrary.pairFor(factory, tokenA, tokenB);
        IMakiswapPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = IMakiswapPair(pair).burn(to);
        (address token0, ) = MakiswapLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0
            ? (amount0, amount1)
            : (amount1, amount0);
        require(amountA >= amountAMin, "MakiswapRouter: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "MakiswapRouter: INSUFFICIENT_B_AMOUNT");
    }

    function removeLiquidityHT(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountHTMin,
        address to,
        uint256 deadline
    )
        public
        virtual
        override
        ensure(deadline)
        returns (uint256 amountToken, uint256 amountHT)
    {
        (amountToken, amountHT) = removeLiquidity(
            token,
            WHT,
            liquidity,
            amountTokenMin,
            amountHTMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWHT(WHT).withdraw(amountHT);
        TransferHelper.safeTransferHT(to, amountHT);
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountA, uint256 amountB) {
        address pair = MakiswapLibrary.pairFor(factory, tokenA, tokenB);
        uint256 value = approveMax ? uint256(-1) : liquidity;
        IMakiswapPair(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        (amountA, amountB) = removeLiquidity(
            tokenA,
            tokenB,
            liquidity,
            amountAMin,
            amountBMin,
            to,
            deadline
        );
    }

    function removeLiquidityHTWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountHTMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        virtual
        override
        returns (uint256 amountToken, uint256 amountHT)
    {
        address pair = MakiswapLibrary.pairFor(factory, token, WHT);
        uint256 value = approveMax ? uint256(-1) : liquidity;
        IMakiswapPair(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        (amountToken, amountHT) = removeLiquidityHT(
            token,
            liquidity,
            amountTokenMin,
            amountHTMin,
            to,
            deadline
        );
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityHTSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountHTMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountHT) {
        (, amountHT) = removeLiquidity(
            token,
            WHT,
            liquidity,
            amountTokenMin,
            amountHTMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(
            token,
            to,
            IHRC20(token).balanceOf(address(this))
        );
        IWHT(WHT).withdraw(amountHT);
        TransferHelper.safeTransferHT(to, amountHT);
    }

    function removeLiquidityHTWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountHTMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountHT) {
        address pair = MakiswapLibrary.pairFor(factory, token, WHT);
        uint256 value = approveMax ? uint256(-1) : liquidity;
        IMakiswapPair(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        amountHT = removeLiquidityHTSupportingFeeOnTransferTokens(
            token,
            liquidity,
            amountTokenMin,
            amountHTMin,
            to,
            deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address _to
    ) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = MakiswapLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0
                    ? (uint256(0), amountOut)
                    : (amountOut, uint256(0));
            address to =
                i < path.length - 2
                    ? MakiswapLibrary.pairFor(factory, output, path[i + 2])
                    : _to;
            IMakiswapPair(MakiswapLibrary.pairFor(factory, input, output)).swap(
                amount0Out,
                amount1Out,
                to,
                new bytes(0)
            );
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        amounts = MakiswapLibrary.getAmountsOut(factory, amountIn, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "MakiswapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            MakiswapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        amounts = MakiswapLibrary.getAmountsIn(factory, amountOut, path);
        require(
            amounts[0] <= amountInMax,
            "MakiswapRouter: EXCESSIVE_INPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            MakiswapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapExactHTForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[0] == WHT, "MakiswapRouter: INVALID_PATH");
        amounts = MakiswapLibrary.getAmountsOut(factory, msg.value, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "MakiswapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        IWHT(WHT).deposit{value: amounts[0]}();
        assert(
            IWHT(WHT).transfer(
                MakiswapLibrary.pairFor(factory, path[0], path[1]),
                amounts[0]
            )
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactHT(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[path.length - 1] == WHT, "MakiswapRouter: INVALID_PATH");
        amounts = MakiswapLibrary.getAmountsIn(factory, amountOut, path);
        require(
            amounts[0] <= amountInMax,
            "MakiswapRouter: EXCESSIVE_INPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            MakiswapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IWHT(WHT).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferHT(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForHT(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[path.length - 1] == WHT, "MakiswapRouter: INVALID_PATH");
        amounts = MakiswapLibrary.getAmountsOut(factory, amountIn, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "MakiswapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            MakiswapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        IWHT(WHT).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferHT(to, amounts[amounts.length - 1]);
    }

    function swapHTForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[0] == WHT, "MakiswapRouter: INVALID_PATH");
        amounts = MakiswapLibrary.getAmountsIn(factory, amountOut, path);
        require(
            amounts[0] <= msg.value,
            "MakiswapRouter: EXCESSIVE_INPUT_AMOUNT"
        );
        IWHT(WHT).deposit{value: amounts[0]}();
        assert(
            IWHT(WHT).transfer(
                MakiswapLibrary.pairFor(factory, path[0], path[1]),
                amounts[0]
            )
        );
        _swap(amounts, path, to);
        // refund dust eth, if any
        if (msg.value > amounts[0])
            TransferHelper.safeTransferHT(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(
        address[] memory path,
        address _to
    ) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = MakiswapLibrary.sortTokens(input, output);
            IMakiswapPair pair =
                IMakiswapPair(MakiswapLibrary.pairFor(factory, input, output));
            uint256 amountInput;
            uint256 amountOutput;
            {
                // scope to avoid stack too deep errors
                (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
                (uint256 reserveInput, uint256 reserveOutput) =
                    input == token0
                        ? (reserve0, reserve1)
                        : (reserve1, reserve0);
                amountInput = IHRC20(input).balanceOf(address(pair)).sub(
                    reserveInput
                );
                amountOutput = MakiswapLibrary.getAmountOut(
                    amountInput,
                    reserveInput,
                    reserveOutput
                );
            }
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0
                    ? (uint256(0), amountOutput)
                    : (amountOutput, uint256(0));
            address to =
                i < path.length - 2
                    ? MakiswapLibrary.pairFor(factory, output, path[i + 2])
                    : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            MakiswapLibrary.pairFor(factory, path[0], path[1]),
            amountIn
        );
        uint256 balanceBefore = IHRC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IHRC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >=
                amountOutMin,
            "MakiswapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactHTForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable virtual override ensure(deadline) {
        require(path[0] == WHT, "MakiswapRouter: INVALID_PATH");
        uint256 amountIn = msg.value;
        IWHT(WHT).deposit{value: amountIn}();
        assert(
            IWHT(WHT).transfer(
                MakiswapLibrary.pairFor(factory, path[0], path[1]),
                amountIn
            )
        );
        uint256 balanceBefore = IHRC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IHRC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >=
                amountOutMin,
            "MakiswapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactTokensForHTSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        require(path[path.length - 1] == WHT, "MakiswapRouter: INVALID_PATH");
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            MakiswapLibrary.pairFor(factory, path[0], path[1]),
            amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint256 amountOut = IHRC20(WHT).balanceOf(address(this));
        require(
            amountOut >= amountOutMin,
            "MakiswapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        IWHT(WHT).withdraw(amountOut);
        TransferHelper.safeTransferHT(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) public pure virtual override returns (uint256 amountB) {
        return MakiswapLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure virtual override returns (uint256 amountOut) {
        return MakiswapLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure virtual override returns (uint256 amountIn) {
        return MakiswapLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return MakiswapLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return MakiswapLibrary.getAmountsIn(factory, amountOut, path);
    }
}
