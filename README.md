# 💰 KipuBankV3 — Contrato de Banca Descentralizada con Swap Uniswap V3

**KipuBankV3** es una evolución del contrato original **KipuBank**, diseñado para ofrecer **capacidad de *swapping* interno** a través del *SwapRouter* de **Uniswap V3**. Permite a los usuarios mover y rebalancear sus activos depositados (ETH y ERC20) de manera atómica y eficiente en términos de gas.

---

## 🚀 1. Mejoras realizadas y justificación

### 🔄 Integración Atómica con Uniswap V3
- **Motivo:** La versión anterior carecía de capacidades DeFi, limitándose solo a depósitos y retiros.
- **Mejora:** Se implementó una instancia inmutable de **`ISwapRouter`** (Uniswap V3) y la función `swapExactInputSingle` que usa el `recipient: address(this)`.
- **Beneficio:** Permite a los usuarios realizar intercambios de tokens **sin retirar sus fondos** (ahorrando gas) y garantiza que los tokens resultantes se acrediten inmediatamente al *ledger* interno.

---

### 🧱 Sistema de Ledger Unificado
- **Motivo:** Necesidad de un sistema robusto para manejar saldos ETH y ERC20 sin conflicto.
- **Mejora:** Se utilizan mappings separados para ETH (`_ethBook`) y tokens (`_erc20Balances`, `_erc20LastUpdated`) y se introduce una estructura `Ledger` simple.
- **Beneficio:** El código es limpio y modular, y la gestión de saldos es clara. La lógica de depósito y *swap* actualiza directamente estos *ledgers*.

---

### 🛡️ Transacciones de Tokens Seguras (`TransferHelper`)
- **Motivo:** Los *tokens no estándar* pueden causar errores en llamadas de bajo nivel (`.transfer()`).
- **Mejora:** Se implementó una librería minimalista `TransferHelper` con funciones `safeTransferFrom`, `safeTransfer` y `safeApprove`.
- **Beneficio:** Aísla la lógica de transferencia, haciendo que la interacción con cualquier token ERC20 sea **más robusta y segura**.

---

### ⚙️ Optimización de Almacenamiento
- **Motivo:** Optimizar el uso de *storage slots* para reducir los costos de gas.
- **Mejora:** Se utiliza **`uint40`** para el campo `lastUpdated` dentro de la estructura `Ledger`.
- **Beneficio:** Permite el **empaquetamiento de *slots*** (*storage packing*) con otras variables, logrando un **ahorro de gas** en cada depósito, retiro o *swap* que actualiza el *timestamp*.

---

## ⚙️ 2. Instrucciones de despliegue e interacción

### 🧩 Compilación

1.  Asegúrate de que tus dependencias están instaladas: `@openzeppelin/contracts` y `@uniswap/v3-periphery`.
2.  Compila con Hardhat:
    ```bash
    npx hardhat compile
    ```

---

### 🚀 Despliegue

#### Red de Prueba (Ej. Sepolia)
1.  **Obtén Direcciones:** Necesitas la dirección del *SwapRouter* de Uniswap V3 para Sepolia (o tu red) y la dirección del contrato Permit2.
2.  **Ejecuta el despliegue:**
    ```bash
    # Asegúrate de pasar las direcciones del SwapRouter y Permit2 en tu script.
    npx hardhat run scripts/deploy.js --network sepolia
    ```
3.  El constructor revierte si alguna de las direcciones es `address(0)`.

---

### 💬 Interacción básica

| Función | Tipo | Descripción |
|----------|------|-------------|
| `deposit()` | `external payable` | Envía ETH al contrato y actualiza tu saldo interno. (También usa `receive()`). |
| `depositArbitraryToken(token, amount)` | `external` | Deposita un token ERC20. Requiere aprobación previa del usuario. |
| `withdrawETH(amount)` | `external` | Retira ETH del saldo interno. |
| `withdrawToken(token, amount)` | `external` | Retira tokens ERC20 del saldo interno. |
| `swapExactInputSingle(...)` | `external` | Ejecuta un *swap* en Uniswap V3. El resultado se acredita internamente. |
| `balanceOfETH(user)` | `view` | Devuelve el saldo de ETH. |
| `balanceOfToken(user, token)` | `view` | Devuelve el saldo de un token específico. |

---

### 💡 Ejemplo de Flujo de Uso (Swap)

1.  **Aprobar:** El usuario llama a `tokenIn.approve(KIPUBANK_ADDRESS, amount)` para permitir el depósito.
2.  **Depositar:** El usuario llama a `depositArbitraryToken(tokenIn, amountIn)`.
3.  **Swapear:** El usuario llama a `swapExactInputSingle(tokenIn, tokenOut, fee, amountIn, amountOutMinimum)`.
4.  **Verificar:** El saldo interno de `tokenIn` se reduce y el saldo interno de `tokenOut` aumenta.
5.  **Retirar:** El usuario llama a `withdrawToken(tokenOut, amountOut)`.

---

## 🧩 3. Notas de Diseño y *Trade-offs*

### 🔒 Seguridad y Control de Fondos
* **Patrón de Swap:** Se usa `recipient: address(this)` en los parámetros de Uniswap. Esto significa que el token resultante del *swap* siempre regresa a `KipuBankV3`, y luego se acredita al *ledger* del usuario. Esto previene que los fondos salgan del control del *ledger* durante la operación.
* **Manejo de Errores:** Se utilizan *Custom Errors* (`ZeroAddress`, `ZeroAmount`, `InsufficientBalance`) en lugar de `require()` con mensajes largos, lo que ahorra gas y ofrece errores más claros.

### 💸 Trade-offs de Diseño
| Decisión | Beneficio | Costo o limitación |
|-----------|------------|--------------------|
| **Swap Interno** | Máxima eficiencia en gas (ahorra transacciones externas). | Requiere que el usuario realice un `withdraw` separado para acceder a los tokens. |
| **`TransferHelper`** | Robustez y seguridad contra tokens no estándar. | Añade una librería extra al tamaño del bytecode. |
| **`permit2` en constructor** | Reserva la capacidad para una mejora futura (UX). | La dirección se almacena de forma inmutable, pero no se usa en el código actual. |
| **`uint40 lastUpdated`** | Ahorro de gas por *storage packing*. | El *timestamp* se limita a un valor que será válido por cientos de años (pero es suficiente). |

---
## 👨‍💻 Autor y créditos

Desarrollado por **Christian Cañar**
Proyecto académico: *KipuBankV3 – Integración con Uniswap V3*
© 2025 — Todos los derechos reservados.
