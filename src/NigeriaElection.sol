// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract NigeriaElection {
    enum Gender {
        Male,
        Female,
        Other
    }

    struct Candidate {
        string name;
        uint256 voteCount;
        Gender gender;
        string party;
    }

    struct Voter {
        bool registered;
        bool voted;
        uint256 age;
        string cardId;
        uint256 cardExpiry;
        Gender gender;
    }

    struct GenderStats {
        uint256 maleVotes;
        uint256 femaleVotes;
        uint256 otherVotes;
        uint256 maleVoters;
        uint256 femaleVoters;
        uint256 otherVoters;
    }

    // Custom Errors
    error NotAdmin(address caller);
    error VotingNotActive(uint256 currentTime);
    error VoterUnderage(uint256 age);
    error CardAlreadyUsed(string cardId);
    error CardExpired(string cardId);
    error VoterNotRegistered(address voter);
    error AlreadyVoted(address voter);
    error InvalidCandidate(uint256 candidateId);
    error VotingAlreadyEnded();
    error VotingNotEnded();
    error InvalidVotingPeriod();
    error StartTimeMustBeFuture();
    error EmptyCandidateName();
    error EmptyPartyName();
    error VoterAlreadyRegistered(address voter);

    address public admin;
    mapping(uint256 => Candidate) public candidates;
    mapping(address => Voter) public voters;
    mapping(string => bool) public usedCards;

    uint256 public candidateCount;
    uint256 public votingStart;
    uint256 public votingEnd;
    GenderStats public genderStats;
    bool public electionFinalized;

    // Events
    event VoteCast(address indexed voter, uint256 indexed candidateId, Gender voterGender);
    event VoterRegistered(address indexed voter, uint256 age, Gender gender);
    event CandidateAdded(uint256 indexed candidateId, string name, Gender gender, string party);
    event VotingPeriodSet(uint256 start, uint256 end);
    event ElectionFinalized(uint256 totalVotes, uint256 timestamp);
    event WinnerDeclared(uint256 indexed candidateId, string name, uint256 voteCount);

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin(msg.sender);
        _;
    }

    modifier votingActive() {
        if (block.timestamp < votingStart || block.timestamp > votingEnd) {
            revert VotingNotActive(block.timestamp);
        }
        _;
    }

    modifier votingEnded() {
        if (block.timestamp <= votingEnd) revert VotingNotEnded();
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    // Internal helper functions to reduce redundancy
    function _updateGenderVoterStats(Gender gender, bool increment) internal {
        if (increment) {
            if (gender == Gender.Male) {
                genderStats.maleVoters++;
            } else if (gender == Gender.Female) {
                genderStats.femaleVoters++;
            } else {
                genderStats.otherVoters++;
            }
        } else {
            if (gender == Gender.Male) {
                genderStats.maleVoters--;
            } else if (gender == Gender.Female) {
                genderStats.femaleVoters--;
            } else {
                genderStats.otherVoters--;
            }
        }
    }

    function _updateGenderVoteStats(Gender gender) internal {
        if (gender == Gender.Male) {
            genderStats.maleVotes++;
        } else if (gender == Gender.Female) {
            genderStats.femaleVotes++;
        } else {
            genderStats.otherVotes++;
        }
    }

    function _getTotalVotes() internal view returns (uint256) {
        return genderStats.maleVotes + genderStats.femaleVotes + genderStats.otherVotes;
    }

    function _getTotalRegisteredVoters() internal view returns (uint256) {
        return genderStats.maleVoters + genderStats.femaleVoters + genderStats.otherVoters;
    }

    // Admin sets voting period
    function setVotingPeriod(uint256 start, uint256 end) external onlyAdmin {
        if (electionFinalized) revert VotingAlreadyEnded();
        if (start >= end) revert InvalidVotingPeriod();
        if (start <= block.timestamp) revert StartTimeMustBeFuture();

        votingStart = start;
        votingEnd = end;
        emit VotingPeriodSet(start, end);
    }

    // Admin adds candidates with gender and party
    function addCandidate(string memory name, Gender gender, string memory party) external onlyAdmin {
        if (electionFinalized) revert VotingAlreadyEnded();
        if (bytes(name).length == 0) revert EmptyCandidateName();
        if (bytes(party).length == 0) revert EmptyPartyName();

        candidates[candidateCount] = Candidate(name, 0, gender, party);
        emit CandidateAdded(candidateCount, name, gender, party);
        candidateCount++;
    }

    // Admin registers voters with gender
    function registerVoter(address voter, uint256 age, string memory cardId, uint256 expiry, Gender gender)
        external
        onlyAdmin
    {
        if (age < 18) revert VoterUnderage(age);
        if (usedCards[cardId]) revert CardAlreadyUsed(cardId);
        if (expiry <= block.timestamp) revert CardExpired(cardId);
        if (voters[voter].registered) revert VoterAlreadyRegistered(voter);

        voters[voter] = Voter(true, false, age, cardId, expiry, gender);
        usedCards[cardId] = true;

        // Update gender stats for registered voters using helper function
        _updateGenderVoterStats(gender, true);

        emit VoterRegistered(voter, age, gender);
    }

    // Admin can remove voter registration (only before voting starts)
    function removeVoter(address voter) external onlyAdmin {
        if (electionFinalized) revert VotingAlreadyEnded();
        if (block.timestamp >= votingStart) revert("Cannot remove voter after voting starts");
        if (!voters[voter].registered) revert VoterNotRegistered(voter);

        // Update gender stats using helper function
        _updateGenderVoterStats(voters[voter].gender, false);

        // Mark card as unused again
        usedCards[voters[voter].cardId] = false;

        // Remove voter
        delete voters[voter];
    }

    // Voters cast votes
    function vote(uint256 candidateId) external votingActive {
        Voter storage voter = voters[msg.sender];

        if (!voter.registered) revert VoterNotRegistered(msg.sender);
        if (voter.voted) revert AlreadyVoted(msg.sender);
        if (voter.cardExpiry <= block.timestamp) revert CardExpired(voter.cardId);
        if (candidateId >= candidateCount) revert InvalidCandidate(candidateId);

        voter.voted = true;
        candidates[candidateId].voteCount++;

        // Update gender vote stats using helper function
        _updateGenderVoteStats(voter.gender);

        emit VoteCast(msg.sender, candidateId, voter.gender);
    }

    // Finalize election (can only be called after voting ends)
    function finalizeElection() external onlyAdmin votingEnded {
        if (electionFinalized) revert VotingAlreadyEnded();

        electionFinalized = true;
        uint256 totalVotes = _getTotalVotes();

        emit ElectionFinalized(totalVotes, block.timestamp);

        // Find and emit winner(s) - handles ties better
        if (totalVotes > 0) {
            _declareWinner();
        }
    }

    // Internal function to find and declare winner(s)
    function _declareWinner() internal {
        uint256 winningVotes = 0;

        // First pass: find the highest vote count
        for (uint256 i = 0; i < candidateCount; i++) {
            if (candidates[i].voteCount > winningVotes) {
                winningVotes = candidates[i].voteCount;
            }
        }

        // Second pass: emit event for all candidates with winning votes (handles ties)
        for (uint256 i = 0; i < candidateCount; i++) {
            if (candidates[i].voteCount == winningVotes) {
                emit WinnerDeclared(i, candidates[i].name, winningVotes);
            }
        }
    }

    // View results
    function getResults(uint256 candidateId)
        external
        view
        returns (string memory name, uint256 votes, Gender gender, string memory party)
    {
        if (candidateId >= candidateCount) revert InvalidCandidate(candidateId);
        Candidate memory candidate = candidates[candidateId];
        return (candidate.name, candidate.voteCount, candidate.gender, candidate.party);
    }

    // Get gender statistics
    function getGenderStats() external view returns (GenderStats memory) {
        return genderStats;
    }

    // Get total votes cast
    function getTotalVotes() external view returns (uint256) {
        return _getTotalVotes();
    }

    // Get total registered voters
    function getTotalRegisteredVoters() external view returns (uint256) {
        return _getTotalRegisteredVoters();
    }

    // Get voter turnout percentage (returns percentage * 100 to avoid decimals)
    function getVoterTurnout() external view returns (uint256) {
        uint256 totalRegistered = _getTotalRegisteredVoters();
        if (totalRegistered == 0) return 0;

        uint256 totalVotes = _getTotalVotes();
        return (totalVotes * 10000) / totalRegistered; // Returns percentage * 100
    }

    // Get all candidates (for display purposes)
    function getAllCandidates()
        external
        view
        returns (
            uint256[] memory ids,
            string[] memory names,
            uint256[] memory votes,
            Gender[] memory genders,
            string[] memory parties
        )
    {
        ids = new uint256[](candidateCount);
        names = new string[](candidateCount);
        votes = new uint256[](candidateCount);
        genders = new Gender[](candidateCount);
        parties = new string[](candidateCount);

        for (uint256 i = 0; i < candidateCount; i++) {
            ids[i] = i;
            names[i] = candidates[i].name;
            votes[i] = candidates[i].voteCount;
            genders[i] = candidates[i].gender;
            parties[i] = candidates[i].party;
        }
    }

    // Check if address has voted
    function hasVoted(address voter) external view returns (bool) {
        return voters[voter].voted;
    }

    // Check if address is registered
    function isRegistered(address voter) external view returns (bool) {
        return voters[voter].registered;
    }
}
