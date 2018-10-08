pragma solidity ^0.4.23;

import "../node_modules/openzeppelin-solidity/contracts/ReentrancyGuard.sol";
import "../node_modules/openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./usingOraclize.sol";

contract IgiCertificate is Ownable, ReentrancyGuard, usingOraclize {

  struct certificate {
    uint256 CertificateID;
    uint256 date;    //Its a timestamp would be initialized using the variable "now" while during traction, and would be parsed to humman readable format in Java script
    uint256 hash;  // Stores in ipfs, for tracking the details of the Diamond
  }
  //hash contains some details attribuites about the diomand, including the geo location where it was certified


  address private ContractAddress; //Can be used for emergency stop and for self mortal, Owner is Vlinder
  address private IgiAddress; // Only Igi could use this contract to add certificate, User is IGI
  uint32 certIdx = 0;
  //mapping (address => mapping (uint => address) ) ownerVsUser; //under owner How many users are transacting, owner is usually ContractAddress.
  //mapping (address => mapping (uint256 => certificate)) CertificateInfo; // only registered address could bale to access the certificate informations
  mapping (bytes32 => certificate) CertificateInfo;  //Ths is the mapping between the QueryID and the CErtificate details
  mapping (uint32 => bytes32) CertificateIdx;

  constructor(address igi) public {  // Igi address holds the administrator rights of this Contract
    ContractAddress = msg.sender;  //each time while the certificate is added the transactor address id added in the mapping
    IgiAddress = igi;
  }

  modifier AllowOnlyIgi (address _address) { require (msg.sender == _address); _;}

  event updateCertificateInfo(uint32 certIdx, uint256 certificataeID);
  event findingTrap(address);

  function AddCertificate(uint256 hash) external
    nonReentrant // modifier from ReentracyGuard OpenZeppelin Library protects against being called again
    AllowOnlyIgi(IgiAddress) returns (bool){ //External function would reduce the amount of gas consumption compared to public function
      //generate random number as a CertificateID, it would better If the TRNG is implemented.
      //TODO : Implement 1) get a random number from the library;
      oraclize_setProof(proofType_Ledger); // sets the Ledger authenticity proof
      uint N = 12; // number of random bytes we want the datasource to return
      uint delay = 0; // number of seconds to wait before the execution takes place
      uint callbackGas = 200000; // amount of gas we want Oraclize to set for the callback function
      bytes32 queryId = oraclize_newRandomDSQuery(delay, N, callbackGas); // this function internally generates the correct oraclize_query and returns its queryId
      CertificateInfo[queryId].date = now;
      CertificateInfo[queryId].hash = hash;
      CertificateIdx[certIdx] = queryId;
      certIdx++;
      return true; //this need to be changed if the random number generation fails
  }
  function __callback(bytes32 _queryId, string _result, bytes _proof) public
  {
      // if we reach this point successfully, it means that the attached authenticity proof has passed!
      require (msg.sender == oraclize_cbAddress());

      if (oraclize_randomDS_proofVerify__returnCode(_queryId, _result, _proof) != 0) {
          // the proof verification has failed, do we need to take any action here? (depends on the use case)
      } else {
          // the proof verification has passed

          // for simplicity of use, let's also convert the random bytes to uint if we need
          uint maxRange = 1000000; // this is the highest uint we want to get. It should never be greater than 2^(8*N), where N is the number of random bytes we had asked the datasource to return
          uint randomNumber = uint(sha3(_result)) % maxRange; // this is an efficient way to get the uint out in the [0, maxRange] range

          CertificateInfo[_queryId].CertificateID = randomNumber; // this is the resulting random number (uint)
          emit updateCertificateInfo(certIdx,CertificateInfo[_queryId].CertificateID);

      }
    }

  function GetCertificate(uint32 CertId) view external returns(uint256, uint256 , uint256){  //External function would reduce the amount of gas consumption compared to public function
    return (CertificateInfo[CertificateIdx[CertId]].CertificateID, CertificateInfo[CertificateIdx[certIdx]].date,  CertificateInfo[CertificateIdx[certIdx]].hash);
  }

  // Fallback function - Called if other functions don't match call or
  // sent ether without data
  // Typically, called when invalid data is sent
  // Added so ether sent to this contract is reverted if the contract fails
  // otherwise, the sender's money is transferred to contract
  function () public {
    if(IgiAddress != msg.sender)
      emit findingTrap(msg.sender);  //Just notify the front ens about the trap addres

    revert();
  }
  function Mortal () onlyOwner public {
    require(msg.sender == ContractAddress,"message sender is not owner");
    selfdestruct(ContractAddress);
  }

}
