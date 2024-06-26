<?php

/**
 * SPDX-FileCopyrightText: 2016-2024 Nextcloud GmbH and Nextcloud contributors
 * SPDX-FileCopyrightText: 2016 ownCloud, Inc.
 * SPDX-License-Identifier: AGPL-3.0-only
 */
namespace OC\Core\Command\Encryption;

use OCP\Encryption\IManager;
use OCP\IConfig;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;

class Enable extends Command {
	public function __construct(
		protected IConfig $config,
		protected IManager $encryptionManager,
	) {
		parent::__construct();
	}

	protected function configure() {
		$this
			->setName('encryption:enable')
			->setDescription('Enable encryption')
		;
	}

	protected function execute(InputInterface $input, OutputInterface $output): int {
		if ($this->config->getAppValue('core', 'encryption_enabled', 'no') === 'yes') {
			$output->writeln('Encryption is already enabled');
		} else {
			$this->config->setAppValue('core', 'encryption_enabled', 'yes');
			$output->writeln('<info>Encryption enabled</info>');
		}
		$output->writeln('');

		$modules = $this->encryptionManager->getEncryptionModules();
		if (empty($modules)) {
			$output->writeln('<error>No encryption module is loaded</error>');
			return 1;
		}
		$defaultModule = $this->config->getAppValue('core', 'default_encryption_module', null);
		if ($defaultModule === null) {
			$output->writeln('<error>No default module is set</error>');
			return 1;
		}
		if (!isset($modules[$defaultModule])) {
			$output->writeln('<error>The current default module does not exist: ' . $defaultModule . '</error>');
			return 1;
		}
		$output->writeln('Default module: ' . $defaultModule);

		return 0;
	}
}
