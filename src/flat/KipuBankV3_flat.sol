// SPDX-License-Identifier: MIT

pragma abicoder v2;

// File @uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol@v1.0.1

pragma solidity >=0.5.0;

/// @title Callback for IUniswapV3PoolActions#swap
/// @notice Any contract that calls IUniswapV3PoolActions#swap must implement this interface
interface IUniswapV3SwapCallback {
    /// @notice Called to `msg.sender` after executing a swap via IUniswapV3Pool#swap.
    /// @dev In the implementation you must pay the pool tokens owed for the swap.
    /// The caller of this method must be checked to be a UniswapV3Pool deployed by the canonical UniswapV3Factory.
    /// amount0Delta and amount1Delta can both be 0 if no tokens were swapped.
    /// @param amount0Delta The amount of token0 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token0 to the pool.
    /// @param amount1Delta The amount of token1 that was sent (negative) or must be received (positive) by the pool by
    /// the end of the swap. If positive, the callback must send that amount of token1 to the pool.
    /// @param data Any data passed through by the caller via the IUniswapV3PoolActions#swap call
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}



pragma solidity >=0.7.5;

/// @title Router token swapping functionality
/// @notice Functions for swapping tokens via Uniswap V3
interface ISwapRouter is IUniswapV3SwapCallback {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactInputParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactOutputSingleParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another along the specified path (reversed)
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactOutputParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
}


pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

   
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}


// File contracts/KipuBankV3.sol

pragma solidity ^0.8.24;

/*
  KipuBankV3 adaptado a Uniswap V3 (SwapRouter)
  - Depósitos ETH
  - Depósitos ERC20 (por token)
  - Retiros ETH / ERC20
  - swapExactInputSingle usando ISwapRouter.exactInputSingle (Uniswap V3)
*/


// Minimal TransferHelper (copiado / simplificado)
library TransferHelper {
    function safeTransferFrom(address token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20(token).transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferFrom failed");
    }

    function safeApprove(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20(token).approve.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Approve failed");
    }

    function safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20(token).transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed");
    }
}

enum Currency { NATIVE, ERC20 }

struct Ledger {
    uint256 balance;
    uint40 lastUpdated;
}

error ZeroAddress();
error ZeroAmount();
error InsufficientBalance();

contract KipuBankV3 {
    // ledger para ETH
    mapping(address => Ledger) internal _ethBook;

    // ledger por token: user => token => balance
    mapping(address => mapping(address => uint256)) internal _erc20Balances;
    mapping(address => mapping(address => uint40)) internal _erc20LastUpdated;

    // Uniswap V3 SwapRouter (ej: mainnet: 0xE592427A0AEce92De3Edee1F18E0157C05861564)
    ISwapRouter public immutable swapRouter;
    address public permit2;
    // Eventos
    event Deposit(address indexed user, address token, uint256 amount);
    event Withdraw(address indexed user, address token, uint256 amount);
    event SwapExecuted(address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    constructor(address _swapRouter, address _permit2) {
        if (_swapRouter == address(0) || _permit2 == address(0)) revert ZeroAddress();
        swapRouter = ISwapRouter(_swapRouter);
        permit2 = _permit2;
    }


    // ---- Depósito ETH ----
    function deposit() external payable {
        if (msg.value == 0) revert ZeroAmount();
        Ledger storage L = _ethBook[msg.sender];
        L.balance += msg.value;
        L.lastUpdated = uint40(block.timestamp);
        emit Deposit(msg.sender, address(0), msg.value);
    }

    // ---- Depósito ERC20 arbitrario ----
    // El usuario debe haber aprobado previamente este contrato con token.approve(contract, amount)
    function depositArbitraryToken(address token, uint256 amount) external {
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        // transferir token desde el usuario al contrato
        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amount);

        _erc20Balances[msg.sender][token] += amount;
        _erc20LastUpdated[msg.sender][token] = uint40(block.timestamp);

        emit Deposit(msg.sender, token, amount);
    }

    // ---- Withdraw ETH ----
    function withdrawETH(uint256 amount) external {
        Ledger storage L = _ethBook[msg.sender];
        if (L.balance < amount) revert InsufficientBalance();
        L.balance -= amount;
        L.lastUpdated = uint40(block.timestamp);

        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "ETH transfer failed");
        emit Withdraw(msg.sender, address(0), amount);
    }

    // ---- Withdraw Token ----
    function withdrawToken(address token, uint256 amount) external {
        if (token == address(0)) revert ZeroAddress();
        uint256 bal = _erc20Balances[msg.sender][token];
        if (bal < amount) revert InsufficientBalance();

        _erc20Balances[msg.sender][token] = bal - amount;
        _erc20LastUpdated[msg.sender][token] = uint40(block.timestamp);

        TransferHelper.safeTransfer(token, msg.sender, amount);
        emit Withdraw(msg.sender, token, amount);
    }

    // ---- Balance views ----
    function balanceOfETH(address user) external view returns (uint256) {
        return _ethBook[user].balance;
    }

    function balanceOfToken(address user, address token) external view returns (uint256) {
        return _erc20Balances[user][token];
    }

    // ---- Swap exact input single (Uniswap V3)
    //
    // Nota: Uniswap V3 router requiere que este contrato tenga allowance sobre tokenIn
    // (es decir, el usuario debe transferir tokenIn a este contrato con depositArbitraryToken,
    // o aprobar este contrato para que lo mueva). Aquí asumimos que el contrato ya posee tokenIn
    // en su balance (por ejemplo, usuario depositó previamente).
    //
    // fee: típico 3000 (0.3%) o 500 (0.05%) - ajústalo según el pool que quieras usar.
    //
    function swapExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) external returns (uint256 amountOut) {
        if (tokenIn == address(0) || tokenOut == address(0)) revert ZeroAddress();
        if (amountIn == 0) revert ZeroAmount();

        // Verificamos que el usuario haya depositado suficiente tokenIn en el banco interno
        uint256 userBal = _erc20Balances[msg.sender][tokenIn];
        if (userBal < amountIn) revert InsufficientBalance();

        // Reducimos saldo interno del usuario (moveremos tokens desde el contrato al router)
        _erc20Balances[msg.sender][tokenIn] = userBal - amountIn;
        _erc20LastUpdated[msg.sender][tokenIn] = uint40(block.timestamp);

        // Aprobar al router para mover amountIn desde el contrato
        TransferHelper.safeApprove(tokenIn, address(swapRouter), amountIn);

        // Preparar parámetros para exactInputSingle
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: address(this), // recibir los tokens en este contrato; luego podríamos asignarlos al usuario
            deadline: block.timestamp + 300, // 5 minutos
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum,
            sqrtPriceLimitX96: 0
        });

        // Ejecutar swap
        amountOut = swapRouter.exactInputSingle(params);

        // Registrar el resultado: sumamos tokenOut al balance interno del usuario
        _erc20Balances[msg.sender][tokenOut] += amountOut;
        _erc20LastUpdated[msg.sender][tokenOut] = uint40(block.timestamp);

        emit SwapExecuted(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    // fallback / receive para recibir ETH directo
    receive() external payable {
        if (msg.value == 0) return;
        Ledger storage L = _ethBook[msg.sender];
        L.balance += msg.value;
        L.lastUpdated = uint40(block.timestamp);
        emit Deposit(msg.sender, address(0), msg.value);
    }
}
