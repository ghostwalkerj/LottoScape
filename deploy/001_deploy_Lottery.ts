import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  const LSCResult = await deploy('LSC', {
    from: deployer,
    args: [],
    log: true,
  });

  await deploy('LOTTOSCAPE', {
    from: deployer,
    args: [LSCResult.address],
    log: true,
  });
};

export default func;
func.tags = ['LSC', 'LOTTOSCAPE'];
