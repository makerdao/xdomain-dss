all         :; forge build --use solc:0.8.13
clean       :; forge clean
test        :; ./test.sh $(match)
certora-vat :; PATH=~/.solc-select/artifacts/solc-0.8.13:~/.solc-select/artifacts/:${PATH} certoraRun --solc_map Vat=solc-0.8.13 --optimize_map Vat=200 --rule_sanity basic src/Vat.sol --verify Vat:certora/Vat.spec --settings -mediumTimeout=180,-deleteSMTFile=false,-postProcessCounterExamples=none,-t=1200$(if $(short), --short_output,)$(if $(rule), --rule $(rule),)$(if $(multi), --multi_assert_check,)
certora-dai :; PATH=~/.solc-select/artifacts/solc-0.8.13:~/.solc-select/artifacts:${PATH} certoraRun --solc_map Dai=solc-0.8.13,Auxiliar=solc-0.8.13,SignerMock=solc-0.8.13 --optimize_map Dai=200,Auxiliar=0,SignerMock=0 --rule_sanity basic src/Dai.sol certora/Auxiliar.sol certora/SignerMock.sol --verify Dai:certora/Dai.spec --settings -mediumTimeout=180 --optimistic_loop$(if $(short), --short_output,)$(if $(rule), --rule $(rule),)$(if $(multi), --multi_assert_check,)
