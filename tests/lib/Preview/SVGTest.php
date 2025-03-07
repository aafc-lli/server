<?php
/**
 * @author Olivier Paroz <owncloud@interfasys.ch>
 *
 * @copyright Copyright (c) 2015, ownCloud, Inc.
 * @license AGPL-3.0
 *
 * This code is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License, version 3,
 * as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License, version 3,
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 *
 */

namespace Test\Preview;

/**
 * Class SVGTest
 *
 * @group DB
 *
 * @package Test\Preview
 */
class SVGTest extends Provider {
	protected function setUp(): void {
		$checkImagick = new \Imagick();
		if (count($checkImagick->queryFormats('SVG')) === 1) {
			parent::setUp();

			$fileName = 'testimagelarge.svg';
			$this->imgPath = $this->prepareTestFile($fileName, \OC::$SERVERROOT . '/tests/data/' . $fileName);
			$this->width = 3000;
			$this->height = 2000;
			$this->provider = new \OC\Preview\SVG;
		} else {
			$this->markTestSkipped('No SVG provider present');
		}
	}

	public function dataGetThumbnailSVGHref(): array {
		return [
			['href'],
			[' href'],
			["\nhref"],
			['xlink:href'],
			[' xlink:href'],
			["\nxlink:href"],
		];
	}

	/**
	 * @dataProvider dataGetThumbnailSVGHref
	 * @requires extension imagick
	 */
	public function testGetThumbnailSVGHref(string $content): void {
		$handle = fopen('php://temp', 'w+');
		fwrite($handle, '<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <image x="0" y="0"' . $content . '="fxlogo.png" height="100" width="100" />
</svg>');
		rewind($handle);

		$file = $this->createMock(\OCP\Files\File::class);
		$file->method('fopen')
			->willReturn($handle);

		self::assertNull($this->provider->getThumbnail($file, 512, 512));
	}
}
