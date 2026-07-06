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
vm.prank(fee_h);
fac.setFeeTo(fee_h);

console.log(fac.feeTo(), "fee setter sent");
token0.transfer(user, 200000e6);
token0.transfer(player, 200000e6);
token1.transfer(user, 100e18);
token1.transfer(player, 100e18);

}



modifier f_lp(){

vm.startPrank(user);

token0.transfer(address(pair), 8000e6);
token1.transfer(address(pair), 4e18);

pair.mint(user);

vm.stopPrank();


_;
}



function getAmountOut(
    uint256 amountIn, 
    uint256 reserveIn, 
    uint256 reserveOut
) internal pure returns (uint256 amountOut) {
    require(amountIn > 0, 'INSUFFICIENT_INPUT_AMOUNT');
    require(reserveIn > 0 && reserveOut > 0, 'INSUFFICIENT_LIQUIDITY');
    
    uint256 amountInWithFee = amountIn * 997;
    uint256 numerator = amountInWithFee * reserveOut;
    uint256 denominator = (reserveIn * 1000) + amountInWithFee;
    
    amountOut = numerator / denominator;
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





function test_mint_Swap_diffent_ratioReturned()external f_lp{




(uint112 rev0, uint112 rev1,) = pair.getReserves();

console.log("revser0 before swap",rev0, "Reserve 1 before swap", rev1);

address t_user = makeAddr("testUser");


//swap prank
vm.startPrank(player);


token1.transfer(address(pair), 1 ether);

pair.swap(1330667, 0, t_user, "");
vm.stopPrank();
token0.balanceOf(t_user);





address f_user = makeAddr("fBalancUser");
console.log(fac.feeTo(),"Fee recerver address");
vm.startPrank(user);

pair.transfer(address(pair), pair.balanceOf(user));
pair.burn(f_user);
console.log(pair.balanceOf(fee_h),"fee recever balance");
console.log(pair.balanceOf(f_user),"balance");

vm.stopPrank();

assertGe(token0.balanceOf(f_user),0);
assertGe(token1.balanceOf(f_user),0);


}




function test_swapFashCall_suceed() external f_lp{

 TFlashSwap flashSwap =  new TFlashSwap(address(pair), address(token1));
 uint256 amountOut= 1330663997;


 vm.startPrank(player);
 token1.transfer(address(flashSwap),2 ether);
 pair.swap(amountOut,0, address(flashSwap),abi.encode(100)); 


vm.stopPrank();


assertEq(token0.balanceOf(address(flashSwap)), amountOut);
assertEq(token1.balanceOf(address(flashSwap)), 1e18);






}






function test_swapFashCall_failed() external f_lp{

 TFlashSwap flashSwap =  new TFlashSwap(address(pair), address(token1));
 uint256 amountOut= 100e6;


 vm.startPrank(player);
 token1.transfer(address(flashSwap),2 ether);
 vm.stopPrank();

 vm.expectRevert('UniswapV2: K');
 pair.swap(amountOut,0, address(flashSwap),abi.encode(100)); 











}






function test_Sequence_SwapThenBurn() public f_lp {
        // 1. Perform a swap




(uint112 rev0, uint112 rev1,) = pair.getReserves();
uint256 _klas = pair.kLast();
 uint256 amountOut= 1330663997;
address t_user = makeAddr("testUser");


//swap prank
vm.startPrank(player);


token1.transfer(address(pair), 1 ether);

pair.swap(1330667, 0, t_user, "");
vm.stopPrank();
token0.balanceOf(t_user);
(uint112 reev0, uint112 reev1,) = pair.getReserves();
assertGe((reev0 * reev1), _klas);



address f_user = makeAddr("fBalancUser");
console.log(fac.feeTo(),"Fee recerver address");
vm.startPrank(user);

pair.transfer(address(pair), pair.balanceOf(user));
pair.burn(f_user);
console.log(pair.balanceOf(fee_h),"fee recever balance");
console.log(pair.balanceOf(f_user),"balance");
(uint112 reeev0, uint112 reeev1,) = pair.getReserves();
assert((reeev0 * reeev1) < _klas);
vm.stopPrank();








    }

    function test_Sequence_FlashSwapThenMint() public  {
        // 1. Initiate a flash swap (borrow tokens, execute callback)
        // 2. Inside callback or right after, Mint new liquidity
        // 3. Repay flash swap
        // 4. Assert K
    }

    function test_Sequence_MultipleSwaps() public f_lp {


(uint112 rev0, uint112 rev1,) = pair.getReserves();
uint256 _klas = pair.kLast();
 uint256 amountOut= 1330663997;
address t_user = makeAddr("testUser");


//swap prank
vm.startPrank(player);




//token1.transfer(address(pair), 1 ether);

//pair.swap(1330667, 0, t_user, "");

token1.transfer(address(pair), 1 ether);
 uint256 amountG = getAmountOut(1 ether, rev1, rev0);


pair.swap(amountG, 0, t_user, "");
vm.stopPrank();
token0.balanceOf(t_user);
(uint112 reev0, uint112 reev1,) = pair.getReserves();
assert((reev0 * reev1) >= _klas);


   



    }

















 function test_Twap() public {
   

vm.startPrank(user);

token0.transfer(address(pair), 20_000e6);
token1.transfer(address(pair), 10e18);

pair.mint(user);

vm.stopPrank();

(uint112 rev0_, uint112 rev1_,) = pair.getReserves();


//swap prank
vm.startPrank(player);




//token1.transfer(address(pair), 1 ether);

//pair.swap(1330667, 0, t_user, "");

token1.transfer(address(pair), 1 ether);
 uint256 amountGG = getAmountOut(1 ether, rev1_, rev0_);


pair.swap(amountGG, 0, user, "");
vm.stopPrank();













(uint112 rev0, uint112 rev1,) = pair.getReserves();
console.log("revser0 before swap",rev0, "Reserve 1 before swap", rev1);

uint256 priceMove0;
uint256 priceMove1;
address t_player = makeAddr("t_player");

vm.startPrank(player);
vm.warp(block.timestamp + 60);
vm.roll(100);





token1.transfer(address(pair), 9 ether);
 uint256 amountG = getAmountOut(9 ether, rev1, rev0);


pair.swap(amountG, 0, t_player, "");
priceMove0  = pair.price0CumulativeLast();
priceMove1 = pair.price1CumulativeLast();
(uint112 rev00, uint112 rev11,) = pair.getReserves();
console.log("revser0 after swap",rev00, "Reserve 1 after swap", rev11);


 uint256 amountJ = getAmountOut(token0.balanceOf(t_player), rev00, rev11);
 console.log("amountJ", amountJ);
token0.transfer(address(pair), token0.balanceOf(t_player));
pair.swap(0, amountJ, t_player, "");
(uint112 rev000, uint112 rev111,) = pair.getReserves();
console.log("revser0 after swap",rev000, "Reserve 1 after swap", rev111);


 

 vm.stopPrank();

uint256 currentPriceAccumulator0 = pair.price0CumulativeLast();
uint256 currentPriceAccumulator1 = pair.price1CumulativeLast();

console.log("currentPriceAccumulator0", currentPriceAccumulator0);
console.log("currentPriceAccumulator1", currentPriceAccumulator1);



assertEq(priceMove0, currentPriceAccumulator0);
assertEq(priceMove1, currentPriceAccumulator1);
 



 
 }  
}































contract TFlashSwap{
IUniswapV2Pair pair;
IUniswapV2ERC20 token1;

constructor(address _pair,address _token1){

pair = IUniswapV2Pair(_pair);
token1 = IUniswapV2ERC20(_token1);

}


 function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external{

if(amount0 > 1000e6){
token1.transfer(address(pair), 1e18);
}else{
  token1.transfer(address(pair), 1);
}
    


 }

}