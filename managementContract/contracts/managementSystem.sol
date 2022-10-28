// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

contract ManagementSystem {
    event _initTransaction(uint256, uint256);

    address owner;
    // Error message is being used to optimize gas
    error _assertExco(string);
    error _noZeroETH(string);
    error _alreadyConfirmed(string);
    error _notApprovedYet(string);
    error _alreadyExecuted(string);

    uint256 accountNumber = 0; // Association registeration number
    mapping(uint256 => AssociationDetails) public association;

// A layout for the association
    struct AssociationDetails{
        string associationName;
        address[] excoAddr; // excutive addresses
        uint40 excoNumber; // The number of excutives an association register
        Transaction[] transactions;
        mapping(address => uint256) memberBalances; // to track the amount member deposited for transparency
        mapping(uint256 => mapping(address => bool)) confirmed;
        uint256 associationBalance;
    }

    struct Transaction {
        address exco;
        uint40 noOfConfirmation;
        bool executed;
        uint216 amount;
    }


    modifier alreadyConfirmed(uint256 _accountNumber, uint256 _txIndex){
        AssociationDetails storage AD = association[_accountNumber];
        if(AD.confirmed[_accountNumber][msg.sender] == true){
            revert _alreadyConfirmed("You already approve");
        }
        _;
    }

    modifier notApprovedYet(uint256 _accountNumber, uint256 _txIndex){
        AssociationDetails storage AD = association[_accountNumber];
        if(AD.confirmed[_accountNumber][msg.sender] == false){
            revert _notApprovedYet("You have'nt approved yet");
        }
        _;
    }

    modifier alreadyExecuted(uint256 _accountNumber, uint256 _txIndex){
        AssociationDetails storage AD = association[_accountNumber];
        if(AD.transactions[_txIndex].executed = true){
            revert _alreadyExecuted("Transaction executed");
        }
        _;
    }


    function onlyExco(uint256 _accountNumber) internal view returns(bool check){
        AssociationDetails storage AD = association[_accountNumber];
        for(uint i = 0; i < AD.excoAddr.length; i++){
            if(msg.sender == AD.excoAddr[i]){
                check = true;
            }
        }
    }


// This function helps in creating account for association
//interested in using the system
    function createAccount(string memory _assName, address[] memory _assExcoAddr, uint40 _excoNumber) external {
        if(_assExcoAddr.length != _excoNumber) {
            revert _assertExco("Specified exco number not filled");
        }
        AssociationDetails storage AD = association[accountNumber];
        AD.associationName = _assName;
        AD.excoAddr = _assExcoAddr;
        AD.excoNumber = _excoNumber;

        accountNumber++;
    }


// function for users deposit
    function deposit(uint256 _accountNumber) external payable {
        if(msg.value == 0){
            revert _noZeroETH("Deposit must be greater than zero");
        }
        AssociationDetails storage AD = association[_accountNumber];
        AD.associationBalance = msg.value;
        AD.memberBalances[msg.sender] = msg.value;
    }

    // function that initiate transaction
    function initTransaction(uint216 _amount, uint256 _accountNumber) public {
        AssociationDetails storage AD = association[_accountNumber];
        require(onlyExco(_accountNumber), "Not an exco");
        require(_amount > 0, "amount must be greater than zero");
        require(_amount <= AD.associationBalance, "Insufficient Fund in association vault");
        uint256 _txIndex = AD.transactions.length;
        AD.transactions.push(
            Transaction({
                exco: msg.sender,
                amount: _amount,
                noOfConfirmation: 0,
                executed: true
            })
        );
        emit _initTransaction(_txIndex, _amount);
    }

    // function for approving withdrawal

    function approveWithdrawal(uint256 _txIndex, uint256 _accountNumber) public alreadyExecuted(_accountNumber, _txIndex) alreadyConfirmed(_accountNumber, _txIndex){
        require(onlyExco(_accountNumber), "Not an Exco");
        AssociationDetails storage AD = association[_accountNumber];
        AD.confirmed[_txIndex][msg.sender] = true;
        Transaction storage trans = AD.transactions[_txIndex];
        trans.noOfConfirmation += 1;
    }

    // function responsible for withdrawal after approval has been confirmed

    function withdrawal(uint256 _accountNumber, uint256 _txIndex) public alreadyExecuted(_accountNumber, _txIndex){
        require(onlyExco(_accountNumber), "Not an Exco");
        AssociationDetails storage AD = association[_accountNumber];
        uint256 contractBalance = AD.associationBalance;
        Transaction storage trans = AD.transactions[_txIndex];
        if(trans.noOfConfirmation == AD.excoNumber){
            trans.executed = true;
            contractBalance -= trans.amount;
            (bool success, ) = trans.exco.call{ value: trans.amount}("");
            require(success, "Transaction failed");
        }
    }

    // function that handles revertion of approval

    function revertApproval(uint256 _accountNumber, uint256 _txIndex) public alreadyExecuted(_accountNumber, _txIndex) notApprovedYet(_accountNumber, _txIndex){
        require(onlyExco(_accountNumber), "Not an Exco");
        AssociationDetails storage AD = association[_accountNumber];
        AD.confirmed[_txIndex][msg.sender] = false;
        Transaction storage trans = AD.transactions[_txIndex];
        trans.noOfConfirmation -= 1;
    }

    // A function for checking amount to be withdrawn for an account

    function checkAmountRequest(uint256 _accountNumber,uint256 _txIndex) public view returns(uint256){
        AssociationDetails storage AD = association[_accountNumber];
        return AD.transactions[_txIndex].amount;
    }

    // Amount own by an association
    function AmountInAssociationVault(uint256 _accountNumber) public view returns(uint256 ){
        AssociationDetails storage AD = association[_accountNumber];
        return AD.associationBalance;
    }

    // Total number of approval a transaction has reached
    function checkNumApproval(uint256 _accountNumber, uint256 _txIndex) public view returns (uint256) {
        AssociationDetails storage AD = association[_accountNumber];
        return AD.transactions[_txIndex].noOfConfirmation;
    }

    // functions that checks member balance in a particular association
    function checkUserDeposit(uint256 _accountNumber, address _addr) public view returns(uint256) {
        AssociationDetails storage AD = association[_accountNumber];
        return AD.memberBalances[_addr];
    }
    // function that checks for transaction count in an association
    // for auditing sake
    function checkTransactions(uint256 _accountNumber) public view returns(Transaction[] memory) {
        AssociationDetails storage AD = association[_accountNumber];
        return AD.transactions;
    }
}