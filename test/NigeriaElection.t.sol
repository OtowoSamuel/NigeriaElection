// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {NigeriaElection} from "../src/NigeriaElection.sol";

contract NigeriaElectionTest is Test {
    NigeriaElection public election;
    address public admin;
    address public voter1;
    address public voter2;

    function setUp() public {
        admin = address(this);
        voter1 = address(0x1);
        voter2 = address(0x2);

        election = new NigeriaElection();

        // Set voting period (1 hour from now to 2 hours from now)
        election.setVotingPeriod(block.timestamp + 1 hours, block.timestamp + 2 hours);
    }

    function test_AddCandidate() public {
        election.addCandidate("Alice Johnson", NigeriaElection.Gender.Female, "Labour Party");

        (string memory name, uint256 voteCount, NigeriaElection.Gender gender, string memory party) =
            election.getResults(0);
        assertEq(name, "Alice Johnson");
        assertEq(voteCount, 0);
        assertEq(uint256(gender), uint256(NigeriaElection.Gender.Female));
        assertEq(party, "Labour Party");
    }

    function test_RegisterVoter() public {
        election.registerVoter(voter1, 25, "ABC123", block.timestamp + 365 days, NigeriaElection.Gender.Male);

        assertTrue(election.isRegistered(voter1));
        assertFalse(election.hasVoted(voter1));

        // Check gender stats
        NigeriaElection.GenderStats memory stats = election.getGenderStats();
        assertEq(stats.maleVoters, 1);
        assertEq(stats.femaleVoters, 0);
        assertEq(stats.otherVoters, 0);
    }

    function test_Vote() public {
        // Add candidate
        election.addCandidate("Bob Smith", NigeriaElection.Gender.Male, "Progress Party");

        // Register voter
        election.registerVoter(voter1, 30, "XYZ789", block.timestamp + 365 days, NigeriaElection.Gender.Female);

        // Fast forward to voting period
        vm.warp(block.timestamp + 1 hours + 1);

        // Vote as voter1
        vm.prank(voter1);
        election.vote(0);

        // Check results
        (string memory name, uint256 voteCount,,) = election.getResults(0);
        assertEq(name, "Bob Smith");
        assertEq(voteCount, 1);

        // Check voter status
        assertTrue(election.hasVoted(voter1));

        // Check gender stats
        NigeriaElection.GenderStats memory stats = election.getGenderStats();
        assertEq(stats.femaleVotes, 1);
        assertEq(stats.maleVotes, 0);
        assertEq(stats.otherVotes, 0);
    }

    function test_FinalizeElection() public {
        // Add candidates
        election.addCandidate("Alice Johnson", NigeriaElection.Gender.Female, "Labour Party");
        election.addCandidate("Bob Smith", NigeriaElection.Gender.Male, "Progress Party");

        // Register voters
        election.registerVoter(voter1, 25, "ABC123", block.timestamp + 365 days, NigeriaElection.Gender.Male);
        election.registerVoter(voter2, 28, "XYZ789", block.timestamp + 365 days, NigeriaElection.Gender.Female);

        // Fast forward to voting period
        vm.warp(block.timestamp + 1 hours + 1);

        // Cast votes
        vm.prank(voter1);
        election.vote(0); // Vote for Alice

        vm.prank(voter2);
        election.vote(0); // Vote for Alice

        // Fast forward past voting end
        vm.warp(block.timestamp + 2 hours + 1);

        // Finalize election
        election.finalizeElection();

        assertTrue(election.electionFinalized());
        assertEq(election.getTotalVotes(), 2);
        assertEq(election.getTotalRegisteredVoters(), 2);
    }

    function test_GetVoterTurnout() public {
        // Register 3 voters
        election.registerVoter(voter1, 25, "ABC123", block.timestamp + 365 days, NigeriaElection.Gender.Male);
        election.registerVoter(voter2, 28, "XYZ789", block.timestamp + 365 days, NigeriaElection.Gender.Female);
        election.registerVoter(address(0x3), 30, "DEF456", block.timestamp + 365 days, NigeriaElection.Gender.Other);

        // Add candidate
        election.addCandidate("Test Candidate", NigeriaElection.Gender.Male, "Test Party");

        // Fast forward to voting period
        vm.warp(block.timestamp + 1 hours + 1);

        // Only 2 out of 3 vote
        vm.prank(voter1);
        election.vote(0);

        vm.prank(voter2);
        election.vote(0);

        // Check turnout (should be 66.66% = 6666 when multiplied by 100)
        uint256 turnout = election.getVoterTurnout();
        assertEq(turnout, 6666); // 2/3 * 10000 = 6666
    }

    function test_RevertWhen_VoterUnderAge() public {
        // Try to register underage voter
        vm.expectRevert(abi.encodeWithSelector(NigeriaElection.VoterUnderage.selector, 17));
        election.registerVoter(voter1, 17, "ABC123", block.timestamp + 365 days, NigeriaElection.Gender.Male);
    }

    function test_RevertWhen_VoteAfterVotingEnds() public {
        // Add candidate and register voter
        election.addCandidate("Test Candidate", NigeriaElection.Gender.Male, "Test Party");
        election.registerVoter(voter1, 25, "ABC123", block.timestamp + 365 days, NigeriaElection.Gender.Male);

        // Fast forward past voting end
        vm.warp(block.timestamp + 3 hours);

        // Try to vote (should fail)
        vm.expectRevert(abi.encodeWithSelector(NigeriaElection.VotingNotActive.selector, block.timestamp));
        vm.prank(voter1);
        election.vote(0);
    }

    function test_RemoveVoter() public {
        // Register a voter
        election.registerVoter(voter1, 25, "ABC123", block.timestamp + 365 days, NigeriaElection.Gender.Male);

        // Verify voter is registered
        assertTrue(election.isRegistered(voter1));
        assertEq(election.getTotalRegisteredVoters(), 1);

        // Remove the voter
        election.removeVoter(voter1);

        // Verify voter is removed
        assertFalse(election.isRegistered(voter1));
        assertEq(election.getTotalRegisteredVoters(), 0);

        // Check that gender stats are properly decremented
        NigeriaElection.GenderStats memory stats = election.getGenderStats();
        assertEq(stats.maleVoters, 0);
    }

    function test_TieHandling() public {
        // Add two candidates
        election.addCandidate("Alice Johnson", NigeriaElection.Gender.Female, "Labour Party");
        election.addCandidate("Bob Smith", NigeriaElection.Gender.Male, "Progress Party");

        // Register two voters
        election.registerVoter(voter1, 25, "ABC123", block.timestamp + 365 days, NigeriaElection.Gender.Male);
        election.registerVoter(voter2, 28, "XYZ789", block.timestamp + 365 days, NigeriaElection.Gender.Female);

        // Fast forward to voting period
        vm.warp(block.timestamp + 1 hours + 1);

        // Each voter votes for a different candidate (creating a tie)
        vm.prank(voter1);
        election.vote(0); // Vote for Alice

        vm.prank(voter2);
        election.vote(1); // Vote for Bob

        // Fast forward past voting end
        vm.warp(block.timestamp + 2 hours + 1);

        // Finalize election - should emit WinnerDeclared for both candidates
        election.finalizeElection();

        // Both candidates should have 1 vote each
        (, uint256 aliceVotes,,) = election.getResults(0);
        (, uint256 bobVotes,,) = election.getResults(1);
        assertEq(aliceVotes, 1);
        assertEq(bobVotes, 1);
    }

    function test_RevertWhen_EmptyCandidateName() public {
        vm.expectRevert(NigeriaElection.EmptyCandidateName.selector);
        election.addCandidate("", NigeriaElection.Gender.Male, "Test Party");
    }

    function test_RevertWhen_EmptyPartyName() public {
        vm.expectRevert(NigeriaElection.EmptyPartyName.selector);
        election.addCandidate("Test Candidate", NigeriaElection.Gender.Male, "");
    }

    function test_RevertWhen_InvalidVotingPeriod() public {
        uint256 futureTime = block.timestamp + 1 hours;
        vm.expectRevert(NigeriaElection.InvalidVotingPeriod.selector);
        election.setVotingPeriod(futureTime, futureTime); // start == end
    }
}
