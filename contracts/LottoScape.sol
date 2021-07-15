// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.4;
pragma experimental ABIEncoderV2;

// import "@pancakeswap2/pancake-swap-core/contracts/interfaces/IPancakeFactory.sol";
// import "pancakeswap-peripheral/contracts/interfaces/IPancakeRouter02.sol";
import "https://github.com/pancakeswap/pancake-swap-core/contracts/interfaces/IPancakeFactory.sol";
import "https://github.com/pancakeswap/pancake-swap-periphery/contracts/interfaces/IPancakeRouter02.sol";

interface IBEP20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
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

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }
}

contract Context {
    function _msgSender() internal view returns (address) {
        return msg.sender;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract LOTTOSCAPE is Context, Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private _isExcludedFromFee;

    mapping(address => bool) private _isExcluded;
    address[] private _excluded;

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 1000000000 * 10**9;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    string private _name = "LOTTOSCAPE";

    uint256 public _taxFee = 5;
    uint256 private _previousTaxFee = _taxFee;

    uint256 public _liquidityFee = 3;
    uint256 private _previousLiquidityFee = _liquidityFee;

    uint256 public _potFee = 2;
    uint256 private _previousPotFee = _potFee;

    uint256 public _potFeeExtra = 5;
    uint256 private _previousPotFeeExtra = _potFeeExtra;

    IPancakeRouter02 public pancakeswapV2Router;
    address public pancakeswapV2Pair;
    address payable public _liquidityAddress =
        payable(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);

    bool inSwap;

    struct GameSettings {
        uint256 maxTxAmount; // maximum number of tokens in one transfer
        uint256 tokenSwapThreshold; // number of tokens needed in contract to swap and sell
        uint256 minimumBuyForPotEligibility; // minimum buy to be eligible to win share of the pot
        uint256 tokensToAddOneSecond; // number of tokens that will add one second to the timer
        uint256 maxTimeLeft; // maximum number of seconds the timer can be
        uint256 potFeeExtraTimeLeftThreshold; //if timer is under this value, the potFeeExtra is used
        uint256 eligiblePlayers; // number of players eligible for winning share of the pot
        uint256 potPayoutPercent; // what percent of the pot is paid out, vs. carried over to next round
        uint256 lastBuyerPayoutPercent; // what percent of the paid-out-pot is paid to absolute last buyer
        uint256 marketingPercent; // what percent of the payout is paid to marketing
        uint256 liquidityPercent; // percent of autoliquidity
    }

    GameSettings public gameSettings;

    bool public gameIsActive = false;

    uint256 private roundNumber;

    uint256 private timeLeftAtLastBuy;
    uint256 private lastBuyBlock;

    uint256 private liquidityTokens;
    uint256 private potTokens;

    address private liquidityAddress;
    address private gameSettingsUpdaterAddress;

    address private presaleContractAddress;

    address payable private _marketingContractAddress;

    IBEP20 private _stakingContract;

    mapping(uint256 => Buyer[]) private buyersByRound;

    modifier onlyGameSettingsUpdater() {
        require(
            _msgSender() == gameSettingsUpdaterAddress,
            "caller != game settings updater"
        );
        _;
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiquidity
    );

    event GameSettingsUpdated(
        uint256 maxTxAmount,
        uint256 tokenSwapThreshold,
        uint256 minimumBuyForPotEligibility,
        uint256 tokensToAddOneSecond,
        uint256 maxTimeLeft,
        uint256 potFeeExtraTimeLeftThreshold,
        uint256 eligiblePlayers,
        uint256 potPayoutPercent,
        uint256 lastBuyerPayoutPercent,
        uint256 marketingPercent,
        uint256 liquidityPercent
    );

    event GameSettingsUpdaterUpdated(
        address oldGameSettingsUpdater,
        address newGameSettingsUpdater
    );

    event RoundStarted(uint256 number, uint256 potValue);

    event Buy(
        bool indexed isEligible,
        address indexed buyer,
        uint256 amount,
        uint256 timeLeftBefore,
        uint256 timeLeftAfter,
        uint256 blockTime,
        uint256 blockNumber
    );

    event RoundPayout(
        uint256 indexed roundNumber,
        address indexed buyer,
        uint256 amount,
        bool success
    );

    event InternalPayout(
        uint256 indexed roundNumber,
        address indexed marketing,
        uint256 marketingAmount,
        uint256 liquidityAmount,
        bool success
    );

    event RoundEnded(
        uint256 number,
        address payable[] winners,
        uint256[] winnerAmountsRound
    );

    enum TransferType {
        Normal,
        Buy,
        Sell,
        RemoveLiquidity
    }

    struct Buyer {
        address payable buyer;
        uint256 amount;
        uint256 timeLeftBefore;
        uint256 timeLeftAfter;
        uint256 blockTime;
        uint256 blockNumber;
    }

    constructor(address payable _stakingAddress) payable {
        gameSettings = GameSettings(
            1000000 * 10**9, //maxTxAmount is 1 million tokens
            100000 * 10**9, //tokenSwapThreshold is 100,000 tokens
            100000 * 10**9, //minimumBuyForPotEligibility is 100,000 tokens
            1000 * 10**9, //tokensToAddOneSecond is 1000 tokens
            300, //maxTimeLeft is 5 min
            0, //potFeeExtraTimeLeftThreshold is 0 minutes
            5, //eligiblePlayers is 5
            60, //potPayoutPercent is 60%
            0, //lastBuyerPayoutPercent is 0%
            10, //marketingPercent is 10%
            5 //liquidityPercent is 5
        );

        liquidityAddress = _msgSender();
        gameSettingsUpdaterAddress = _msgSender();
        _marketingContractAddress = payable(_msgSender());
        _stakingContract = IBEP20(_stakingAddress);

        _rOwned[_msgSender()] = _rTotal;

        IPancakeRouter02 _pancakeswapV2Router = IPancakeRouter02(
            _liquidityAddress
        );

        //   // Create a Pancake pair for this new token
        pancakeswapV2Pair = IPancakeFactory(_pancakeswapV2Router.factory())
        .getPair(_stakingAddress, _pancakeswapV2Router.WETH());

        //     // set the rest of the contract variables
        pancakeswapV2Router = _pancakeswapV2Router;

        //exclude owner and this contract from fee
        _isExcludedFromFee[_msgSender()] = true;
        _isExcludedFromFee[address(this)] = true;

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    // for any non-zero value it updates the game settings to that value
    function updateGameSettings(
        uint256 maxTxAmount,
        uint256 tokenSwapThreshold,
        uint256 minimumBuyForPotEligibility,
        uint256 tokensToAddOneSecond,
        uint256 maxTimeLeft,
        uint256 potFeeExtraTimeLeftThreshold,
        uint256 eligiblePlayers,
        uint256 potPayoutPercent,
        uint256 lastBuyerPayoutPercent,
        uint256 marketingPercent,
        uint256 liquidityPercent
    ) public onlyGameSettingsUpdater {
        if (maxTxAmount > 0) {
            require(
                maxTxAmount >= 1000000 * 10**9 &&
                    maxTxAmount <= 10000000 * 10**9
            );
            gameSettings.maxTxAmount = maxTxAmount;
        }
        if (tokenSwapThreshold > 0) {
            require(
                tokenSwapThreshold >= 100000 * 10**9 &&
                    tokenSwapThreshold <= 1000000 * 10**9
            );
            gameSettings.tokenSwapThreshold = tokenSwapThreshold;
        }
        if (minimumBuyForPotEligibility > 0) {
            require(
                minimumBuyForPotEligibility >= 1000 * 10**9 &&
                    minimumBuyForPotEligibility <= 100000 * 10**9
            );
            gameSettings
            .minimumBuyForPotEligibility = minimumBuyForPotEligibility;
        }
        if (tokensToAddOneSecond > 0) {
            require(
                tokensToAddOneSecond >= 100 * 10**9 &&
                    tokensToAddOneSecond <= 10000 * 10**9
            );
            gameSettings.tokensToAddOneSecond = tokensToAddOneSecond;
        }
        if (maxTimeLeft > 0) {
            require(maxTimeLeft >= 7200 && maxTimeLeft <= 86400);
            gameSettings.maxTimeLeft = maxTimeLeft;
        }
        if (potFeeExtraTimeLeftThreshold > 0) {
            require(
                potFeeExtraTimeLeftThreshold >= 60 &&
                    potFeeExtraTimeLeftThreshold <= 3600
            );
            gameSettings
            .potFeeExtraTimeLeftThreshold = potFeeExtraTimeLeftThreshold;
        }
        if (eligiblePlayers > 0) {
            require(eligiblePlayers >= 3 && eligiblePlayers <= 15);
            gameSettings.eligiblePlayers = eligiblePlayers;
        }
        if (potPayoutPercent > 0) {
            require(potPayoutPercent >= 30 && potPayoutPercent <= 99);
            gameSettings.potPayoutPercent = potPayoutPercent;
        }
        if (lastBuyerPayoutPercent > 0) {
            require(
                lastBuyerPayoutPercent >= 10 && lastBuyerPayoutPercent <= 60
            );
            gameSettings.lastBuyerPayoutPercent = lastBuyerPayoutPercent;
        }
        if (marketingPercent >= 0) {
            require(marketingPercent >= 0 && marketingPercent <= 60);
            gameSettings.marketingPercent = marketingPercent;
        }
        if (liquidityPercent >= 0) {
            require(liquidityPercent >= 0 && liquidityPercent <= 60);
            gameSettings.liquidityPercent = liquidityPercent;
        }

        emit GameSettingsUpdated(
            maxTxAmount,
            tokenSwapThreshold,
            minimumBuyForPotEligibility,
            tokensToAddOneSecond,
            maxTimeLeft,
            potFeeExtraTimeLeftThreshold,
            eligiblePlayers,
            potPayoutPercent,
            lastBuyerPayoutPercent,
            marketingPercent,
            liquidityPercent
        );
    }

    function renounceGameSettingsUpdater()
        public
        virtual
        onlyGameSettingsUpdater
    {
        emit GameSettingsUpdaterUpdated(gameSettingsUpdaterAddress, address(0));
        gameSettingsUpdaterAddress = address(0);
    }

    function setPresaleContractAddress(address _address) public onlyOwner {
        require(presaleContractAddress == address(0));
        presaleContractAddress = _address;
    }

    function updateMarketingContractAddress(address _address) public onlyOwner {
        _marketingContractAddress = payable(_address);
    }

    function marketingContractAddress() public view returns (address payable) {
        return _marketingContractAddress;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee)
        public
        view
        returns (uint256)
    {
        require(tAmount <= _tTotal, "Amount must be < supply");
        if (!deductTransferFee) {
            (uint256 rAmount, , , , , ) = _getValues(tAmount);
            return rAmount;
        } else {
            (, uint256 rTransferAmount, , , , ) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount)
        public
        view
        returns (uint256)
    {
        require(rAmount <= _rTotal, "Amount must be < total reflections");
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    function excludeFromReward(address account) public onlyOwner() {
        // require(account != 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, 'We can not exclude Uniswap router.');
        require(!_isExcluded[account], "Account is already excluded");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner() {
        require(_isExcluded[account], "Account is already excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidityAndPot(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function startGame() public onlyOwner {
        require(!gameIsActive);

        // start on round 1
        roundNumber = roundNumber.add(1);

        timeLeftAtLastBuy = gameSettings.maxTimeLeft;
        lastBuyBlock = block.number;

        gameIsActive = true;

        emit RoundStarted(roundNumber, potValue());
    }

    //to receive ETH from uniswapV2Router when swapping
    receive() external payable {}

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidityAndPot
        ) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tFee,
            tLiquidityAndPot,
            _getRate()
        );
        return (
            rAmount,
            rTransferAmount,
            rFee,
            tTransferAmount,
            tFee,
            tLiquidityAndPot
        );
    }

    function _getTValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tLiquidityAndPot = calculateLiquidityAndPotFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidityAndPot);
        return (tTransferAmount, tFee, tLiquidityAndPot);
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tLiquidityAndPot,
        uint256 currentRate
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rLiquidityAndPot = tLiquidityAndPot.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rLiquidityAndPot);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _takeLiquidityAndPot(uint256 tLiquidityAndPot) private {
        uint256 currentRate = _getRate();
        uint256 rLiquidityAndPot = tLiquidityAndPot.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidityAndPot);
        if (_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(
                tLiquidityAndPot
            );

        //keep track of ratio of liquidity vs. pot

        uint256 potFee = currentPotFee();

        uint256 totalFee = potFee.add(_liquidityFee);

        if (totalFee > 0) {
            potTokens = potTokens.add(
                tLiquidityAndPot.mul(potFee).div(totalFee)
            );
            liquidityTokens = liquidityTokens.add(
                tLiquidityAndPot.mul(_liquidityFee).div(totalFee)
            );
        }
    }

    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_taxFee).div(10**2);
    }

    function calculateLiquidityAndPotFee(uint256 _amount)
        private
        view
        returns (uint256)
    {
        uint256 _currentPotFee = currentPotFee();

        return _amount.mul(_liquidityFee.add(_currentPotFee)).div(10**2);
    }

    function removeAllFee() private {
        if (
            _taxFee == 0 &&
            _liquidityFee == 0 &&
            _potFee == 0 &&
            _potFeeExtra == 0
        ) return;

        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;
        _previousPotFee = _potFee;
        _previousPotFeeExtra = _potFeeExtra;

        _taxFee = 0;
        _liquidityFee = 0;
        _potFee = 0;
        _potFeeExtra = 0;
    }

    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
        _potFee = _previousPotFee;
        _potFeeExtra = _previousPotFeeExtra;
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function _approve(
        address _owner,
        address spender,
        uint256 amount
    ) private {
        require(_owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[_owner][spender] = amount;
        emit Approval(_owner, spender, amount);
    }

    function getTransferType(address from, address payable to)
        private
        view
        returns (TransferType)
    {
        if (from == pancakeswapV2Pair) {
            if (to == address(pancakeswapV2Router)) {
                return TransferType.RemoveLiquidity;
            }
            return TransferType.Buy;
        }
        if (to == pancakeswapV2Pair) {
            return TransferType.Sell;
        }
        if (from == address(pancakeswapV2Router)) {
            return TransferType.RemoveLiquidity;
        }

        return TransferType.Normal;
    }

    function _transfer(
        address from,
        address payable to,
        uint256 amount
    ) private {
        require(from != address(0), "transfer from the zero address");
        require(to != address(0), "transfer to the zero address");
        require(amount > 0, "Transfer amount must be > 0");

        TransferType transferType = getTransferType(from, to);

        if (
            gameIsActive &&
            !inSwap &&
            transferType != TransferType.RemoveLiquidity &&
            from != liquidityAddress &&
            to != liquidityAddress &&
            from != presaleContractAddress
        ) {
            require(
                amount <= gameSettings.maxTxAmount,
                "Transfer amount exceeds the maxTxAmount."
            );
        }

        completeRoundWhenNoTimeLeft();

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = _stakingContract.balanceOf(
            address(this)
        );

        bool overMinTokenBalance = contractTokenBalance >=
            gameSettings.tokenSwapThreshold;

        if (
            gameIsActive &&
            overMinTokenBalance &&
            !inSwap &&
            transferType != TransferType.Buy &&
            from != liquidityAddress &&
            to != liquidityAddress
        ) {
            inSwap = true;

            //Calculate how much to swap and liquify, and how much to just swap for the pot
            uint256 totalTokens = liquidityTokens.add(potTokens);

            if (totalTokens > 0) {
                uint256 swapTokens = contractTokenBalance
                .mul(liquidityTokens)
                .div(totalTokens);

                //add liquidity
                swapAndLiquify(swapTokens);
            }

            //sell the rest
            uint256 sellTokens = _stakingContract.balanceOf(address(this));

            swapTokensForEth(sellTokens);

            liquidityTokens = 0;
            potTokens = 0;

            inSwap = false;
        }

        //indicates if fee should be deducted from transfer
        bool takeFee = gameIsActive;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from, to, amount, takeFee);

        if (gameIsActive && transferType == TransferType.Buy) {
            handleBuyer(to, amount);
        }
    }

    function handleBuyer(address payable buyer, uint256 amount) private {
        int256 oldTimeLeft = timeLeft();

        if (oldTimeLeft < 0) {
            return;
        }

        int256 newTimeLeft = oldTimeLeft +
            int256(amount / gameSettings.tokensToAddOneSecond);

        bool isEligible = buyer != address(pancakeswapV2Router) &&
            !_isExcludedFromFee[buyer] &&
            amount >= gameSettings.minimumBuyForPotEligibility;

        if (isEligible) {
            Buyer memory newBuyer = Buyer(
                buyer,
                amount,
                uint256(oldTimeLeft),
                uint256(newTimeLeft),
                block.timestamp,
                block.number
            );

            Buyer[] storage buyers = buyersByRound[roundNumber];

            bool added = false;

            // check if buyer would have a 2nd entry in last 7, and remove old one
            for (
                int256 i = int256(buyers.length) - 1;
                i >= 0 &&
                    i >
                    int256(buyers.length) -
                        int256(gameSettings.eligiblePlayers);
                i--
            ) {
                Buyer storage existingBuyer = buyers[uint256(i)];

                if (existingBuyer.buyer == buyer) {
                    // shift all buyers after back one, and put new buyer at end of array
                    for (
                        uint256 j = uint256(i).add(1);
                        j < buyers.length;
                        j = j.add(1)
                    ) {
                        buyers[j.sub(1)] = buyers[j];
                    }

                    buyers[buyers.length.sub(1)] = newBuyer;
                    added = true;

                    break;
                }
            }

            if (!added) {
                buyers.push(newBuyer);
            }
        }

        if (newTimeLeft < 0) {
            newTimeLeft = 0;
        } else if (newTimeLeft > int256(gameSettings.maxTimeLeft)) {
            newTimeLeft = int256(gameSettings.maxTimeLeft);
        }

        timeLeftAtLastBuy = uint256(newTimeLeft);
        lastBuyBlock = block.number;

        emit Buy(
            isEligible,
            buyer,
            amount,
            uint256(oldTimeLeft),
            uint256(newTimeLeft),
            block.timestamp,
            block.number
        );
    }

    function swapAndLiquify(uint256 swapAmount) private {
        // split the value able to be liquified into halves

        uint256 half = swapAmount.div(2);
        uint256 otherHalf = swapAmount.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeswapV2Router.WETH();

        _approve(address(this), address(pancakeswapV2Router), tokenAmount);

        // make the swap
        pancakeswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(pancakeswapV2Router), tokenAmount);

        // add the liquidity
        pancakeswapV2Router.addLiquidityETH{ value: ethAmount }(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            liquidityAddress,
            block.timestamp
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (!takeFee) removeAllFee();

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        if (!takeFee) restoreAllFee();
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidityAndPot
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidityAndPot(tLiquidityAndPot);
        _reflectFee(rFee, tFee);
        //emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidityAndPot
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidityAndPot(tLiquidityAndPot);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidityAndPot
        ) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidityAndPot(tLiquidityAndPot);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function potValue() public view returns (uint256) {
        return
            _stakingContract
                .balanceOf(address(this))
                .mul(gameSettings.potPayoutPercent)
                .div(100);
    }

    function timeLeft() public view returns (int256) {
        if (!gameIsActive) {
            return 0;
        }

        uint256 blocksSinceLastBuy = block.number.sub(lastBuyBlock);

        return int256(timeLeftAtLastBuy) - int256(blocksSinceLastBuy.mul(3));
    }

    function currentPotFee() public view returns (uint256) {
        if (timeLeft() < int256(gameSettings.potFeeExtraTimeLeftThreshold)) {
            return _potFeeExtra;
        }
        return _potFee;
    }

    function completeRoundWhenNoTimeLeft() public {
        int256 secondsLeft = timeLeft();

        if (secondsLeft >= 0) {
            return;
        }

        (
            address payable[] memory buyers,
            uint256[] memory payoutAmounts
        ) = _getPayoutAmounts();

        uint256 lastRoundNumber = roundNumber;

        roundNumber = roundNumber.add(1);

        timeLeftAtLastBuy = gameSettings.maxTimeLeft;
        lastBuyBlock = block.number;

        for (uint256 i = 0; i < buyers.length; i = i.add(1)) {
            uint256 amount = payoutAmounts[i];

            if (amount > 0) {
                (bool success, ) = buyers[i].call{ value: amount, gas: 5000 }(
                    ""
                );
                emit RoundPayout(lastRoundNumber, buyers[i], amount, success);
            }
        }

        uint256 totalPayout = potValue();

        // internal transfer
        uint256 marketingPayout = totalPayout
        .mul(gameSettings.marketingPercent)
        .div(100);

        (bool marketing_success, ) = _marketingContractAddress.call{
            value: marketingPayout,
            gas: 5000
        }("");

        uint256 liquidityPayout = totalPayout
        .mul(gameSettings.liquidityPercent)
        .div(100);

        swapAndLiquify(liquidityPayout);

        emit InternalPayout(
            lastRoundNumber,
            _marketingContractAddress,
            marketingPayout,
            liquidityPayout,
            marketing_success
        );

        emit RoundEnded(lastRoundNumber, buyers, payoutAmounts);

        emit RoundStarted(roundNumber, potValue());
    }

    function _getPayoutAmounts()
        internal
        view
        returns (
            address payable[] memory buyers,
            uint256[] memory payoutAmounts
        )
    {
        buyers = new address payable[](gameSettings.eligiblePlayers);
        payoutAmounts = new uint256[](gameSettings.eligiblePlayers);

        Buyer[] storage roundBuyers = buyersByRound[roundNumber];

        if (roundBuyers.length > 0) {
            uint256 totalPayout = potValue();

            uint256 lastBuyerPayout = totalPayout
            .mul(gameSettings.lastBuyerPayoutPercent)
            .div(100);

            uint256 payoutLeft = totalPayout.sub(lastBuyerPayout);

            uint256 numberOfWinners = roundBuyers.length >
                gameSettings.eligiblePlayers
                ? gameSettings.eligiblePlayers
                : roundBuyers.length;

            uint256 amountLeft;

            for (
                int256 i = int256(roundBuyers.length) - 1;
                i >= int256(roundBuyers.length) - int256(numberOfWinners);
                i--
            ) {
                amountLeft = amountLeft.add(roundBuyers[uint256(i)].amount);
            }

            uint256 returnIndex = 0;

            for (
                int256 i = int256(roundBuyers.length) - 1;
                i >= int256(roundBuyers.length) - int256(numberOfWinners);
                i--
            ) {
                uint256 amount = roundBuyers[uint256(i)].amount;

                uint256 payout = 0;

                if (amountLeft > 0) {
                    payout = payoutLeft.mul(amount).div(amountLeft);
                }

                amountLeft = amountLeft.sub(amount);
                payoutLeft = payoutLeft.sub(payout);

                buyers[returnIndex] = roundBuyers[uint256(i)].buyer;
                payoutAmounts[returnIndex] = payout;

                if (returnIndex == 0) {
                    payoutAmounts[0] = payoutAmounts[0].add(lastBuyerPayout);
                }

                returnIndex = returnIndex.add(1);
            }
        }
    }

    function gameStats()
        external
        view
        returns (
            uint256 currentRoundNumber,
            int256 currentTimeLeft,
            uint256 currentPotValue,
            uint256 currentTimeLeftAtLastBuy,
            uint256 currentLastBuyBlock,
            uint256 currentBlockTime,
            uint256 currentBlockNumber,
            address[] memory lastBuyerAddress,
            uint256[] memory lastBuyerData
        )
    {
        currentRoundNumber = roundNumber;
        currentTimeLeft = timeLeft();
        currentPotValue = potValue();
        currentTimeLeftAtLastBuy = timeLeftAtLastBuy;
        currentLastBuyBlock = lastBuyBlock;
        currentBlockTime = block.timestamp;
        currentBlockNumber = block.number;

        lastBuyerAddress = new address[](gameSettings.eligiblePlayers);
        lastBuyerData = new uint256[](gameSettings.eligiblePlayers.mul(6));

        Buyer[] storage buyers = buyersByRound[roundNumber];

        uint256 iteration = 0;

        (, uint256[] memory payoutAmounts) = _getPayoutAmounts();

        for (int256 i = int256(buyers.length) - 1; i >= 0; i--) {
            Buyer storage buyer = buyers[uint256(i)];

            lastBuyerAddress[iteration] = buyer.buyer;
            lastBuyerData[iteration.mul(6).add(0)] = buyer.amount;
            lastBuyerData[iteration.mul(6).add(1)] = buyer.timeLeftBefore;
            lastBuyerData[iteration.mul(6).add(2)] = buyer.timeLeftAfter;
            lastBuyerData[iteration.mul(6).add(3)] = buyer.blockTime;
            lastBuyerData[iteration.mul(6).add(4)] = buyer.blockNumber;
            lastBuyerData[iteration.mul(6).add(5)] = payoutAmounts[iteration];

            iteration = iteration.add(1);

            if (iteration == gameSettings.eligiblePlayers) {
                break;
            }
        }
    }
}
