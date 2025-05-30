// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {SimpleLeverageDEX} from "../../src/vAMMDEX/SimpleLeverageDEX.sol";

contract DeploySimpleLeverageDEX is Script {
    function run() external returns (SimpleLeverageDEX) {
        // 读取环境变量或使用默认值
        address collateralToken = vm.envOr("COLLATERAL_TOKEN", address(0x6B175474E89094C44Da98b954EedeAC495271d0F)); // DAI默认地址
        uint256 initialPrice = vm.envOr("INITIAL_PRICE", uint256(1000 * 1e18)); // 初始价格1000
        uint256 vammReserveX = vm.envOr("VAMM_RESERVE_X", uint256(1000000 * 1e18)); // 初始X储备
        uint256 openFee = vm.envOr("OPEN_FEE", uint256(10)); // 0.1%开仓手续费
        uint256 closeFee = vm.envOr("CLOSE_FEE", uint256(10)); // 0.1%平仓手续费
        uint256 liquidationThreshold = vm.envOr("LIQUIDATION_THRESHOLD", uint256(8000)); // 80%清算阈值
        uint256 maxLeverage = vm.envOr("MAX_LEVERAGE", uint256(10)); // 最大10倍杠杆
        
        vm.startBroadcast();
        SimpleLeverageDEX dex = new SimpleLeverageDEX(
            collateralToken,
            initialPrice,
            vammReserveX,
            openFee,
            closeFee,
            liquidationThreshold,
            maxLeverage
        );
        vm.stopBroadcast();
        
        return dex;
    }
} 