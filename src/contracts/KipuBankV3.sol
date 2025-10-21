// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
  KipuBankV3 adaptado a Uniswap V3 (SwapRouter)
  - Depósitos ETH
  - Depósitos ERC20 (por token)
  - Retiros ETH / ERC20
  - swapExactInputSingle usando ISwapRouter.exactInputSingle (Uniswap V3)
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

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
