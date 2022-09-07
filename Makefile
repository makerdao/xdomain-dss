all         :; forge build --use solc:0.8.13
clean       :; forge clean
test        :; ./test.sh $(match)
certora-vat :; certoraRun --solc ~/.solc-select/artifacts/solc-0.8.13 --rule_sanity basic src/Vat.sol --verify Vat:certora/Vat.spec --settings -mediumTimeout=300 --staging$(if $(short), --short_output,)$(if $(rule), --rule $(rule),)$(if $(multi), --multi_assert_check,)
