// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./MerkleTree.sol";
import "./verifier.sol";

contract Mixer is MerkleTree ,PlonkVerifier {
    mapping (uint256 => bool) public roots;
    mapping(uint256 => bool) public nullifierHashes;
    mapping(uint256 => bool) public commitments;

    event Deposit(uint256 indexed commitment, uint256 leafIndex, uint256 timestamp);
    event Withdraw(address to, uint256 nullifierHash);
    event Forward(uint256 indexed commitment, uint256 leafIndex, uint256 timestamp);

    // Constructor
    // TODO: Add the denomination to the mixer constructor to customize the denomination of the mixer as we deploy it
    constructor  (address _mimc) MerkleTree(_mimc) public {}

    // Deposit takes a commitment as a parameter
    // The commitment in inserted in the Merkle Tree of commitment
    function deposit(uint256 _commitment) public payable{
        require(!commitments[_commitment], "The commitment has been submitted");
        // Make sure the user paid the good denomination to append a commitment in the tree
        // (Need to pay AMOUNT ether to participate in the mixing)
        //require(msg.value == AMOUNT, "Amount not meet");
        uint256 insertedIndex = insert(_commitment);
        commitments[_commitment] = true;
        roots[getRoot()] = true;
        emit Deposit(_commitment,insertedIndex,block.timestamp);
    }

    // The withdraw function enables a user to redeem AMOUNT ether by providing a valid proof of knowledge of the secret
    function withdraw(
        bytes memory proof,
        uint[] memory input) public payable {
        uint256 _root = uint256(input[0]);
        uint256 _nullifierHash = uint256(input[1]);
        uint256 _amount = uint256(input[2]);

        require(!nullifierHashes[_nullifierHash], "The note has been already spent");
        require(isKnownRoot(_root), "Cannot find your merkle root"); // Make sure to use a recent one
        require(verifyProof(proof,input), "Invalid withdraw proof");

        nullifierHashes[_nullifierHash] = true;
        payable(msg.sender).transfer(_amount);
        emit Withdraw(msg.sender, _nullifierHash);
    }

    // The forward function enables a user who has been the recipient
    // of a "private payment" in the past
    // (thus possessing the secret associated with a non-spent nullifier, and a commitment in the tree)
    // to use it to pay someone else
    // (ie: "spend" his nullifier and creating a new commitment in the tree to pay someone else)
    function forward (
        bytes memory proof,
        uint[] memory input,
        uint256 _commitment
    ) public returns (address) {

        uint256 _nullifierHash = uint256(input[1]);
        uint256 _root = uint256(input[0]);

        require(!commitments[_commitment], "The commitment has been submitted");
        require(!nullifierHashes[_nullifierHash], "The note has been already spent");
        require(isKnownRoot(_root), "Cannot find your merkle root"); // Make sure to use a recent one
        require(verifyProof(proof,input), "Invalid withdraw proof");

        // We insert the new commitment in the tree once:
        // 1. We checked that the forward request was triggered by the recipient of a past payment who has an "unspent nullifier"
        // 2. The proof given is valid
        uint insertedIndex = insert(_commitment);
        roots[getRoot()] = true;
        // The caller of the "forward" function now has "spent" his nullifier to pay someone else
        // This allow for people to use the payments they receive as a way to pay others
        nullifierHashes[_nullifierHash] = true;
        emit Forward(_commitment,insertedIndex,block.timestamp);
    }

    function isKnownRoot(uint256 _root) public view returns(bool){
        return roots[_root];
    }

}
