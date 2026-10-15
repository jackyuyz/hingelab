// Renders scripts/assets/AppIcon.svg (fan geometry generated here) to
// App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png, and the
// spark particle to hl.particleSpark.imageset. Uses Playwright's Chromium.
// Usage: node scripts/render-icon.mjs
import fs from 'node:fs';
import { createRequire } from 'node:module';
import { execSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// Resolve playwright from the project or from the global npm root.
let chromium;
try {
  ({ chromium } = await import('playwright'));
} catch {
  const globalRoot = execSync('npm root -g').toString().trim();
  ({ chromium } = createRequire(path.join(globalRoot, 'noop.js'))('playwright'));
}

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const hues = ['#E5483C', '#F0A332', '#2FC4D6', '#A274F2'];

function fan() {
  // Pivot at the hinge barrel; stem points straight up, flag opens 40°.
  const px = 414, py = 722;
  const open = 54, pleats = 8, rIn = 170, rOut = 492, rValley = 440, len = 520;
  const toXY = (deg, r) => {
    const a = (deg - 90) * Math.PI / 180; // 0° = up
    return [px + r * Math.cos(a), py + r * Math.sin(a)];
  };
  let out = '';
  // glow behind the bellows
  const g = toXY(open / 2, 330);
  out += `<circle cx="${g[0]}" cy="${g[1]}" r="230" fill="#E5483C" opacity="0.28" filter="url(#glow)"/>`;
  const g2 = toXY(open * 0.8, 380);
  out += `<circle cx="${g2[0]}" cy="${g2[1]}" r="160" fill="#A274F2" opacity="0.22" filter="url(#glow)"/>`;
  const step = open / pleats;
  for (let i = 0; i < pleats; i++) {
    const a0 = i * step, am = a0 + step / 2, a1 = a0 + step;
    const hue = hues[Math.floor(i / 2)];
    const [ix0, iy0] = toXY(a0, rIn), [ixm, iym] = toXY(am, rIn * 0.86), [ix1, iy1] = toXY(a1, rIn);
    const [ox0, oy0] = toXY(a0, rOut), [oxm, oym] = toXY(am, rValley), [ox1, oy1] = toXY(a1, rOut);
    // lit face then shaded face of each pleat
    out += `<path d="M${ix0},${iy0} L${ox0},${oy0} L${oxm},${oym} L${ixm},${iym} Z" fill="${hue}"/>`;
    out += `<path d="M${ixm},${iym} L${oxm},${oym} L${ox1},${oy1} L${ix1},${iy1} Z" fill="${hue}" opacity="0.62"/>`;
    out += `<path d="M${ix0},${iy0} L${ox0},${oy0}" stroke="#f3ead2" stroke-width="5" stroke-linecap="round" opacity="0.9"/>`;
  }
  // panels: stem (0°) and flag (open°)
  // Each panel is a phone half seen edge-on: a slab with a dark glass line.
  const panel = (deg, glassSide) => `<g transform="rotate(${deg} ${px} ${py})"><rect x="${px - 40}" y="${py - len}" width="80" height="${len}" rx="24" fill="url(#panel)"/><rect x="${px + glassSide * 22 - 5}" y="${py - len + 34}" width="10" height="${len - 120}" rx="5" fill="#0c0d12" opacity="0.55"/></g>`;
  out += panel(open, -1);
  out += panel(0, 1);
  // note head = hinge barrel, tilted like an engraved note head; a knurled
  // groove marks it as the barrel.
  const hx = px - 70, hy = py + 26;
  out += `<g transform="rotate(-22 ${hx} ${hy})"><ellipse cx="${hx}" cy="${hy}" rx="134" ry="100" fill="url(#head)"/></g>`;
  return out;
}

const svgPath = path.join(root, 'scripts/assets/AppIcon.svg');
const svg = fs.readFileSync(svgPath, 'utf8').replace('<g id="art" transform="translate(0 0)"></g>', `<g id="art">${fan()}</g>`);

const spark = `<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128"><defs><radialGradient id="s"><stop offset="0" stop-color="#fff" stop-opacity="1"/><stop offset="0.25" stop-color="#fff" stop-opacity="0.85"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient></defs><circle cx="64" cy="64" r="64" fill="url(#s)"/></svg>`;

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1024, height: 1024 } });
await page.setContent(`<html><body style="margin:0;background:#0c0d12">${svg}</body></html>`);
const iconDir = path.join(root, 'App/Resources/Assets.xcassets/AppIcon.appiconset');
await page.screenshot({ path: path.join(iconDir, 'AppIcon-1024.png'), omitBackground: false });
// Preview copy for design review (not shipped).
if (process.env.PREVIEW_DIR) fs.writeFileSync(path.join(process.env.PREVIEW_DIR, 'AppIcon.svg'), svg);

const sparkDir = path.join(root, 'App/Resources/Assets.xcassets/hl.particleSpark.imageset');
fs.mkdirSync(sparkDir, { recursive: true });
await page.setViewportSize({ width: 128, height: 128 });
await page.setContent(`<html><body style="margin:0;background:transparent">${spark}</body></html>`);
await page.screenshot({ path: path.join(sparkDir, 'hl.particleSpark.png'), omitBackground: true });
await browser.close();
console.log('rendered icon and spark');
