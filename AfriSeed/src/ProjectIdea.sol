//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

// [X] Anyone can contribute
// [X] End project if targeted contribution amount reached
// [X] Expire project if raised amount not fullfill between deadline
//    & return donated amount to all contributor .
// [X] Owner need to request contributers for withdraw amount.
// [X] Owner can withdraw amount if 50% contributors agree

contract Project {
    //error
    error Project__NotTheCreator();
    error Project__InvalidState();
    error Project__DeadlineHasPassed();
    error Project__ContributionIsTooLow();
    error Project__NotAContributor();
    error Project__HasAlreadyVoted();
    error Project__RequestCompleted();
    error Project__HalfContributorsVoteIsRequired();

    // Project state
    enum State {
        Fundraising,
        Expired,
        Successful
    }

    // Structs

    struct WithdrawRequest {
        string description;
        uint256 amount;
        uint256 noOfVotes;
        mapping(address => bool) voters;
        bool isCompleted;
        address payable reciptent;
    }

    // Variables
    address payable public creator;
    uint256 public minimumContribution;
    uint256 public deadline;
    uint256 public targetContribution; // required to reach at least this much amount
    uint256 public completeAt;
    uint256 public raisedAmount; // Total raised amount till now
    uint256 public noOfContributers;
    string public projectTitle;
    string public projectDes;
    State public state = State.Fundraising;

    mapping(address => uint256) public contributiors;
    mapping(uint256 => WithdrawRequest) public withdrawRequests;

    uint256 public numOfWithdrawRequests = 0;

  

    // Events

    // Event that will be emitted whenever funding will be received
    event FundingReceived(
        address contributor, 
        uint256 amount, 
        uint256 currentTotal
    );
    // Event that will be emitted whenever withdraw request created
    event WithdrawRequestCreated(
        uint256 requestId, 
        string description, 
        uint256 amount, 
        uint256 noOfVotes, 
        bool isCompleted, 
        address reciptent
    );
    // Event that will be emitted whenever contributor vote for withdraw request
    event WithdrawVote(
        address voter, 
        uint256 totalVote
    );
    // Event that will be emitted whenever contributor vote for withdraw request
    event AmountWithdrawSuccessful(
        uint256 requestId, 
        string description, 
        uint256 amount, 
        uint256 noOfVotes, 
        bool isCompleted, 
        address reciptent
    );

      // Modifiers
    modifier isCreator() {
        if (msg.sender != creator) {
            revert Project__NotTheCreator();
        }
        _;
    }

    modifier validateExpiry(State _state) {
        if (state != _state) {
            revert Project__InvalidState();
        }
        if (block.timestamp >= deadline) {
            revert Project__DeadlineHasPassed();
        }
        _;
    }

    // @dev Create project
    // @return null

    constructor(
        address _creator,
        uint256 _minimumContribution,
        uint256 _deadline,
        uint256 _targetContribution,
        string memory _projectTitle,
        string memory _projectDes
    ) {
        creator = payable(_creator);
        minimumContribution = _minimumContribution;
        deadline = _deadline;
        targetContribution = _targetContribution;
        projectTitle = _projectTitle;
        projectDes = _projectDes;
        raisedAmount = 0;
    }

    // @dev Anyone can contribute
    // @return null

    function contribute(address _contributor) public payable validateExpiry(State.Fundraising) {
        if (msg.value < minimumContribution) {
            revert Project__ContributionIsTooLow();
        }
        if (contributiors[_contributor] == 0) {
            noOfContributers++;
        }
        contributiors[_contributor] += msg.value;
        raisedAmount += msg.value;
        emit FundingReceived(_contributor, msg.value, raisedAmount);
        checkFundingCompleteOrExpire();
    }

    // @dev complete or expire funding
    // @return null

    function checkFundingCompleteOrExpire() internal {
        if (raisedAmount >= targetContribution) {
            state = State.Successful;
        } else if (block.timestamp > deadline) {
            state = State.Expired;
        }
        completeAt = block.timestamp;
    }

    // @dev Get contract current balance
    // @return uint

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // @dev Request refunt if funding expired
    // @return boolean

    function requestRefund() public validateExpiry(State.Expired) returns (bool) {
        if ( contributiors[msg.sender] <= 0) {
            revert Project__NotAContributor();
        }
        uint256 refundAmount = contributiors[msg.sender];
        contributiors[msg.sender] = 0;
        address payable user = payable(msg.sender);
        (bool success, ) = user.call{value: refundAmount}("");
        require(success, "Transfer fail");
        return true;
    }

    // @dev Request contributor for withdraw amount
    // @return null

    function createWithdrawRequest(string memory _description, uint256 _amount, address payable _reciptent)
        public
        isCreator
        validateExpiry(State.Successful)
    {
        WithdrawRequest storage newRequest = withdrawRequests[numOfWithdrawRequests];
        numOfWithdrawRequests++;

        newRequest.description = _description;
        newRequest.amount = _amount;
        newRequest.noOfVotes = 0;
        newRequest.isCompleted = false;
        newRequest.reciptent = _reciptent;

        emit WithdrawRequestCreated(numOfWithdrawRequests, _description, _amount, 0, false, _reciptent);
    }

    // @dev contributors can vote for withdraw request
    // @return null

    function voteWithdrawRequest(uint256 _requestId) public {
        if (contributiors[msg.sender] <= 0) {
            revert Project__NotAContributor();
        }
        WithdrawRequest storage requestDetails = withdrawRequests[_requestId];
        if (requestDetails.voters[msg.sender] != false) {
            revert Project__HasAlreadyVoted();
        }
        requestDetails.voters[msg.sender] = true;
        requestDetails.noOfVotes += 1;
        emit WithdrawVote(msg.sender, requestDetails.noOfVotes);
    }

    // @dev Owner can withdraw requested amount
    // @return null

   function withdrawRequestedAmount(uint256 _requestId) public isCreator validateExpiry(State.Successful) {
    WithdrawRequest storage requestDetails = withdrawRequests[_requestId];
    if (requestDetails.isCompleted == true) {
        revert Project__RequestCompleted();
    }
    if (requestDetails.noOfVotes < noOfContributers / 2) {
        revert Project__HalfContributorsVoteIsRequired();
    }
    
    uint256 amountToWithdraw = requestDetails.amount;
    requestDetails.amount = 0;
    requestDetails.isCompleted = true;

    (bool success, ) = requestDetails.reciptent.call{value: amountToWithdraw}("");
    require(success, "Transfer failed");

    emit AmountWithdrawSuccessful(
        _requestId,
        requestDetails.description,
        amountToWithdraw,
        requestDetails.noOfVotes,
        true,
        requestDetails.reciptent
    );
}

    // @dev Get contract details
    // @return all the project's details

    function getProjectDetails()
        public
        view
        returns (
            address payable projectStarter,
            uint256 minContribution,
            uint256 projectDeadline,
            uint256 goalAmount,
            uint256 completedTime,
            uint256 currentAmount,
            string memory title,
            string memory desc,
            State currentState,
            uint256 balance
        )
    {
        projectStarter = creator;
        minContribution = minimumContribution;
        projectDeadline = deadline;
        goalAmount = targetContribution;
        completedTime = completeAt;
        currentAmount = raisedAmount;
        title = projectTitle;
        desc = projectDes;
        currentState = state;
        balance = address(this).balance;
    }
}
