object "ERC1155" {

  // constructor
  code {
    // the below runtime object code is deployed
    datacopy(0, dataoffset("runtime"), datasize("runtime"))
    return(0, datasize("runtime"))
  }

  // runtime code
  object "runtime" {
    code {
      // protection against sending Ether
      require(iszero(callvalue()))

      // Dispatcher
      switch selector()
      case 0xa22cb465 /* "setApprovalForAll(address,bool)" */ {
        setApprovalForAll(caller(), decodeAsAddress(0), decodeAsBool(1))
      }
      case 0xe985e9c5 /* "isApprovedForAll(address,address)" */ {}
      case 0x00fdd58e /* "balanceOf(address,uint256)" */ {}
      case 0x4e1273f4 /* "balanceOfBatch(address[],uint256[])" */ {}
      case 0xf242432a /* "safeTransferFrom(address,address,uint256,uint256,bytes)" */ {}
      case 0x2eb2c2d6 /* "safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)" */ {}
      case 0x731133e9 /* "mint(address,uint256,uint256,bytes)" */ {}
      case 0xf5298aca /* "burn(address,uint256,uint256,bytes)" */ {}
      case 0xb48ab8b6 /* "batchMint(address,uint256[],uint256[],bytes)" */ {}
      case 0xf6eb127a /* "batchBurn(address,uint256[],uint256[])" */ {}
      case 0x02fe5305 /* "setURI(string)" */ {}
      case 0x0e89341c /* "uri(uint256)" */ {}
      default {
        // revert if none of the above functions
        revert(0, 0)
      }

      function setApprovalForAll(account, operator, isApproved) {
        setApprovalForAllStorage(account, operator, isApproved)
        emitApprovalForAll(account, operator, isApproved)
      }

      /* -------- storage layout ---------- */
      function isApprovedForAllOffset(account, operator) -> offset {
        mstore(0, 0x1)
        mstore(0x20, account)
        mstore(0x40, operator)
        offset := keccak256(0, 0x60)
      }

      /* -------- storage access ---------- */
      function setApprovalForAllStorage(account, operator, isApproved) {
        sstore(isApprovedForAllOffset(account, operator), isApproved)
      }

      /* -------- events ---------- */
      function emitApprovalForAll(owner, operator, approved) /* ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved) */ {
        let signatureHash := 0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31
        mstore(0, approved)
        log3(0, 0x20, signatureHash, owner, operator)
      }

      /* ---------- calldata decoding functions ----------- */
      function selector() -> s {
        s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
      }

      function decodeAsAddress(offset) -> v {
        v := decodeAsUint(offset)
        if iszero(iszero(and(v, not(0xffffffffffffffffffffffffffffffffffffffff)))) {
            revert(0, 0)
        }
      }

      function decodeAsBool(offset) -> v {
        v := decodeAsUint(offset)
        if iszero(iszero(and(v, not(0x1)))) {
            revert(0, 0)
        }
      }

      function decodeAsUint(offset) -> v {
        let pos := add(4, mul(offset, 0x20))
        if lt(calldatasize(), add(pos, 0x20)) {
            revert(0, 0)
        }
        v := calldataload(pos)
      }

      /* ---------- calldata encoding functions ---------- */
      function returnUint(v) {
        mstore(0, v)
        return(0, 0x20)
      }

      /* ---------- utility functions ---------- */
      function require(condition) {
        if iszero(condition) { revert(0, 0) }
      }
    }
  }
}
