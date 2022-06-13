const Tests = artifacts.require('Tests')

module.exports = (deployer) => deployer.deploy(Tests, {gas: '1000000000'})
