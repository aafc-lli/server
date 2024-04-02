<template>
	<ul>
		<SharingEntrySimple ref="shareEntrySimple"
			class="sharing-entry__internal"
			:title="t('files_sharing', 'Internal link')"
			:subtitle="internalLinkSubtitle">
			<template #avatar>
				<div class="avatar-external icon-external-white" />
			</template>

			<NcActionButton :title="copyLinkTooltip"
				:aria-label="copyLinkTooltip"
				@click="copyLink">
				<template #icon>
					<CheckIcon v-if="copied && copySuccess"
						:size="20"
						class="icon-checkmark-color" />
					<ClipboardIcon v-else :size="20" />
				</template>
			</NcActionButton>
		</SharingEntrySimple>
	</ul>
</template>

<script>
import { generateUrl } from '@nextcloud/router'
import { showSuccess } from '@nextcloud/dialogs'
import NcActionButton from '@nextcloud/vue/dist/Components/NcActionButton.js'

import CheckIcon from 'vue-material-design-icons/CheckBold.vue'
import ClipboardIcon from 'vue-material-design-icons/ClipboardFlow.vue'

import SharingEntrySimple from './SharingEntrySimple.vue'

export default {
	name: 'SharingEntryInternal',

	components: {
		NcActionButton,
		SharingEntrySimple,
		CheckIcon,
		ClipboardIcon,
	},

	props: {
		fileInfo: {
			type: Object,
			default: () => {},
			required: true,
		},
	},

	data() {
		return {
			copied: false,
			copySuccess: false,
		}
	},

	computed: {
		/**
		 * Get the internal link to this file id
		 *
		 * @return {string}
		 */
		internalLink() {
			// XXX CDSP -- start
			
			// TODO: Using a hardcoded URL is not good. We should add the interal and external url to the defaults.php in theme,
			// write it to the the page, and grab it with JS. We can determine whether we are internal or external using the 'Side'
			// cookie that is set

			// Generate the base link using fileInfo.id
			const baseLink = window.location.protocol + '//' + window.location.host + generateUrl('/f/') + this.fileInfo.id;
			let otherLink = '';
			let internal = false;

			// Determine if the current host is internal and generate the alternate link accordingly
			if (window.location.host.includes('lli')) {
				internal = true;
				otherLink = window.location.protocol + '//' + window.location.host.replace('lli', 'll-lv') + generateUrl('/f/') + this.fileInfo.id;
			} else {
				otherLink = window.location.protocol + '//' + window.location.host.replace('ll-lv', 'lli') + generateUrl('/f/') + this.fileInfo.id;
			}

			// Format and return the links based on whether the current host is internal
			if (internal) {
				return `Internal link/Lien interne:\n    ${baseLink}\n\nExternal link/Lien externe:\n    ${otherLink}`;
			} else {
				return `Internal link/Lien interne:\n    ${otherLink}\n\nExternal link/Lien externe:\n    ${baseLink}`;
			}
		},

		/**
		 * Tooltip message
		 *
		 * @return {string}
		 */
		copyLinkTooltip() {
			if (this.copied) {
				if (this.copySuccess) {
					return ''
				}
				return t('files_sharing', 'Cannot copy, please copy the link manually')
			}
			return t('files_sharing', 'Copy internal link to clipboard')
		},

		internalLinkSubtitle() {
			if (this.fileInfo.type === 'dir') {
				return t('files_sharing', 'Only works for people with access to this folder')
			}
			return t('files_sharing', 'Only works for people with access to this file')
		},
	},

	methods: {
		async copyLink() {
			try {
				await navigator.clipboard.writeText(this.internalLink)
				showSuccess(t('files_sharing', 'Link copied'))
				this.$refs.shareEntrySimple.$refs.actionsComponent.$el.focus()
				this.copySuccess = true
				this.copied = true
			} catch (error) {
				this.copySuccess = false
				this.copied = true
				console.error(error)
			} finally {
				setTimeout(() => {
					this.copySuccess = false
					this.copied = false
				}, 4000)
			}
		},
	},
}
</script>

<style lang="scss" scoped>
.sharing-entry__internal {
	.avatar-external {
		width: 32px;
		height: 32px;
		line-height: 32px;
		font-size: 18px;
		background-color: var(--color-text-maxcontrast);
		border-radius: 50%;
		flex-shrink: 0;
	}
	.icon-checkmark-color {
		opacity: 1;
		color: var(--color-success);
	}
}
</style>
