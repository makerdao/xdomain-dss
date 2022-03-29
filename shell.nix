{ dappPkgs ? (
    import (fetchTarball "https://github.com/makerdao/makerpkgs/tarball/master") {}
  ).dappPkgsVersions.master-20220308
}: with dappPkgs;

mkShell {
  DAPP_SOLC = solc-static-versions.solc_0_8_12 + "/bin/solc-0.8.12";
  DAPP_TEST_ADDRESS = "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B";
  # No optimizations
  SOLC_FLAGS = "";
  buildInputs = [
    dapp
  ];
}
