/**
 *Submitted for verification at BscScan.com on 2022-01-20
*/

pragma solidity ^0.8.5;
// SPDX-License-Identifier: MIT

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }
    
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }
}

/**
 * BEP20 standard interface.
 */
interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getOwner() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


abstract contract Auth {
    address internal owner;

    constructor(address _owner) {
        owner = _owner;
    }

    /**
     * Function modifier to require caller to be contract owner
     */
    modifier onlyOwner() {
        require(isOwner(msg.sender), "!OWNER"); _;
    }

    /**
     * Check if address is owner
     */
    function isOwner(address account) public view returns (bool) {
        return account == owner;
    }

    /**
     * Transfer ownership to new address. Caller must be owner
     */
    function transferOwnership(address payable adr) public onlyOwner {
        require(adr !=  address(0),  "adr is a zero address");
        owner = adr;
        emit OwnershipTransferred(adr);
    }

    event OwnershipTransferred(address owner);
}

interface IDEXFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IDEXRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract Label2Earn is IBEP20, Auth {
    using SafeMath for uint256;

    address private WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address private DEAD = 0x000000000000000000000000000000000000dEaD;

    address public REWARD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address public PANCAKE_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

    string constant _name = "Label2Earn";
    string constant _symbol = "L2E";
    uint8 constant _decimals = 18;

    uint256 _totalSupply = 256000000 * (10 ** _decimals);
   
    uint256 public _maxTxAmount = (_totalSupply * 10) / 1000;
    uint256 public _maxWalletSize = (_totalSupply * 30) / 1000; 

    mapping (address => uint256) _balances;
    mapping (address => mapping (address => uint256)) _allowances;

    mapping (address => bool) isFeeExempt;
    mapping (address => bool) isTxLimitExempt;

    uint256 public liquidityFeeSell = 3;
    uint256 public marketingFeeSell = 3;
    uint256 public burnFeeSell = 1;
    uint256 public totalFeeSell = 7;
    uint256 public buyAndTransferFee = 3;

    uint256 public liqamount = 0;

    mapping(address => bool) public _isBlacklisted;
    
    address private marketingFeeReceiver = 0xbD4d2bFC985Ec6dE018cE91D1850bcCb6E5b85A7;

    IDEXRouter public router;
    address public pair;

    bool public swapEnabled = true;

    uint256 public swapThreshold = 640000 * (10 ** _decimals); // 0.25%

    bool inSwap;

    modifier swapping() { inSwap = true; _; inSwap = false; }

    constructor () Auth(msg.sender) {
        router = IDEXRouter(PANCAKE_ROUTER);
        pair = IDEXFactory(router.factory()).createPair(WBNB, address(this));
        _allowances[address(this)][address(router)] = type(uint256).max;

        address _owner = owner;
        isFeeExempt[_owner] = true;
        isFeeExempt[address(this)] = true;
        isTxLimitExempt[_owner] = true;
        isTxLimitExempt[address(this)] = true;
        
        _balances[_owner] = _totalSupply;

        emit Transfer(address(0), _owner, _totalSupply);        
    }

    receive() external payable { }

    function totalSupply() external view override returns (uint256) { return _totalSupply; }
    function decimals() external pure override returns (uint8) { return _decimals; }
    function symbol() external pure override returns (string memory) { return _symbol; }
    function name() external pure override returns (string memory) { return _name; }
    function getOwner() external view override returns (address) { return owner; }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }
    function allowance(address holder, address spender) external view override returns (uint256) { return _allowances[holder][spender]; }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function approveMax(address spender) external returns (bool) {
        return approve(spender, type(uint256).max);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        if(_allowances[sender][msg.sender] != type(uint256).max){
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender].sub(amount, "Insufficient Allowance");
        }
        return _transferFrom(sender, recipient, amount);
    }

    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        require(!_isBlacklisted[sender] && !_isBlacklisted[recipient], 'Blacklisted address');
        if(inSwap){ return _basicTransfer(sender, recipient, amount); }
        
        checkTxLimit(sender, amount);

        if (recipient != pair && recipient != DEAD && recipient != owner && recipient != marketingFeeReceiver) {
            require(isTxLimitExempt[recipient] || _balances[recipient] + amount < _maxWalletSize, "Transfer amount exceeds the bag size.");
        }
    
        if(shouldSwapBack()){ swapBack(); }

        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");

        uint256 amountReceived = shouldTakeFee(sender) ? takeFee(sender, recipient, amount) : amount;
        _balances[recipient] = _balances[recipient].add(amountReceived);

        emit Transfer(sender, recipient, amountReceived);
        return true;
    }
    
    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
        return true;
    }
    
    function shouldTakeFee(address sender) internal view returns (bool) {
        return !isFeeExempt[sender];
    }
    
    function takeFee(address sender, address receiver, uint256 amount) internal returns (uint256) {
        if(receiver == pair) {
            uint256 feeAmount = amount.mul(totalFeeSell).div(100);
            if(totalFeeSell > 0){
                uint256 burnAmount = 0; 
                if(burnFeeSell > 0){
                    burnAmount = amount.mul(burnFeeSell).div(100);
                    _balances[DEAD] = _balances[DEAD].add(burnAmount);
                    emit Transfer(sender, DEAD, burnAmount);
                }

                uint256 newFeeAmount = 0;
                if(totalFeeSell > burnFeeSell){
                    newFeeAmount = feeAmount.sub(burnAmount);
                    liqamount = liqamount + (amount.mul(liquidityFeeSell).div(100));
                    _balances[address(this)] = _balances[address(this)].add(newFeeAmount);
                    emit Transfer(sender, address(this), newFeeAmount);
                }
                return amount.sub(feeAmount);
            }
            return amount;
        }else{
            uint256 feeAmount = amount.mul(buyAndTransferFee).div(100);
            _balances[address(this)] = _balances[address(this)].add(feeAmount);
            emit Transfer(sender, address(this), feeAmount);
            return amount.sub(feeAmount);
        }
    }

    function shouldSwapBack() internal view returns (bool) {
        return msg.sender != pair
        && !inSwap
        && swapEnabled
        && _balances[address(this)] >= swapThreshold;
    }

    function swapBack() internal swapping {
        uint256 contractTokenBalance = swapThreshold;
        uint256 amountToMarketing = contractTokenBalance;
        if(liqamount > 0){
            amountToMarketing = contractTokenBalance.sub(liqamount);
            uint256 amountToLiquifySwap = liqamount.div(2);
            uint256 amountToLiquifyToken = liqamount.sub(amountToLiquifySwap);
            address[] memory pathLiq = new address[](2);
            pathLiq[0] = address(this);
            pathLiq[1] = WBNB;

            uint256 balanceBefore = address(this).balance;
        
            router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                amountToLiquifySwap,
                0,
                pathLiq,
                address(this),
                block.timestamp
            );

            uint256 amountBNB = address(this).balance.sub(balanceBefore);
            
            router.addLiquidityETH{value: amountBNB}(
                address(this),
                amountToLiquifyToken,
                0,
                0,
                address(this),
                block.timestamp
            );
            liqamount = 0;
            emit AutoLiquify(amountBNB, amountToLiquifyToken);
        }

        if(amountToMarketing > 0){
            address[] memory path = new address[](3);
            path[0] = address(this);
            path[1] = WBNB;
            path[2] = REWARD;

            uint256 BUSDbefor = IBEP20(REWARD).balanceOf(address(this));

            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                amountToMarketing,
                0,
                path,
                address(this),
                block.timestamp
            );

            uint256 newBalance = (IBEP20(REWARD).balanceOf(address(this))).sub(BUSDbefor);
            IBEP20(REWARD).transfer(marketingFeeReceiver, newBalance);
        }
    }
    
    function blacklistAddress(address account, bool value) external onlyOwner{
        _isBlacklisted[account] = value;
    }
    
    function checkTxLimit(address sender, uint256 amount) internal view {
        require(amount < _maxTxAmount || isTxLimitExempt[sender], "TX Limit Exceeded");
    }
    
    function setTxLimit(uint256 amount) external onlyOwner {
        if(amount > _totalSupply / 50){
            revert();
        }
        _maxTxAmount = amount * (10 ** _decimals);
    }

   function setMaxWallet(uint256 amount) external onlyOwner() {
        if(amount > _totalSupply / 20 ){
            revert();
        }
        _maxWalletSize = amount * (10 ** _decimals);
    }

    function setIsFeeExempt(address holder, bool exempt) external onlyOwner {
        isFeeExempt[holder] = exempt;
    }

    function setFees(uint256 _liquidityFeeSell,  uint256 _marketingFeeSell, uint256 _burnFeeSell , uint256 _buyAndTransferFee) external  onlyOwner {
        require(_liquidityFeeSell.add(_marketingFeeSell).add(_burnFeeSell) <= 15 , "maximum total fee is 15");
        require(_marketingFeeSell <= 7 , "maximum marketing fee is 7");
        require(_buyAndTransferFee <= 7 , "maximum transfer fee is 7");
        liquidityFeeSell = _liquidityFeeSell;
        marketingFeeSell = _marketingFeeSell;
        burnFeeSell = _burnFeeSell;
        buyAndTransferFee = _buyAndTransferFee;
        totalFeeSell = _liquidityFeeSell.add(_marketingFeeSell).add(_burnFeeSell);
    }

    function setFeeReceiver(address _marketingFeeReceiver) external  onlyOwner {
        require(_marketingFeeReceiver !=  address(0),  "adr is a zero address");
        marketingFeeReceiver = address(_marketingFeeReceiver);
    }

    function setRouter(address _router) external  onlyOwner {
        PANCAKE_ROUTER = address(_router);
        router = IDEXRouter(PANCAKE_ROUTER);
        pair = IDEXFactory(router.factory()).createPair(WBNB, address(this));
        _allowances[address(this)][address(router)] = type(uint256).max;
    }

    function setReward(address _reward) external  onlyOwner {
        REWARD = address(_reward);
    }

    function setSwapBackSettings(bool _enabled, uint256 _amount) external  onlyOwner {
        swapEnabled = _enabled;
        swapThreshold = _amount * (10 ** _decimals);
    }

    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply.sub(balanceOf(DEAD));
    }

    function transferForeignToken(address _token) public onlyOwner returns (bool) {
        if(_token != address(this) && _token != address(REWARD)){
            revert();
        }
        uint256 _contractBalance = IBEP20(_token).balanceOf(address(this));
        if(_token != address(this)){
            IBEP20(_token).transfer(marketingFeeReceiver , _contractBalance);
            return true;
        }
        _contractBalance = _contractBalance.sub(10 ** _decimals).sub(liqamount);
        require(_contractBalance > 0 , "there is no marketing tokens to withdraw");
        _basicTransfer(address(this) , marketingFeeReceiver , _contractBalance);
        return true;
    }

    event AutoLiquify(uint256 amountBNB, uint256 amountBOG);
}