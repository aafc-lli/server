/**
 * SPDX-FileCopyrightText: 2020 Nextcloud GmbH and Nextcloud contributors
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import { showError, showUndo, TOAST_UNDO_TIMEOUT } from '@nextcloud/dialogs'
import NewComment from '../services/NewComment.js'
import DeleteComment from '../services/DeleteComment.js'
import EditComment from '../services/EditComment.js'
import { mapStores } from 'pinia'
import { useDeletedCommentLimbo } from '../store/deletedCommentLimbo.js'
import logger from '../logger.js'

export default {
	props: {
		id: {
			type: Number,
			default: null,
		},
		message: {
			type: String,
			default: '',
		},
		resourceId: {
			type: [String, Number],
			required: true,
		},
		resourceType: {
			type: String,
			default: 'files',
		},
	},

	data() {
		return {
			deleted: false,
			editing: false,
			loading: false,
		}
	},

	computed: {
		...mapStores(useDeletedCommentLimbo),
	},

	methods: {
		// EDITION
		onEdit() {
			this.editing = true
		},
		onEditCancel() {
			this.editing = false
			// Restore original value
			this.updateLocalMessage(this.message)
		},
		async onEditComment(message) {
			this.loading = true
			try {
				await EditComment(this.resourceType, this.resourceId, this.id, message)
				logger.debug('Comment edited', { resourceType: this.resourceType, resourceId: this.resourceId, id: this.id, message })
				this.$emit('update:message', message)
				this.editing = false
			} catch (error) {
				showError(t('comments', 'An error occurred while trying to edit the comment'))
				console.error(error)
			} finally {
				this.loading = false
			}
		},

		// DELETION
		onDeleteWithUndo() {
			this.$emit('delete')
			this.deleted = true
			this.deletedCommentLimboStore.addId(this.id)
			const timeOutDelete = setTimeout(this.onDelete, TOAST_UNDO_TIMEOUT)
			showUndo(t('comments', 'Comment deleted'), () => {
				clearTimeout(timeOutDelete)
				this.deleted = false
				this.deletedCommentLimboStore.removeId(this.id)
			})
		},
		async onDelete() {
			try {
				await DeleteComment(this.resourceType, this.resourceId, this.id)
				logger.debug('Comment deleted', { resourceType: this.resourceType, resourceId: this.resourceId, id: this.id })
				this.$emit('delete', this.id)
			} catch (error) {
				showError(t('comments', 'An error occurred while trying to delete the comment'))
				console.error(error)
				this.deleted = false
				this.deletedCommentLimboStore.removeId(this.id)
			}
		},

		// CREATION
		async onNewComment(message) {
			this.loading = true
			try {
				// !CDSP: This uses the ID of the first file details was opened for without this hacky fix.
				const actualResourceId = (window.location.pathname + '').split('/').pop()
				const newComment = await NewComment(this.resourceType, actualResourceId, message)
				logger.debug('New comment posted', { resourceType: this.resourceType, resourceId: actualResourceId, newComment })
				// !CDSP: End change.
				this.$emit('new', newComment)

				// Clear old content
				this.$emit('update:message', '')
				this.localMessage = ''
			} catch (error) {
				showError(t('comments', 'An error occurred while trying to create the comment'))
				console.error(error)
			} finally {
				this.loading = false
			}
		},
	},
}
