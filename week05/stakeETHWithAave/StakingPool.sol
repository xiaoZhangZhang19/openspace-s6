// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "forge-std/console.sol";
import "./KKToken.sol";
import "./IAave.sol";

/**
 * @title Staking Interface
 */
interface IStaking {
    /**
     * @dev 质押 ETH 到合约
     */
    function stake() payable external;

    /**
     * @dev 赎回质押的 ETH
     * @param amount 赎回数量
     */
    function unstake(uint256 amount) external; 

    /**
     * @dev 领取 KK Token 收益
     */
    function claim() external;

    /**
     * @dev 获取质押的 ETH 数量
     * @param account 质押账户
     * @return 质押的 ETH 数量
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev 获取待领取的 KK Token 收益
     * @param account 质押账户
     * @return 待领取的 KK Token 收益
     */
    function earned(address account) external view returns (uint256);
}

/**
 * @title StakingPool - ETH 质押池
 * @notice 允许用户质押 ETH 获取 KK Token 奖励，并将质押的 ETH 存入 Aave 借贷市场获取额外收益
 */
contract StakingPool is IStaking, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC20 for IAToken;

    // KK Token 合约
    KKToken public immutable kkToken;
    
    // Aave 的 WETH 网关合约，用于 ETH 存取
    IWETHGateway public immutable wethGateway;
    
    // Aave 的借贷池合约
    ILendingPool public immutable lendingPool;
    
    // aWETH 代币合约，表示在 Aave 中存入的 ETH
    IAToken public immutable aWETH;
    
    // WETH 地址，用于与 Aave 交互
    address public immutable WETH_ADDRESS;
    
    // 每区块产出的 KK Token 数量
    uint256 public constant REWARD_PER_BLOCK = 10 * 1e18;
    
    // 最近更新奖励的区块
    uint256 public lastUpdateBlock;
    
    // 每单位质押可获取的累计奖励
    uint256 public rewardPerTokenStored;
    
    // 用户已结算的每单位奖励
    mapping(address => uint256) public userRewardPerTokenPaid;
    
    // 用户已获得但未领取的奖励
    mapping(address => uint256) public rewards;
    
    // 用户质押的 ETH 数量
    mapping(address => uint256) public stakes;
    
    // 总质押量
    uint256 public totalStaked;
    
    // 用户最后一次质押或领取奖励的时间（用于计算质押时长）
    mapping(address => uint256) public lastStakeTime;

    /**
     * @notice 构造函数
     * @param _kkToken KK Token 合约地址
     * @param _wethGateway Aave WETH网关地址
     * @param _lendingPool Aave借贷池地址
     * @param _aWETH aWETH代币地址
     * @param _wethAddress WETH代币地址
     */
    constructor(
        address _kkToken, 
        address _wethGateway, 
        address _lendingPool, 
        address _aWETH,
        address _wethAddress
    ) Ownable(msg.sender) {
        kkToken = KKToken(_kkToken);
        wethGateway = IWETHGateway(_wethGateway);
        lendingPool = ILendingPool(_lendingPool);
        aWETH = IAToken(_aWETH);
        WETH_ADDRESS = _wethAddress;
        lastUpdateBlock = block.number;
    }

    /**
     * @notice 更新奖励状态
     * @dev 在每次质押、取回、领取操作前调用
     */
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateBlock = block.number;
        
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /**
     * @notice 计算每单位质押的累计奖励
     * @return 累计奖励（按 1e18 缩放）
     */
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        
        return rewardPerTokenStored + (
            (block.number - lastUpdateBlock) * REWARD_PER_BLOCK * 1e18 / totalStaked
        );
    }

    /**
     * @notice 获取用户已赚取但未领取的 KK Token 数量
     * @param account 用户地址
     * @return 未领取的奖励数量
     */
    function earned(address account) public view override returns (uint256) {
        uint256 stakedAmount = stakes[account];
        uint256 stakeDuration = block.timestamp - lastStakeTime[account];
        
        // 根据质押数量和时长计算奖励，时长越长权重越大
        uint256 durationWeight = (stakeDuration * 1e18) / 1 days + 1e18; // 最小权重为1
        
        return rewards[account] + (
            stakedAmount * (rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18
        ) * durationWeight / 1e18;
    }

    /**
     * @notice 质押 ETH 到合约
     * @dev 将 ETH 质押并存入 Aave 借贷池获取利息
     */
    function stake() external payable override updateReward(msg.sender) nonReentrant {
        require(msg.value > 0, "Cannot stake 0");
        
        // 更新用户质押记录
        stakes[msg.sender] += msg.value;
        totalStaked += msg.value;
        
        // 更新质押时间
        lastStakeTime[msg.sender] = block.timestamp;
        
        // 检查 aWETH 余额
        uint256 aWETHBalanceBefore = aWETH.balanceOf(address(this));
        
        // 将 ETH 存入 Aave 借贷池赚取利息
        wethGateway.depositETH{value: msg.value}(
            address(lendingPool),
            address(this),
            0 // 无推荐码
        );
        
        // 确认 aWETH 余额增加
        uint256 aWETHBalanceAfter = aWETH.balanceOf(address(this));
        require(aWETHBalanceAfter > aWETHBalanceBefore, "No aWETH received");
        
        emit Staked(msg.sender, msg.value);
    }

    /**
     * @notice 赎回质押的 ETH
     * @param amount 赎回数量
     */
    function unstake(uint256 amount) external override updateReward(msg.sender) nonReentrant {
        require(amount > 0, "Cannot withdraw 0");
        require(stakes[msg.sender] >= amount, "Not enough staked");
        
        // 检查合约是否有足够的 aWETH 余额
        uint256 aWethBalance = aWETH.balanceOf(address(this));
        if (aWethBalance < amount) {
            // 如果 aWETH 余额不足，调整取回数量为可用余额
            console.log("Not enough aWETH balance. Requested:", amount, "Available:", aWethBalance);
            
            // 更新用户质押记录
            stakes[msg.sender] -= amount;
            totalStaked = totalStaked > amount ? totalStaked - amount : 0;
            
            // 如果没有可用余额，直接返回，但已更新了用户质押记录
            if (aWethBalance == 0) {
                console.log("No aWETH available to withdraw, but updated user stake record");
                emit Unstaked(msg.sender, 0);
                return;
            }
            
            amount = aWethBalance;
        } else {
            // 更新用户质押记录 - 先记录，确保先减少用户余额防止重入攻击
            stakes[msg.sender] -= amount;
            totalStaked -= amount;
        }
        
        // 记录赎回前的 ETH 余额
        uint256 balanceBefore = address(this).balance;
        
        // 确保 aWETH 有足够的批准额度
        aWETH.approve(address(wethGateway), amount);
        
        // 从 Aave 赎回 ETH
        wethGateway.withdrawETH(
            address(lendingPool),
            amount,
            address(this)
        );
        
        // 计算实际获得的 ETH 数量
        uint256 actualAmount = address(this).balance - balanceBefore;
        
        // 确保能够赎回一定数量的 ETH
        require(actualAmount > 0, "No ETH redeemed");
        
        // 如果实际获得的 ETH 少于请求的数量，调整用户记录
        if (actualAmount < amount) {
            uint256 diff = amount - actualAmount;
            stakes[msg.sender] += diff;
            totalStaked += diff;
        }
        
        // 转账实际获得的 ETH 给用户
        (bool success, ) = payable(msg.sender).call{value: actualAmount}("");
        require(success, "ETH transfer failed");
        
        emit Unstaked(msg.sender, actualAmount);
    }

    /**
     * @notice 领取 KK Token 奖励
     */
    function claim() external override updateReward(msg.sender) nonReentrant {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            kkToken.mint(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    /**
     * @notice 获取用户质押的 ETH 数量
     * @param account 用户地址
     * @return 质押的 ETH 数量
     */
    function balanceOf(address account) external view override returns (uint256) {
        return stakes[account];
    }

    /**
     * @notice 获取合约 ETH 余额
     * @return 合约当前 ETH 余额
     */
    function getContractETHBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice 获取合约在 Aave 中的 aWETH 余额
     * @return aWETH 余额
     */
    function getAWethBalance() external view returns (uint256) {
        return aWETH.balanceOf(address(this));
    }

    /**
     * @notice 紧急提款函数，仅所有者可调用
     * @dev 用于紧急情况下从 Aave 提取所有资金
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 aWethBalance = aWETH.balanceOf(address(this));
        if (aWethBalance > 0) {
            // 确保有足够的批准额度
            aWETH.approve(address(wethGateway), aWethBalance);
            
            // 从 Aave 提取所有 ETH
            wethGateway.withdrawETH(
                address(lendingPool),
                type(uint256).max, // 提取全部
                address(this)
            );
            
            // 更新总质押量，因为所有资金已经从 Aave 提取
            console.log("Emergency withdraw: resetting total staked from", totalStaked, "to 0");
            
            // 记录紧急提款事件，通知用户
            emit EmergencyWithdraw(totalStaked);
            
            // 重置总质押量
            totalStaked = 0;
        }
        
        // 提取所有 ETH 到合约拥有者
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            (bool success, ) = payable(owner()).call{value: ethBalance}("");
            require(success, "ETH transfer failed");
        }
    }

    /**
     * @notice 接收 ETH 函数
     */
    receive() external payable {}

    // 事件
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event EmergencyWithdraw(uint256 totalAmount);
} 