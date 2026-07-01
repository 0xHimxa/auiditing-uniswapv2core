pragma solidity =0.8.16;
import {Test} from "forge-std/Test.sol";

import {IERC20} from "src/interfaces/IERC20.sol";
import {IUniswapV2Callee} from "src/interfaces/IUniswapV2Callee.sol";
import {IUniswapV2ERC20} from "src/interfaces/IUniswapV2ERC20.sol";
import {IUniswapV2Factory} from "src/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "src/interfaces/IUniswapV2Pair.sol";
import {Math} from "./Math.sol";
import {USDC_ERC20} from "src/test/1ERC20.sol";





contract CoreHandler is Test {
    IUniswapV2Pair public pair;
    IERC20 public token0;
    IERC20 public token1;
    
    address[] public users;
    address public currentActor;
    
    // Constants for testing
    uint256 constant TOKEN0_DECIMALS = 1e6;
    uint256 constant TOKEN1_DECIMALS = 1e18;
    uint256 constant INITIAL_TOKEN0 = 1_000_000e6;
    uint256 constant INITIAL_TOKEN1 = 500e18;
    
    constructor(address _pair) {
        pair = IUniswapV2Pair(_pair);
        token0 = IERC20(pair.token0());
        token1 = IERC20(pair.token1());
        
        users = [address(0x1111), address(0x2222), address(0x3333)];
        
        for (uint256 i = 0; i < users.length; i++) {
            vm.deal(users[i], 100 ether);
            deal(address(token0), users[i], INITIAL_TOKEN0);
            deal(address(token1), users[i], INITIAL_TOKEN1);
        }
    }
    
    function addLiquidity(uint256 _amountAdding, uint256 amount1side, uint8 _player) external {
        address player = users[_player % users.length];
        (uint256 rev0, uint256 rev1,) = pair.getReserves();
        
        uint256 amount0 = bound(_amountAdding, 1e4, 1_000_000e6);
        uint256 amount1 = rev0 == 0 && rev1 == 0 
            ? bound(amount1side, 1e4, 500e18)
            : (amount0 * rev1) / rev0;
        
        _ensureBalance(player, amount0, amount1);
        
        vm.startPrank(player);
        token0.transfer(address(pair), amount0);
        token1.transfer(address(pair), amount1);
        pair.mint(player);
        vm.stopPrank();
    }
    
    function burn(uint256 _amountBurn, uint8 _playerIndex) external {
        address player = users[_playerIndex % users.length];
        uint256 balance = pair.balanceOf(player);
        
        if (balance == 0) return;
        
        uint256 amount = bound(_amountBurn, 1e4, balance);
        
        vm.startPrank(player);
        pair.transfer(address(pair), amount);
        pair.burn(player);
        vm.stopPrank();
    }
    
    function swap(uint256 amountOut, bool side, uint8 _playerIndex) external {
        address player = users[_playerIndex % users.length];
        (uint256 rev0, uint256 rev1,) = pair.getReserves();
        
        if (side) {
            uint256 amountIn = bound(amountOut, 1e4, 490e18);
            _ensureToken1Balance(player, amountIn);
            
            uint256 amountOut0 = _getAmountOut(amountIn, rev1, rev0);
            if (amountOut0 > rev0) return;
            
            vm.startPrank(player);
            token1.transfer(address(pair), amountIn);
            pair.swap(amountOut0, 0, player, "");
            vm.stopPrank();
        } else {
            uint256 amountIn = bound(amountOut, 1e3, 900_000e6);
            _ensureToken0Balance(player, amountIn);
            
            uint256 amountOut1 = _getAmountOut(amountIn, rev0, rev1);
            
            if (amountOut1 > rev1) return;
            
            vm.startPrank(player);
            token0.transfer(address(pair), amountIn);
            pair.swap(0, amountOut1, player, "");
            vm.stopPrank();
        }
    }
    

    
    function _ensureBalance(address user, uint256 amt0, uint256 amt1) internal {
        if (token0.balanceOf(user) < amt0) deal(address(token0), user, amt0 * 2);
        if (token1.balanceOf(user) < amt1) deal(address(token1), user, amt1 * 2);
    }
    
    function _ensureToken0Balance(address user, uint256 amt) internal {
        if (token0.balanceOf(user) < amt) deal(address(token0), user, amt * 2);
    }
    
    function _ensureToken1Balance(address user, uint256 amt) internal {
        if (token1.balanceOf(user) < amt) deal(address(token1), user, amt * 2);
    }
    

    
    function getBalances(address user) external view returns (uint256, uint256, uint256, uint256) {
        return (
            user.balance,
            token0.balanceOf(user),
            token1.balanceOf(user),
            pair.balanceOf(user)
        );
    }



    function _getAmountOut(
    uint256 amountIn,
    uint256 reserveIn,
    uint256 reserveOut
)
    internal
    pure
    returns (uint256)
{
    uint256 amountInWithFee = amountIn * 997;

    return reserveOut * amountInWithFee
        / (reserveIn * 1000 + amountInWithFee);
}
}