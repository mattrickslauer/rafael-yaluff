// Rebuilds the "artworks" lists in artwork-archive.json from the image file names in each
// collection's folder. Intro text and titles in the JSON are kept as they are.
//
// File name format (parts separated by double underscores):
//   1__Title EN__Título ES__Medium EN__Medio ES__Dimensions__Year.jpg
// Dimensions and year may also be given per language:
//   1__Title EN__Título ES__Medium EN__Medio ES__Dims EN__Dims ES__Year EN__Year ES.jpg
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { dirname, extname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const manifestPath = join(root, 'artwork-archive.json');
const imageExtensions = new Set(['.jpg', '.jpeg', '.png', '.webp']);
const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
const errors = [];

for (const [id, collection] of Object.entries(manifest.collections)) {
  if (!collection.folder) continue;

  const files = readdirSync(join(root, collection.folder)).filter(file =>
    imageExtensions.has(extname(file).toLowerCase())
  );
  const artworks = [];

  for (const file of files) {
    const parts = file.slice(0, -extname(file).length).split('__').map(part => part.trim());
    const [number, ...fields] = parts;

    if (!/^\d+$/.test(number) || (fields.length !== 6 && fields.length !== 8)) {
      errors.push(`${collection.folder}/${file}: expected number__title EN__title ES__medium EN__medium ES__dimensions__year`);
      continue;
    }

    const [titleEn, titleEs, mediumEn, mediumEs] = fields;
    const perLanguage = fields.length === 8;
    artworks.push({
      number: Number(number),
      image: `${collection.folder}/${file}`,
      title: { en: titleEn, es: titleEs },
      medium: { en: mediumEn, es: mediumEs },
      dimensions: perLanguage ? { en: fields[4], es: fields[5] } : { en: fields[4], es: fields[4] },
      year: perLanguage ? { en: fields[6], es: fields[7] } : { en: fields[5], es: fields[5] }
    });
  }

  artworks.sort((a, b) => a.number - b.number);
  const seen = new Set();
  for (const { number } of artworks) {
    if (seen.has(number)) errors.push(`${collection.folder}: number ${number} is used by more than one image`);
    seen.add(number);
  }
  collection.artworks = artworks;
  console.log(`${id}: ${artworks.length} artwork(s)`);
}

if (errors.length) {
  console.error(errors.join('\n'));
  process.exit(1);
}

writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n');
