/**
 * SPDX-FileCopyrightText: 2022 Nextcloud GmbH and Nextcloud contributors
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
const { merge } = require('webpack-merge')
const config = require('./webpack.common.js')

let isDev = false
try {
	const buildMode = process.env.NODE_ENV
	isDev = buildMode === 'development'
} catch (e) {
	console.error('Could not determine build mode', e)
}

module.exports = merge(config, {
	mode: isDev ? 'development' : 'production',
	devtool: isDev ? 'cheap-source-map' : 'source-map',
})
