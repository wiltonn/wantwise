// Generates placeholder "screenshots", a "photo" and a link preview for the fixture Display.
// They imitate what a child would really capture (phone screenshots of store pages) without using real product images.
// Run: npm run fixtures:images
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const out = join(dirname(fileURLToPath(import.meta.url)), "..", "public", "fixtures");
mkdirSync(out, { recursive: true });

const FONT = `font-family="-apple-system, 'SF Pro Display', 'Segoe UI', Helvetica, Arial, sans-serif"`;
const W = 1170;
const H = 2532;

const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;");

function statusBar(fg) {
  return `
  <text x="96" y="104" ${FONT} font-size="46" font-weight="600" fill="${fg}">9:41</text>
  <g fill="${fg}">
    <rect x="890" y="72" width="12" height="30" rx="3" opacity=".9"/><rect x="910" y="64" width="12" height="38" rx="3"/>
    <rect x="930" y="56" width="12" height="46" rx="3"/><rect x="950" y="48" width="12" height="54" rx="3" opacity=".35"/>
    <rect x="990" y="56" width="86" height="44" rx="12" fill="none" stroke="${fg}" stroke-width="4" opacity=".5"/>
    <rect x="997" y="63" width="60" height="30" rx="7"/>
  </g>`;
}

/** A generic shopping-app product page with the product illustration in the hero area. */
function storeScreenshot({ theme, product, brand, title, price, accent, rating = 4.6, reviews = "2,318" }) {
  const dark = theme === "dark";
  const bg = dark ? "#121317" : "#ffffff";
  const fg = dark ? "#f4f4f6" : "#111216";
  const muted = dark ? "#9a9ca6" : "#6b6e76";
  const card = dark ? "#1c1d23" : "#f3f2ef";
  const stars = Array.from({ length: 5 }, (_, i) =>
    `<path transform="translate(${96 + i * 52} 1946) scale(1.9)" d="M10 1l2.9 6 6.6.9-4.8 4.6 1.2 6.5L10 16l-5.9 3 1.2-6.5L.5 7.9 7.1 7z" fill="${i < Math.round(rating) ? "#f5a623" : muted}"/>`
  ).join("");
  const titleLines = title.length > 26 ? splitTitle(title) : [title];
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}">
  <rect width="${W}" height="${H}" fill="${bg}"/>
  ${statusBar(fg)}
  <path d="M110 214l-34 34 34 34" fill="none" stroke="${fg}" stroke-width="10" stroke-linecap="round" stroke-linejoin="round"/>
  <rect x="170" y="186" width="760" height="100" rx="50" fill="${card}"/>
  <circle cx="232" cy="234" r="20" fill="none" stroke="${muted}" stroke-width="7"/><path d="M247 250l18 18" stroke="${muted}" stroke-width="7" stroke-linecap="round"/>
  <text x="286" y="250" ${FONT} font-size="42" fill="${muted}">Search</text>
  <path d="M990 206h22l20 76h92l18-56h-122" fill="none" stroke="${fg}" stroke-width="8" stroke-linejoin="round"/>
  <circle cx="1046" cy="306" r="11" fill="${fg}"/><circle cx="1110" cy="306" r="11" fill="${fg}"/>
  <rect x="0" y="340" width="${W}" height="1300" fill="${card}"/>
  <g transform="translate(0 340)">${product}</g>
  <g>${[0, 1, 2, 3, 4].map((i) => `<circle cx="${505 + i * 40}" cy="1600" r="10" fill="${i === 0 ? fg : muted}" opacity="${i === 0 ? 1 : 0.4}"/>`).join("")}</g>
  <text x="96" y="1742" ${FONT} font-size="40" fill="${accent}" font-weight="600">${esc(brand)}</text>
  ${titleLines.map((l, i) => `<text x="96" y="${1822 + i * 72}" ${FONT} font-size="62" font-weight="700" fill="${fg}">${esc(l)}</text>`).join("")}
  ${stars}
  <text x="370" y="1982" ${FONT} font-size="40" fill="${muted}">${rating} · ${reviews} ratings</text>
  <text x="96" y="2124" ${FONT} font-size="96" font-weight="700" fill="${fg}">${esc(price)}</text>
  <text x="96" y="2192" ${FONT} font-size="40" fill="#2e9e5b" font-weight="600">In stock · Free delivery Tue</text>
  <rect x="96" y="2262" width="${W - 192}" height="128" rx="64" fill="${accent}"/>
  <text x="${W / 2}" y="2343" text-anchor="middle" ${FONT} font-size="48" font-weight="700" fill="${dark ? "#111" : "#fff"}">Add to cart</text>
  <rect x="420" y="2480" width="330" height="14" rx="7" fill="${fg}" opacity=".85"/>
</svg>`;
}

function splitTitle(t) {
  const words = t.split(" ");
  let a = "";
  while (words.length && (a + " " + words[0]).trim().length <= 26) a = (a + " " + words.shift()).trim();
  return [a, words.join(" ")];
}

// ---------- product illustrations (drawn in a 1170 x 1300 box) ----------

const headphones = `
  <defs>
    <linearGradient id="hp" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#5b6170"/><stop offset="1" stop-color="#1d2028"/></linearGradient>
    <linearGradient id="cush" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3a3e48"/><stop offset="1" stop-color="#14161b"/></linearGradient>
    <radialGradient id="shadow"><stop offset="0" stop-color="#000" stop-opacity=".22"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>
  </defs>
  <ellipse cx="585" cy="1080" rx="380" ry="60" fill="url(#shadow)"/>
  <path d="M300 720 C300 330 870 330 870 720" fill="none" stroke="url(#hp)" stroke-width="64" stroke-linecap="round"/>
  <path d="M330 690 C330 390 840 390 840 690" fill="none" stroke="#7a8090" stroke-width="10" opacity=".5"/>
  <rect x="210" y="640" width="210" height="360" rx="100" fill="url(#hp)"/>
  <rect x="750" y="640" width="210" height="360" rx="100" fill="url(#hp)"/>
  <rect x="380" y="680" width="70" height="280" rx="35" fill="url(#cush)"/>
  <rect x="720" y="680" width="70" height="280" rx="35" fill="url(#cush)"/>
  <ellipse cx="290" cy="720" rx="40" ry="90" fill="#fff" opacity=".12"/>
  <ellipse cx="830" cy="720" rx="40" ry="90" fill="#fff" opacity=".12"/>
  <circle cx="855" cy="930" r="12" fill="#6fe3a5"/>`;

const squishCube = `
  <defs>
    <linearGradient id="top" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffd1f0"/><stop offset="1" stop-color="#f5a3dd"/></linearGradient>
    <linearGradient id="left" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#d57ad0"/><stop offset="1" stop-color="#a15ad6"/></linearGradient>
    <linearGradient id="right" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#b77cf0"/><stop offset="1" stop-color="#7c5ce0"/></linearGradient>
    <radialGradient id="sh2"><stop offset="0" stop-color="#5a2a7a" stop-opacity=".25"/><stop offset="1" stop-color="#5a2a7a" stop-opacity="0"/></radialGradient>
  </defs>
  <rect width="1170" height="1300" fill="#fbeefa"/>
  <ellipse cx="585" cy="1060" rx="360" ry="60" fill="url(#sh2)"/>
  <path d="M585 330 Q600 325 900 470 Q915 480 900 495 L600 640 Q585 648 570 640 L270 495 Q255 482 270 470 L570 330 Z" fill="url(#top)"/>
  <path d="M262 495 L572 645 Q585 652 585 670 L585 1010 Q585 1030 565 1020 L280 878 Q262 868 262 848 Z" fill="url(#left)"/>
  <path d="M908 495 L598 645 Q585 652 585 670 L585 1010 Q585 1030 605 1020 L890 878 Q908 868 908 848 Z" fill="url(#right)"/>
  <ellipse cx="520" cy="430" rx="120" ry="40" fill="#fff" opacity=".55" transform="rotate(-18 520 430)"/>
  <ellipse cx="350" cy="680" rx="26" ry="70" fill="#fff" opacity=".25"/>
  <g fill="#fff" opacity=".9"><circle cx="700" cy="760" r="14"/><circle cx="780" cy="720" r="14"/><path d="M690 830 Q745 870 805 800" fill="none" stroke="#fff" stroke-width="12" stroke-linecap="round"/></g>`;

const markerColors = ["#ff5a5f", "#ff9f1c", "#ffd23f", "#3bceac", "#0ead69", "#4ea8de", "#5e60ce", "#c77dff", "#f15bb5", "#8d99ae", "#2b2d42", "#e76f51"];
const artSet = `
  <defs><linearGradient id="case" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2d3142"/><stop offset="1" stop-color="#1b1d29"/></linearGradient></defs>
  <rect width="1170" height="1300" fill="#f1efe9"/>
  <rect x="150" y="300" width="870" height="760" rx="48" fill="url(#case)"/>
  <rect x="190" y="340" width="790" height="680" rx="28" fill="#e9e6df"/>
  ${markerColors.map((c, i) => {
    const x = 225 + (i % 6) * 125;
    const y = i < 6 ? 380 : 700;
    return `<g><rect x="${x}" y="${y}" width="90" height="290" rx="34" fill="#fafafa" stroke="#d4d0c8" stroke-width="4"/>
      <rect x="${x}" y="${y}" width="90" height="96" rx="34" fill="${c}"/><rect x="${x}" y="${y + 70}" width="90" height="26" fill="${c}"/>
      <rect x="${x + 22}" y="${y + 150}" width="46" height="90" rx="10" fill="${c}" opacity=".85"/></g>`;
  }).join("")}
  <text x="585" y="1150" text-anchor="middle" ${FONT} font-size="44" font-weight="700" fill="#2d3142" letter-spacing="8">24 DUAL-TIP MARKERS</text>`;

const buildingSet = `
  <defs>
    <linearGradient id="box" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#0b1d3a"/><stop offset="1" stop-color="#1e3c72"/></linearGradient>
    <linearGradient id="panel" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4ea8de"/><stop offset="1" stop-color="#1b5e9c"/></linearGradient>
  </defs>
  <rect width="1170" height="1300" fill="#eef1f6"/>
  <rect x="140" y="230" width="890" height="860" rx="20" fill="url(#box)"/>
  ${Array.from({ length: 40 }, (_, i) => `<circle cx="${180 + ((i * 197) % 820)}" cy="${270 + ((i * 131) % 780)}" r="${(i % 3) + 2}" fill="#fff" opacity=".7"/>`).join("")}
  <circle cx="860" cy="380" r="90" fill="#f4a261" opacity=".9"/>
  <g transform="translate(585 690)">
    <rect x="-60" y="-200" width="120" height="400" rx="20" fill="#e5e5e5"/>
    <rect x="-60" y="-200" width="120" height="40" rx="10" fill="#c1121f"/>
    <rect x="-200" y="-30" width="400" height="60" rx="14" fill="#d9d9d9"/>
    ${[-1, 1].map((s) => `<g transform="translate(${s * 330} 0)">
      ${[0, 1, 2].map((r) => `<rect x="-120" y="${-170 + r * 115}" width="240" height="100" rx="8" fill="url(#panel)" stroke="#9ecbf0" stroke-width="5"/>`).join("")}
      <rect x="-12" y="-180" width="24" height="360" fill="#bdbdbd"/></g>`).join("")}
    ${[-30, 0, 30].map((x) => `<circle cx="${x}" cy="-120" r="12" fill="#bdbdbd"/>`).join("")}
  </g>
  <rect x="140" y="230" width="890" height="110" fill="#c1121f"/>
  <text x="190" y="306" ${FONT} font-size="54" font-weight="800" fill="#fff" letter-spacing="4">SPACE STATION</text>
  <text x="980" y="306" text-anchor="end" ${FONT} font-size="44" font-weight="700" fill="#ffd23f">9+</text>
  <text x="190" y="1060" ${FONT} font-size="40" font-weight="700" fill="#fff" opacity=".85">1,024 pieces</text>`;

function kartGameScreenshot() {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}">
  <defs>
    <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ff7e5f"/><stop offset=".55" stop-color="#feb47b"/><stop offset="1" stop-color="#6a3093"/></linearGradient>
    <linearGradient id="road" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#55536a"/><stop offset="1" stop-color="#22212c"/></linearGradient>
    <linearGradient id="fade" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0d0d12" stop-opacity="0"/><stop offset="1" stop-color="#0d0d12"/></linearGradient>
  </defs>
  <rect width="${W}" height="${H}" fill="#0d0d12"/>
  <rect y="0" width="${W}" height="1500" fill="url(#sky)"/>
  <circle cx="585" cy="760" r="170" fill="#ffe29a" opacity=".9"/>
  <path d="M0 900 L240 700 L420 860 L620 640 L850 880 L1000 760 L1170 900 L1170 1500 L0 1500Z" fill="#4b2c6e" opacity=".85"/>
  <path d="M540 900 L630 900 L1170 1500 L0 1500 Z" fill="url(#road)"/>
  <path d="M540 900 L0 1500 M630 900 L1170 1500" stroke="#f1faee" stroke-width="14" opacity=".8"/>
  ${[0, 1, 2, 3].map((i) => `<path d="M${578 - i * 3} ${940 + i * 140} l${8 + i * 6} 0 l${4 + i * 3} ${70 + i * 20} l-${16 + i * 12} 0z" fill="#ffd23f"/>`).join("")}
  <g transform="translate(585 1250)">
    <ellipse cx="0" cy="150" rx="300" ry="40" fill="#000" opacity=".35"/>
    <path d="M-250 60 Q-240 -40 -120 -60 L120 -60 Q240 -40 250 60 L240 120 L-240 120Z" fill="#e63946"/>
    <path d="M-110 -60 Q-80 -170 0 -170 Q80 -170 110 -60Z" fill="#1d3557"/>
    <circle cx="0" cy="-200" r="72" fill="#f1faee"/><rect x="-72" y="-215" width="144" height="40" rx="18" fill="#457b9d"/>
    ${[-200, 200].map((x) => `<rect x="${x - 55}" y="70" width="110" height="110" rx="30" fill="#111"/>`).join("")}
    <rect x="-150" y="20" width="300" height="34" rx="12" fill="#ffd23f"/>
  </g>
  <rect y="1300" width="${W}" height="220" fill="url(#fade)"/>
  ${statusBar("#fff")}
  <text x="96" y="1640" ${FONT} font-size="44" fill="#a3a3b5" font-weight="600">Game · Racing · 1–4 players</text>
  <text x="96" y="1730" ${FONT} font-size="72" font-weight="800" fill="#fff">Kart Rally Deluxe</text>
  <text x="96" y="1800" ${FONT} font-size="42" fill="#a3a3b5">Online multiplayer · Rated E</text>
  <rect x="96" y="1880" width="978" height="2" fill="#2a2a35"/>
  <text x="96" y="2000" ${FONT} font-size="92" font-weight="800" fill="#fff">$79.99</text>
  <rect x="96" y="2080" width="978" height="128" rx="64" fill="#e63946"/>
  <text x="585" y="2161" text-anchor="middle" ${FONT} font-size="48" font-weight="700" fill="#fff">Buy now</text>
  <rect x="96" y="2236" width="978" height="128" rx="64" fill="none" stroke="#3a3a48" stroke-width="4"/>
  <text x="585" y="2317" text-anchor="middle" ${FONT} font-size="48" font-weight="600" fill="#fff">Add to wishlist</text>
  <rect x="420" y="2480" width="330" height="14" rx="7" fill="#fff" opacity=".85"/>
</svg>`;
}

function skateboardPhoto() {
  // A "photo" taken in a shop: landscape, soft light, film grain.
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1600 1200" width="1600" height="1200">
  <defs>
    <linearGradient id="wall" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#d9cbb8"/><stop offset="1" stop-color="#9c8b77"/></linearGradient>
    <linearGradient id="floor" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#6d5a48"/><stop offset="1" stop-color="#3b2f25"/></linearGradient>
    <linearGradient id="deck" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#2a9d8f"/><stop offset=".5" stop-color="#e9c46a"/><stop offset="1" stop-color="#e76f51"/></linearGradient>
    <radialGradient id="vig" cx=".5" cy=".45" r=".75"><stop offset=".55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".55"/></radialGradient>
    <filter id="grain"><feTurbulence type="fractalNoise" baseFrequency=".9" numOctaves="2" seed="4"/><feColorMatrix values="0 0 0 0 .5  0 0 0 0 .5  0 0 0 0 .5  0 0 0 .18 0"/><feComposite in2="SourceGraphic" operator="in"/></filter>
    <filter id="soft"><feGaussianBlur stdDeviation="14"/></filter>
  </defs>
  <rect width="1600" height="800" fill="url(#wall)"/>
  <rect y="780" width="1600" height="420" fill="url(#floor)"/>
  ${[0, 1, 2, 3, 4, 5].map((i) => `<rect x="${120 + i * 240}" y="120" width="150" height="520" rx="70" fill="${["#264653", "#e76f51", "#8ab17d", "#f4a261", "#3d5a80", "#b5838d"][i]}" opacity=".55" filter="url(#soft)"/>`).join("")}
  <ellipse cx="820" cy="930" rx="560" ry="70" fill="#000" opacity=".35" filter="url(#soft)"/>
  <g transform="translate(800 820) rotate(-6)">
    <rect x="-560" y="-70" width="1120" height="140" rx="70" fill="url(#deck)"/>
    <rect x="-560" y="-70" width="1120" height="40" rx="20" fill="#fff" opacity=".18"/>
    ${[-380, 380].map((x) => `<rect x="${x - 70}" y="60" width="140" height="26" rx="8" fill="#b0b0b0"/>
      <circle cx="${x - 70}" cy="112" r="44" fill="#f2e8cf"/><circle cx="${x + 70}" cy="112" r="44" fill="#f2e8cf"/>
      <circle cx="${x - 70}" cy="112" r="16" fill="#999"/><circle cx="${x + 70}" cy="112" r="16" fill="#999"/>`).join("")}
  </g>
  <rect x="1180" y="560" width="220" height="130" rx="10" fill="#fdfcf7" transform="rotate(4 1290 625)"/>
  <text x="1290" y="645" text-anchor="middle" ${FONT} font-size="56" font-weight="800" fill="#222" transform="rotate(4 1290 625)">$74.99</text>
  <rect width="1600" height="1200" fill="url(#vig)"/>
  <rect width="1600" height="1200" filter="url(#grain)" opacity=".6"/>
</svg>`;
}

function starProjectorLink() {
  // A link-preview (og:image) style card, 1.91:1.
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 630" width="1200" height="630">
  <defs>
    <radialGradient id="room" cx=".5" cy=".9" r="1"><stop offset="0" stop-color="#1b2a6b"/><stop offset="1" stop-color="#05061a"/></radialGradient>
    <radialGradient id="glow" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#9bd1ff" stop-opacity=".6"/><stop offset="1" stop-color="#9bd1ff" stop-opacity="0"/></radialGradient>
  </defs>
  <rect width="1200" height="630" fill="url(#room)"/>
  ${Array.from({ length: 90 }, (_, i) => `<circle cx="${(i * 389) % 1200}" cy="${(i * 211) % 420}" r="${(i % 4) * 0.8 + 1}" fill="#fff" opacity="${0.35 + (i % 5) * 0.13}"/>`).join("")}
  <path d="M260 120 l6 18 18 6 -18 6 -6 18 -6 -18 -18 -6 18 -6z M900 90 l5 15 15 5 -15 5 -5 15 -5 -15 -15 -5 15 -5z" fill="#ffe8a3"/>
  <ellipse cx="600" cy="420" rx="260" ry="200" fill="url(#glow)"/>
  <path d="M480 520 Q480 380 600 380 Q720 380 720 520Z" fill="#e8eefc" opacity=".95"/>
  ${[0, 1, 2, 3, 4].map((i) => `<path transform="translate(${520 + i * 40} ${430 + (i % 2) * 30}) scale(.9)" d="M10 1l2.9 6 6.6.9-4.8 4.6 1.2 6.5L10 16l-5.9 3 1.2-6.5L.5 7.9 7.1 7z" fill="#5b7bd5"/>`).join("")}
  <rect x="460" y="515" width="280" height="40" rx="14" fill="#c7d2ef"/>
  <text x="60" y="590" ${FONT} font-size="30" font-weight="600" fill="#c9d4ff" opacity=".85">starnight-shop.example</text>
</svg>`;
}

const files = {
  "headphones.svg": storeScreenshot({ theme: "light", product: headphones, brand: "Auralite", title: "Wireless Over-Ear Headphones, 40h battery", price: "$49.00", accent: "#ff7a1a" }),
  "squish-cube.svg": storeScreenshot({ theme: "light", product: squishCube, brand: "NeeDoh", title: "Nice Cube Squishy Fidget – Lavender", price: "$12.00", accent: "#8a4fff", rating: 4.8, reviews: "9,402" }),
  "art-set.svg": storeScreenshot({ theme: "light", product: artSet, brand: "Studio Line", title: "Alcohol Marker Set, 24 Dual-Tip Colours", price: "$32.00", accent: "#2d3142", rating: 4.5, reviews: "1,077" }),
  "building-set.svg": storeScreenshot({ theme: "dark", product: buildingSet, brand: "BrickWorks", title: "Space Station Building Set (1,024 pcs)", price: "$89.99", accent: "#ffd23f", rating: 4.9, reviews: "640" }),
  "kart-game.svg": kartGameScreenshot(),
  "skateboard-photo.svg": skateboardPhoto(),
  "star-projector-link.svg": starProjectorLink(),
};

for (const [name, svg] of Object.entries(files)) {
  writeFileSync(join(out, name), svg.trim() + "\n");
  console.log(`wrote public/fixtures/${name}`);
}
