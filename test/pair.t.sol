pragma solidity =0.8.16;
import {Test,console} from "forge-std/Test.sol";
import {IERC20} from "src/interfaces/IERC20.sol";
import {IUniswapV2Callee} from "src/interfaces/IUniswapV2Callee.sol";
import {IUniswapV2ERC20} from "src/interfaces/IUniswapV2ERC20.sol";
import {IUniswapV2Factory} from "src/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "src/interfaces/IUniswapV2Pair.sol";
import {Math} from "./Math.sol";
import {USDC_ERC20} from "src/test/1ERC20.sol";

contract UniswapPairTest is Test{

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

function setUp() external{
  
tokenA = deployCode("src/test/ERC20.sol:ERC20",abi.encodePacked(TOKEN_A_BAL));
 tokenB = address(new USDC_ERC20(address(this),TOKEN_B_BAL));


address _fac =deployCode("src/UniswapV2Factory.sol:UniswapV2Factory",abi.encode(fee_h));
fac = IUniswapV2Factory(_fac);
    pair =IUniswapV2Pair(fac.createPair(tokenA, tokenB));

token0 = IERC20(pair.token0());
token1 = IERC20(pair.token1());



token0.transfer(user, 200000e6);
token0.transfer(player, 200000e6);
token1.transfer(user, 100e18);
token1.transfer(player, 100e18);

}


function test_createPair_Revert_Same_Token() external{


vm.expectRevert("UniswapV2: IDENTICAL_ADDRESSES");
fac.createPair(tokenA, tokenA);



}



//did test sort and zero address work
function test_createPair_revert_zero_address() external{

vm.expectRevert("UniswapV2: ZERO_ADDRESS");
fac.createPair(address(0), tokenB);



vm.expectRevert('UniswapV2: PAIR_EXISTS');
fac.createPair(tokenA, tokenB);
}


function test_getter_works() external{

address _pair = fac.getPair(tokenA, tokenB);
address s_pair = fac.getPair(tokenB, tokenA);
assertEq(fac.allPairsLength(),1);
assertEq(_pair,s_pair);




}


function test_setFeeTo_revert() external{
vm.expectRevert('UniswapV2: FORBIDDEN');
fac.setFeeTo(address(0));


vm.expectRevert('UniswapV2: FORBIDDEN');
fac.setFeeToSetter(address(0));

}


function test_feetoSetter() external{

  vm.prank(fee_h);
  fac.setFeeToSetter(address(0));


  assertEq(fac.feeToSetter(),address(0));

vm.expectRevert('UniswapV2: FORBIDDEN');
 fac.setFeeToSetter(address(100));

}





function test_pair_Initialize()external {

vm.expectRevert( 'UniswapV2: FORBIDDEN');
pair.initialize(address(100), address(200));


}



function test_pairMint() external {

vm.startPrank(user);

token0.transfer(address(pair), 2000e6);
token1.transfer(address(pair), 1e18);

pair.mint(user);

vm.stopPrank();



uint256 f_lp = Math.sqrt(2000e6 * 1e18) - 1000;

assertEq(pair.balanceOf(user),f_lp);
assertEq(pair.totalSupply(), f_lp + 1000);



vm.startPrank(player);


token0.transfer(address(pair), 2000e6);
token1.transfer(address(pair), 1e18);
pair.mint(player); 


vm.stopPrank();


(uint112 rev0, uint112 rev1,) = pair.getReserves();
uint256 playMints = Math.min((2000e6 * pair.totalSupply())/rev0,( 1e18 * pair.totalSupply())/rev1 );

assertEq(pair.balanceOf(player),playMints);




}



function test_mint_min() external{
vm.startPrank(user);

token0.transfer(address(pair), 2000e6);
token1.transfer(address(pair), 1e18);

pair.mint(user);

vm.stopPrank();


(uint112 rev0, uint112 rev1,) = pair.getReserves();

uint256 supplyBefore = pair.totalSupply();
//price of 0 in 1
uint _price0 = (uint256(rev1) * 1e18)/rev0;
console.log(_price0);
uint256 amount0W = 4000e6;
uint256 amount1W = 1 ether;
//amount 1 required for $100
//in other other we devide our share OurShareWeWantToSend/rev0 = the percententage we want to send
// thne mul it by rev 1 = amount 1 require
//@example  we have 5 token0

//100 token0 in rev and 400 token in rev
//so we mul our percentage by token1 rev that will
//give us the amouunt of token1 we need to send for that percentage


//token 1 needed 5/100  * 400


uint256 amount1required = (amount0W * uint256(rev1)) / uint256(rev0);
console.log("here is the amount 1 required",amount1required);



vm.startPrank(player);

token0.transfer(address(pair),amount0W);
token1.transfer(address(pair), amount1required);

pair.mint(player);


vm.stopPrank();



// 1. Calculate the share weights for both sides independently
uint256 liquidity0 = (amount0W * supplyBefore) / rev0;
uint256 liquidity1 = (amount1required * supplyBefore) / rev1;


assertEq(pair.balanceOf(player),liquidity1);
assertEq(liquidity0, liquidity1);

}












function test_mint_userPenrlised() external{
vm.startPrank(user);

token0.transfer(address(pair), 2000e6);
token1.transfer(address(pair), 1e18);

pair.mint(user);

vm.stopPrank();


(uint112 rev0, uint112 rev1,) = pair.getReserves();

uint256 supplyBefore = pair.totalSupply();
//price of 0 in 1
uint _price0 = (uint256(rev1) * 1e18)/rev0;
console.log(_price0);
uint256 amount0W = 40000e6;
uint256 amount1W = 1 ether;
//amount 1 required for $100
//in other other we devide our share OurShareWeWantToSend/rev0 = the percententage we want to send
// thne mul it by rev 1 = amount 1 require
//@example  we have 5 token0

//100 token0 in rev and 400 token in rev
//so we mul our percentage by token1 rev that will
//give us the amouunt of token1 we need to send for that percentage


//token 1 needed 5/100  * 400


uint256 amount1required = (amount0W * uint256(rev1)) / uint256(rev0);
console.log("here is the amount 1 required",amount1required);



uint256 manipulated_amount1 = amount1required * 2;

vm.startPrank(player);

token0.transfer(address(pair),amount0W);
token1.transfer(address(pair), manipulated_amount1);

pair.mint(player);


vm.stopPrank();



// 1. Calculate the share weights for both sides independently
uint256 liquidity0 = (amount0W * supplyBefore) / rev0;
uint256 liquidity1 = (manipulated_amount1 * supplyBefore) / rev1;

assertNotEq(pair.balanceOf(player), liquidity1);
assertEq(pair.balanceOf(player), liquidity0);
assertGe(liquidity1,liquidity0);
//assertEq(liquidity0, liquidity1);

}





}


