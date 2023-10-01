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
      
    }
  }
}