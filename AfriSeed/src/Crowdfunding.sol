//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Project} from "./ProjectIdea.sol";

contract Crowdfunding {
    // [X] Anyone can start a funding project .
    // [X] Get All project list
    // [X]  contribute amount

    error Crowdfunding__InvalidState();
    error Crowdfunding__ContributionIsTooLow();

    event ProjectStarted(
        address projectContractAddress,
        address creator,
        uint256 minContribution,
        uint256 projectDeadline,
        uint256 goalAmount,
        uint256 currentAmount,
        uint256 noOfContributors,
        string title,
        string desc,
        uint256 currentState
    );

    event ContributionReceived(address projectAddress, uint256 contributedAmount, address indexed contributor);

    Project[] private projects;

    // @dev Anyone can start a fund rising
    // @return null
    /**
     * 
     * @param minimumContribution The minimum amount a contributor can contribute with
     * @param deadline The time duration of which the project fund to be raised
     * @param targetContribution To amount to raise for the project
     * @param projectTitle The title of the project.
     * @param projectDesc What the project idea is all about and how it would be executed from start to finish 
     */

    function createProject(
        uint256 minimumContribution,
        uint256 deadline,
        uint256 targetContribution,
        string memory projectTitle,
        string memory projectDesc
    ) public {
        deadline = deadline;

        Project newProject = new Project(msg.sender, minimumContribution, deadline, targetContribution, projectTitle, projectDesc);
        projects.push(newProject);

        emit ProjectStarted(
            address(newProject),
            msg.sender,
            minimumContribution,
            deadline,
            targetContribution,
            0,
            0,
            projectTitle,
            projectDesc,
            0
        );
    }

    // @dev Get projects list
    // @return array

    function returnAllProjects() external view returns (Project[] memory) {
        return projects;
    }

    // @dev User can contribute
    // @return null
    /**
     * 
     * @param _projectAddress The project contract address that contribute what to check out.
     */

    function contribute(address _projectAddress) public payable {
        uint256 minContributionAmount = Project(_projectAddress).minimumContribution();
        Project.State projectState = Project(_projectAddress).state();
        if (projectState != Project.State.Fundraising) {
            revert Crowdfunding__InvalidState();
        }
        if (msg.value < minContributionAmount) {
            revert Crowdfunding__ContributionIsTooLow();
        }
        // Call function
        Project(_projectAddress).contribute{value: msg.value}(msg.sender);
        // Trigger event
        emit ContributionReceived(_projectAddress, msg.value, msg.sender);
    }
}
