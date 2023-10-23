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
      case 0xe985e9c5 /* "isApprovedForAll(address,address)" */ {
        returnUint(isApprovedForAll(decodeAsAddress(0), decodeAsAddress(1)))
      }
      case 0x00fdd58e /* "balanceOf(address,uint256)" */ {
        returnUint(balanceOf(decodeAsAddress(0), decodeAsUint(1)))
      }
      case 0x4e1273f4 /* "balanceOfBatch(address[],uint256[])" */ {
        let ownersOffset := calldataload(0x04)
        let ownersStartPos := add(ownersOffset, 0x04)
        let ownersLength := calldataload(ownersStartPos)

        let tokenIdsOffset := calldataload(0x24)
        let tokenIdsStartPos := add(tokenIdsOffset, 0x04)
        let tokenIdsLength := calldataload(tokenIdsStartPos)

        revertIfMismatchedLengths(ownersLength, tokenIdsLength)

        mstore(0x80, 0x20) 
        mstore(0xa0, ownersLength)

        let ownerPos := ownersStartPos
        let owner
        let tokenIdPos := tokenIdsStartPos
        let tokenId
        let tokenBalance
        for { let i := 0 } lt(i, ownersLength) { i := add(i, 1) } {
          tokenIdPos := add(tokenIdPos, 0x20)
          ownerPos := add(ownerPos, 0x20)
          
          owner := calldataload(ownerPos)
          tokenId := calldataload(tokenIdPos)

          tokenBalance := sload(balanceOfOffset(owner, tokenId))
          mstore(add(0xc0, mul(i, 0x20)), tokenBalance)
        }

        return(0x80, add(mul(ownersLength, 0x20), 0x40))
      }
      case 0xf242432a /* "safeTransferFrom(address,address,uint256,uint256,bytes)" */ {
        let from := decodeAsAddress(0)
        let to := decodeAsAddress(1)
        let tokenId := decodeAsUint(2)
        let amount := decodeAsUint(3)
        let operator := caller()

        revertIfNotAuthorised(from)

        let bytesOffset := calldataload(0x84)
        let bytesStartPos := add(bytesOffset, 0x04)

        deductFromBalance(from, tokenId, amount)
        addToBalance(to, tokenId, amount)
        emitTransferSingle(operator, from, to, tokenId, amount)

        if eq(extcodesize(to), 0) {
          if iszero(to) {
            revertWithUnsafeRecipient()
          }
        }
        if gt(extcodesize(to), 0) {
          mstore(0, 0xf23a6e6100000000000000000000000000000000000000000000000000000000)
          mstore(0x04, operator)
          mstore(0x24, from)
          mstore(0x44, tokenId)
          mstore(0x64, amount)
          // store bytes starting pos
          mstore(0x84, 0xa0)
          // copy bytes length and contents
          calldatacopy(0xa4, bytesStartPos, sub(calldatasize(), 0xa4))
          
          let success := call(
            gas(),
            to,
            0,
            0,
            calldatasize(),
            0,
            0x04
          )
          if iszero(success) {
            revertWithUnsafeRecipient()
          }
          let retVal := and(mload(0), 0xffffffff00000000000000000000000000000000000000000000000000000000)
          if iszero(eq(retVal, 0xf23a6e6100000000000000000000000000000000000000000000000000000000)) {
            revertWithUnsafeRecipient()
          }
        }
      }
      case 0x2eb2c2d6 /* "safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)" */ {
        let from := decodeAsAddress(0)
        let to := decodeAsAddress(1)
        revertIfNotAuthorised(from)

        let tokenIdsStartPos := add(calldataload(0x44), 0x04)
        let tokenIdsLength := calldataload(tokenIdsStartPos)

        let tokenQuantitiesStartPos := add(calldataload(0x64), 0x04)
        let tokenQuantitiesLength := calldataload(tokenQuantitiesStartPos)

        revertIfMismatchedLengths(tokenIdsLength, tokenQuantitiesLength)

        {
          let tokenIdPos := tokenIdsStartPos
          let tokenId
          let tokenQuantityPos := tokenQuantitiesStartPos
          let tokenQuantity
          for { let i := 0 } lt(i, tokenIdsLength) { i := add(i, 1) } {
            tokenIdPos := add(tokenIdPos, 0x20)
            tokenQuantityPos := add(tokenQuantityPos, 0x20)
            
            tokenId := calldataload(tokenIdPos)
            tokenQuantity := calldataload(tokenQuantityPos)

            deductFromBalance(from, tokenId, tokenQuantity)
            addToBalance(to, tokenId, tokenQuantity)
          }
        }

        {
          // TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] amounts)
          let signatureHash := 0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb
          mstore(0, 0x40)
          mstore(0x20, add(0x60, mul(tokenIdsLength, 0x20)))
          calldatacopy(0x40, tokenIdsStartPos, mul(add(tokenIdsLength, 1), 0x20))
          calldatacopy(add(0x40, mul(add(tokenIdsLength, 1), 0x20)), tokenQuantitiesStartPos, mul(add(tokenQuantitiesLength, 1), 0x20))
          let totalLength := add(tokenIdsLength, tokenQuantitiesLength)
          log4(0, mul(add(totalLength, 4), 0x20), signatureHash, caller(), from, to)
        }

        if eq(extcodesize(to), 0) {
          if iszero(to) {
            revertWithUnsafeRecipient()
          }
        }
        if gt(extcodesize(to), 0) {
          mstore(0, 0xbc197c8100000000000000000000000000000000000000000000000000000000)
          mstore(0x04, caller())
          mstore(0x24, from)
          mstore(0x44, 0xa0)
          mstore(0x64, add(0xc0, mul(tokenIdsLength, 0x20)))
          mstore(0x84, add(0xe0, mul(add(tokenIdsLength, tokenQuantitiesLength), 0x20)))
          calldatacopy(0xa4, tokenIdsStartPos, sub(calldatasize(), 0xa4))
          
          let success := call(
            gas(),
            to,
            0,
            0,
            calldatasize(),
            0,
            0x04
          )
          if iszero(success) {
            revertWithUnsafeRecipient()
          }
          let retVal := and(mload(0), 0xffffffff00000000000000000000000000000000000000000000000000000000)
          if iszero(eq(retVal, 0xbc197c8100000000000000000000000000000000000000000000000000000000)) {
            revertWithUnsafeRecipient()
          }
        }
      }
      case 0x731133e9 /* "mint(address,uint256,uint256,bytes)" */ {
        let to := decodeAsAddress(0)
        let tokenId := decodeAsUint(1)
        let amount := decodeAsUint(2)

        let bytesOffset := calldataload(0x64)
        let bytesStartPos := add(bytesOffset, 0x04)

        addToBalance(to, tokenId, amount)
        emitTransferSingle(caller(), 0x0, to, tokenId, amount)
        
        if eq(extcodesize(to), 0) {
          if iszero(to) {
            revertWithUnsafeRecipient()
          }
        }
        if gt(extcodesize(to), 0) {
          mstore(0, 0xf23a6e6100000000000000000000000000000000000000000000000000000000)
          mstore(0x04, caller())
          mstore(0x24, 0)
          mstore(0x44, tokenId)
          mstore(0x64, amount)
          // store bytes starting pos
          mstore(0x84, 0xa0)
          // copy bytes length and contents
          calldatacopy(0xa4, bytesStartPos, sub(calldatasize(), 0x84))
          
          let success := call(
            gas(),
            to,
            0,
            0,
            // we are sending one additional field compared to calldata
            add(calldatasize(), 0x20),
            0,
            0x04
          )
          if iszero(success) {
            revertWithUnsafeRecipient()
          }
          let retVal := and(mload(0), 0xffffffff00000000000000000000000000000000000000000000000000000000)
          if iszero(eq(retVal, 0xf23a6e6100000000000000000000000000000000000000000000000000000000)) {
            revertWithUnsafeRecipient()
          }
        }
      }
      case 0xf5298aca /* "burn(address,uint256,uint256,bytes)" */ {
        burn(decodeAsAddress(0), decodeAsUint(1), decodeAsUint(2))
      }
      case 0xb48ab8b6 /* "batchMint(address,uint256[],uint256[],bytes)" */ {
        let to := decodeAsAddress(0)

        let tokenIdsStartPos := add(calldataload(0x24), 0x04)
        let tokenIdsLength := calldataload(tokenIdsStartPos)

        let tokenQuantitiesStartPos := add(calldataload(0x44), 0x04)
        let tokenQuantitiesLength := calldataload(tokenQuantitiesStartPos)

        revertIfMismatchedLengths(tokenIdsLength, tokenQuantitiesLength)

        {
          let tokenIdPos := tokenIdsStartPos
          let tokenId
          let tokenQuantityPos := tokenQuantitiesStartPos
          let tokenQuantity
          for { let i := 0 } lt(i, tokenIdsLength) { i := add(i, 1) } {
            tokenIdPos := add(tokenIdPos, 0x20)
            tokenQuantityPos := add(tokenQuantityPos, 0x20)
            
            tokenId := calldataload(tokenIdPos)
            tokenQuantity := calldataload(tokenQuantityPos)

            addToBalance(to, tokenId, tokenQuantity)
          }
        }

        {
          // TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] amounts)
          let signatureHash := 0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb
          mstore(0, 0x40)
          mstore(0x20, add(0x60, mul(tokenIdsLength, 0x20)))
          calldatacopy(0x40, tokenIdsStartPos, mul(add(tokenIdsLength, 1), 0x20))
          calldatacopy(add(0x40, mul(add(tokenIdsLength, 1), 0x20)), tokenQuantitiesStartPos, mul(add(tokenQuantitiesLength, 1), 0x20))
          let eventDataLength := add(add(tokenIdsLength, tokenQuantitiesLength), 4)
          log4(0, mul(eventDataLength, 0x20), signatureHash, caller(), 0, to)
        }

        if eq(extcodesize(to), 0) {
          if iszero(to) {
            revertWithUnsafeRecipient()
          }
        }
        if gt(extcodesize(to), 0) {
          mstore(0, 0xbc197c8100000000000000000000000000000000000000000000000000000000)
          mstore(0x04, caller())
          mstore(0x24, 0)
          mstore(0x44, 0xa0)
          mstore(0x64, add(0xc0, mul(tokenIdsLength, 0x20)))
          mstore(0x84, add(0xe0, mul(add(tokenIdsLength, tokenQuantitiesLength), 0x20)))
          calldatacopy(0xa4, tokenIdsStartPos, sub(calldatasize(), 0x84))
          
          let success := call(
            gas(),
            to,
            0,
            0,
            // we are sending one additional field compared to calldata
            add(calldatasize(), 0x20),
            0,
            0x04
          )
          if iszero(success) {
            revertWithUnsafeRecipient()
          }
          let retVal := and(mload(0), 0xffffffff00000000000000000000000000000000000000000000000000000000)
          if iszero(eq(retVal, 0xbc197c8100000000000000000000000000000000000000000000000000000000)) {
            revertWithUnsafeRecipient()
          }
        }
      }
      case 0xf6eb127a /* "batchBurn(address,uint256[],uint256[])" */ {
        let from := decodeAsAddress(0)

        let tokenIdsStartPos := add(calldataload(0x24), 0x04)
        let tokenIdsLength := calldataload(tokenIdsStartPos)

        let tokenQuantitiesStartPos := add(calldataload(0x44), 0x04)
        let tokenQuantitiesLength := calldataload(tokenQuantitiesStartPos)

        revertIfMismatchedLengths(tokenIdsLength, tokenQuantitiesLength)

        {
          let tokenIdPos := tokenIdsStartPos
          let tokenId
          let tokenQuantityPos := tokenQuantitiesStartPos
          let tokenQuantity
          for { let i := 0 } lt(i, tokenIdsLength) { i := add(i, 1) } {
            tokenIdPos := add(tokenIdPos, 0x20)
            tokenQuantityPos := add(tokenQuantityPos, 0x20)
            
            tokenId := calldataload(tokenIdPos)
            tokenQuantity := calldataload(tokenQuantityPos)

            deductFromBalance(from, tokenId, tokenQuantity)
          }
        }

        {
          // TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] amounts)
          let signatureHash := 0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb
          mstore(0, 0x40)
          mstore(0x20, add(0x60, mul(tokenIdsLength, 0x20)))
          calldatacopy(0x40, tokenIdsStartPos, mul(add(tokenIdsLength, 1), 0x20))
          calldatacopy(add(0x40, mul(add(tokenIdsLength, 1), 0x20)), tokenQuantitiesStartPos, mul(add(tokenQuantitiesLength, 1), 0x20))
          let eventDataLength := add(add(tokenIdsLength, tokenQuantitiesLength), 4)
          log4(0, mul(eventDataLength, 0x20), signatureHash, caller(), from, 0)
        }
      }
      case 0x02fe5305 /* "setURI(string)" */ {
        let lengthOffset, dataOffset := uriOffset()

        let uriStartPos := add(calldataload(0x04), 0x04)
        let uriLength := calldataload(uriStartPos)
        sstore(lengthOffset, uriLength)

        let uriPos := uriStartPos
        let uriFragment
        for { let i := 0 } lt(i, sub(calldatasize(), 0x44)) { i := add(i, 0x20) } {
          uriPos := add(uriPos, 0x20)
          uriFragment := calldataload(uriPos)
          sstore(dataOffset, uriFragment)
          dataOffset := add(dataOffset, 0x20)
        }
      }
      case 0x0e89341c /* "uri(uint256)" */ {
        let lengthOffset, dataOffset := uriOffset()

        let uriLength := sload(lengthOffset)
        mstore(0, 0x20)
        mstore(0x20, uriLength)

        let uriFragment
        let bytesWritten := 0
        for {} lt(bytesWritten, uriLength) {} {
          uriFragment := sload(dataOffset)
          mstore(add(bytesWritten, 0x40), uriFragment)
          bytesWritten := add(bytesWritten, 0x20)
          dataOffset := add(dataOffset, 0x20)
        }

        return (0, add(bytesWritten, 0x40))
      }
      default {
        // revert if none of the above functions
        revert(0, 0)
      }

      function setApprovalForAll(account, operator, isApproved) {
        setApprovalForAllStorage(account, operator, isApproved)
        emitApprovalForAll(account, operator, isApproved)
      }

      function burn(from, tokenId, amount) {
        deductFromBalance(from, tokenId, amount)
        emitTransferSingle(caller(), from, 0x0, tokenId, amount)
      }

      /* -------- storage layout ---------- */
      function isApprovedForAllOffset(account, operator) -> offset {
        mstore(0, 0x1)
        mstore(0x20, account)
        mstore(0x40, operator)
        offset := keccak256(0, 0x60)
      }
      function balanceOfOffset(account, tokenId) -> offset {
        mstore(0, 0x2)
        mstore(0x20, account)
        mstore(0x40, tokenId)
        offset := keccak256(0, 0x60)
      }
      function uriOffset() -> lengthOffset, dataOffset {
        lengthOffset := 0x01
        mstore(0, 0x1)
        dataOffset := keccak256(0, 0x20)
      }

      /* -------- storage access ---------- */
      function setApprovalForAllStorage(account, operator, isApproved) {
        sstore(isApprovedForAllOffset(account, operator), isApproved)
      }
      function isApprovedForAll(account, operator) -> isApproved {
        isApproved := sload(isApprovedForAllOffset(account, operator))
      }
      function balanceOf(account, tokenId) -> tokenBalance {
        tokenBalance := sload(balanceOfOffset(account, tokenId))
      }
      function addToBalance(account, tokenId, amount) {
        let offset := balanceOfOffset(account, tokenId)
        sstore(offset, safeAdd(sload(offset), amount))
      }
      function deductFromBalance(account, tokenId, amount) {
        let offset := balanceOfOffset(account, tokenId)
        let bal := sload(offset)
        require(lte(amount, bal))
        sstore(offset, sub(bal, amount))
      }

      /* -------- events ---------- */
      function emitApprovalForAll(owner, operator, approved) /* ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved) */ {
        let signatureHash := 0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31
        mstore(0, approved)
        log3(0, 0x20, signatureHash, owner, operator)
      }
      function emitTransferSingle(operator, from, to, tokenId, value) /* TransferSingle(address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _value) */ {
        let signatureHash := 0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62
        mstore(0, tokenId)
        mstore(0x20, value)
        log4(0, 0x40, signatureHash, operator, from, to)
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
      function revertIfNotAuthorised(from) {
        let isAuthorised := or(eq(caller(), from), isApprovedForAll(from, caller()))
        if iszero(isAuthorised) {
          mstore(0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
          mstore(0x4, 0x20)
          mstore(0x24, 0xe)
          mstore(0x44, "NOT_AUTHORIZED")
          revert(0, 0x64)
        }
      }
      function revertIfMismatchedLengths(len1, len2) {
        if iszero(eq(len1, len2)) {
          mstore(0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
          mstore(0x4, 0x20)
          mstore(0x24, 0xf)
          mstore(0x44, "LENGTH_MISMATCH")
          revert(0, 0x64)
        }
      }
      function revertWithUnsafeRecipient() {
        mstore(0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
        mstore(0x4, 0x20)
        mstore(0x24, 0x10)
        mstore(0x44, "UNSAFE_RECIPIENT")
        revert(0, 0x64)
      }
      function lte(a, b) -> r {
        r := iszero(gt(a, b))
      }
      function safeAdd(a, b) -> r {
        r := add(a, b)
        if or(lt(r, a), lt(r, b)) { revert(0, 0) }
      }
    }
  }
}
