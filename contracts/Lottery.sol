//SPDX-License-Identifier: MIT

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
    constructor() {}

    // solhint-disable-previous-line no-empty-blocks

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

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        address payable msgSender = payable(_msgSender());
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract LSC is Context, IBEP20, Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) internal _balances;

    mapping(address => mapping(address => uint256)) internal _allowances;

    address public _lottoWallet;
    address public _marketWallet;

    uint8 internal _decimals = 9;
    uint256 internal _totalSupply;
    string internal _name;
    string internal _symbol;

    address private _owner = msg.sender;

    uint256 public _prize = 20 * 10**uint256(9 + _decimals);

    address[] private _targetTickets;
    address public _winnerParticipant;

    bool _isStartLotto = false;

    uint256 public lscInterval = 24 hours;
    uint256 public lscNextTime;
    uint256 public lscLastTime;

    event ChooseWinner(uint256 _chosenNumber, address winner);
    event RandomNumberGenerated(uint256);
    event AlertLotto(string);

    address[] internal _validParticipants;

    uint256 public _ticketPrice = 1 * 10**uint256(_decimals + 5);
    uint256 public _liquidityAmount = 2 * 10**uint256(_decimals + 12);
    uint256 public maxRange;

    IPancakeRouter02 public pancakeswapV2Router;
    address public pancakeswapV2Pair;
    address payable public _liquidityAddress =
        payable(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);

    constructor() public {
        _totalSupply = 1 * (10**uint256(_decimals + 15));
        _balances[_owner] = _totalSupply; //4 *(10**uint256(_decimals+14));
        _name = "LottoScape";
        _symbol = "LTSC";

        // emit Transfer(address(0), msg.sender, _totalSupply);

        IPancakeRouter02 _pancakeswapV2Router = IPancakeRouter02(
            _liquidityAddress
        );

        //   // Create a Pancake pair for this new token
        pancakeswapV2Pair = IPancakeFactory(_pancakeswapV2Router.factory())
        .createPair(address(this), _pancakeswapV2Router.WETH());

        //     // set the rest of the contract variables
        pancakeswapV2Router = _pancakeswapV2Router;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function setLottoWallet(address lotto) public onlyOwner returns (bool) {
        require(_lottoWallet == address(0), "Exist lotto wallet already");
        transferInternal(lotto, 20 * 10**uint256(12 + _decimals));
        _lottoWallet = lotto;
        return true;
    }

    function addLottoWalletBalance(uint256 amount)
        public
        onlyOwner
        returns (bool)
    {
        require(_lottoWallet != address(0), "Please set lotto wallet");
        transferInternal(_lottoWallet, amount);

        return true;
    }

    function setMarketWallet(address market) public onlyOwner returns (bool) {
        require(_marketWallet == address(0), "Exist market wallet already");
        transferInternal(market, 10 * 10**uint256(12 + _decimals));
        _marketWallet = market;
        return true;
    }

    function addMarketWalletBalance(uint256 amount)
        public
        onlyOwner
        returns (bool)
    {
        require(_marketWallet != address(0), "Please set market wallet");
        transferInternal(_marketWallet, amount);

        return true;
    }

    function sendLiquidity() public returns (bool) {
        _sendToLiquidity(_liquidityAmount);

        return true;
    }

    function setRouterAddress(address payable newRouter) public onlyOwner() {
        //Thank you FreezyEx
        IPancakeRouter02 _pancakeswapV2Router = IPancakeRouter02(newRouter);
        pancakeswapV2Pair = IPancakeFactory(_pancakeswapV2Router.factory())
        .createPair(address(this), _pancakeswapV2Router.WETH());
        pancakeswapV2Router = _pancakeswapV2Router;
        _liquidityAddress = newRouter;
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        // _transfer(_msgSender(), recipient, amount);

        uint256 remain = _distributeTransaction(amount);

        transferInternal(recipient, remain);

        if (recipient != _marketWallet && recipient != _lottoWallet) {
            if (_isNewPlayer(recipient)) {
                _validParticipants.push(recipient);
            }
        }

        return true;
    }

    function transferInternal(address recipient, uint256 amount)
        public
        onlyOwner
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(
            amount,
            "BEP20: transfer amount exceeds balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(sender, recipient, amount);

        if (_isStartLotto && block.timestamp >= lscNextTime)
            _scheduleNextDraw();
    }

    function _burn(address account, uint256 amount) private {
        require(account != address(0), "BEP20: burn from the zero address");

        _balances[account] = _balances[account].sub(
            amount,
            "BEP20: burn amount exceeds balance"
        );
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _burnFrom(address account, uint256 amount) private {
        _burn(account, amount);
        _approve(
            account,
            _msgSender(),
            _allowances[account][_msgSender()].sub(
                amount,
                "BEP20: burn amount exceeds allowance"
            )
        );
    }

    function _sendToLottery(uint256 amount) private returns (bool) {
        require(_lottoWallet != address(0), "Please set lotto wallet");
        transferInternal(_lottoWallet, amount);
        return true;
    }

    function _sendToMarket(uint256 amount) private returns (bool) {
        require(_marketWallet != address(0), "Please set market wallet");
        transferInternal(_marketWallet, amount);
        return true;
    }

    function _sendToLiquidity(uint256 tokenAmount) private {
        uint256 half = tokenAmount.div(2);
        uint256 otherHalf = tokenAmount.sub(half); //BNB

        uint256 initialBalance = address(this).balance;

        // swap tokens for BNB
        swapTokensForBNB(half); // <- this breaks the BNB -> HATE swap when swap+liquify is triggered

        uint256 newBalance = address(this).balance.sub(initialBalance);

        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(pancakeswapV2Router), tokenAmount);

        // // add the liquidity
        pancakeswapV2Router.addLiquidityETH{ value: newBalance }(
            address(this),
            otherHalf,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    function swapTokensForBNB(uint256 tokenAmount) private {
        // generate the Pancake pair path of token -> weth
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

    function _distributeTransaction(uint256 amount) internal returns (uint256) {
        uint256 distributeAmount = _calculatePercent(amount, 2);
        uint256 liquidityAmount = _calculatePercent(amount, 2);
        uint256 lotteryAmount = _calculatePercent(amount, 2);
        uint256 marketAmount = _calculatePercent(amount, 1);

        _sendToLottery(lotteryAmount);
        _sendToMarket(marketAmount);
        _sendToLiquidity(liquidityAmount);

        uint256 playerCnt = _validParticipants.length;
        uint256 disamount = distributeAmount.div(playerCnt);

        for (uint256 i = 0; i < playerCnt; i++) {
            transferInternal(_validParticipants[i], disamount);
        }

        uint256 remain = amount -
            distributeAmount -
            liquidityAmount -
            lotteryAmount -
            marketAmount;

        return remain;
    }

    function _isNewPlayer(address playerAddress) internal view returns (bool) {
        if (_validParticipants.length == 0) {
            return true;
        }

        for (uint256 i = 0; i < _validParticipants.length; i++) {
            if (_validParticipants[i] == playerAddress) {
                return false;
            }
        }
        return true;
    }

    function _calculatePercent(uint256 amount, uint256 percent)
        private
        pure
        returns (uint256)
    {
        uint256 value = (amount * percent) / 100;
        return value;
    }

    function startLotto() public onlyOwner returns (bool) {
        require(!_isStartLotto, "Starting Lotto already");
        require(_lottoWallet != address(0), "Please set lotto wallet");
        require(_marketWallet != address(0), "Please set market wallet");

        _isStartLotto = true;

        lscNextTime = block.timestamp + lscInterval;

        emit AlertLotto("Started Lotto");

        return true;
    }

    function stopLotto() public onlyOwner returns (bool) {
        require(_isStartLotto, "A lotto is not started yet");

        _isStartLotto = false;

        emit AlertLotto("Stopped Lotto");

        return true;
    }

    function newRound() public onlyOwner returns (bool) {
        require(_isStartLotto, "A lotto is not started yet");

        _scheduleNextDraw();

        return true;
    }

    /**
     * Schedule next lsc by setting the time.
     */
    function _scheduleNextDraw() private {
        lscLastTime = lscNextTime; // set last lsc time
        lscNextTime = lscLastTime + lscInterval;

        _createTicket();

        maxRange = _targetTickets.length; // this is the highest uint we want to get. It should never be greater than 2^(8*N), where N is the number of random bytes we had asked the datasource to return
        if (maxRange > 0) {
            uint256 randomNumber = getRandomNumber(maxRange) % maxRange; // this is an efficient way to get the uint out in the [0, maxRange] range
            _chooseWinner(randomNumber);
            _sendToWinner();

            // _tCount++;

            emit RandomNumberGenerated(randomNumber); // this is the resulting random number (uint)
        }
    }

    function getRandomNumber(uint256 seed) private view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(block.difficulty, block.timestamp, seed)
                )
            );
    }

    function updatePlayer(address participate, uint256 amount)
        public
        returns (bool)
    {
        // require(!_isNewPlayer(participate), "No exist the player.");

        uint256 remain = _distributeTransaction(amount);

        transfer(participate, remain);

        if (_isNewPlayer(participate)) {
            _validParticipants.push(participate);
        }
    }

    function _createTicket() private {
        delete _targetTickets;
        for (uint256 i = 0; i < _validParticipants.length; i++) {
            address wallet = _validParticipants[i];
            uint256 balance = balanceOf(wallet);
            uint256 ticketCount = balance.div(_ticketPrice);
            for (uint256 p = 0; p < ticketCount; p++) {
                _targetTickets.push(wallet);
            }
        }
    }

    function _chooseWinner(uint256 _chosenNum) private {
        _winnerParticipant = _targetTickets[_chosenNum];

        emit ChooseWinner(_chosenNum, _targetTickets[_chosenNum]);
    }

    function _sendToWinner() private returns (bool) {
        _transfer(_lottoWallet, _winnerParticipant, _prize);
        return true;
    }
}
