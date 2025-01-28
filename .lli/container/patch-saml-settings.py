import os
import sys

print('Patching SAML settings...')

if os.environ.get('NCLOUD_PATCH_SAML') != '1':
    print('-> Skipping')
    sys.exit(0)

target = '/ncloud/server/apps/user_saml/lib/SAMLSettings.php'

snippet = '''public function getOneLoginSettingsArray(int $idp): array {
        $settings = $this->_getOneLoginSettingsArray($idp);

        $baseUrl = '__NCLOUD_INTERNAL_HOST';
        if ($_SERVER['HTTP_X_LLI_SIDE'] == 'External') {
            $baseUrl = '__NCLOUD_EXTERNAL_HOST';
        }

        $settings['strict'] = false;
        $settings['sp']['entityId'] = 'https://' . $baseUrl . '/ncloud/index.php/apps/user_saml/saml/metadata';
        $settings['sp']['assertionConsumerService']['url'] = 'https://' . $baseUrl . '/ncloud/index.php/apps/user_saml/saml/acs';

        return $settings;
    }

	public function _getOneLoginSettingsArray(int $idp): array {
'''\
    .replace('__NCLOUD_INTERNAL_HOST', os.environ['NCLOUD_INTERNAL_HOST'])\
    .replace('__NCLOUD_EXTERNAL_HOST', os.environ['NCLOUD_EXTERNAL_HOST'])

with open(target) as fp:
    content = fp.read()

content = content.replace('public function getOneLoginSettingsArray(int $idp): array {', snippet)

with open(target, 'w') as fp:
    fp.write(content)

print('-> Done')
