// Modèles 3D procéduraux (style cartoon brillant) pour unités, tours et arènes.
import * as THREE from 'three';

export const TEAM_COLORS = [0x2f86ff, 0xff3d4f];
const TEAM_GLOW = [0x6fd0ff, 0xff7a5c];

const matCache = new Map();
export function mat(color, opts = {}) {
  const key = color + JSON.stringify(opts);
  if (!matCache.has(key)) {
    matCache.set(key, new THREE.MeshStandardMaterial({ color, roughness: 0.55, metalness: 0.05, ...opts }));
  }
  return matCache.get(key);
}
const glow = (color, intensity = 1.6) => mat(color, { emissive: color, emissiveIntensity: intensity, roughness: 0.3 });

function m(geo, material, x = 0, y = 0, z = 0, parent) {
  const o = new THREE.Mesh(geo, material);
  o.position.set(x, y, z);
  o.castShadow = true;
  o.receiveShadow = true;
  if (parent) parent.add(o);
  return o;
}
const sphere = (r, w = 16, h = 12) => new THREE.SphereGeometry(r, w, h);
const box = (x, y, z) => new THREE.BoxGeometry(x, y, z);
const cyl = (rt, rb, h, s = 14) => new THREE.CylinderGeometry(rt, rb, h, s);
const cone = (r, h, s = 14) => new THREE.ConeGeometry(r, h, s);

function pivot(parent, x, y, z) {
  const g = new THREE.Group();
  g.position.set(x, y, z);
  parent.add(g);
  return g;
}

// Humanoïde générique : grosse tête cartoon, membres articulés.
function humanoid(o) {
  const root = new THREE.Group();
  const body = new THREE.Group();
  root.add(body);
  const s = o.scale || 1;
  body.scale.setScalar(s);
  const skin = mat(o.skin ?? 0xf2c19b);
  const cloth = mat(o.cloth ?? 0x555555, o.clothOpts || {});
  const pants = mat(o.pants ?? 0x3b3b48);

  const legL = pivot(body, -0.17, 0.5, 0);
  const legR = pivot(body, 0.17, 0.5, 0);
  for (const leg of [legL, legR]) {
    m(cyl(0.11, 0.1, 0.42), pants, 0, -0.22, 0, leg);
    m(box(0.2, 0.12, 0.3), mat(o.boots ?? 0x4a2f1f), 0, -0.44, 0.05, leg);
  }
  const torso = m(cyl(0.3, 0.34, 0.55, 16), cloth, 0, 0.78, 0, body);
  m(cyl(0.36, 0.36, 0.08, 16), mat(o.belt ?? 0x6b4423), 0, 0.55, 0, body);
  const headG = pivot(body, 0, 1.2, 0);
  const head = m(sphere(0.33), skin, 0, 0.12, 0, headG);
  head.scale.set(1, 1.02, 0.95);
  // yeux
  const eyeMat = o.eyeGlow ? glow(o.eyeGlow, 3) : mat(0x1b1b22, { roughness: 0.2 });
  m(sphere(0.055, 8, 6), eyeMat, -0.12, 0.16, 0.29, headG);
  m(sphere(0.055, 8, 6), eyeMat, 0.12, 0.16, 0.29, headG);
  const armL = pivot(body, -0.4, 0.98, 0);
  const armR = pivot(body, 0.4, 0.98, 0);
  for (const arm of [armL, armR]) {
    m(cyl(0.09, 0.08, 0.42), cloth, 0, -0.2, 0, arm);
    m(sphere(0.1, 10, 8), skin, 0, -0.44, 0, arm);
  }
  root.userData.rig = { body, legL, legR, armL, armR, headG, torso };
  return root;
}

function teamTrim(team) { return mat(TEAM_COLORS[team]); }

const builders = {
  blade(team) {
    const r = humanoid({ skin: 0x9fd8ff, cloth: 0x2b2440, pants: 0x1d1830, boots: 0x15121f, eyeGlow: 0x7ff6ff,
      skin2: true });
    const { headG, armR, body } = r.userData.rig;
    // capuche
    const hood = m(sphere(0.38, 16, 12, 0), mat(0x2b2440), 0, 0.16, -0.04, headG);
    hood.scale.set(1.05, 1.08, 1.1);
    headG.children[0].material = mat(0x0c0f1c);
    m(cone(0.3, 0.35), mat(0x2b2440), 0, 0.5, -0.15, headG).rotation.x = -0.6;
    // écharpe d'équipe
    m(cyl(0.33, 0.36, 0.12, 16), teamTrim(team), 0, 1.05, 0, body);
    const cape = m(box(0.55, 0.7, 0.05), teamTrim(team), 0, 0.75, -0.32, body);
    cape.rotation.x = 0.15;
    // lame spectrale
    const sword = pivot(armR, 0, -0.45, 0.05);
    m(box(0.07, 0.95, 0.16), glow(0x63f5ff, 2.2), 0, 0.5, 0, sword).material.transparent = false;
    m(box(0.3, 0.06, 0.08), mat(0x8a8fa8, { metalness: 0.8, roughness: 0.3 }), 0, 0.02, 0, sword);
    sword.rotation.x = Math.PI / 2.3;
    r.userData.weapon = sword;
    return r;
  },
  archers(team) {
    const r = humanoid({ skin: 0xf6cfae, cloth: 0x2f7d3a, pants: 0x4a3524, boots: 0x3a2516 });
    const { headG, armL, body } = r.userData.rig;
    // cheveux et oreilles d'elfe
    const hair = m(sphere(0.36), mat(0xf1d36b), 0, 0.2, -0.05, headG);
    hair.scale.set(1.02, 0.9, 1.05);
    m(cone(0.07, 0.3, 6), mat(0xf6cfae), -0.34, 0.12, 0, headG).rotation.z = 1.2;
    m(cone(0.07, 0.3, 6), mat(0xf6cfae), 0.34, 0.12, 0, headG).rotation.z = -1.2;
    m(cone(0.2, 0.55), mat(0xf1d36b), 0, -0.05, -0.32, headG).rotation.x = 2.7;
    // capuche d'équipe
    m(box(0.62, 0.12, 0.6), teamTrim(team), 0, 1.07, 0, body);
    // arc
    const bow = pivot(armL, 0, -0.45, 0.1);
    const arc = m(new THREE.TorusGeometry(0.45, 0.035, 6, 20, Math.PI), mat(0x8b5a2b), 0, 0, 0, bow);
    arc.rotation.z = -Math.PI / 2;
    m(cyl(0.008, 0.008, 0.9, 4), mat(0xffffff), 0, 0, 0, bow);
    bow.rotation.x = Math.PI / 2;
    // carquois
    m(cyl(0.1, 0.09, 0.5, 10), mat(0x6b3f1f), 0.15, 0.85, -0.33, body).rotation.z = 0.3;
    r.userData.weapon = bow;
    return r;
  },
  pyro(team) {
    const r = humanoid({ skin: 0xe9b48f, cloth: 0xb32d1a, pants: 0xb32d1a, boots: 0x2a1a12 });
    const { headG, armR, body, legL, legR } = r.userData.rig;
    // robe longue
    m(cone(0.48, 0.8, 18), mat(0x9c2414), 0, 0.42, 0, body);
    legL.visible = legR.visible = false;
    // chapeau pointu
    const hat = m(cone(0.42, 0.75, 18), mat(0x5a1810), 0, 0.68, 0, headG);
    hat.rotation.z = 0.15;
    m(cyl(0.55, 0.55, 0.05, 20), mat(0x5a1810), 0, 0.36, 0, headG);
    m(cyl(0.43, 0.43, 0.08, 20), teamTrim(team), 0, 0.42, 0, headG);
    // barbe
    m(cone(0.2, 0.45, 10), mat(0xdddddd), 0, -0.15, 0.22, headG).rotation.x = Math.PI;
    // bâton + orbe de feu
    const staff = pivot(armR, 0, -0.45, 0);
    m(cyl(0.04, 0.04, 1.6, 8), mat(0x5b3a1e), 0, 0.3, 0, staff);
    m(sphere(0.16), glow(0xff8a1f, 2.5), 0, 1.15, 0, staff);
    r.userData.weapon = staff;
    r.userData.orb = staff.children[1];
    return r;
  },
  swarm(team) {
    const r = new THREE.Group();
    const body = new THREE.Group();
    r.add(body);
    const shell = m(sphere(0.28, 16, 10), mat(TEAM_COLORS[team], { metalness: 0.6, roughness: 0.25 }), 0, 0.25, 0, body);
    shell.scale.set(1, 0.7, 1.3);
    m(sphere(0.16, 12, 8), mat(0x1a1a1a, { metalness: 0.4, roughness: 0.3 }), 0, 0.22, 0.32, body);
    m(cone(0.05, 0.25, 6), mat(0xffd34d, { metalness: 0.7 }), 0, 0.32, 0.48, body).rotation.x = 1.1;
    m(sphere(0.04, 6, 6), glow(0xfff176), -0.07, 0.27, 0.45, body);
    m(sphere(0.04, 6, 6), glow(0xfff176), 0.07, 0.27, 0.45, body);
    const legs = [];
    for (let i = 0; i < 3; i++) for (const sx of [-1, 1]) {
      const leg = m(cyl(0.02, 0.02, 0.28, 4), mat(0x111111), sx * 0.24, 0.12, -0.15 + i * 0.15, body);
      leg.rotation.z = sx * 0.9;
      legs.push(leg);
    }
    r.userData.rig = { body, legs };
    return r;
  },
  golem(team, small = false) {
    const r = new THREE.Group();
    const body = new THREE.Group();
    r.add(body);
    const rock = mat(0x4a4a52, { roughness: 0.9, flatShading: true });
    const lava = glow(0xff6a00, 2.4);
    const core = m(new THREE.DodecahedronGeometry(0.85, 0), rock, 0, 1.55, 0, body);
    core.scale.set(1.15, 1, 0.9);
    m(new THREE.OctahedronGeometry(0.28, 0), lava, 0, 1.6, 0.68, body);
    const headG = pivot(body, 0, 2.35, 0.15);
    m(new THREE.DodecahedronGeometry(0.42, 0), rock, 0, 0, 0, headG);
    m(box(0.5, 0.07, 0.1), lava, 0, 0.05, 0.36, headG);
    m(box(0.9, 0.18, 0.18), teamTrim(team), 0, 2.05, 0.35, body);
    const armL = pivot(body, -1.05, 2.0, 0);
    const armR = pivot(body, 1.05, 2.0, 0);
    for (const a of [armL, armR]) {
      m(new THREE.DodecahedronGeometry(0.4, 0), rock, 0, -0.35, 0, a);
      m(new THREE.DodecahedronGeometry(0.5, 0), rock, 0, -1.0, 0.05, a);
      m(box(0.12, 0.3, 0.12), lava, 0, -0.7, 0.3, a);
    }
    const legL = pivot(body, -0.45, 0.85, 0);
    const legR = pivot(body, 0.45, 0.85, 0);
    for (const l of [legL, legR]) m(new THREE.DodecahedronGeometry(0.42, 0), rock, 0, -0.45, 0, l);
    if (small) body.scale.setScalar(0.45);
    r.userData.rig = { body, legL, legR, armL, armR, headG, heavy: true };
    return r;
  },
  shard(team) { return builders.golem(team, true); },
  storm(team) {
    const r = humanoid({ skin: 0x7c8aa8, cloth: 0x5d6a85, clothOpts: { metalness: 0.75, roughness: 0.3 },
      pants: 0x3c4458, boots: 0x2a3040, eyeGlow: 0x8fe9ff, scale: 1.75 });
    const { headG, armR, body, torso } = r.userData.rig;
    torso.scale.set(1.35, 1, 1.2);
    m(sphere(0.17), glow(0x59d8ff, 3), 0, 0.85, 0.33, body);
    m(sphere(0.2), mat(0x8c9ab8, { metalness: 0.8, roughness: 0.25 }), -0.5, 1.08, 0, body).scale.set(1.3, 0.8, 1.2);
    m(sphere(0.2), mat(0x8c9ab8, { metalness: 0.8, roughness: 0.25 }), 0.5, 1.08, 0, body).scale.set(1.3, 0.8, 1.2);
    // casque à cornes
    m(sphere(0.36, 16, 10, 0, Math.PI * 2, 0, Math.PI / 1.8), mat(0x8c9ab8, { metalness: 0.8, roughness: 0.25 }), 0, 0.15, 0, headG);
    m(cone(0.07, 0.4, 8), teamTrim(team), -0.3, 0.45, 0, headG).rotation.z = 0.5;
    m(cone(0.07, 0.4, 8), teamTrim(team), 0.3, 0.45, 0, headG).rotation.z = -0.5;
    // marteau-tempête
    const ham = pivot(armR, 0, -0.45, 0);
    m(cyl(0.04, 0.04, 1.0, 8), mat(0x3a2a1a), 0, 0.3, 0, ham);
    m(box(0.45, 0.28, 0.28), mat(0x9aa7c2, { metalness: 0.9, roughness: 0.2 }), 0, 0.8, 0, ham);
    m(box(0.47, 0.06, 0.3), glow(0x59d8ff, 2.5), 0, 0.8, 0, ham);
    ham.rotation.x = 0.4;
    r.userData.weapon = ham;
    return r;
  },
  shield(team) {
    const steel = mat(0xc3c9d6, { metalness: 0.85, roughness: 0.25 });
    const r = humanoid({ skin: 0xf0c4a0, cloth: 0xc3c9d6, clothOpts: { metalness: 0.85, roughness: 0.25 }, pants: 0x6d7385, boots: 0x6d7385 });
    const { headG, armR, armL } = r.userData.rig;
    const helm = m(sphere(0.37, 16, 12), steel, 0, 0.14, -0.02, headG);
    helm.scale.set(1, 1.05, 1);
    m(box(0.5, 0.06, 0.06), mat(0x222222), 0, 0.15, 0.34, headG);
    m(box(0.08, 0.35, 0.45), teamTrim(team), 0, 0.55, -0.05, headG);
    const sw = pivot(armR, 0, -0.45, 0.05);
    m(box(0.07, 0.8, 0.12), steel, 0, 0.45, 0, sw);
    m(box(0.28, 0.06, 0.1), mat(0xd4a52a, { metalness: 0.8, roughness: 0.3 }), 0, 0.05, 0, sw);
    sw.rotation.x = Math.PI / 2.4;
    const sh = pivot(armL, -0.08, -0.35, 0.18);
    const disc = m(cyl(0.38, 0.38, 0.07, 20), teamTrim(team), 0, 0, 0, sh);
    disc.rotation.x = Math.PI / 2;
    const rim = m(new THREE.TorusGeometry(0.38, 0.04, 6, 20), mat(0xd4a52a, { metalness: 0.8, roughness: 0.3 }), 0, 0, 0.02, sh);
    m(sphere(0.1, 10, 8), mat(0xd4a52a, { metalness: 0.8, roughness: 0.3 }), 0, 0, 0.05, sh);
    void rim;
    r.userData.weapon = sw;
    r.userData.shieldMesh = sh;
    return r;
  },
  sapper(team) {
    const r = humanoid({ skin: 0x8fd16a, cloth: 0x6b4a2b, pants: 0x4a3420, boots: 0x2c1d10, scale: 0.85 });
    const { headG, body } = r.userData.rig;
    m(cone(0.08, 0.35, 6), mat(0x8fd16a), -0.38, 0.18, 0, headG).rotation.z = 1.3;
    m(cone(0.08, 0.35, 6), mat(0x8fd16a), 0.38, 0.18, 0, headG).rotation.z = -1.3;
    m(cyl(0.34, 0.34, 0.12, 16), teamTrim(team), 0, 0.42, 0, headG);
    m(box(0.45, 0.12, 0.08), mat(0x332211), 0, 0.22, 0.3, headG);
    // tonneau sur le dos
    const barrel = pivot(body, 0, 1.0, -0.42);
    m(cyl(0.3, 0.3, 0.6, 14), mat(0x8b5a2b), 0, 0, 0, barrel);
    m(cyl(0.31, 0.31, 0.06, 14), mat(0x333333, { metalness: 0.7 }), 0, 0.2, 0, barrel);
    m(cyl(0.31, 0.31, 0.06, 14), mat(0x333333, { metalness: 0.7 }), 0, -0.2, 0, barrel);
    m(cyl(0.02, 0.02, 0.25, 4), mat(0x222222), 0, 0.42, 0, barrel);
    const spark = m(sphere(0.07, 8, 6), glow(0xffd23f, 4), 0, 0.56, 0, barrel);
    r.userData.spark = spark;
    return r;
  },
  drake(team) {
    const r = new THREE.Group();
    const body = new THREE.Group();
    r.add(body);
    const scale = mat(0x3e9b5a, { roughness: 0.45 });
    const belly = mat(0xe6c27a);
    const torso = m(sphere(0.55, 16, 12), scale, 0, 0, 0, body);
    torso.scale.set(0.9, 0.8, 1.5);
    m(sphere(0.45, 14, 10), belly, 0, -0.18, 0.1, body).scale.set(0.8, 0.6, 1.3);
    const neck = m(cyl(0.18, 0.26, 0.7, 10), scale, 0, 0.35, 0.75, body);
    neck.rotation.x = 0.8;
    const headG = pivot(body, 0, 0.62, 1.1);
    m(box(0.38, 0.3, 0.6), scale, 0, 0, 0.1, headG);
    m(cone(0.06, 0.3, 6), mat(0xeeeeee), -0.12, 0.25, -0.1, headG).rotation.x = -0.6;
    m(cone(0.06, 0.3, 6), mat(0xeeeeee), 0.12, 0.25, -0.1, headG).rotation.x = -0.6;
    m(sphere(0.05, 6, 6), glow(0xffd23f, 3), -0.15, 0.08, 0.3, headG);
    m(sphere(0.05, 6, 6), glow(0xffd23f, 3), 0.15, 0.08, 0.3, headG);
    const tail = m(cone(0.2, 1.3, 10), scale, 0, -0.05, -1.25, body);
    tail.rotation.x = -Math.PI / 2;
    const wingShape = new THREE.Shape();
    wingShape.moveTo(0, 0); wingShape.lineTo(1.6, 0.4); wingShape.lineTo(1.3, -0.2);
    wingShape.lineTo(0.9, -0.1); wingShape.lineTo(0.6, -0.45); wingShape.lineTo(0, -0.4);
    const wingGeo = new THREE.ShapeGeometry(wingShape);
    const wingMat = mat(TEAM_COLORS[team], { side: THREE.DoubleSide, roughness: 0.6 });
    const wingL = pivot(body, -0.35, 0.25, 0.1);
    const wingR = pivot(body, 0.35, 0.25, 0.1);
    const wl = m(wingGeo, wingMat, 0, 0, 0, wingL); wl.rotation.set(-Math.PI / 2, 0, Math.PI); wl.scale.x = 1;
    const wr = m(wingGeo, wingMat, 0, 0, 0, wingR); wr.rotation.set(-Math.PI / 2, 0, 0);
    // cavalier
    const rider = humanoid({ skin: 0xf0c4a0, cloth: TEAM_COLORS[team], scale: 0.5 });
    rider.position.set(0, 0.3, 0.1);
    body.add(rider);
    r.userData.rig = { body, wingL, wingR, headG, flying: true };
    return r;
  },
  totem(team) {
    const r = new THREE.Group();
    const stone = mat(0x8a8f9c, { roughness: 0.85, flatShading: true });
    m(cyl(0.85, 1.0, 0.35, 8), stone, 0, 0.17, 0, r);
    m(cyl(0.45, 0.6, 1.6, 6), stone, 0, 1.1, 0, r);
    m(cyl(0.62, 0.62, 0.12, 6), teamTrim(team), 0, 1.4, 0, r);
    for (let i = 0; i < 3; i++) {
      const rune = m(box(0.12, 0.3, 0.05), glow(TEAM_GLOW[team], 2), 0, 0.9, 0, r);
      rune.position.set(Math.sin(i * 2.1) * 0.5, 0.95, Math.cos(i * 2.1) * 0.5);
      rune.rotation.y = i * 2.1;
    }
    const crystal = m(new THREE.OctahedronGeometry(0.38, 0), glow(TEAM_GLOW[team], 2.2), 0, 2.4, 0, r);
    crystal.scale.y = 1.5;
    r.userData.crystal = crystal;
    r.userData.rig = { body: r };
    return r;
  },
  meteor() {
    const r = new THREE.Group();
    const rock = m(new THREE.DodecahedronGeometry(0.8, 1), mat(0x3a2a22, { roughness: 0.9, flatShading: true }), 0, 0, 0, r);
    for (let i = 0; i < 7; i++) {
      const c = m(box(0.3, 0.08, 0.08), glow(0xff5a00, 3), 0, 0, 0, rock);
      const a = i * 0.9;
      c.position.set(Math.cos(a) * 0.72, Math.sin(a * 1.7) * 0.5, Math.sin(a) * 0.72);
      c.lookAt(0, 0, 0);
    }
    m(sphere(0.95, 16, 12), mat(0xff7a1a, { emissive: 0xff4400, emissiveIntensity: 1.5, transparent: true, opacity: 0.35 }), 0, 0, 0, r).castShadow = false;
    return r;
  },
  frost() {
    const r = new THREE.Group();
    const ice = mat(0xaeeaff, { emissive: 0x4fc3ff, emissiveIntensity: 0.6, metalness: 0.2, roughness: 0.1, transparent: true, opacity: 0.9 });
    for (let i = 0; i < 7; i++) {
      const c = m(new THREE.OctahedronGeometry(0.3, 0), ice, 0, 0, 0, r);
      c.scale.set(0.6, 2 + (i % 3) * 0.6, 0.6);
      c.rotation.z = (i - 3) * 0.35;
      c.rotation.x = Math.sin(i * 1.3) * 0.4;
      c.position.set((i - 3) * 0.15, 0.3, Math.cos(i) * 0.15);
    }
    m(sphere(0.25), glow(0xffffff, 2), 0, 0.2, 0, r);
    return r;
  },
};

export function buildModel(cardId, team) {
  const g = builders[cardId](team);
  g.userData.cardId = cardId;
  return g;
}

// Animation : phase de marche, intensité d'attaque (0..1).
export function animate(model, t, moving, attack, seed = 0) {
  const rig = model.userData.rig;
  if (!rig) return;
  const w = moving ? Math.sin(t * (rig.heavy ? 5 : 9) + seed) : 0;
  if (rig.flying) {
    const f = Math.sin(t * 7 + seed);
    rig.wingL.rotation.z = -f * 0.6;
    rig.wingR.rotation.z = f * 0.6;
    rig.body.position.y = Math.sin(t * 2 + seed) * 0.15;
    rig.headG.rotation.x = -attack * 0.5;
    return;
  }
  if (rig.legs) { // scarabée
    rig.legs.forEach((l, i) => { l.rotation.x = Math.sin(t * 22 + i * 1.7 + seed) * (moving ? 0.6 : 0); });
    rig.body.position.y = moving ? Math.abs(Math.sin(t * 22 + seed)) * 0.04 : 0;
    rig.body.rotation.x = -attack * 0.4;
    return;
  }
  if (rig.legL) {
    rig.legL.rotation.x = w * 0.7;
    rig.legR.rotation.x = -w * 0.7;
    rig.body.position.y = moving ? Math.abs(w) * 0.06 : Math.sin(t * 2 + seed) * 0.015;
  }
  if (rig.armL) {
    rig.armL.rotation.x = -w * 0.5;
    rig.armR.rotation.x = w * 0.5 - attack * 2.2;
    if (rig.heavy) { rig.armL.rotation.x = -attack * 2.0 - w * 0.3; }
  }
  if (rig.torso) rig.torso.rotation.y = attack * 0.3;
}

// ---------- Tours ----------
export function buildTower(team, core = false) {
  const g = new THREE.Group();
  const stone = mat(0xb9b2a5, { roughness: 0.8 });
  const stoneDark = mat(0x8c8579, { roughness: 0.85 });
  const wood = mat(0x7a4a26);
  const trim = teamTrim(team);
  const gold = mat(0xf4c542, { metalness: 0.7, roughness: 0.3 });
  if (!core) {
    m(cyl(1.35, 1.55, 0.45, 10), stoneDark, 0, 0.22, 0, g);
    m(cyl(1.15, 1.3, 2.2, 12), stone, 0, 1.55, 0, g);
    // pierres décoratives
    for (let i = 0; i < 10; i++) {
      const a = (i / 10) * Math.PI * 2;
      m(box(0.35, 0.22, 0.12), stoneDark, Math.cos(a) * 1.25, 0.9 + (i % 2) * 0.7, Math.sin(a) * 1.25, g).rotation.y = -a + Math.PI / 2;
    }
    m(cyl(1.4, 1.2, 0.3, 12), trim, 0, 2.75, 0, g);
    for (let i = 0; i < 8; i++) {
      const a = (i / 8) * Math.PI * 2;
      m(box(0.35, 0.4, 0.35), stone, Math.cos(a) * 1.2, 3.1, Math.sin(a) * 1.2, g);
    }
    // porte
    m(box(0.6, 0.85, 0.1), wood, 0, 0.85, 1.25 * (team === 0 ? 1 : -1), g);
    // gardien-arbalète
    const guard = humanoid({ skin: 0xf0c4a0, cloth: TEAM_COLORS[team], scale: 0.7 });
    guard.position.set(0, 2.85, 0);
    g.add(guard);
    const bow = m(box(0.9, 0.08, 0.1), wood, 0, 0.55, 0.45, guard.userData.rig.body);
    void bow;
    g.userData.guard = guard;
    // bannière
    const pole = m(cyl(0.04, 0.04, 1.3, 6), wood, 0.9, 3.6, -0.6, g);
    void pole;
    const flag = m(box(0.02, 0.45, 0.6), trim, 0.9, 3.95, -0.3, g);
    g.userData.flag = flag;
    const crystal = m(new THREE.OctahedronGeometry(0.25, 0), glow(TEAM_GLOW[team], 2), -0.9, 3.7, -0.6, g);
    g.userData.crystal = crystal;
  } else {
    m(box(3.6, 0.5, 3.6), stoneDark, 0, 0.25, 0, g);
    m(box(3.1, 2.4, 3.1), stone, 0, 1.7, 0, g);
    m(box(3.4, 0.3, 3.4), trim, 0, 2.95, 0, g);
    for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
      m(cyl(0.5, 0.55, 3.6, 10), stone, sx * 1.5, 1.8, sz * 1.5, g);
      m(cone(0.65, 0.9, 10), trim, sx * 1.5, 4.05, sz * 1.5, g);
      m(sphere(0.12, 8, 6), gold, sx * 1.5, 4.55, sz * 1.5, g);
    }
    m(box(0.9, 1.3, 0.12), wood, 0, 1.0, 1.58 * (team === 0 ? 1 : -1), g);
    m(new THREE.TorusGeometry(0.55, 0.1, 8, 20), gold, 0, 2.1, 1.6 * (team === 0 ? 1 : -1), g);
    // grand cristal d'essence
    const base = m(cyl(0.6, 0.9, 0.5, 8), gold, 0, 3.35, 0, g);
    void base;
    const crystal = m(new THREE.OctahedronGeometry(0.75, 0), glow(TEAM_GLOW[team], 1.8), 0, 4.6, 0, g);
    crystal.scale.y = 1.6;
    g.userData.crystal = crystal;
    const guard = humanoid({ skin: 0xf0c4a0, cloth: TEAM_COLORS[team], scale: 0.85 });
    m(cone(0.3, 0.45, 5), gold, 0, 0.6, 0, guard.userData.rig.headG);
    guard.position.set(0.9, 3.1, 0.9 * (team === 0 ? 1 : -1));
    g.add(guard);
    g.userData.guard = guard;
  }
  return g;
}

export function buildRubble() {
  const g = new THREE.Group();
  const s = mat(0x6d675d, { roughness: 0.95, flatShading: true });
  for (let i = 0; i < 9; i++) {
    const r = 0.25 + Math.random() * 0.45;
    const o = m(new THREE.DodecahedronGeometry(r, 0), s, (Math.random() - 0.5) * 2.2, r * 0.6, (Math.random() - 0.5) * 2.2, g);
    o.rotation.set(Math.random() * 3, Math.random() * 3, 0);
  }
  return g;
}

// ---------- Îles / arènes ----------
export const ISLANDS = [
  { id: 0, name: 'Île des Brumes', trophies: 0, grass: '#58b847', grass2: '#4ea83f', tile: '#d8c9a3', water: '#2ab7e8', sky: 0x8fd8ff, fog: 0xbfe8ff, cliff: 0x8a6b4a },
  { id: 1, name: 'Île de Braise', trophies: 300, grass: '#7a8a3c', grass2: '#6d7c33', tile: '#c9a98a', water: '#ff6a1a', sky: 0xffb27a, fog: 0xffcc9a, cliff: 0x5a3a2a },
  { id: 2, name: 'Île Givrée', trophies: 700, grass: '#cfe7f2', grass2: '#bcdbea', tile: '#a7b8c9', water: '#4fd2ff', sky: 0xb7d6ff, fog: 0xdcecff, cliff: 0x7a8ca6 },
  { id: 3, name: 'Île Céleste', trophies: 1200, grass: '#8f6cd8', grass2: '#7f5ec9', tile: '#e6d7a8', water: '#ffd84f', sky: 0x9a7bff, fog: 0xd2c2ff, cliff: 0x5a4a8a },
];

export function islandFor(trophies) {
  let isl = ISLANDS[0];
  for (const i of ISLANDS) if (trophies >= i.trophies) isl = i;
  return isl;
}

function groundTexture(isl) {
  const c = document.createElement('canvas');
  c.width = 512; c.height = 896;
  const x = c.getContext('2d');
  const W = 18, H = 32, sx = c.width / W, sz = c.height / H;
  // herbe en damier
  for (let i = 0; i < W; i++) for (let j = 0; j < H; j++) {
    x.fillStyle = (i + j) % 2 ? isl.grass : isl.grass2;
    x.fillRect(i * sx, j * sz, sx + 1, sz + 1);
  }
  // bruit
  for (let k = 0; k < 4000; k++) {
    x.fillStyle = `rgba(${Math.random() < 0.5 ? '0,0,0' : '255,255,255'},0.05)`;
    x.fillRect(Math.random() * c.width, Math.random() * c.height, 2, 2);
  }
  const path = (x0, z0, x1, z1) => {
    x.fillStyle = isl.tile;
    x.fillRect((x0 + 9) * sx, (z0 + 16) * sz, (x1 - x0) * sx, (z1 - z0) * sz);
    x.strokeStyle = 'rgba(0,0,0,0.12)';
    x.lineWidth = 2;
    for (let i = x0; i < x1; i += 0.75) for (let j = z0; j < z1; j += 0.75)
      x.strokeRect((i + 9) * sx + 1, (j + 16) * sz + 1, 0.75 * sx - 2, 0.75 * sz - 2);
  };
  // chemins des voies
  for (const lx of [-5.5, 5.5]) path(lx - 0.75, -12, lx + 0.75, 12);
  path(-5.5, 11.2, 5.5, 12.4);
  path(-5.5, -12.4, 5.5, -11.2);
  // ombre des bords
  const grd = x.createLinearGradient(0, 0, 40, 0);
  grd.addColorStop(0, 'rgba(0,0,0,0.25)'); grd.addColorStop(1, 'rgba(0,0,0,0)');
  x.fillStyle = grd; x.fillRect(0, 0, 40, c.height);
  x.save(); x.translate(c.width, 0); x.scale(-1, 1); x.fillRect(0, 0, 40, c.height); x.restore();
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 4;
  return t;
}

function waterTexture(color) {
  const c = document.createElement('canvas');
  c.width = 256; c.height = 64;
  const x = c.getContext('2d');
  x.fillStyle = color; x.fillRect(0, 0, 256, 64);
  x.strokeStyle = 'rgba(255,255,255,0.45)';
  x.lineWidth = 3;
  for (let i = 0; i < 9; i++) {
    x.beginPath();
    const y = 6 + i * 7;
    for (let k = 0; k <= 256; k += 8) x.lineTo(k, y + Math.sin(k / 20 + i) * 2.5);
    x.stroke();
  }
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.repeat.set(3, 1);
  return t;
}

function tree(parent, x, z, s, isl) {
  const g = new THREE.Group();
  g.position.set(x, 0, z);
  g.scale.setScalar(s);
  const leaf = isl.id === 2 ? 0xe8f6ff : isl.id === 1 ? 0xd9661f : isl.id === 3 ? 0xff9ad5 : 0x3f9e3a;
  m(cyl(0.18, 0.25, 1.2, 8), mat(0x6b4423), 0, 0.6, 0, g);
  m(new THREE.IcosahedronGeometry(0.9, 0), mat(leaf, { flatShading: true }), 0, 1.7, 0, g);
  m(new THREE.IcosahedronGeometry(0.65, 0), mat(leaf, { flatShading: true }), 0.3, 2.3, 0.1, g);
  parent.add(g);
}

export function buildArena(isl) {
  const g = new THREE.Group();
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(18, 32), new THREE.MeshStandardMaterial({ map: groundTexture(isl), roughness: 0.95 }));
  ground.rotation.x = -Math.PI / 2;
  ground.receiveShadow = true;
  g.add(ground);
  // île flottante : socle rocheux
  const cliff = mat(isl.cliff, { roughness: 0.95, flatShading: true });
  const base = m(cyl(15, 7, 10, 10), cliff, 0, -5.2, 0, g);
  base.scale.set(1, 1, 1.75);
  base.receiveShadow = true;
  const lip = m(box(24, 0.6, 38), mat(new THREE.Color(isl.grass).getHex(), { roughness: 1 }), 0, -0.32, 0, g);
  void lip;
  for (let i = 0; i < 14; i++) {
    const r = m(new THREE.DodecahedronGeometry(1 + Math.random() * 1.5, 0), cliff, (Math.random() - 0.5) * 22, -2 - Math.random() * 8, (Math.random() - 0.5) * 40, g);
    r.rotation.set(Math.random() * 3, Math.random() * 3, 0);
  }
  // rivière
  const wtex = waterTexture(isl.water);
  const water = new THREE.Mesh(new THREE.PlaneGeometry(24, 2.4), new THREE.MeshStandardMaterial({ map: wtex, roughness: 0.15, metalness: 0.1, emissive: isl.id === 1 ? 0xff3300 : 0x000000, emissiveIntensity: 0.4 }));
  water.rotation.x = -Math.PI / 2;
  water.position.y = -0.08;
  g.add(water);
  g.userData.water = wtex;
  const bankMat = mat(0xa8865a, { roughness: 0.9 });
  m(box(18, 0.25, 0.25), bankMat, 0, -0.02, 1.25, g);
  m(box(18, 0.25, 0.25), bankMat, 0, -0.02, -1.25, g);
  // ponts
  for (const bx of [-5.5, 5.5]) {
    for (let i = 0; i < 7; i++) m(box(2.4, 0.18, 0.42), mat(0x9a6233), bx, 0.08, -1.35 + i * 0.45, g);
    for (const sx of [-1.25, 1.25]) {
      m(box(0.12, 0.5, 3.1), mat(0x6b3f1f), bx + sx, 0.4, 0, g);
      for (const sz of [-1.4, 0, 1.4]) m(cyl(0.1, 0.1, 0.75, 6), mat(0x5a341a), bx + sx, 0.3, sz, g);
    }
  }
  // murets du bord
  const wall = mat(0xc9bfae, { roughness: 0.85 });
  for (const sx of [-9.3, 9.3]) {
    m(box(0.6, 0.7, 32.6), wall, sx, 0.35, 0, g);
    for (let z = -15; z <= 15; z += 3) m(box(0.8, 0.9, 0.8), wall, sx, 0.45, z, g);
  }
  for (const sz of [-16.3, 16.3]) m(box(19.2, 0.7, 0.6), wall, 0, 0.35, sz, g);
  // décor
  for (let i = 0; i < 18; i++) {
    const side = i % 2 ? 1 : -1;
    tree(g, side * (10.6 + Math.random() * 1.8), -16 + (i / 18) * 32 + Math.random(), 0.8 + Math.random() * 0.5, isl);
  }
  for (const sz of [-1, 1]) for (let i = 0; i < 6; i++) tree(g, -9 + i * 3.6 + Math.random(), sz * (17.4 + Math.random()), 0.9, isl);
  // torches
  for (const sx of [-8.6, 8.6]) for (const sz of [-1.8, 1.8]) {
    m(cyl(0.08, 0.1, 1.1, 6), mat(0x4a2f1f), sx, 0.55, sz, g);
    m(sphere(0.16, 8, 6), glow(0xffa21f, 3), sx, 1.2, sz, g);
  }
  return g;
}
