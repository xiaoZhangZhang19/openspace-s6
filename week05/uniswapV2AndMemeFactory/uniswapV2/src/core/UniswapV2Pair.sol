// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import '../interfaces/IUniswapV2Pair.sol';
import './UniswapV2ERC20.sol';
import '../libraries/Math.sol';
import '../libraries/UQ112x112.sol';
import '../interfaces/IERC20.sol';
import '../interfaces/IUniswapV2Factory.sol';
import '../interfaces/IUniswapV2Callee.sol';

/**
 * @title UniswapV2Pair
 * @dev 交易对合约，实现了Uniswap V2的核心交易逻辑
 * 管理两种代币的流动性池，并提供交换功能
 */
contract UniswapV2Pair is IUniswapV2Pair, UniswapV2ERC20 {
    using SafeMath for uint;
    using UQ112x112 for uint224;

    // 最小流动性，永久锁定在合约中，防止首次流动性提供者拥有过高比例
    uint public constant MINIMUM_LIQUIDITY = 10**3;
    // transfer函数的选择器，用于低级调用
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    // 创建此交易对的工厂合约地址
    address public factory;
    // 交易对中的第一个代币地址（按地址排序）
    address public token0;
    // 交易对中的第二个代币地址（按地址排序）
    address public token1;

    // 代币0的储备量，使用uint112以优化存储
    uint112 private reserve0;
    // 代币1的储备量，使用uint112以优化存储
    uint112 private reserve1;
    // 最后一次更新储备量的区块时间戳
    uint32 private blockTimestampLast;

    // 代币0的累积价格，用于价格预言机
    uint public price0CumulativeLast;
    // 代币1的累积价格，用于价格预言机
    uint public price1CumulativeLast;
    // 最后一次流动性事件后的k值（reserve0 * reserve1）
    uint public kLast;

    // 重入锁状态变量
    uint private unlocked = 1;
    
    /**
     * @dev 防止重入攻击的修饰符
     */
    modifier lock() {
        require(unlocked == 1, 'UniswapV2: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    /**
     * @dev 获取当前储备量和最后更新时间戳
     * @return _reserve0 代币0的储备量
     * @return _reserve1 代币1的储备量
     * @return _blockTimestampLast 最后更新时间戳
     * 这是一个视图函数，外部合约可以用来查询当前池状态
     */
    function getReserves() public view override returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    /**
     * @dev 安全转账函数，处理非标准ERC20代币
     * @param token 代币地址
     * @param to 接收地址
     * @param value 转账金额
     * 使用低级call调用，兼容不同的ERC20实现
     * 但有些代币（如早期的 USDT）可能不返回任何值。所以这里有处理返回值为空或布尔值的情况
     */
    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'UniswapV2: TRANSFER_FAILED');
    }

    // 事件在接口中已定义，这里不再重复定义

    /**
     * @dev 构造函数，设置工厂合约地址
     */
    constructor() {
        factory = msg.sender;
    }

    /**
     * @dev 初始化交易对，只能由工厂合约调用一次
     * @param _token0 代币0地址
     * @param _token1 代币1地址
     * 只能由工厂合约调用，且只能调用一次
     * 只能调用一次实现的方式是factory只会在初始化的时候调用，其余用户没法执行这个方法，变相的控制只能执行一次
     */
    function initialize(address _token0, address _token1) external override {
        require(msg.sender == factory, 'UniswapV2: FORBIDDEN');
        token0 = _token0;
        token1 = _token1;
    }

    /**
     * @dev 更新储备量和价格累积器
     * @param balance0 代币0的当前余额
     * @param balance1 代币1的当前余额
     * @param _reserve0 代币0的旧储备量
     * @param _reserve1 代币1的旧储备量
     */
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        // 确保余额不会溢出uint112
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, 'UniswapV2: OVERFLOW');
        
        // 获取当前区块时间戳，并计算经过的时间
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // 溢出是预期行为
        
        // 如果时间已经过去且储备量不为零，更新价格累积器
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // 累积价格 = 旧累积价格 + (当前价格 * 经过时间)
            // 使用UQ112x112定点数格式计算价格并累加
            // 价格 = 对方储备量 / 本方储备量
            // 乘以时间间隔得到时间加权价格
            // 将_reserve1改为高精度的定点数，比如5.5通过UQ112x112.encode(5.5) 等于 5 * 2**112
            // 用一个高精度的定点数（UQ112x112 格式）除以一个普通整数，得到一个新的高精度定点数。
            // price0CumulativeLast 和 price1CumulativeLast 在uniswap中不会被使用到，主要是给外界提供一个查询，这样做的原因是防止一些闪电贷的攻击等
            price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        
        // 更新储备量和时间戳
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        
        emit Sync(reserve0, reserve1);
    }

    /**
     * @dev 计算并铸造协议费用（如果启用）
     * @param _reserve0 代币0的储备量
     * @param _reserve1 代币1的储备量
     * @return feeOn 是否启用协议费
     * 协议费用机制：
     * 1. 如果开启协议费用（feeTo地址不为0），计算应收费用
     * 2. 费用为流动性增长的1/6（即总手续费的1/6）
     * 3. 费用以LP代币形式铸造给feeTo地址
     * 4. 使用sqrt(k)的增长来计算费用，确保公平性
     */
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        // 检查工厂合约中的feeTo地址
        address feeTo = IUniswapV2Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint _kLast = kLast; // 节省gas
        
        // 如果启用了协议费且kLast不为零
        if (feeOn) {
            if (_kLast != 0) {
                // 计算当前k值的平方根
                uint rootK = Math.sqrt(uint(_reserve0).mul(_reserve1));
                // 计算上次k值的平方根
                uint rootKLast = Math.sqrt(_kLast);
                
                // 如果k值增加了（流动性增加）
                if (rootK > rootKLast) {
                    // 计算应该铸造的流动性代币数量
                    // 公式: L * (√(k) - √(kLast)) / (5 * √(k) + √(kLast))
                    uint numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint denominator = rootK.mul(5).add(rootKLast);
                    uint liquidity = numerator / denominator;
                    
                    // 铸造流动性代币给feeTo地址
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            // 如果协议费被禁用，重置kLast
            kLast = 0;
        }
    }

    /**
     * @dev 添加流动性并铸造流动性代币
     * @param to 接收流动性代币的地址
     * @return liquidity 铸造的流动性代币数量
     * 流动性添加机制：
     * 1. 计算用户新增的代币数量（当前余额 - 储备量）
     * 2. 如果是首次添加流动性，使用几何平均数计算LP代币
     * 3. 如果不是首次，按比例计算LP代币数量
     * 4. 锁定最小流动性以防止攻击
     * 5. 更新储备量和k值
     */
    function mint(address to) external lock override returns (uint liquidity) {
        // 获取当前储备量
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        
        // 获取合约中的代币余额
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        
        // 计算添加的代币数量
        uint amount0 = balance0.sub(_reserve0);
        uint amount1 = balance1.sub(_reserve1);

        // 计算并铸造协议费（如果启用）
        bool feeOn = _mintFee(_reserve0, _reserve1);
        // 获取当前总供应量（必须在_mintFee之后，因为如果流动性增加了会通胀一部分LP Token作为手续费给到项目当，那么可能会更新totalSupply）
        uint _totalSupply = totalSupply; // 节省gas
        
        // 首次添加流动性的特殊处理
        if (_totalSupply == 0) {
            // 铸造的流动性代币 = sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY
            // 首次添加流动性的情况
            // 使用几何平均数计算初始流动性，减去最小流动性防止攻击
            // 因为 x*y=K（乘积恒定），所有当你往池子里加两种 token 时，合理的流动性衡量方式就是：L = sqrt(x * y)
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
            // 永久锁定最小流动性
            // 将最小流动性永久锁定在零地址，（防止总供应量为0的攻击，防止项目方作恶或者第一次添加流动性的人作恶）
            // 如果流动性为0以后，那么用户添加流动性时可能存在被作恶导致获取不到合适的LP Token，从而造成损失
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            // 铸造的流动性代币 = min(amount0 * totalSupply / reserve0, amount1 * totalSupply / reserve1)
            // 后续添加流动性的情况
            // 按照较小的比例计算LP代币数量，确保不会稀释现有流动性提供者
            liquidity = Math.min(
                amount0.mul(_totalSupply) / _reserve0,
                amount1.mul(_totalSupply) / _reserve1
            );
        }
        
        // 确保铸造的流动性代币数量大于0
        require(liquidity > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED');
        
        // 铸造流动性代币给接收者
        _mint(to, liquidity);

        // 更新储备量
        _update(balance0, balance1, _reserve0, _reserve1);
        
        // 如果启用了协议费，更新kLast
        if (feeOn) kLast = uint(reserve0).mul(reserve1);
        
        emit Mint(msg.sender, amount0, amount1);
    }

    /**
     * @dev 销毁流动性代币并返还代币
     * @param to 接收代币的地址
     * @return amount0 返还的代币0数量
     * @return amount1 返还的代币1数量
     * 流动性移除机制：
     * 1. 获取合约持有的LP代币数量（用户需要先转入）
     * 2. 按LP代币占总供应量的比例计算应返还的代币数量
     * 3. 销毁LP代币
     * 4. 转账代币给用户
     * 5. 更新储备量
     * 
     * 注意：调用前需要先将LP代币转入合约
     */
    function burn(address to) external lock override returns (uint amount0, uint amount1) {
        // 获取当前储备量
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        address _token0 = token0; // 节省gas
        address _token1 = token1; // 节省gas
        
        // 获取合约中的代币余额
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        
        // 获取合约中持有的流动性代币数量
        // 通过网关合约实现用户转入token的数量等于Pair合约地址的LP Token数量
        uint liquidity = balanceOf[address(this)];

        // 计算并铸造协议费（如果启用）
        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // 节省gas
        
        // 按比例计算应返还的代币数量
        // 使用当前余额而非储备量，确保包含任何意外转入的代币
        amount0 = liquidity.mul(balance0) / _totalSupply;
        amount1 = liquidity.mul(balance1) / _totalSupply;
        
        // 确保返还的代币数量大于0
        require(amount0 > 0 && amount1 > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED');
        
        // 销毁流动性代币
        _burn(address(this), liquidity);
        
        // 转账代币给接收者
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        
        // 更新合约中的代币余额
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        // 更新储备量
        _update(balance0, balance1, _reserve0, _reserve1);
        
        // 如果启用了协议费，更新kLast
        if (feeOn) kLast = uint(reserve0).mul(reserve1);
        
        emit Burn(msg.sender, amount0, amount1, to);
    }

    /**
     * @dev 交换代币
     * @param amount0Out 输出的代币0数量
     * @param amount1Out 输出的代币1数量
     * @param to 接收代币的地址
     * @param data 回调数据
     * 交换机制：
     * 1. 验证输出参数的有效性
     * 2. 检查流动性是否充足
     * 3. 乐观转账（先转账再验证）
     * 4. 如果有回调数据，执行闪电贷回调
     * 5. 计算输入数量并验证K不变性
     * 6. 扣除0.3%手续费
     * 7. 更新储备量
     * 
     * 恒定乘积公式：(x + Δx * 0.997) * (y - Δy) ≥ x * y
     */
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock override {
        // 确保至少有一种代币输出
        require(amount0Out > 0 || amount1Out > 0, 'UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT');
        
        // 获取当前储备量
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        
        // 确保输出数量小于储备量
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'UniswapV2: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;
        { // 作用域以避免堆栈过深错误
            address _token0 = token0;
            address _token1 = token1;
            
            // 确保接收者不是代币地址
            require(to != _token0 && to != _token1, 'UniswapV2: INVALID_TO');
            
            // 乐观转账代币给接收者
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
            
            // 如果有回调数据，调用接收者的uniswapV2Call函数
            if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
            
            // 获取合约中的代币余额
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }
        
        // 计算输入的代币数量
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        
        // 确保至少有一种代币输入
        require(amount0In > 0 || amount1In > 0, 'UniswapV2: INSUFFICIENT_INPUT_AMOUNT');
        
        { // 作用域以避免堆栈过深错误
            // 应用交易手续费(0.3%)后的余额
            uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
            uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
            
            // 验证交易后的k值不小于交易前的k值
            require(
                balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000**2),
                'UniswapV2: K'
            );
        }

        // 更新储备量
        _update(balance0, balance1, _reserve0, _reserve1);
        
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /**
     * @dev 将超额代币转移出合约
     * @param to 接收代币的地址
     * 将合约余额中超过储备量的部分转给指定地址
     * 用于处理意外转入的代币或捐赠
     */
    function skim(address to) external lock override {
        address _token0 = token0; // 节省gas
        address _token1 = token1; // 节省gas
        
        // 转移超过储备量的代币
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)).sub(reserve0));
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)).sub(reserve1));
    }

    /**
     * @dev 强制使储备量与当前余额匹配
     * 用于处理代币余额与储备量不匹配的情况
     * 通常在发生代币转账错误或攻击后使用
     */
    function sync() external lock override {
        // 更新储备量为当前余额
        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this)),
            reserve0,
            reserve1
        );
    }
} 