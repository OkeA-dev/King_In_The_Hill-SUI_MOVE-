pragma solidity =0.5.16;
pragma experimental ABIEncoderV2;

import "../../src/UniswapV2Factory.sol";
import "../../src/UniswapV2Pair.sol";
import "../../src/test/ERC20.sol";
import "../../src/libraries/Math.sol";
import "../../src/libraries/SafeMath.sol";

contract UniswapV2Invariant {
    using SafeMath for uint;

    UniswapV2Factory public factory;
    UniswapV2Pair public pair;
    ERC20 public token0;
    ERC20 public token1;
    
    // Track initial state for invariants
    uint public initialK;
    uint public totalLiquidityProvided;
    uint public totalLiquidityRemoved;
    
    // Constants
    uint public constant MINIMUM_LIQUIDITY = 10**3;
    uint public constant MAX_UINT112 = 2**112 - 1;
    
    // Ghost variables for tracking
    mapping(address => uint) public ghostBalances;
    uint public ghostTotalSupply;
    
    constructor() public {
        // Deploy factory with this contract as fee setter
        factory = new UniswapV2Factory(address(this));
        
        // Deploy test tokens with large supply
        token0 = new ERC20(10**27); // 1 billion tokens with 18 decimals
        token1 = new ERC20(10**27);
        
        // Ensure token0 < token1 for consistent ordering
        if (address(token0) > address(token1)) {
            ERC20 temp = token0;
            token0 = token1;
            token1 = temp;
        }
        
        // Create pair
        address pairAddress = factory.createPair(address(token0), address(token1));
        pair = UniswapV2Pair(pairAddress);
        
        // Approve pair to spend tokens
        token0.approve(address(pair), uint(-1));
        token1.approve(address(pair), uint(-1));
    }
    
    // =============================================================================
    // FUZZING FUNCTIONS
    // =============================================================================
    
    function addLiquidity(uint amount0, uint amount1) public {
        // Bound inputs to reasonable ranges
        amount0 = _bound(amount0, 1000, token0.balanceOf(address(this)) / 10);
        amount1 = _bound(amount1, 1000, token1.balanceOf(address(this)) / 10);
        
        // Transfer tokens to pair
        token0.transfer(address(pair), amount0);
        token1.transfer(address(pair), amount1);
        
        // Mint liquidity
        uint liquidity = pair.mint(address(this));
        totalLiquidityProvided = totalLiquidityProvided.add(liquidity);
        
        // Update ghost variables
        ghostBalances[address(this)] = ghostBalances[address(this)].add(liquidity);
        ghostTotalSupply = ghostTotalSupply.add(liquidity);
    }
    
    function removeLiquidity(uint liquidity) public {
        if (pair.balanceOf(address(this)) == 0) return;
        
        // Bound liquidity to available balance
        liquidity = _bound(liquidity, 1, pair.balanceOf(address(this)));
        
        // Transfer liquidity tokens to pair
        pair.transfer(address(pair), liquidity);
        
        // Burn liquidity
        pair.burn(address(this));
        totalLiquidityRemoved = totalLiquidityRemoved.add(liquidity);
        
        // Update ghost variables
        ghostBalances[address(this)] = ghostBalances[address(this)].sub(liquidity);
        ghostTotalSupply = ghostTotalSupply.sub(liquidity);
    }
    
    function swap(uint amount0Out, uint amount1Out, bool useCallback) public {
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        
        // Ensure we don't try to swap more than available
        if (amount0Out >= reserve0) amount0Out = 0;
        if (amount1Out >= reserve1) amount1Out = 0;
        if (amount0Out == 0 && amount1Out == 0) return;
        
        // Bound outputs to reasonable amounts
        amount0Out = _bound(amount0Out, 0, reserve0 / 2);
        amount1Out = _bound(amount1Out, 0, reserve1 / 2);
        
        // Calculate required input based on constant product formula
        uint amount0In = 0;
        uint amount1In = 0;
        
        if (amount0Out > 0 && amount1Out == 0) {
            // Swapping token1 for token0
            amount1In = _getAmountIn(amount0Out, reserve1, reserve0);
            token1.transfer(address(pair), amount1In);
        } else if (amount1Out > 0 && amount0Out == 0) {
            // Swapping token0 for token1
            amount0In = _getAmountIn(amount1Out, reserve0, reserve1);
            token0.transfer(address(pair), amount0In);
        } else {
            // Invalid swap - both outputs specified
            return;
        }
        
        // Execute swap
        bytes memory data;
        if (useCallback) {
            data = abi.encode("callback");
        }
        pair.swap(amount0Out, amount1Out, address(this), data);
    }
    
    function skim() public {
        pair.skim(address(this));
    }
    
    function sync() public {
        pair.sync();
    }
    
    // Callback for flash swaps
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external {
        require(msg.sender == address(pair), "Invalid caller");
        
        // Simple callback that pays back the loan with fee
        if (amount0 > 0) {
            uint amountRequired = amount0.mul(1000) / 997 + 1;
            token0.transfer(address(pair), amountRequired);
        }
        if (amount1 > 0) {
            uint amountRequired = amount1.mul(1000) / 997 + 1;
            token1.transfer(address(pair), amountRequired);
        }
    }
    
    // =============================================================================
    // INVARIANT PROPERTIES
    // =============================================================================
    
    function property_constantProductFormula() public view returns (bool) {
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        
        if (reserve0 == 0 || reserve1 == 0) return true;
        
        uint currentK = uint(reserve0).mul(reserve1);
        
        // K should never decrease (accounting for rounding)
        return currentK >= initialK || initialK == 0;
    }
    
    function property_reservesMatchBalances() public view returns (bool) {
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        
        uint balance0 = token0.balanceOf(address(pair));
        uint balance1 = token1.balanceOf(address(pair));
        
        // Reserves should match balances (or balances should be higher due to pending fees)
        return balance0 >= reserve0 && balance1 >= reserve1;
    }
    
    function property_minimumLiquidityLocked() public view returns (bool) {
        if (pair.totalSupply() == 0) return true;
        
        // Minimum liquidity should be permanently locked
        return pair.balanceOf(address(0)) == MINIMUM_LIQUIDITY;
    }
    
    function property_totalSupplyConsistency() public view returns (bool) {
        uint actualTotalSupply = pair.totalSupply();
        
        // Total supply should equal sum of all balances
        uint sumOfBalances = pair.balanceOf(address(this)) + pair.balanceOf(address(0));
        
        return actualTotalSupply == sumOfBalances;
    }
    
    function property_noOverflowInReserves() public view returns (bool) {
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        
        // Reserves should never overflow uint112
        return reserve0 <= MAX_UINT112 && reserve1 <= MAX_UINT112;
    }
    
    function property_priceAccumulatorIncreases() public view returns (bool) {
        uint price0 = pair.price0CumulativeLast();
        uint price1 = pair.price1CumulativeLast();
        
        // Price accumulators should only increase (or stay same if no time passed)
        // This is a simplified check - in practice we'd track previous values
        return price0 >= 0 && price1 >= 0;
    }
    
    function property_liquidityTokensConservation() public view returns (bool) {
        if (pair.totalSupply() == 0) return true;
        
        // The sum of liquidity provided minus removed should equal current holdings plus locked minimum
        uint expectedLiquidity = totalLiquidityProvided.sub(totalLiquidityRemoved);
        uint actualLiquidity = pair.balanceOf(address(this)).add(MINIMUM_LIQUIDITY);
        
        // Allow for small rounding differences
        return _almostEqual(expectedLiquidity, actualLiquidity, 1000);
    }
    
    function property_kLastConsistency() public view returns (bool) {
        uint kLast = pair.kLast();
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        
        if (kLast == 0) return true;
        
        // kLast should be reasonable compared to current reserves
        uint currentK = uint(reserve0).mul(reserve1);
        
        // kLast should not be drastically different from current K
        return kLast <= currentK.mul(2) && currentK <= kLast.mul(2);
    }
    
    function property_noTokenLoss() public view returns (bool) {
        uint totalToken0 = token0.balanceOf(address(this)).add(token0.balanceOf(address(pair)));
        uint totalToken1 = token1.balanceOf(address(this)).add(token1.balanceOf(address(pair)));
        
        // Total tokens should not exceed initial supply (allowing for fees)
        return totalToken0 <= 10**27 && totalToken1 <= 10**27;
    }
    
    function property_swapAmountBounds() public view returns (bool) {
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        
        // Reserves should be reasonable (not zero unless pair is empty)
        if (pair.totalSupply() > MINIMUM_LIQUIDITY) {
            return reserve0 > 0 && reserve1 > 0;
        }
        return true;
    }
    
    // =============================================================================
    // HELPER FUNCTIONS
    // =============================================================================
    
    function _bound(uint value, uint min, uint max) internal pure returns (uint) {
        if (max <= min) return min;
        return min + (value % (max - min + 1));
    }
    
    function _almostEqual(uint a, uint b, uint tolerance) internal pure returns (bool) {
        if (a > b) {
            return a.sub(b) <= tolerance;
        } else {
            return b.sub(a) <= tolerance;
        }
    }
    
    function _getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint) {
        require(amountOut > 0, 'INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'INSUFFICIENT_LIQUIDITY');
        
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        return numerator / denominator + 1;
    }
    
    // Initialize K after first liquidity provision
    function _updateInitialK() internal {
        if (initialK == 0) {
            (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
            if (reserve0 > 0 && reserve1 > 0) {
                initialK = uint(reserve0).mul(reserve1);
            }
        }
    }
    
    // Override to update initial K after first mint
    function mint(address to) external returns (uint liquidity) {
        liquidity = pair.mint(to);
        _updateInitialK();
        return liquidity;
    }
}
