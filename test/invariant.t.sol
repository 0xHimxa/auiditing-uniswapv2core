pragma solidity =0.8.16;
import {Test,console} from "forge-std/Test.sol";
import {IERC20} from "src/interfaces/IERC20.sol";
import {IUniswapV2Callee} from "src/interfaces/IUniswapV2Callee.sol";
import {IUniswapV2ERC20} from "src/interfaces/IUniswapV2ERC20.sol";
import {IUniswapV2Factory} from "src/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "src/interfaces/IUniswapV2Pair.sol";
import {Math} from "./Math.sol";
import {USDC_ERC20} from "src/test/1ERC20.sol";
import{ CoreHandler} from "./handler.t.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
contract UniswapPairTest is StdInvariant, Test{

//do for token that have 6 decimal
IUniswapV2Pair pair;
IUniswapV2Factory fac;
uint256 constant TOKEN_A_BAL = 100000e18;
uint256 constant TOKEN_B_BAL = 400000e6;

uint256 pair0Amount = 20e6;
uint256 pair1Amount = 10e18;

address user = makeAddr("user");
address player = makeAddr("player");
address fee_h = makeAddr("feeSetter");
   
address tokenA;
address tokenB;
IERC20 token0;
IERC20 token1;
CoreHandler handler;
function setUp() external{
  
tokenA = deployCode("src/test/ERC20.sol:ERC20",abi.encodePacked(TOKEN_A_BAL));
 tokenB = address(new USDC_ERC20(address(this),TOKEN_B_BAL));


address _fac =deployCode("src/UniswapV2Factory.sol:UniswapV2Factory",abi.encode(fee_h));
fac = IUniswapV2Factory(_fac);
pair =IUniswapV2Pair(fac.createPair(tokenA, tokenB));
handler =  new CoreHandler(address(pair),player);

bytes4[] memory selectors = new bytes4[](7);
selectors[0] = CoreHandler.addLiquidity.selector;
selectors[1] = CoreHandler.addUnBalancedLiquidity.selector;
selectors[2] = CoreHandler.swap.selector;
selectors[3] = CoreHandler.syncPrice.selector;
selectors[4] = CoreHandler.skim.selector;
selectors[5] = CoreHandler.sendTokenToCore.selector;
selectors[6] = CoreHandler.burn.selector;



targetContract(address(handler));
targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));


token0 = IERC20(pair.token0());
token1 = IERC20(pair.token1());
vm.prank(fee_h);
fac.setFeeTo(fee_h);


}




function invariant_balancesMatchOrExceedReserves() external{

(uint256 rev0,uint256 rev1,) = pair.getReserves();
assertGe(token0.balanceOf(address(pair)),rev0,"Token A balance increased");
assertGe(token1.balanceOf(address(pair)),rev1,"Token B balance increased");

}

function invariant_totalSupplyMinimum() public {
    uint256 totalSupply = pair.totalSupply();
    if (totalSupply > 0) {
        assertGe(totalSupply, 1000, "Total supply cannot be non-zero and less than MINIMUM_LIQUIDITY");
    }
}

function invariant_kLastNonZero() public {
    uint256 kLast = pair.kLast();
    (uint256 _reserve0,uint256 _reserve1,) = pair.getReserves();

    uint256 k = _reserve0 * _reserve1;

    if (kLast != 0) {
      
        assertGe(k, kLast, "k must be >= kLast");
    }
}



function invariant_lpShareSolvency() public {
    uint256 totalSupply = pair.totalSupply();
    if (totalSupply == 0) return;

    (uint256 reserve0, uint256 reserve1,) = pair.getReserves();

    address testUser = handler.users(0);
    uint256 userLP = pair.balanceOf(testUser);

    if (userLP == 0) return;

    uint256 claim0 = (userLP * reserve0) / totalSupply;
    uint256 claim1 = (userLP * reserve1) / totalSupply;

    // A user's proportional claim can never exceed the pool reserves.
    assertLe(claim0, reserve0, "LP claim exceeds reserve0");
    assertLe(claim1, reserve1, "LP claim exceeds reserve1");

}



    function invariant_kLastGrowth() public {
    uint256 kLast = pair.kLast();
    if (kLast > 0) {
        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
        uint256 currentK = reserve0 * reserve1;
        
        // The current K must never drop below the last saved K 
        assertGe(currentK, kLast, "Current K dropped below kLast (Value leakage or math overflow)");
    }
}




function invariant_lpShareAccounting() public {
    uint256 totalSupply = pair.totalSupply();
    if (totalSupply == 0) return;

    uint256 sum;

    for (uint256 i = 0; i < 3; i++) {
        sum += pair.balanceOf(handler.users(i));
    }

    uint256 totalSum = sum + pair.balanceOf(player) + 1000;

    // Total LP owned by tracked users can never exceed total supply.
    assertLe(totalSum, totalSupply, "LP balances exceed total supply");
}


function invariant_feeReceiverBalance() public{
    uint256 feeReceiverLpshare = pair.balanceOf(fee_h);
    uint256 totalFee =  handler.totalFeeLp();
    
    assertEq(feeReceiverLpshare,totalFee,"fee receiver balance is not equal to total fee");
}

}