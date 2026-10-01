// Run with Node.js and Sharp installed: npm install --no-save sharp
// The source artwork is preserved; only platform sizes and safe padding change.
const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');
const root = path.resolve(__dirname, '..');
const source = path.join(root, 'assets/branding/app-icon.png');

async function png(size, padded = false) {
  const image = await sharp(source).resize(padded ? Math.round(size * 0.8) : size)
    .flatten({ background: '#ffffff' }).png().toBuffer();
  if (!padded) return image;
  return sharp({ create: { width: size, height: size, channels: 3, background: '#ffffff' } })
    .composite([{ input: image, gravity: 'centre' }]).png().toBuffer();
}

async function save(file, content) {
  const target = path.join(root, file);
  await fs.mkdir(path.dirname(target), { recursive: true });
  await fs.writeFile(target, content);
}

async function generate() {
  await save('assets/branding/logo.png', await png(512));
  for (const [density, size] of Object.entries({ mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 })) {
    await save(`android/app/src/main/res/mipmap-${density}/ic_launcher.png`, await png(size));
  }
  const catalog = JSON.parse(await fs.readFile(path.join(root, 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json'), 'utf8'));
  for (const icon of catalog.images) {
    const size = Math.round(parseFloat(icon.size) * parseFloat(icon.scale));
    await save(`ios/Runner/Assets.xcassets/AppIcon.appiconset/${icon.filename}`, await png(size));
  }
  await save('web/favicon.png', await png(64));
  for (const size of [192, 512]) {
    await save(`web/icons/Icon-${size}.png`, await png(size));
    await save(`web/icons/Icon-maskable-${size}.png`, await png(size, true));
  }
  // Windows ICO entries contain lossless PNG images at multiple resolutions.
  const sizes = [16, 32, 48, 256];
  const images = await Promise.all(sizes.map(size => png(size)));
  const header = Buffer.alloc(6 + sizes.length * 16);
  header.writeUInt16LE(1, 2);
  header.writeUInt16LE(sizes.length, 4);
  let offset = header.length;
  images.forEach((image, index) => {
    const entry = 6 + index * 16;
    header[entry] = header[entry + 1] = sizes[index] === 256 ? 0 : sizes[index];
    header.writeUInt16LE(1, entry + 4);
    header.writeUInt16LE(32, entry + 6);
    header.writeUInt32LE(image.length, entry + 8);
    header.writeUInt32LE(offset, entry + 12);
    offset += image.length;
  });
  await save('windows/runner/resources/app_icon.ico', Buffer.concat([header, ...images]));
  console.log('Generated app logo and Android, iOS, web and Windows icons.');
}

generate().catch(error => { console.error(error); process.exitCode = 1; });
