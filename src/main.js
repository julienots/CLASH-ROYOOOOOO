// Essence Arena — SuperEssence Studio. Coquille de l'application : écrans, sauvegarde, navigation.
import * as THREE from 'three';
import { CARDS, PLAYABLE, DEFAULT_DECK, RARITY } from './cards.js';
import { buildModel, buildArena, buildTower, ISLANDS, islandFor } from './models.js';
import { Battle } from './battle.js';
import { initAudio, sfx, setMuted, muted } from './audio.js';

const $ = (s, r = document) => r.querySelector(s);

// Anciennes WebView Android : roundRect absent du canvas 2D
if (!CanvasRenderingContext2D.prototype.roundRect) {
  CanvasRenderingContext2D.prototype.roundRect = function (x, y, w, h) { this.rect(x, y, w, h); };
}
const SAVE_KEY = 'essence-arena-save-v1';
const MAX_LEVEL = 9;

// ---------- Sauvegarde ----------
function loadSave() {
  let s = null;
  try { s = JSON.parse(localStorage.getItem(SAVE_KEY)); } catch { s = null; }
  const levels = {};
  for (const id of PLAYABLE) levels[id] = 1;
  return {
    name: 'Joueur', trophies: 0, gold: 500, gems: 50, deck: [...DEFAULT_DECK], levels, wins: 0, losses: 0, muted: false,
    ...(s || {}), levels: { ...levels, ...(s?.levels || {}) },
  };
}
const save = loadSave();
const persist = () => { try { localStorage.setItem(SAVE_KEY, JSON.stringify(save)); } catch { /* stockage indisponible */ } };
setMuted(save.muted);

const upgradeCost = (lvl) => 80 * lvl * lvl;

// ---------- Rendu 3D partagé ----------
const app = $('#app');
const canvas = document.createElement('canvas');
canvas.id = 'gl';
app.prepend(canvas);
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.05;
renderer.setSize(app.clientWidth, app.clientHeight);

// ---------- Images de cartes (rendu des vrais modèles 3D) ----------
const cardImages = {};
function renderCardImages() {
  const W = 220, H = 280;
  const r = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
  r.setSize(W, H);
  r.toneMapping = THREE.ACESFilmicToneMapping;
  const scene = new THREE.Scene();
  scene.add(new THREE.HemisphereLight(0xffffff, 0x445566, 1.6));
  const key = new THREE.DirectionalLight(0xffffff, 2.4);
  key.position.set(3, 5, 6);
  scene.add(key);
  const rim = new THREE.DirectionalLight(0x9fd8ff, 1.5);
  rim.position.set(-4, 3, -4);
  scene.add(rim);
  const cam = new THREE.PerspectiveCamera(32, W / H, 0.1, 100);
  const out = document.createElement('canvas');
  out.width = W; out.height = H;
  const x = out.getContext('2d');
  const framing = {
    golem: [6.2, 1.5, 1.2], storm: [5.8, 1.6, 1.2], drake: [5.2, 0.2, 1.0], totem: [5.4, 1.3, 0.4],
    meteor: [4.0, 0, 0.3], frost: [3.6, 0.6, 0.3], swarm: [2.6, 0.2, 0.6], sapper: [3.0, 0.75, 0.5], pyro: [3.8, 1.0, 0.4],
  };
  for (const id of Object.keys(CARDS)) {
    if (CARDS[id].hidden) continue;
    const model = buildModel(id, 0);
    if (id === 'archers') { const b = buildModel(id, 0); b.position.set(0.55, 0, -0.5); model.add(b); model.position.x = -0.25; }
    if (id === 'swarm') for (let i = 0; i < 2; i++) { const b = buildModel(id, 0); b.position.set(i ? 0.5 : -0.5, 0, -0.5); model.add(b); }
    model.rotation.y = 0.5;
    scene.add(model);
    const [d, h, tilt] = framing[id] || [3.4, 0.85, 0.4];
    cam.position.set(0, h + tilt + 0.3, d);
    cam.lookAt(0, h, 0);
    r.render(scene, cam);
    const c = CARDS[id];
    const rc = RARITY[c.rarity].color;
    x.clearRect(0, 0, W, H);
    x.save();
    x.beginPath(); x.roundRect(4, 4, W - 8, H - 8, 18); x.clip();
    const g = x.createLinearGradient(0, 0, 0, H);
    const bg = { common: ['#5f86b8', '#2b4a78'], rare: ['#f0a43a', '#9a4d12'], epic: ['#b25cf0', '#4b1f86'], legendary: ['#43d8c4', '#1b4e7a'] }[c.rarity];
    g.addColorStop(0, bg[0]); g.addColorStop(1, bg[1]);
    x.fillStyle = g; x.fillRect(0, 0, W, H);
    const rg = x.createRadialGradient(W / 2, H * 0.45, 10, W / 2, H * 0.45, W * 0.7);
    rg.addColorStop(0, 'rgba(255,255,255,0.35)'); rg.addColorStop(1, 'rgba(255,255,255,0)');
    x.fillStyle = rg; x.fillRect(0, 0, W, H);
    x.drawImage(r.domElement, 0, 0);
    if (c.type === 'spell') { x.fillStyle = 'rgba(0,0,0,0.35)'; x.fillRect(0, H - 34, W, 34); x.fillStyle = '#ffe9a8'; x.font = '20px "Lilita One"'; x.textAlign = 'center'; x.fillText('SORT', W / 2, H - 11); }
    x.restore();
    x.lineWidth = 8; x.strokeStyle = rc;
    x.beginPath(); x.roundRect(4, 4, W - 8, H - 8, 18); x.stroke();
    x.lineWidth = 2; x.strokeStyle = 'rgba(255,255,255,0.6)';
    x.beginPath(); x.roundRect(10, 10, W - 20, H - 20, 13); x.stroke();
    cardImages[id] = out.toDataURL('image/png');
    scene.remove(model);
  }
  r.dispose();
  r.forceContextLoss();
}

// ---------- Scène du menu (île qui tourne) ----------
let menuScene = null;
function buildMenuScene() {
  const isl = islandFor(save.trophies);
  const scene = new THREE.Scene();
  scene.fog = new THREE.Fog(isl.fog, 40, 120);
  scene.background = new THREE.Color(isl.sky);
  scene.add(new THREE.HemisphereLight(0xe8f6ff, 0x554433, 1.4));
  const sun = new THREE.DirectionalLight(0xfff1d6, 2.4);
  sun.position.set(-12, 30, 18);
  sun.castShadow = true;
  sun.shadow.mapSize.set(1024, 1024);
  Object.assign(sun.shadow.camera, { left: -20, right: 20, top: 25, bottom: -25 });
  scene.add(sun);
  const root = new THREE.Group();
  const arena = buildArena(isl);
  root.add(arena);
  for (const [team, s] of [[0, 1], [1, -1]]) {
    for (const x of [-5.5, 5.5]) { const t = buildTower(team, false); t.position.set(x, 0, 10.5 * s); if (team) t.rotation.y = Math.PI; root.add(t); }
    const c = buildTower(team, true); c.position.set(0, 0, 13.6 * s); if (team) c.rotation.y = Math.PI; root.add(c);
  }
  // quelques héros qui posent au centre
  const heroes = ['shield', 'pyro', 'archers'];
  heroes.forEach((id, i) => { const mdl = buildModel(id, 0); mdl.position.set((i - 1) * 2, 0, 4); mdl.scale.setScalar(1.6); root.add(mdl); });
  root.scale.setScalar(0.6);
  scene.add(root);
  // îles flottantes lointaines
  for (let i = 0; i < 6; i++) {
    const g = new THREE.Group();
    const rock = new THREE.Mesh(new THREE.ConeGeometry(2 + Math.random() * 2, 4, 7), new THREE.MeshStandardMaterial({ color: isl.cliff, flatShading: true }));
    rock.rotation.x = Math.PI; rock.position.y = -2;
    const top = new THREE.Mesh(new THREE.CylinderGeometry(2.4, 2.2, 0.6, 7), new THREE.MeshStandardMaterial({ color: new THREE.Color(isl.grass), flatShading: true }));
    g.add(rock, top);
    const a = (i / 6) * Math.PI * 2;
    g.position.set(Math.cos(a) * 30, -4 + Math.random() * 8, Math.sin(a) * 30);
    g.userData.bob = Math.random() * 6;
    scene.add(g);
    root.userData[`isle${i}`] = g;
  }
  const cam = new THREE.PerspectiveCamera(40, app.clientWidth / app.clientHeight, 0.5, 300);
  menuScene = { scene, root, cam, arena, isl };
}

function renderMenu(now) {
  if (!menuScene) return;
  const { scene, root, cam, arena } = menuScene;
  root.rotation.y = now * 0.12;
  arena.userData.water.offset.x = now * 0.08;
  const portrait = app.clientHeight > app.clientWidth;
  cam.aspect = app.clientWidth / app.clientHeight;
  cam.position.set(0, portrait ? 26 : 18, portrait ? 34 : 26);
  cam.lookAt(0, -2, 0);
  cam.updateProjectionMatrix();
  renderer.render(scene, cam);
}

// ---------- UI ----------
const ui = $('#ui');
let tab = 'battle';
let battle = null;

function topBar() {
  const isl = islandFor(save.trophies);
  return `
  <div class="topbar">
    <div class="profile"><div class="avatar">${save.name[0] || 'J'}</div><div><b>${save.name}</b><small>${isl.name}</small></div></div>
    <div class="res trophy">🏆<span>${save.trophies}</span></div>
    <div class="res gold">🪙<span>${save.gold}</span></div>
    <div class="res gem">💎<span>${save.gems}</span></div>
  </div>`;
}

const NAV = [
  ['shop', '🛒', 'Boutique'], ['cards', '🃏', 'Cartes'], ['battle', '⚔️', 'Combat'], ['islands', '🏝️', 'Îles'], ['settings', '⚙️', 'Options'],
];

function navBar() {
  return `<nav class="nav">${NAV.map(([id, ico, lbl]) => `<button data-tab="${id}" class="${tab === id ? 'on' : ''}"><i>${ico}</i><span>${lbl}</span></button>`).join('')}</nav>`;
}

function cardTile(id, opts = {}) {
  const c = CARDS[id];
  const lvl = save.levels[id];
  return `<div class="ctile ${opts.cls || ''}" data-id="${id}" data-rarity="${c.rarity}">
    <div class="cimg"><img src="${cardImages[id]}" alt="${c.name}"><div class="cost">${c.cost}</div><div class="lvl">Niv. ${lvl}</div></div>
    ${opts.label ? `<div class="cname">${c.name}</div>` : ''}</div>`;
}

function screenBattle() {
  const isl = islandFor(save.trophies);
  const nextIsl = ISLANDS.find((i) => i.trophies > save.trophies);
  const pct = nextIsl ? ((save.trophies - isl.trophies) / (nextIsl.trophies - isl.trophies)) * 100 : 100;
  return `
  <div class="home">
    <div class="island-title"><small>Arène actuelle</small><h2>${isl.name}</h2>
      <div class="road"><div style="width:${pct}%"></div><span>${nextIsl ? `${save.trophies} / ${nextIsl.trophies} 🏆 → ${nextIsl.name}` : 'Île maximale atteinte !'}</span></div></div>
    <div class="home-deck">${save.deck.map((id) => `<img src="${cardImages[id]}">`).join('')}</div>
    <button class="big-btn battle-btn" id="go">Combat</button>
    <div class="record">${save.wins} victoires · ${save.losses} défaites</div>
  </div>`;
}

let selCard = null;
function screenCards() {
  const avg = (save.deck.reduce((s, id) => s + CARDS[id].cost, 0) / 8).toFixed(1);
  const rest = PLAYABLE.filter((id) => !save.deck.includes(id));
  return `
  <div class="panel cards-screen">
    <div class="tabs-head"><div class="tabhead on">Deck de combat</div></div>
    <div class="deck-grid">${save.deck.map((id) => cardTile(id, { cls: selCard === id ? 'sel' : '' })).join('')}</div>
    <div class="deck-info"><span class="avg">💧 Coût moyen : <b>${avg}</b></span><span class="hint">${selCard ? (save.deck.includes(selCard) ? 'Touchez une carte de la collection pour échanger' : 'Touchez une carte du deck pour la remplacer') : 'Touchez une carte pour la voir'}</span></div>
    <h3 class="section">Collection <small>${PLAYABLE.length} cartes</small></h3>
    <div class="deck-grid coll">${rest.map((id) => cardTile(id, { cls: selCard === id ? 'sel' : '', label: true })).join('')}</div>
  </div>`;
}

function cardPopup(id) {
  const c = CARDS[id];
  const lvl = save.levels[id];
  const mult = 1 + 0.1 * (lvl - 1);
  const stats = [];
  if (c.hp) stats.push(['❤️ Points de vie', Math.round(c.hp * mult) + (c.shield ? ` + 🛡️${Math.round(c.shield * mult)}` : '')]);
  if (c.dmg) stats.push([c.type === 'spell' ? '💥 Dégâts de zone' : '⚔️ Dégâts', Math.round(c.dmg * mult)]);
  if (c.hitSpeed && c.type !== 'spell' && c.attack !== 'kamikaze') stats.push(['⏱️ Vitesse d’attaque', c.hitSpeed + ' s']);
  if (c.speed) stats.push(['👟 Vitesse', c.speed >= 2 ? 'Très rapide' : c.speed >= 1.4 ? 'Rapide' : c.speed >= 1.1 ? 'Moyenne' : 'Lente']);
  if (c.range) stats.push(['🎯 Portée', c.range < 1.5 ? 'Mêlée' : c.range.toFixed(1)]);
  if (c.targets) stats.push(['👁️ Cibles', { ground: 'Terrestres', both: 'Air & sol', buildings: 'Bâtiments' }[c.targets]]);
  if (c.count) stats.push(['👥 Nombre', 'x' + c.count]);
  if (c.radius && c.type === 'spell') stats.push(['⭕ Rayon', c.radius]);
  if (c.lifetime) stats.push(['⌛ Durée', c.lifetime + ' s']);
  if (c.freeze) stats.push(['❄️ Gel', c.freeze + ' s']);
  const cost = upgradeCost(lvl);
  const inDeck = save.deck.includes(id);
  return `<div class="modal" id="modal"><div class="modal-box" data-rarity="${c.rarity}">
    <div class="modal-head"><h3>${c.name}</h3><span class="rar" style="color:${RARITY[c.rarity].color}">${RARITY[c.rarity].label} · Niv. ${lvl}</span></div>
    <div class="modal-body"><img src="${cardImages[id]}"><p>${c.desc}</p></div>
    <div class="stats">${stats.map(([k, v]) => `<div><span>${k}</span><b>${v}</b></div>`).join('')}</div>
    <div class="modal-actions">
      ${lvl < MAX_LEVEL ? `<button class="big-btn green" id="upg" ${save.gold < cost ? 'disabled' : ''}>Améliorer<br><small>🪙 ${cost}</small></button>` : '<button class="big-btn" disabled>Niveau max</button>'}
      <button class="big-btn blue" id="use">${inDeck ? 'Échanger' : 'Utiliser'}</button>
    </div>
    <button class="close" id="close">✕</button></div></div>`;
}

const CHESTS = [
  { id: 'wood', name: 'Coffre de Bois', price: 0, cur: 'free', gold: [60, 120], gems: [0, 2], ico: '🧰' },
  { id: 'silver', name: 'Coffre d’Argent', price: 30, cur: 'gems', gold: [250, 400], gems: [0, 5], ico: '🎁' },
  { id: 'magic', name: 'Coffre Magique', price: 90, cur: 'gems', gold: [900, 1400], gems: [5, 15], ico: '🔮' },
];
function screenShop() {
  const freeReady = Date.now() - (save.lastFree || 0) > 4 * 3600 * 1000;
  return `<div class="panel shop">
    <div class="ribbon">Boutique</div>
    <div class="offer">
      <div class="offer-art">💎</div>
      <div><h3>Offre de bienvenue</h3><p>Récupère 100 gemmes et 1000 pièces d’or, gratuitement !</p>
      <button class="big-btn green" id="welcome" ${save.welcome ? 'disabled' : ''}>${save.welcome ? 'Récupérée' : 'Récupérer'}</button></div>
    </div>
    <h3 class="section">Coffres</h3>
    <div class="chests">${CHESTS.map((c) => `<div class="chest" data-id="${c.id}"><div class="chest-ico">${c.ico}</div><b>${c.name}</b>
      <small>🪙 ${c.gold[0]}–${c.gold[1]}</small>
      <button class="big-btn ${c.cur === 'free' ? 'green' : 'blue'}" data-buy="${c.id}" ${c.cur === 'free' && !freeReady ? 'disabled' : ''}>${c.cur === 'free' ? (freeReady ? 'Gratuit' : 'Bientôt') : `💎 ${c.price}`}</button></div>`).join('')}</div>
    <h3 class="section">Or</h3>
    <div class="chests">${[[1000, 60], [5000, 250], [20000, 900]].map(([g, p]) => `<div class="chest"><div class="chest-ico">🪙</div><b>${g} or</b><button class="big-btn blue" data-gold="${g}" data-price="${p}">💎 ${p}</button></div>`).join('')}</div>
  </div>`;
}

function screenIslands() {
  return `<div class="panel islands"><div class="ribbon">Route des Îles</div>
    ${[...ISLANDS].reverse().map((i) => {
      const unlocked = save.trophies >= i.trophies;
      const cur = islandFor(save.trophies).id === i.id;
      return `<div class="isle ${unlocked ? '' : 'locked'} ${cur ? 'cur' : ''}" style="--sky:#${i.sky.toString(16).padStart(6, '0')};--grass:${i.grass}">
        <div class="isle-art"><div class="isle-top"></div><div class="isle-rock"></div></div>
        <div><h3>${i.name}</h3><small>🏆 ${i.trophies}+</small></div>
        <div class="isle-state">${cur ? 'Actuelle' : unlocked ? '✔' : '🔒'}</div></div>`;
    }).join('')}</div>`;
}

function screenSettings() {
  return `<div class="panel settings"><div class="ribbon">Options</div>
    <label>Nom du joueur<input id="pname" maxlength="14" value="${save.name}"></label>
    <button class="big-btn blue" id="mute">${muted ? '🔇 Son désactivé' : '🔊 Son activé'}</button>
    <button class="big-btn red" id="reset">Réinitialiser la progression</button>
    <div class="credits"><img src="assets/superessence-logo.jpg"><p>Essence Arena · v1.0<br>Un jeu SuperEssence Studio</p></div>
  </div>`;
}

function renderUI() {
  const screens = { battle: screenBattle, cards: screenCards, shop: screenShop, islands: screenIslands, settings: screenSettings };
  ui.className = 'ui menu tab-' + tab;
  ui.innerHTML = topBar() + `<main class="screen">${screens[tab]()}</main>` + navBar();
  bindUI();
}

function toast(text) {
  const t = document.createElement('div');
  t.className = 'toast';
  t.textContent = text;
  document.body.appendChild(t);
  setTimeout(() => t.remove(), 2200);
}

function bindUI() {
  ui.querySelectorAll('.nav button').forEach((b) => b.onclick = () => { sfx.click(); tab = b.dataset.tab; selCard = null; renderUI(); });
  const go = $('#go');
  if (go) go.onclick = () => { sfx.click(); startMatchmaking(); };
  if (tab === 'cards') {
    ui.querySelectorAll('.ctile').forEach((t) => t.onclick = () => {
      sfx.click();
      const id = t.dataset.id;
      if (selCard && selCard !== id) {
        const a = save.deck.indexOf(selCard), b = save.deck.indexOf(id);
        if ((a >= 0) !== (b >= 0)) {
          if (a >= 0) save.deck[a] = id; else save.deck[b] = selCard;
          persist(); selCard = null; renderUI(); return;
        }
      }
      selCard = null;
      openCard(id);
    });
  }
  if (tab === 'shop') {
    const w = $('#welcome');
    if (w) w.onclick = () => { save.welcome = true; save.gems += 100; save.gold += 1000; persist(); sfx.win(); toast('+100 💎  +1000 🪙'); renderUI(); };
    ui.querySelectorAll('[data-buy]').forEach((b) => b.onclick = () => {
      const c = CHESTS.find((k) => k.id === b.dataset.buy);
      if (c.cur === 'gems' && save.gems < c.price) { sfx.noEssence(); toast('Pas assez de gemmes'); return; }
      if (c.cur === 'gems') save.gems -= c.price; else save.lastFree = Date.now();
      const g = Math.round(c.gold[0] + Math.random() * (c.gold[1] - c.gold[0]));
      const gm = Math.round(c.gems[0] + Math.random() * (c.gems[1] - c.gems[0]));
      save.gold += g; save.gems += gm; persist();
      openChest(c, g, gm);
    });
    ui.querySelectorAll('[data-gold]').forEach((b) => b.onclick = () => {
      const p = +b.dataset.price;
      if (save.gems < p) { sfx.noEssence(); toast('Pas assez de gemmes'); return; }
      save.gems -= p; save.gold += +b.dataset.gold; persist(); sfx.crown(); renderUI();
    });
  }
  if (tab === 'settings') {
    $('#pname').onchange = (e) => { save.name = e.target.value.trim() || 'Joueur'; persist(); renderUI(); };
    $('#mute').onclick = () => { save.muted = !muted; setMuted(save.muted); persist(); renderUI(); };
    $('#reset').onclick = () => { if (confirm('Effacer toute la progression ?')) { localStorage.removeItem(SAVE_KEY); location.reload(); } };
  }
}

function openChest(c, g, gm) {
  const m = document.createElement('div');
  m.className = 'modal chest-open';
  m.innerHTML = `<div class="chest-anim">${c.ico}</div><div class="loot"><div>🪙 +${g}</div>${gm ? `<div>💎 +${gm}</div>` : ''}</div><button class="big-btn" id="ok">OK</button>`;
  document.body.appendChild(m);
  sfx.win();
  $('#ok', m).onclick = () => { m.remove(); renderUI(); };
}

function openCard(id) {
  document.body.insertAdjacentHTML('beforeend', cardPopup(id));
  const m = $('#modal');
  const close = () => m.remove();
  $('#close', m).onclick = close;
  m.onclick = (e) => { if (e.target === m) close(); };
  const upg = $('#upg', m);
  if (upg) upg.onclick = () => {
    const cost = upgradeCost(save.levels[id]);
    if (save.gold < cost) return;
    save.gold -= cost; save.levels[id] += 1; persist(); sfx.win();
    close(); renderUI(); openCard(id);
  };
  $('#use', m).onclick = () => { selCard = id; close(); renderUI(); };
}

// ---------- Combat ----------
const ENEMY_NAMES = ['Kraken_Lord', 'Mira la Rusée', 'ToxicPanda', 'Sir Boulon', 'LunaFlash', 'Gromak', 'NeoVortex', 'Pixelion', 'Zéphyr77', 'La Taupe'];

function startMatchmaking() {
  initAudio();
  const isl = islandFor(save.trophies);
  ui.className = 'ui matchmaking';
  ui.innerHTML = `<div class="mm"><div class="mm-title"><span class="loupe">🔍</span><div><b>Recherche d’adversaire…</b><small>Île : ${isl.name}</small></div></div>
    <div class="mm-vs"><div class="mm-p blue"><b>${save.name}</b><small>🏆 ${save.trophies}</small></div><div class="vs">VS</div><div class="mm-p red" id="opp"><b>???</b><small>🏆 ???</small></div></div>
    <button class="big-btn red" id="cancel">Annuler</button>
    <div class="tip"><b>Conseil</b><p>${['Placez le Golem de Basalte derrière votre Tour Cœur pour accumuler de l’essence.', 'La Nova de Givre stoppe net une poussée ennemie.', 'Le Totem Arcanique attire les unités qui visent les bâtiments.', 'Les Archères Sylvaines touchent le Chevaucheur de Drake.'][Math.floor(Math.random() * 4)]}</p></div></div>`;
  let cancelled = false;
  $('#cancel').onclick = () => { cancelled = true; sfx.click(); renderUI(); };
  const name = ENEMY_NAMES[Math.floor(Math.random() * ENEMY_NAMES.length)];
  const trophies = Math.max(0, save.trophies + Math.round((Math.random() - 0.5) * 120));
  setTimeout(() => { if (cancelled) return; $('#opp b').textContent = name; $('#opp small').textContent = `🏆 ${trophies}`; sfx.crown(); }, 1500);
  setTimeout(() => { if (!cancelled) startBattle(name, isl); }, 2700);
}

function startBattle(enemyName, isl) {
  ui.className = 'ui hidden';
  ui.innerHTML = '';
  const enemyDeck = [...PLAYABLE].sort(() => Math.random() - 0.5).slice(0, 8);
  const eLvl = {};
  const avg = Math.round(Object.values(save.levels).reduce((a, b) => a + b, 0) / PLAYABLE.length);
  for (const id of PLAYABLE) eLvl[id] = Math.max(1, Math.min(MAX_LEVEL, avg + isl.id - (Math.random() < 0.5 ? 1 : 0)));
  battle = new Battle({
    renderer, root: app, deck: save.deck, enemyDeck, island: isl, enemyName, cardImages,
    levels: [save.levels, eLvl],
    onEnd: (res) => endBattle(res, enemyName),
  });
}

function endBattle({ winner, crowns }, enemyName) {
  const win = winner === 0, draw = winner === -1;
  const dT = draw ? 0 : win ? 28 + Math.floor(Math.random() * 6) : -(16 + Math.floor(Math.random() * 6));
  const gold = draw ? 20 : win ? 60 + crowns[0] * 20 : 10;
  const before = islandFor(save.trophies);
  save.trophies = Math.max(0, save.trophies + dT);
  save.gold += gold;
  if (win) save.wins++; else if (!draw) save.losses++;
  persist();
  const after = islandFor(save.trophies);
  win ? sfx.win() : sfx.lose();
  const crownRow = (n, cls) => `<div class="crown-row ${cls}">${[0, 1, 2].map((i) => `<span class="${i < n ? 'on' : ''}" style="animation-delay:${0.3 + i * 0.25}s">👑</span>`).join('')}</div>`;
  ui.className = 'ui result';
  ui.innerHTML = `<div class="res-box ${win ? 'win' : draw ? 'draw' : 'lose'}">
    <div class="res-title">${win ? 'Victoire !' : draw ? 'Égalité' : 'Défaite'}</div>
    <div class="res-p red"><b>${enemyName}</b>${crownRow(crowns[1], 'red')}</div>
    <div class="res-p blue"><b>${save.name}</b>${crownRow(crowns[0], 'blue')}</div>
    <div class="rewards"><div>🏆 ${dT >= 0 ? '+' : ''}${dT}</div><div>🪙 +${gold}</div></div>
    ${after.id > before.id ? `<div class="unlock">🏝️ Nouvelle île débloquée : <b>${after.name}</b> !</div>` : ''}
    <button class="big-btn" id="ok">OK</button></div>`;
  $('#ok').onclick = () => {
    sfx.click();
    battle.dispose();
    battle = null;
    buildMenuScene();
    tab = 'battle';
    renderUI();
  };
}

// ---------- Boucle principale ----------
let last = performance.now();
let acc = 0;
function loop(t) {
  requestAnimationFrame(loop);
  const dt = Math.min(0.1, (t - last) / 1000);
  last = t;
  const now = t / 1000;
  if (battle) {
    acc += dt;
    const step = 1 / 60;
    while (acc >= step) { battle.update(step); acc -= step; }
    battle.render(dt, now);
  } else {
    renderMenu(now);
  }
}

window.addEventListener('resize', () => { if (!battle) renderer.setSize(app.clientWidth, app.clientHeight); });
document.addEventListener('pointerdown', initAudio, { once: true });
document.addEventListener('contextmenu', (e) => e.preventDefault());

// ---------- Démarrage : écran du studio ----------
async function boot() {
  const splash = $('#splash');
  await document.fonts.load('20px "Lilita One"').catch(() => {});
  await new Promise((r) => setTimeout(r, 50));
  renderCardImages();
  buildMenuScene();
  requestAnimationFrame(loop);
  const bar = $('#load-fill');
  let p = 0;
  const iv = setInterval(() => {
    p = Math.min(100, p + 4 + Math.random() * 8);
    bar.style.width = p + '%';
    $('#load-pct').textContent = Math.floor(p) + '%';
    if (p >= 100) {
      clearInterval(iv);
      setTimeout(() => { splash.classList.add('hide'); setTimeout(() => splash.remove(), 600); renderUI(); }, 300);
    }
  }, 90);
}
boot();
