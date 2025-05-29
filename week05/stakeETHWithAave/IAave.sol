// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IAave 接口
 * @notice 定义与 Aave 协议交互所需的接口
 */

/**
 * @dev Aave 借贷池接口，用于存款和取款
 */
interface ILendingPool {
    /**
     * @dev 向 Aave 存入资产
     * @param asset 要存入的资产地址
     * @param amount 存入的数量
     * @param onBehalfOf 存款将计入的地址
     * @param referralCode 推荐码，0表示无推荐
     */
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;
    
    /**
     * @dev 从 Aave 中取出资产
     * @param asset 要取出的资产地址
     * @param amount 取出的数量
     * @param to 接收资产的地址
     * @return 实际取出的数量
     */
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);

    /**
     * @dev 获取用户账户数据
     * @param user 用户地址
     * @return totalCollateralETH 用户的总抵押品价值(ETH)
     * @return totalDebtETH 用户的总债务(ETH)
     * @return availableBorrowsETH 用户可借款额度(ETH)
     * @return currentLiquidationThreshold 当前清算阈值
     * @return ltv 贷款价值比率
     * @return healthFactor 健康因子
     */
    function getUserAccountData(address user) 
        external 
        view 
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
}

/**
 * @dev Aave WETH网关接口，用于ETH存款和取款
 */
interface IWETHGateway {
    /**
     * @dev 存入ETH到Aave
     * @param lendingPool Aave借贷池地址
     * @param onBehalfOf 存款将计入的地址
     * @param referralCode 推荐码
     */
    function depositETH(
        address lendingPool,
        address onBehalfOf,
        uint16 referralCode
    ) external payable;
    
    /**
     * @dev 从Aave取出ETH
     * @param lendingPool Aave借贷池地址
     * @param amount 取出的数量
     * @param to 接收ETH的地址
     */
    function withdrawETH(
        address lendingPool,
        uint256 amount,
        address to
    ) external;
}

/**
 * @dev aWETH代币接口，表示在Aave上存入的ETH获得的利息代币
 */
interface IAToken {
    /**
     * @dev 获取代币余额
     * @param account 账户地址
     * @return 代币余额
     */
    function balanceOf(address account) external view returns (uint256);
    
    /**
     * @dev 转移代币
     * @param recipient 接收者地址
     * @param amount 转移数量
     * @return 是否成功
     */
    function transfer(address recipient, uint256 amount) external returns (bool);
    
    /**
     * @dev 批准代币使用额度
     * @param spender 被批准者地址
     * @param amount 批准数量
     * @return 是否成功
     */
    function approve(address spender, uint256 amount) external returns (bool);
    
    /**
     * @dev 获取允许使用的代币数量
     * @param owner 持有者地址
     * @param spender 使用者地址
     * @return 允许使用的数量
     */
    function allowance(address owner, address spender) external view returns (uint256);
} 