<?php
/**
 * @copyright Copyright (c) 2017 Joas Schilling <coding@schilljs.com>
 *
 * @author Arthur Schiwon <blizzz@arthur-schiwon.de>
 * @author Christoph Wurst <christoph@winzerhof-wurst.at>
 * @author Joas Schilling <coding@schilljs.com>
 * @author Morris Jobke <hey@morrisjobke.de>
 * @author Thomas Citharel <nextcloud@tcit.fr>
 *
 * @license GNU AGPL version 3 or any later version
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */
namespace OCA\Settings;

use OCA\Settings\Activity\Provider;
use OCP\Activity\IManager as IActivityManager;
use OCP\Defaults;
use OCP\IConfig;
use OCP\IGroupManager;
use OCP\IURLGenerator;
use OCP\IUser;
use OCP\IUserManager;
use OCP\IUserSession;
use OCP\L10N\IFactory;
use OCP\Mail\IMailer;

class Hooks {

	/** @var IActivityManager */
	protected $activityManager;
	/** @var IGroupManager|\OC\Group\Manager */
	protected $groupManager;
	/** @var IUserManager */
	protected $userManager;
	/** @var IUserSession */
	protected $userSession;
	/** @var IURLGenerator */
	protected $urlGenerator;
	/** @var IMailer */
	protected $mailer;
	/** @var IConfig */
	protected $config;
	/** @var IFactory */
	protected $languageFactory;
	/** @var Defaults */
	protected $defaults;

	public function __construct(IActivityManager $activityManager,
		IGroupManager $groupManager,
		IUserManager $userManager,
		IUserSession $userSession,
		IURLGenerator $urlGenerator,
		IMailer $mailer,
		IConfig $config,
		IFactory $languageFactory,
		Defaults $defaults) {
		$this->activityManager = $activityManager;
		$this->groupManager = $groupManager;
		$this->userManager = $userManager;
		$this->userSession = $userSession;
		$this->urlGenerator = $urlGenerator;
		$this->mailer = $mailer;
		$this->config = $config;
		$this->languageFactory = $languageFactory;
		$this->defaults = $defaults;
	}

	/**
	 * @param string $uid
	 * @throws \InvalidArgumentException
	 * @throws \BadMethodCallException
	 * @throws \Exception
	 */
	public function onChangePassword($uid) {
		$user = $this->userManager->get($uid);

		if (!$user instanceof IUser || $user->getLastLogin() === 0) {
			// User didn't login, so don't create activities and emails.
			return;
		}

		$event = $this->activityManager->generateEvent();
		$event->setApp('settings')
			->setType('personal_settings')
			->setAffectedUser($user->getUID());

		$instanceName = $this->defaults->getName();
		$instanceUrl = $this->urlGenerator->getAbsoluteURL('/');
		$language = $this->languageFactory->getUserLanguage($user);
		$l = $this->languageFactory->get('settings', $language);

		$actor = $this->userSession->getUser();
		if ($actor instanceof IUser) {
			if ($actor->getUID() !== $user->getUID()) {
				// Admin changed the password through the user panel
				$text = $l->t('%1$s changed your password on %2$s.', [$actor->getDisplayName(), $instanceUrl]);
				$event->setAuthor($actor->getUID())
					->setSubject(Provider::PASSWORD_CHANGED_BY, [$actor->getUID()]);
			} else {
				// User changed their password themselves through settings
				$text = $l->t('Your password on %s was changed.', [$instanceUrl]);
				$event->setAuthor($actor->getUID())
					->setSubject(Provider::PASSWORD_CHANGED_SELF);
			}
		} else {
			if (\OC::$CLI) {
				// Admin used occ to reset the password
				$text = $l->t('Your password on %s was reset by an administrator.', [$instanceUrl]);
				$event->setSubject(Provider::PASSWORD_RESET);
			} else {
				// User reset their password from Lost page
				$text = $l->t('Your password on %s was reset.', [$instanceUrl]);
				$event->setSubject(Provider::PASSWORD_RESET_SELF);
			}
		}

		$this->activityManager->publish($event);

		if ($user->getEMailAddress() !== null) {
			$template = $this->mailer->createEMailTemplate('settings.PasswordChanged', [
				'displayname' => $user->getDisplayName(),
				'emailAddress' => $user->getEMailAddress(),
				'instanceUrl' => $instanceUrl,
			]);

			$template->setSubject($l->t('Password for %1$s changed on %2$s', [$user->getDisplayName(), $instanceName]));
			$template->addHeader();
			$template->addHeading($l->t('Password changed for %s', [$user->getDisplayName()]), false);

			// -- XXX CDSP custom email body -- start
			$template->addBodyText($this->l->t("Le français suit"));
			$template->addBodyText($this->l->t("This is an automated message. Please do not reply to this email address."));
			$template->addBodyText($this->l->t("Dear %s", [$user->getDisplayName(), $instanceUrl]));
			$template->addBodyText($this->l->t("Your user account on the Living Labs Cloud Data Storage Platform (LL-CDSP) has requested a password change."));
			$template->addBodyText($this->l->t("You can log in to the LL-CDSP with your existing username and new password at https://lli.agr.gc.ca/ncloud/index.php/"));
			$template->addBodyText($this->l->t("For any additional assistance, please email: aafc.livinglaboratories-laboratoiresvivants.aac@canada.ca "));


			$template->addBodyText($this->l->t("_______________________________________________"));


			$template->addBodyText($this->l->t("Il s'agit d'un message automatisé. Veuillez ne pas répondre à ce courriel.  "));
			$template->addBodyText($this->l->t("Bonjour %s ", [$user->getDisplayName(), $instanceUrl]));
			$template->addBodyText($this->l->t("Une demande de changement de mot de passe a été demandé pour votre compte d'utilisateur de la plateforme de stockage de données infonuagique des laboratoires vivants (PSDI-LV)."));
			$template->addBodyText($this->l->t("Vous pouvez vous connecter à la PSDI-LV en utilisant votre nom d’utilisateur et nouveau mot de passe à l'adresse https://lli.agr.gc.ca/ncloud/index.php/ "));
			$template->addBodyText($this->l->t("Pour toute aide supplémentaire, veuillez envoyer un courriel à : aafc.livinglaboratories-laboratoiresvivants.aac@canada.ca "));
			// -- XXX CDSP custom email body -- end
			$template->addFooter();


			$message = $this->mailer->createMessage();
			$message->setTo([$user->getEMailAddress() => $user->getDisplayName()]);
			$message->useTemplate($template);
			$this->mailer->send($message);
		}
	}

	/**
	 * @param IUser $user
	 * @param string|null $oldMailAddress
	 * @throws \InvalidArgumentException
	 * @throws \BadMethodCallException
	 */
	public function onChangeEmail(IUser $user, $oldMailAddress) {
		if ($oldMailAddress === $user->getEMailAddress() ||
			$user->getLastLogin() === 0) {
			// Email didn't really change or user didn't login,
			// so don't create activities and emails.
			return;
		}

		$event = $this->activityManager->generateEvent();
		$event->setApp('settings')
			->setType('personal_settings')
			->setAffectedUser($user->getUID());

		$instanceUrl = $this->urlGenerator->getAbsoluteURL('/');
		$language = $this->languageFactory->getUserLanguage($user);
		$l = $this->languageFactory->get('settings', $language);

		$actor = $this->userSession->getUser();
		if ($actor instanceof IUser) {
			$subject = Provider::EMAIL_CHANGED_SELF;
			if ($actor->getUID() !== $user->getUID()) {
				// set via the OCS API
				if ($this->config->getAppValue('settings', 'disable_activity.email_address_changed_by_admin', 'no') === 'yes') {
					return;
				}
				$subject = Provider::EMAIL_CHANGED;
			}
			$text = $l->t('Your email address on %s was changed.', [$instanceUrl]);
			$event->setAuthor($actor->getUID())
				->setSubject($subject);
		} else {
			// set with occ
			if ($this->config->getAppValue('settings', 'disable_activity.email_address_changed_by_admin', 'no') === 'yes') {
				return;
			}
			$text = $l->t('Your email address on %s was changed by an administrator.', [$instanceUrl]);
			$event->setSubject(Provider::EMAIL_CHANGED);
		}
		$this->activityManager->publish($event);


		if ($oldMailAddress !== null) {
			$template = $this->mailer->createEMailTemplate('settings.EmailChanged', [
				'displayname' => $user->getDisplayName(),
				'newEMailAddress' => $user->getEMailAddress(),
				'oldEMailAddress' => $oldMailAddress,
				'instanceUrl' => $instanceUrl,
			]);

			$template->setSubject($l->t('Email address for %1$s changed on %2$s', [$user->getDisplayName(), $instanceUrl]));
			$template->addHeader();
			$template->addHeading($l->t('Email address changed for %s', [$user->getDisplayName()]), false);

			if ($user->getEMailAddress()) {
				$template->addBodyText($l->t('The new email address is %s', [$user->getEMailAddress()]));
				// -- TODO - remove hardcoded email, url and app name; get from conf file in theme
				// -- XXX CDSP custom email body -- start
				$template->addBodyText($this->l->t("Le français suit"));

				$template->addBodyText($this->l->t("This is an automated message. Please do not reply to this email address."));
				$template->addBodyText($this->l->t("Dear %s ", [$user->getDisplayName(), $instanceUrl]));
				$template->addBodyText($this->l->t("Your user account on the Living Labs Cloud Data Storage Platform (LL-CDSP) has requested an email address change."));
				$template->addBodyText($this->l->t("This message is to confirm that the contact email address for "));
				$template->addBodyText($this->l->t('Username %s', [$user->getDisplayName()]), false);
				$template->addBodyText($this->l->t("Has been changed to"));

			if ($user->getEMailAddress()) {
				$template->addBodyText($l->t('The new email address is %s', [$user->getEMailAddress()]));
			}
			$template->addBodyText($this->l->t("You can log in to the LL-CDSP with your existing username and password at: https://lli.agr.gc.ca/ncloud/index.php/"));
			$template->addBodyText($this->l->t("For any additional assistance, please email: aafc.livinglaboratories-laboratoiresvivants.aac@canada.ca "));


			$template->addBodyText($this->l->t("_______________________________________________"));


			$template->addBodyText($this->l->t("Il s'agit d'un message automatisé. Veuillez ne pas répondre à ce courriel.  "));
			$template->addBodyText($this->l->t("Bonjour %s ", [$user->getDisplayName(), $instanceUrl]));
			$template->addBodyText($this->l->t("Un changement d’adresse de courriel a été demandé pour votre compte d'utilisateur de la plateforme de stockage de données infonuagique des laboratoires vivants (PSDI-LV). "));
			$template->addBodyText($this->l->t("Le présent message a pour but de confirmer que l'adresse électronique de contact de :"));
			$template->addBodyText($this->l->t('Nom d’utilisateur  %s', [$user->getDisplayName()]), false);
			$template->addBodyText($this->l->t("a été modifié pour "));

			if ($user->getEMailAddress()) {
				$template->addBodyText($this->l->t('%s', [$user->getEMailAddress()]));
			}
			$template->addBodyText($this->l->t("Vous pouvez vous connecter à la PSDI-LV en utilisant votre nom d’utilisateur et mot de passe à l'adresse https://lli.agr.gc.ca/ncloud/index.php/ "));

			$template->addBodyText($this->l->t("Pour toute aide supplémentaire, veuillez envoyer un courriel à : aafc.livinglaboratories-laboratoiresvivants.aac@canada.ca   "));

			}
			// -- XXX CDSP custom email body -- end
			$template->addFooter();


			$message = $this->mailer->createMessage();
			$message->setTo([$oldMailAddress => $user->getDisplayName()]);
			$message->useTemplate($template);
			$this->mailer->send($message);
		}
	}
}
