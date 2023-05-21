// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISimpleSwap } from "./interface/ISimpleSwap.sol";
import { IERC20 } from "./interface/IERC20.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import "forge-std/Test.sol";

contract SimpleSwap is ISimpleSwap, ERC20 {

    address public _tokenA;
    address public _tokenB;

    uint112 private _reserveA;          
    uint112 private _reserveB;           
    ERC20 instance_tokenA;
    ERC20 instance_tokenB;

    // Implement core logic here
    constructor(address tokenA, address tokenB) ERC20("SimpleSwap", "sw") {
        require(isContract(tokenA), "SimpleSwap: TOKENA_IS_NOT_CONTRACT");
        require(isContract(tokenB), "SimpleSwap: TOKENB_IS_NOT_CONTRACT");
        require(tokenA != tokenB, "SimpleSwap: TOKENA_TOKENB_IDENTICAL_ADDRESS");
        (_tokenA, _tokenB) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA); 
        instance_tokenA = ERC20(_tokenA);
        instance_tokenB = ERC20(_tokenB);
    }

    function isContract(address _addr) public view returns (bool) {
        return _addr.code.length > 0;
    }

       
    function swap(address tokenIn, address tokenOut, uint256 amountIn) external returns (uint256 amountOut) {
        require(( (tokenIn == _tokenA) || (tokenIn == _tokenB) ) , "SimpleSwap: INVALID_TOKEN_IN");
        require(( (tokenOut == _tokenA) || (tokenOut == _tokenB) ) , "SimpleSwap: INVALID_TOKEN_OUT");
        require( (tokenIn != tokenOut) , "SimpleSwap: IDENTICAL_ADDRESS");
        require(amountIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");

        // (_reserveA * _reserveB) = (_reserveA + amountIn) * (_reserveB - amountOut)
        // (_reserveA * _reserveB) / (_reserveA + amountIn) = (_reserveB - amountOut)
        // amountOut = _reserveB - (_reserveA * _reserveB) / (_reserveA + amountIn)
        // amountOut * _reserveA + amountOut * amountIn =  _reserveB * amountIn
        // amountOut (_reserveA + amountIn) = _reserveB * amountIn
        // amountOut = (_reserveB * amountIn) / (_reserveA + amountIn)

        if((tokenIn == _tokenA) && (tokenOut == _tokenB)) {
            amountOut = (_reserveB * amountIn) / (_reserveA + amountIn);
            IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
            IERC20(tokenOut).transfer(msg.sender, amountOut);
            _reserveA += uint112(amountIn);
            _reserveB -= uint112(amountOut);
            emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);

        } else if ((tokenIn == _tokenB) && (tokenOut == _tokenA)) {
            amountOut = (_reserveA * amountIn) / (_reserveB + amountIn);
            IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
            IERC20(tokenOut).transfer(msg.sender, amountOut);
            _reserveB += uint112(amountIn);
            _reserveA -= uint112(amountOut);
            emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
        } 
    }

    function addLiquidity(
        uint256 amountAIn,
        uint256 amountBIn
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        require(amountAIn > 0 , "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");
        require(amountBIn > 0 , "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");
        uint totalSupplyLP = totalSupply();
        if (totalSupplyLP == 0) {
            liquidity = Math.sqrt(amountAIn * amountBIn);

            amountA = amountAIn;
            amountB = amountBIn;

            instance_tokenA.transferFrom(msg.sender, address(this), amountAIn);
            instance_tokenB.transferFrom(msg.sender, address(this), amountBIn);

            _reserveA += uint112(amountA);
            _reserveB += uint112(amountB);

            _mint(msg.sender, liquidity);
            emit AddLiquidity(msg.sender, amountAIn, amountBIn, liquidity);
        } else {

            liquidity = Math.min((amountAIn * totalSupplyLP) / _reserveA, (amountBIn * totalSupplyLP) / _reserveB);

            amountA = (liquidity * _reserveA) / totalSupplyLP;
            amountB = (liquidity * _reserveB) / totalSupplyLP;

            instance_tokenA.transferFrom(msg.sender, address(this), amountA);
            instance_tokenB.transferFrom(msg.sender, address(this), amountB);

            _reserveA += uint112(amountA);
            _reserveB += uint112(amountB);

            _mint(msg.sender, liquidity);
            emit AddLiquidity(msg.sender, amountA, amountB, liquidity);
        }
        

    }


    function removeLiquidity(uint256 liquidity) external returns (uint256 amountA, uint256 amountB) {
        require(liquidity > 0 , "SimpleSwap: INSUFFICIENT_LIQUIDITY_BURNED");
        uint totalSupplyLP = totalSupply();

        amountA = (liquidity * _reserveA) / totalSupplyLP;
        amountB = (liquidity * _reserveB) / totalSupplyLP;
        instance_tokenA.transfer(msg.sender, amountA);
        instance_tokenB.transfer(msg.sender, amountB);

        _burn(msg.sender, liquidity);
        emit Transfer(address(this), address(0), liquidity);
        emit RemoveLiquidity(msg.sender, amountA, amountB, liquidity);
    }


    function getReserves() external view returns (uint256 reserveA, uint256 reserveB) {
        return (_reserveA, _reserveB);
    }


    function getTokenA() external view returns (address tokenA) {
        return _tokenA;
    }


    function getTokenB() external view returns (address tokenB) {
        return _tokenB;
    }
    

}