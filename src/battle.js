// Moteur de combat : simulation, IA, rendu 3D et HUD.
import * as THREE from 'three';
import { CARDS, TOWER } from './cards.js';
import { buildModel, buildTower, buildRubble, buildArena, animate, TEAM_COLORS } from './models.js';
import { FX } from './fx.js';
import { sfx } from './audio.js';

const RIVER = 1.3;
const BRIDGE_X = 5.5;
const BATTLE_TIME = 180;
const OVERTIME = 60;
const ESSENCE_RATE = 1 / 2.8;
const SIGHT = 5.5;

let nextId = 1;
const dist = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);
const shuffle = (a) => { for (let i = a.length - 1; i > 0; i--) { const j = (Math.random() * (i + 1)) | 0; [a[i], a[j]] = [a[j], a[i]]; } return a; };

export class Battle {
  constructor({ renderer, root, deck, enemyDeck, island, enemyName, cardImages, onEnd, levels = [{}, {}] }) {
    this.levels = levels;
    this.renderer = renderer;
    this.root = root;
    this.island = island;
    this.onEnd = onEnd;
    this.cardImages = cardImages;
    this.enemyName = enemyName;
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(island.sky);
    this.scene.fog = new THREE.Fog(island.fog, 70, 160);
    this.camera = new THREE.PerspectiveCamera(40, 1, 0.5, 200);
    this.setupLights();
    this.arena = buildArena(island);
    this.scene.add(this.arena);
    this.fx = new FX(this.scene);
    this.entities = [];
    this.projectiles = [];
    this.pending = [];
    this.time = BATTLE_TIME;
    this.overtime = false;
    this.elapsed = 0;
    this.over = false;
    this.crowns = [0, 0];
    this.essence = [5, 5];
    this.players = [this.makeHand(deck), this.makeHand(enemyDeck)];
    this.selected = -1;
    this.ai = { think: 1.5, wantCard: null };
    this.texts = [];
    this.raycaster = new THREE.Raycaster();
    this.groundPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);

    for (const team of [0, 1]) {
      const s = team === 0 ? 1 : -1;
      this.addTower(team, -BRIDGE_X, 10.5 * s, false);
      this.addTower(team, BRIDGE_X, 10.5 * s, false);
      this.addTower(team, 0, 13.6 * s, true);
    }
    this.buildHud();
    this.buildPlacementHelpers();
    this.resize();
    this.onResize = () => this.resize();
    window.addEventListener('resize', this.onResize);
    this.showBanner('Au combat !');
  }

  setupLights() {
    const hemi = new THREE.HemisphereLight(0xdff2ff, 0x5a4a30, 1.35);
    this.scene.add(hemi);
    const sun = new THREE.DirectionalLight(0xfff1d6, 2.6);
    sun.position.set(-10, 26, 12);
    sun.castShadow = true;
    const big = Math.min(window.devicePixelRatio, 2) > 1.5 ? 2048 : 1024;
    sun.shadow.mapSize.set(big, big);
    const c = sun.shadow.camera;
    c.left = -14; c.right = 14; c.top = 20; c.bottom = -20; c.near = 1; c.far = 70;
    sun.shadow.bias = -0.0008;
    sun.shadow.normalBias = 0.03;
    this.scene.add(sun);
    this.scene.add(new THREE.AmbientLight(0xffffff, 0.25));
  }

  makeHand(deck) {
    const q = shuffle([...deck]);
    return { hand: q.slice(0, 4), queue: q.slice(4) };
  }

  cycle(team, slot) {
    const p = this.players[team];
    const used = p.hand[slot];
    p.hand[slot] = p.queue.shift();
    p.queue.push(used);
  }

  // ---------- Entités ----------
  addTower(team, x, z, core) {
    const def = core ? TOWER.core : TOWER.side;
    const mesh = buildTower(team, core);
    mesh.position.set(x, 0, z);
    if (team === 1) mesh.rotation.y = Math.PI;
    this.scene.add(mesh);
    const e = {
      id: nextId++, team, kind: 'tower', core, x, z, y: 0, hp: def.hp, maxHp: def.hp, radius: def.radius,
      dmg: def.dmg, hitSpeed: def.hitSpeed, range: def.range, cooldown: 0, targets: 'both', attack: 'arrow',
      mesh, frozen: 0, alive: true, isBuilding: true, lane: x < 0 ? 0 : x > 0 ? 1 : -1, active: !core,
    };
    this.entities.push(e);
    return e;
  }

  spawnUnit(cardId, team, x, z, delay = 1) {
    const c = CARDS[cardId];
    const mult = this.mult(team, cardId);
    const mesh = buildModel(cardId, team);
    mesh.traverse((o) => { if (o.isMesh) o.castShadow = true; });
    const e = {
      id: nextId++, team, cardId, kind: c.type === 'building' ? 'building' : 'unit', x, z, y: c.flying ? 2.6 : 0,
      hp: c.hp * mult, maxHp: c.hp * mult, shield: (c.shield || 0) * mult, maxShield: (c.shield || 0) * mult, radius: c.radius, speed: c.speed || 0,
      dmg: c.dmg * mult, hitSpeed: c.hitSpeed, range: c.range, cooldown: 0.3, windup: 0, targets: c.targets, attack: c.attack,
      flying: !!c.flying, splash: c.splash || 0, mesh, frozen: 0, alive: true, deploy: delay, target: null, retarget: 0,
      firstStrike: c.firstStrike || 0, isBuilding: c.type === 'building', lifetime: c.lifetime || 0, seed: Math.random() * 10,
      attackAnim: 0, hitPulse: 0, facing: team === 0 ? Math.PI : 0,
    };
    mesh.userData.baseScale = c.heavy ? 1.15 : 1.3;
    mesh.position.set(x, e.y + (delay > 0 ? 3 : 0), z);
    mesh.rotation.y = e.facing;
    // anneau d'équipe au sol
    const ring = new THREE.Mesh(new THREE.RingGeometry(c.radius * 0.85, c.radius * 1.05, 28),
      new THREE.MeshBasicMaterial({ color: TEAM_COLORS[team], transparent: true, opacity: 0.55, depthWrite: false }));
    ring.rotation.x = -Math.PI / 2;
    ring.position.set(x, 0.04, z);
    this.scene.add(ring);
    e.ring = ring;
    this.scene.add(mesh);
    this.entities.push(e);
    return e;
  }

  mult(team, cardId) {
    const base = cardId === 'shard' ? 'golem' : cardId;
    return 1 + 0.1 * ((this.levels[team][base] || 1) - 1);
  }

  deploy(team, cardId, x, z) {
    const c = CARDS[cardId];
    this.essence[team] -= c.cost;
    if (team === 1) this.showFloat(x, z, c.name, '#ff8a8a');
    else this.showFloat(x, z, c.name, '#ffffff');
    if (c.type === 'spell') { this.castSpell(team, cardId, x, z); return; }
    sfx.deploy();
    const n = c.count || 1;
    for (let i = 0; i < n; i++) {
      const a = (i / n) * Math.PI * 2;
      const r = n > 1 ? (n > 3 ? 0.8 : 0.55) : 0;
      this.spawnUnit(cardId, team, x + Math.cos(a) * r, z + Math.sin(a) * r, 1);
    }
    this.fx.dust(x, z, 14, 1.2);
    this.fx.ring(x, z, 1.6, TEAM_COLORS[team], 0.5);
  }

  castSpell(team, cardId, x, z) {
    const c = CARDS[cardId];
    if (cardId === 'meteor') {
      const rock = buildModel('meteor', team);
      rock.position.set(x - 6, 22, z - 4);
      this.scene.add(rock);
      sfx.fire();
      const warn = new THREE.Mesh(new THREE.CircleGeometry(c.radius, 40), new THREE.MeshBasicMaterial({ color: 0xff5500, transparent: true, opacity: 0.25, depthWrite: false }));
      warn.rotation.x = -Math.PI / 2;
      warn.position.set(x, 0.06, z);
      this.scene.add(warn);
      this.pending.push({ t: c.delay, total: c.delay, mesh: rock, warn, from: rock.position.clone(), to: new THREE.Vector3(x, 0.5, z),
        done: () => { this.areaDamage(team, x, z, c.radius, c.dmg * this.mult(team, cardId), c.towerMult, true); this.fx.explosion(x, z, c.radius, 0xff6a00); this.shake(0.5); sfx.boom(); } });
    } else if (cardId === 'frost') {
      sfx.freeze();
      this.areaDamage(team, x, z, c.radius, c.dmg * this.mult(team, cardId), c.towerMult, true, c.freeze);
      this.fx.burst(x, 0.5, z, 0xbff4ff, 40, 6, 0.7, 0.9, { grav: 1 });
      this.fx.ring(x, z, c.radius, 0x8fe6ff, 0.6);
      const crystal = buildModel('frost', team);
      crystal.position.set(x, 0, z);
      crystal.scale.setScalar(1.6);
      this.scene.add(crystal);
      this.pending.push({ t: 0.8, total: 0.8, mesh: crystal, shrink: true, done: () => {} });
    }
  }

  areaDamage(team, x, z, r, dmg, towerMult = 1, hitsAir = true, freeze = 0) {
    for (const e of this.entities) {
      if (!e.alive || e.team === team) continue;
      if (e.flying && !hitsAir) continue;
      if (Math.hypot(e.x - x, e.z - z) > r + e.radius * 0.5) continue;
      this.damage(e, e.kind === 'tower' ? dmg * towerMult : dmg);
      if (freeze) e.frozen = Math.max(e.frozen, freeze);
    }
  }

  damage(e, amount) {
    if (!e.alive) return;
    if (e.shield > 0) {
      e.shield -= amount;
      if (e.shield <= 0) {
        amount = -e.shield; e.shield = 0;
        if (e.mesh.userData.shieldMesh) e.mesh.userData.shieldMesh.visible = false;
        this.fx.burst(e.x, 1, e.z, 0xd4a52a, 10, 3, 0.4, 0.5);
      } else amount = 0;
    }
    e.hp -= amount;
    e.hitPulse = 0.15;
    if (e.kind === 'tower' && e.core) e.active = true;
    if (e.hp <= 0) this.kill(e);
  }

  kill(e) {
    e.alive = false;
    e.hp = 0;
    if (e.kind === 'tower') {
      this.scene.remove(e.mesh);
      const rubble = buildRubble();
      rubble.position.set(e.x, 0, e.z);
      this.scene.add(rubble);
      this.fx.explosion(e.x, e.z, 3, 0xffc36b);
      this.fx.dust(e.x, e.z, 30, 3);
      this.shake(0.9);
      sfx.towerDown();
      const other = 1 - e.team;
      if (e.core) {
        this.crowns[other] = 3;
        for (const t of this.entities) if (t.kind === 'tower' && t.team === e.team && t.alive) { t.alive = false; }
        setTimeout(() => sfx.crown(), 300);
        this.finish(other);
      } else {
        this.crowns[other] += 1;
        sfx.crown();
        for (const t of this.entities) if (t.kind === 'tower' && t.core && t.team === e.team) t.active = true;
        this.showBanner(other === 0 ? 'Tour détruite ! 👑' : 'Tour perdue !');
      }
      this.updateHud(true);
      return;
    }
    this.scene.remove(e.mesh);
    this.scene.remove(e.ring);
    this.fx.burst(e.x, e.y + 0.6, e.z, e.team === 0 ? 0x8fd0ff : 0xff9a8a, 12, 2.5, 0.45, 0.6);
    this.fx.burst(e.x, e.y + 0.5, e.z, 0xffffff, 6, 1.5, 0.6, 0.4, { grav: -2, normal: true });
    const c = CARDS[e.cardId];
    if (c.onDeath) {
      for (let i = 0; i < c.onDeath.count; i++) this.spawnUnit(c.onDeath.spawn, e.team, e.x + (i ? 0.6 : -0.6), e.z, 0.3);
      this.fx.dust(e.x, e.z, 20, 2);
      this.shake(0.3);
    }
  }

  // ---------- Ciblage et déplacement ----------
  canTarget(a, b) {
    if (!b.alive || b.team === a.team || b.deploy > 0.5) return false;
    if (a.targets === 'buildings') return b.isBuilding;
    if (a.targets === 'ground' && b.flying) return false;
    return true;
  }

  findTarget(e) {
    let best = null, bd = Infinity;
    const sight = e.kind === 'unit' ? SIGHT + (e.range > 2 ? e.range * 0.3 : 0) : e.range;
    for (const o of this.entities) {
      if (!this.canTarget(e, o)) continue;
      const d = dist(e, o) - o.radius;
      if (e.targets !== 'buildings' && !o.isBuilding && d > sight) continue;
      if (e.kind !== 'unit' && d > e.range + e.radius) continue;
      // préférence aux unités proches face aux bâtiments
      const score = o.isBuilding && e.targets !== 'buildings' ? d + 50 : d;
      if (score < bd) { bd = score; best = o; }
    }
    // bâtiments : on vise d'abord la tour de la voie
    if (best && best.isBuilding && e.kind === 'unit') {
      let bb = null, bdd = Infinity;
      for (const o of this.entities) {
        if (!o.isBuilding || !this.canTarget(e, o)) continue;
        const d = dist(e, o);
        if (d < bdd) { bdd = d; bb = o; }
      }
      best = bb;
    }
    return best;
  }

  moveTarget(e, tx, tz) {
    if (e.flying) return [tx, tz];
    const side = e.z > 0 ? 1 : -1;
    const tside = tz > 0 ? 1 : -1;
    if (Math.abs(e.z) > RIVER - 0.2 && side !== tside) {
      const bx = Math.abs(e.x + BRIDGE_X) < Math.abs(e.x - BRIDGE_X) ? -BRIDGE_X : BRIDGE_X;
      if (Math.abs(e.x - bx) > 0.7) return [bx, side * (RIVER + 0.6)];
      return [bx, -side * (RIVER + 1)];
    }
    if (Math.abs(e.z) <= RIVER + 0.2 && side !== tside) {
      const bx = e.x < 0 ? -BRIDGE_X : BRIDGE_X;
      return [bx, -side * (RIVER + 1)];
    }
    return [tx, tz];
  }

  updateEntity(e, dt) {
    if (e.deploy > 0) { e.deploy -= dt; return; }
    if (e.frozen > 0) { e.frozen -= dt; return; }
    if (e.lifetime) {
      e.hp -= (e.maxHp / e.lifetime) * dt;
      if (e.hp <= 0) { this.kill(e); return; }
    }
    if (e.kind === 'tower' && !e.active) return;
    e.cooldown -= dt;
    e.retarget -= dt;
    if (!e.target || !e.target.alive || e.retarget <= 0 ||
        (e.kind !== 'unit' && dist(e, e.target) - e.target.radius > e.range + e.radius)) {
      const locked = e.target && e.target.alive && e.windup > 0;
      if (!locked) e.target = this.findTarget(e);
      e.retarget = 0.4;
    }
    const t = e.target;
    if (e.windup > 0) {
      e.windup -= dt;
      if (e.windup <= 0 && t && t.alive) this.strike(e, t);
      return;
    }
    if (!t) { e.moving = false; return; }
    const d = dist(e, t) - t.radius - e.radius;
    if (d <= e.range) {
      e.moving = false;
      e.facing = Math.atan2(t.x - e.x, t.z - e.z);
      if (e.cooldown <= 0) {
        e.cooldown = e.hitSpeed;
        e.windup = e.attack === 'kamikaze' ? 0.05 : 0.28;
        e.attackAnim = 1;
      }
    } else if (e.kind === 'unit') {
      const [mx, mz] = this.moveTarget(e, t.x, t.z);
      const dx = mx - e.x, dz = mz - e.z;
      const l = Math.hypot(dx, dz) || 1;
      e.x += (dx / l) * e.speed * dt;
      e.z += (dz / l) * e.speed * dt;
      e.facing = Math.atan2(dx, dz);
      e.moving = true;
    }
  }

  strike(e, t) {
    const pos = (o, h) => new THREE.Vector3(o.x, (o.y || 0) + h, o.z);
    let dmg = e.dmg;
    if (e.firstStrike) { dmg *= e.firstStrike; e.firstStrike = 0; this.fx.burst(t.x, 1, t.z, 0x63f5ff, 14, 4, 0.5, 0.4); }
    switch (e.attack) {
      case 'melee':
        this.damage(t, dmg);
        this.fx.burst(t.x, (t.y || 0) + 0.8, t.z, 0xfff3c4, 6, 2.5, 0.35, 0.3);
        e.cardId === 'golem' || e.cardId === 'shard' ? sfx.hit() : sfx.sword();
        if (e.cardId === 'golem') { this.fx.dust(t.x, t.z, 8, 1.2); this.shake(0.15); }
        break;
      case 'arrow':
        this.projectiles.push({ type: 'arrow', team: e.team, target: t, pos: pos(e, e.kind === 'tower' ? (e.core ? 4 : 3.4) : 1.1), speed: 16, dmg, splash: 0 });
        sfx.arrow();
        break;
      case 'fireball':
        this.projectiles.push({ type: 'fire', team: e.team, target: t, pos: pos(e, 1.8), speed: 9, dmg, splash: e.splash });
        sfx.fire();
        break;
      case 'breath':
        this.projectiles.push({ type: 'breath', team: e.team, target: t, pos: pos(e, 0.4).add(new THREE.Vector3(Math.sin(e.facing) * 1.2, 0, Math.cos(e.facing) * 1.2)), speed: 11, dmg, splash: e.splash });
        sfx.fire();
        break;
      case 'beam': {
        this.damage(t, dmg);
        this.fx.beam(pos(e, 2.4), pos(t, 0.8), e.team === 0 ? 0x6fd0ff : 0xff7a5c);
        this.fx.burst(t.x, (t.y || 0) + 0.8, t.z, e.team === 0 ? 0x6fd0ff : 0xff7a5c, 6, 2, 0.4, 0.3);
        sfx.beam();
        break;
      }
      case 'chain': {
        const hit = [t];
        let cur = t;
        for (let i = 1; i < 3; i++) {
          let nb = null, nd = 3.5;
          for (const o of this.entities) {
            if (!o.alive || o.team === e.team || hit.includes(o) || o.deploy > 0.5) continue;
            const d = dist(cur, o);
            if (d < nd) { nd = d; nb = o; }
          }
          if (!nb) break;
          hit.push(nb); cur = nb;
        }
        const pts = [pos(e, 2.6), ...hit.map((h) => pos(h, h.kind === 'tower' ? 2.5 : 0.9))];
        this.fx.bolt(pts);
        for (const h of hit) this.damage(h, dmg);
        sfx.zap();
        break;
      }
      case 'kamikaze':
        this.fx.explosion(e.x, e.z, e.splash, 0xffa21f);
        this.shake(0.4);
        sfx.boom();
        this.areaDamage(e.team, e.x, e.z, e.splash, e.dmg, 1, false);
        this.kill(e);
        break;
    }
  }

  updateProjectiles(dt) {
    for (let i = this.projectiles.length - 1; i >= 0; i--) {
      const p = this.projectiles[i];
      const t = p.target;
      if (t.alive) p.dest = new THREE.Vector3(t.x, (t.y || 0) + (t.kind === 'tower' ? 2 : 0.8), t.z);
      if (!p.mesh) {
        if (p.type === 'arrow') {
          p.mesh = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.7, 4), new THREE.MeshBasicMaterial({ color: 0x5a3a1a }));
          const tip = new THREE.Mesh(new THREE.ConeGeometry(0.06, 0.15, 4), new THREE.MeshBasicMaterial({ color: 0xdddddd }));
          tip.position.y = 0.4;
          p.mesh.add(tip);
        } else {
          const col = p.type === 'fire' ? 0xff7a1a : 0xffb02e;
          p.mesh = new THREE.Mesh(new THREE.SphereGeometry(p.type === 'fire' ? 0.28 : 0.2, 10, 8), new THREE.MeshBasicMaterial({ color: col }));
        }
        this.scene.add(p.mesh);
      }
      const d = p.dest.clone().sub(p.pos);
      const l = d.length();
      const step = p.speed * dt;
      if (l <= step) {
        this.scene.remove(p.mesh);
        p.mesh.geometry.dispose();
        this.projectiles.splice(i, 1);
        if (p.splash) {
          this.areaDamage(p.team, p.dest.x, p.dest.z, p.splash, p.dmg, 1, true);
          this.fx.burst(p.dest.x, p.dest.y, p.dest.z, 0xff8a1f, 16, 3, 0.6, 0.5);
          this.fx.ring(p.dest.x, p.dest.z, p.splash, 0xff8a1f, 0.35);
          if (p.type === 'fire') sfx.boom();
        } else if (t.alive) {
          this.damage(t, p.dmg);
          this.fx.burst(p.dest.x, p.dest.y, p.dest.z, 0xffffff, 3, 1.5, 0.25, 0.25);
        }
        continue;
      }
      d.multiplyScalar(1 / l);
      p.pos.addScaledVector(d, step);
      p.mesh.position.copy(p.pos);
      if (p.type === 'arrow') {
        p.mesh.position.y += Math.sin(Math.min(1, l / 6) * Math.PI) * 0.3;
        p.mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), d);
      } else if (Math.random() < 0.8) {
        this.fx.spawn(p.pos.x, p.pos.y, p.pos.z, { color: p.type === 'fire' ? 0xff6a00 : 0xffc040, size: 0.5, life: 0.3, grow: 0.3 });
      }
    }
  }

  separate() {
    const list = this.entities.filter((e) => e.alive);
    for (let i = 0; i < list.length; i++) {
      const a = list[i];
      for (let j = i + 1; j < list.length; j++) {
        const b = list[j];
        if (a.flying !== b.flying) continue;
        const dx = b.x - a.x, dz = b.z - a.z;
        const d = Math.hypot(dx, dz);
        const min = (a.radius + b.radius) * 0.9;
        if (d >= min || d === 0) { if (d === 0) { a.x += 0.01; } continue; }
        const push = (min - d) / d;
        const aFixed = a.kind !== 'unit';
        const bFixed = b.kind !== 'unit';
        if (aFixed && bFixed) continue;
        const wa = aFixed ? 0 : bFixed ? 1 : (CARDS[b.cardId]?.heavy ? 0.85 : CARDS[a.cardId]?.heavy ? 0.15 : 0.5);
        const wb = 1 - wa;
        a.x -= dx * push * wa; a.z -= dz * push * wa;
        b.x += dx * push * wb; b.z += dz * push * wb;
      }
    }
    for (const e of list) {
      if (e.kind !== 'unit') continue;
      e.x = Math.max(-8.6, Math.min(8.6, e.x));
      e.z = Math.max(-15.6, Math.min(15.6, e.z));
      if (!e.flying && Math.abs(e.z) < RIVER) {
        const onBridge = Math.abs(Math.abs(e.x) - BRIDGE_X) < 1.1;
        if (!onBridge) e.z = Math.sign(e.z || 1) * RIVER;
      }
    }
  }

  // ---------- IA ----------
  validZone(team, x, z, cardId) {
    const c = CARDS[cardId];
    if (Math.abs(x) > 8.7 || Math.abs(z) > 15.8) return false;
    if (c.type === 'spell') return true;
    const s = team === 0 ? 1 : -1;
    const zz = z * s;
    if (zz >= RIVER + 0.3) return true;
    const lane = x < 0 ? 0 : 1;
    const enemyTowerDown = this.entities.some((t) => t.kind === 'tower' && !t.core && t.team !== team && t.lane === lane && !t.alive);
    return enemyTowerDown && zz >= -6;
  }

  aiUpdate(dt) {
    const ai = this.ai;
    ai.think -= dt;
    if (ai.think > 0) return;
    ai.think = 0.6 + Math.random() * 0.8;
    const P = this.players[1];
    const ess = this.essence[1];
    const threats = this.entities.filter((e) => e.alive && e.team === 0 && e.kind === 'unit' && e.z < 3);
    const affordable = P.hand.map((id, i) => ({ id, i, c: CARDS[id] })).filter((o) => o.c.cost <= ess);
    if (!affordable.length) return;
    const pick = (fn) => affordable.filter(fn).sort((a, b) => b.c.cost - a.c.cost)[0];

    if (threats.length) {
      // sort sur groupe
      const center = threats.reduce((a, t) => ({ x: a.x + t.x / threats.length, z: a.z + t.z / threats.length }), { x: 0, z: 0 });
      const near = threats.filter((t) => Math.hypot(t.x - center.x, t.z - center.z) < 2.5);
      const value = near.reduce((s, t) => s + (CARDS[t.cardId]?.cost || 0) / (CARDS[t.cardId]?.count || 1), 0);
      const spell = pick((o) => o.c.type === 'spell');
      if (spell && value >= spell.c.cost - 0.5 && near.length >= 2) return this.aiPlay(spell, center.x, center.z + 0.5);
      const lead = threats.sort((a, b) => a.z - b.z)[0];
      const def = pick((o) => o.c.type !== 'spell' && o.c.targets !== 'buildings');
      if (def) {
        const z = Math.max(-14, Math.min(-RIVER - 0.8, lead.z - 3));
        return this.aiPlay(def, Math.max(-8, Math.min(8, lead.x * 0.7)), z);
      }
    }
    // attaque quand l'essence est haute
    if (ess >= 8.5 || (ess >= 6 && Math.random() < 0.25)) {
      const card = pick((o) => o.c.type !== 'spell');
      if (!card) return;
      const lane = this.aiLane();
      const lx = lane === 0 ? -BRIDGE_X : BRIDGE_X;
      if (card.c.targets === 'buildings' && card.c.cost >= 5) return this.aiPlay(card, lx * 0.6, -13.5);
      if (card.c.type === 'building') return this.aiPlay(card, lx * 0.4, -6);
      return this.aiPlay(card, lx, card.c.speed > 2 ? -RIVER - 0.8 : -10);
    }
  }

  aiLane() {
    const weak = this.entities.filter((t) => t.kind === 'tower' && !t.core && t.team === 0);
    const alive = weak.filter((t) => t.alive);
    if (alive.length === 1) return alive[0].lane;
    if (alive.length === 2) return alive[0].hp < alive[1].hp ? alive[0].lane : alive[1].lane;
    return Math.random() < 0.5 ? 0 : 1;
  }

  aiPlay(o, x, z) {
    if (!this.validZone(1, x, z, o.id)) z = -RIVER - 1;
    this.deploy(1, o.id, x, z);
    this.cycle(1, o.i);
  }

  // ---------- Boucle ----------
  update(dt) {
    if (this.over) { this.fx.update(dt); return; }
    this.elapsed += dt;
    this.time -= dt;
    const rate = ESSENCE_RATE * (this.overtime || this.time <= 60 ? 2 : 1);
    for (const t of [0, 1]) this.essence[t] = Math.min(10, this.essence[t] + rate * dt);
    if (this.time <= 60 && !this.doubleShown && !this.overtime) { this.doubleShown = true; this.showBanner('Essence x2 !'); }
    if (this.time <= 0) {
      if (!this.overtime && this.crowns[0] === this.crowns[1]) {
        this.overtime = true; this.time = OVERTIME; this.showBanner('Prolongation !');
      } else {
        const w = this.crowns[0] > this.crowns[1] ? 0 : this.crowns[1] > this.crowns[0] ? 1 : this.tieBreak();
        this.finish(w);
        return;
      }
    }
    this.aiUpdate(dt);
    for (const e of [...this.entities]) if (e.alive) this.updateEntity(e, dt);
    this.updateProjectiles(dt);
    this.separate();
    for (let i = this.pending.length - 1; i >= 0; i--) {
      const p = this.pending[i];
      p.t -= dt;
      const k = 1 - Math.max(0, p.t) / p.total;
      if (p.from) {
        p.mesh.position.lerpVectors(p.from, p.to, k * k);
        p.mesh.rotation.x += dt * 4;
        this.fx.spawn(p.mesh.position.x, p.mesh.position.y, p.mesh.position.z, { color: 0xff6a00, size: 1.4, life: 0.4, grow: 0.3 });
      }
      if (p.shrink) p.mesh.scale.setScalar(1.6 * (1 - k * k));
      if (p.t <= 0) {
        this.scene.remove(p.mesh);
        if (p.warn) this.scene.remove(p.warn);
        p.done();
        this.pending.splice(i, 1);
      }
    }
    this.entities = this.entities.filter((e) => e.alive || e.kind === 'tower');
    this.fx.update(dt);
  }

  tieBreak() {
    const minHp = (team) => Math.min(...this.entities.filter((t) => t.kind === 'tower' && t.team === team && t.alive).map((t) => t.hp / t.maxHp));
    const a = minHp(0), b = minHp(1);
    return Math.abs(a - b) < 0.001 ? -1 : a > b ? 0 : 1;
  }

  finish(winner) {
    if (this.over) return;
    this.over = true;
    this.updateHud(true);
    setTimeout(() => this.onEnd({ winner, crowns: [...this.crowns] }), 1600);
  }

  syncVisuals(dt, now) {
    for (const e of this.entities) {
      if (!e.alive) continue;
      const mesh = e.mesh;
      if (e.kind === 'tower') {
        if (mesh.userData.crystal) { mesh.userData.crystal.rotation.y += dt * 1.5; mesh.userData.crystal.position.y += Math.sin(now * 2) * 0.002; }
        if (mesh.userData.flag) mesh.userData.flag.rotation.y = Math.sin(now * 3 + e.x) * 0.25;
        const g = mesh.userData.guard;
        if (g && e.target && e.target.alive) {
          const a = Math.atan2(e.target.x - e.x, e.target.z - e.z) - mesh.rotation.y;
          g.rotation.y = a;
        }
        const pulse = e.hitPulse > 0 ? 1 + e.hitPulse * 0.15 : 1;
        mesh.scale.set(1, pulse > 1 ? 1 - e.hitPulse * 0.1 : 1, 1);
        e.hitPulse = Math.max(0, e.hitPulse - dt);
        continue;
      }
      const drop = e.deploy > 0 ? Math.max(0, e.deploy) * 3 : 0;
      mesh.position.set(e.x, e.y + drop, e.z);
      e.ring.position.set(e.x, 0.04, e.z);
      // rotation douce
      let da = e.facing - mesh.rotation.y;
      da = Math.atan2(Math.sin(da), Math.cos(da));
      mesh.rotation.y += da * Math.min(1, dt * 10);
      e.attackAnim = Math.max(0, e.attackAnim - dt * 3);
      const atk = Math.sin(Math.min(1, (1 - e.attackAnim)) * Math.PI) * (e.attackAnim > 0 ? 1 : 0);
      animate(mesh, now, e.moving && e.frozen <= 0 && e.deploy <= 0, atk, e.seed);
      if (mesh.userData.crystal) mesh.userData.crystal.rotation.y += dt * 2;
      if (mesh.userData.orb) mesh.userData.orb.scale.setScalar(1 + Math.sin(now * 8) * 0.12);
      if (mesh.userData.spark) mesh.userData.spark.scale.setScalar(0.7 + Math.random() * 0.8);
      const s = e.hitPulse > 0 ? 1 + e.hitPulse * 0.6 : 1;
      mesh.scale.setScalar(s * mesh.userData.baseScale);
      e.hitPulse = Math.max(0, e.hitPulse - dt);
      if (e.frozen > 0 && Math.random() < 0.2) this.fx.spawn(e.x + (Math.random() - 0.5), e.y + 0.6 + Math.random(), e.z, { color: 0xbff4ff, size: 0.3, life: 0.5 });
      if (e.deploy > 0 && e.deploy - dt <= 0) this.fx.dust(e.x, e.z, 6, 0.8);
    }
    this.arena.userData.water.offset.x = now * 0.08;
  }

  shake(a) { this.shakeAmt = Math.max(this.shakeAmt || 0, a); }

  render(dt, now) {
    this.syncVisuals(dt, now);
    const cam = this.camera;
    cam.position.copy(this.camBase);
    if (this.shakeAmt > 0) {
      cam.position.x += (Math.random() - 0.5) * this.shakeAmt;
      cam.position.y += (Math.random() - 0.5) * this.shakeAmt;
      this.shakeAmt = Math.max(0, this.shakeAmt - dt * 2.5);
    }
    cam.lookAt(this.camLook);
    this.renderer.render(this.scene, cam);
    this.drawOverlay();
    this.updateHud();
  }

  // ---------- Caméra et HUD ----------
  resize() {
    const w = this.root.clientWidth, h = this.root.clientHeight;
    const handH = this.hand ? this.hand.offsetHeight : 160;
    const topH = this.top ? this.top.offsetHeight : 60;
    const vh = h - handH + 30;
    this.renderer.setSize(w, h);
    this.overlay.width = w * this.dpr; this.overlay.height = h * this.dpr;
    this.overlay.style.width = w + 'px'; this.overlay.style.height = h + 'px';
    const cam = this.camera;
    cam.aspect = w / h;
    cam.fov = 38;
    // L'arène occupe la zone entre la barre du haut et la main de cartes
    cam.setViewOffset(w, h, 0, 0, w, h);
    cam.updateProjectionMatrix();
    const pitch = THREE.MathUtils.degToRad(62);
    const corners = [[-9.6, -16.6], [9.6, -16.6], [-9.6, 16.6], [9.6, 16.6]];
    const look = new THREE.Vector3(0, 0, 0.6);
    let d = 20;
    const v = new THREE.Vector3();
    const top = 1 - (topH / h) * 2;
    const bottom = -1 + ((h - vh) / h) * 2;
    for (let it = 0; it < 120; it++) {
      cam.position.set(0, Math.sin(pitch) * d, Math.cos(pitch) * d).add(look);
      cam.lookAt(look);
      cam.updateMatrixWorld();
      let ok = true;
      for (const [x, z] of corners) {
        v.set(x, 0, z).project(cam);
        if (Math.abs(v.x) > 1 || v.y > top || v.y < bottom - 0.02) { ok = false; break; }
      }
      if (ok) break;
      d += 0.5;
    }
    // recentrer verticalement l'arène dans la zone visible
    cam.updateMatrixWorld();
    const pTop = v.set(0, 0, -16.6).project(cam).y;
    const pBot = v.set(0, 0, 16.6).project(cam).y;
    const shiftNdc = ((top + bottom) - (pTop + pBot)) / 2;
    cam.setViewOffset(w, h, 0, -shiftNdc * h / 2, w, h);
    cam.updateProjectionMatrix();
    this.camBase = cam.position.clone();
    this.camLook = look;
  }

  project(x, y, z) {
    const v = new THREE.Vector3(x, y, z).project(this.camera);
    return [(v.x + 1) / 2 * this.root.clientWidth, (1 - v.y) / 2 * this.root.clientHeight];
  }

  buildHud() {
    this.dpr = Math.min(window.devicePixelRatio, 2);
    const r = this.root;
    this.overlay = document.createElement('canvas');
    this.overlay.className = 'overlay';
    r.appendChild(this.overlay);
    this.octx = this.overlay.getContext('2d');

    const top = document.createElement('div');
    top.className = 'battle-top';
    top.innerHTML = `
      <div class="opp"><div class="opp-name">${this.enemyName}</div><div class="opp-clan">Île : ${this.island.name}</div></div>
      <div class="crowns"><span class="cr blue">0</span><span class="cr-icon">👑</span><span class="cr red">0</span></div>
      <div class="timer"><small>Fin dans</small><b>3:00</b></div>`;
    r.appendChild(top);
    this.top = top;
    this.timerEl = top.querySelector('.timer b');
    this.timerLbl = top.querySelector('.timer small');
    this.crBlue = top.querySelector('.cr.blue');
    this.crRed = top.querySelector('.cr.red');

    const hand = document.createElement('div');
    hand.className = 'hand';
    hand.innerHTML = `
      <div class="hand-row">
        <div class="next"><small>Suivante</small><div class="next-card"></div></div>
        <div class="slots">${[0, 1, 2, 3].map((i) => `<div class="slot" data-i="${i}"><div class="card-face"></div><div class="cost"></div></div>`).join('')}</div>
      </div>
      <div class="essence"><div class="ess-drop"><span>5</span></div><div class="ess-bar"><div class="ess-fill"></div>${'<i></i>'.repeat(9)}</div></div>`;
    r.appendChild(hand);
    this.hand = hand;
    this.slots = [...hand.querySelectorAll('.slot')];
    this.essFill = hand.querySelector('.ess-fill');
    this.essNum = hand.querySelector('.ess-drop span');
    this.nextCard = hand.querySelector('.next-card');

    this.banner = document.createElement('div');
    this.banner.className = 'banner';
    r.appendChild(this.banner);

    this.ghost = document.createElement('div');
    this.ghost.className = 'drag-ghost';
    r.appendChild(this.ghost);

    this.bindInput();
    this.updateHud(true);
  }

  buildPlacementHelpers() {
    const forbid = new THREE.Mesh(new THREE.PlaneGeometry(18, 1), new THREE.MeshBasicMaterial({ color: 0xff2a2a, transparent: true, opacity: 0.28, depthWrite: false }));
    forbid.rotation.x = -Math.PI / 2;
    forbid.position.y = 0.07;
    forbid.visible = false;
    this.scene.add(forbid);
    this.forbid = forbid;
    const forbid2 = forbid.clone();
    forbid2.material = forbid.material;
    this.scene.add(forbid2);
    this.forbid2 = forbid2;
    const cursor = new THREE.Group();
    const disc = new THREE.Mesh(new THREE.CircleGeometry(1, 40), new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.3, depthWrite: false }));
    disc.rotation.x = -Math.PI / 2;
    disc.position.y = 0.08;
    cursor.add(disc);
    cursor.visible = false;
    this.scene.add(cursor);
    this.cursor = cursor;
    this.cursorDisc = disc;
  }

  showPlacement(cardId) {
    const c = CARDS[cardId];
    const on = c && c.type !== 'spell';
    this.forbid.visible = on;
    this.forbid2.visible = false;
    if (!on) return;
    // zone interdite : moitié adverse (sauf voies ouvertes)
    const openL = this.validZone(0, -5, -3, cardId);
    const openR = this.validZone(0, 5, -3, cardId);
    const setZone = (mesh, x0, x1, z0, z1) => {
      mesh.visible = true;
      mesh.scale.set((x1 - x0) / 18, z1 - z0, 1);
      mesh.position.set((x0 + x1) / 2, 0.07, (z0 + z1) / 2);
    };
    if (!openL && !openR) setZone(this.forbid, -9, 9, -16, RIVER + 0.3);
    else if (openL && openR) { setZone(this.forbid, -9, 9, -16, -6); }
    else if (openL) { setZone(this.forbid, 0, 9, -16, RIVER + 0.3); setZone(this.forbid2, -9, 0, -16, -6); }
    else { setZone(this.forbid, -9, 0, -16, RIVER + 0.3); setZone(this.forbid2, 0, 9, -16, -6); }
  }

  hidePlacement() {
    this.forbid.visible = this.forbid2.visible = this.cursor.visible = false;
    if (this.cursorModel) { this.cursor.remove(this.cursorModel); this.cursorModel = null; }
  }

  groundAt(clientX, clientY) {
    const rect = this.root.getBoundingClientRect();
    const ndc = new THREE.Vector2(((clientX - rect.left) / rect.width) * 2 - 1, -((clientY - rect.top) / rect.height) * 2 + 1);
    this.raycaster.setFromCamera(ndc, this.camera);
    const p = new THREE.Vector3();
    return this.raycaster.ray.intersectPlane(this.groundPlane, p) ? p : null;
  }

  bindInput() {
    let drag = null;
    const P = this.players[0];
    const handRect = () => this.hand.getBoundingClientRect();
    const updateCursor = (cx, cy) => {
      const overHand = cy > handRect().top;
      const id = P.hand[drag.slot];
      const c = CARDS[id];
      this.ghost.style.left = cx + 'px';
      this.ghost.style.top = cy + 'px';
      this.ghost.style.opacity = overHand ? 1 : 0;
      const p = overHand ? null : this.groundAt(cx, cy);
      if (!p) { this.cursor.visible = false; drag.pos = null; return; }
      p.x = Math.max(-8.6, Math.min(8.6, p.x));
      p.z = Math.max(-15.6, Math.min(15.6, p.z));
      // aimanter dans la zone autorisée
      if (!this.validZone(0, p.x, p.z, id) && c.type !== 'spell') p.z = Math.max(p.z, RIVER + 0.4);
      drag.pos = p;
      this.cursor.visible = true;
      this.cursor.position.set(p.x, 0, p.z);
      const r = c.type === 'spell' ? c.radius : c.type === 'building' ? c.range : (c.count > 1 ? 1.2 : Math.max(0.7, c.radius * 1.4));
      this.cursorDisc.scale.setScalar(r);
      this.cursorDisc.material.color.set(c.type === 'spell' ? 0xffd34d : 0xffffff);
      if (!this.cursorModel && c.type !== 'spell') {
        this.cursorModel = buildModel(id, 0);
        this.cursorModel.traverse((o) => { if (o.isMesh) { o.material = o.material.clone(); o.material.transparent = true; o.material.opacity = 0.55; o.castShadow = false; } });
        if (c.flying) this.cursorModel.position.y = 2.6;
        this.cursorModel.rotation.y = Math.PI;
        this.cursor.add(this.cursorModel);
      }
    };
    this.slots.forEach((el, i) => {
      el.addEventListener('pointerdown', (ev) => {
        if (this.over) return;
        ev.preventDefault();
        drag = { slot: i, x0: ev.clientX, y0: ev.clientY, moved: false, pos: null };
        this.selectSlot(i);
        this.ghost.style.backgroundImage = `url(${this.cardImages[P.hand[i]]})`;
      });
    });
    this.onMove = (ev) => {
      if (!drag) return;
      if (Math.hypot(ev.clientX - drag.x0, ev.clientY - drag.y0) > 8) drag.moved = true;
      if (drag.moved) { this.ghost.classList.add('on'); updateCursor(ev.clientX, ev.clientY); }
    };
    this.onUp = (ev) => {
      if (!drag) return;
      const d = drag; drag = null;
      this.ghost.classList.remove('on');
      if (d.moved && d.pos) this.tryDeploy(d.slot, d.pos.x, d.pos.z);
      else if (d.moved) { this.hidePlacement(); this.selectSlot(-1); }
      void ev;
    };
    window.addEventListener('pointermove', this.onMove);
    window.addEventListener('pointerup', this.onUp);
    // tap-to-place : carte sélectionnée puis tap dans l'arène
    this.onTap = (ev) => {
      if (this.selected < 0 || this.over || drag) return;
      if (ev.target.closest('.hand') || ev.target.closest('.battle-top')) return;
      const p = this.groundAt(ev.clientX, ev.clientY);
      if (!p) return;
      this.tryDeploy(this.selected, Math.max(-8.6, Math.min(8.6, p.x)), Math.max(-15.6, Math.min(15.6, p.z)));
    };
    this.root.addEventListener('pointerdown', this.onTap);
  }

  selectSlot(i) {
    this.selected = this.selected === i && i >= 0 && !this.ghost.classList.contains('on') ? i : i;
    this.slots.forEach((s, k) => s.classList.toggle('sel', k === i));
    this.hidePlacement();
    if (i >= 0) this.showPlacement(this.players[0].hand[i]);
  }

  tryDeploy(slot, x, z) {
    const id = this.players[0].hand[slot];
    const c = CARDS[id];
    if (!this.validZone(0, x, z, id)) {
      if (c.type !== 'spell') z = Math.max(z, RIVER + 0.4);
      if (!this.validZone(0, x, z, id)) { sfx.noEssence(); return; }
    }
    if (this.essence[0] < c.cost) {
      sfx.noEssence();
      this.showFloat(x, z, 'Pas assez d’essence !', '#d68cff');
      return;
    }
    this.deploy(0, id, x, z);
    this.cycle(0, slot);
    this.selectSlot(-1);
    this.updateHud(true);
  }

  showBanner(text) {
    this.banner.textContent = text;
    this.banner.classList.remove('show');
    void this.banner.offsetWidth;
    this.banner.classList.add('show');
  }

  showFloat(x, z, text, color) {
    this.texts.push({ x, z, text, color, t: 1.4 });
  }

  updateHud(force) {
    const P = this.players[0];
    const ess = this.essence[0];
    this.essFill.style.width = (ess * 10) + '%';
    const n = Math.floor(ess);
    if (n !== this.lastEss) { this.essNum.textContent = n; if (n > (this.lastEss ?? 99)) sfx.essence(); this.lastEss = n; }
    const t = Math.max(0, Math.ceil(this.time));
    const ts = `${Math.floor(t / 60)}:${String(t % 60).padStart(2, '0')}`;
    if (ts !== this.lastTs) {
      this.timerEl.textContent = ts; this.lastTs = ts;
      this.timerLbl.textContent = this.overtime ? 'Prolongation' : this.time <= 60 ? 'Essence x2' : 'Fin dans';
      this.top.classList.toggle('x2', this.overtime || this.time <= 60);
    }
    this.crBlue.textContent = this.crowns[0];
    this.crRed.textContent = this.crowns[1];
    const key = P.hand.join() + P.queue[0];
    if (force || key !== this.handKey) {
      this.handKey = key;
      this.slots.forEach((s, i) => {
        const id = P.hand[i];
        s.querySelector('.card-face').style.backgroundImage = `url(${this.cardImages[id]})`;
        s.querySelector('.cost').textContent = CARDS[id].cost;
        s.dataset.rarity = CARDS[id].rarity;
        s.classList.add('pop');
        setTimeout(() => s.classList.remove('pop'), 250);
      });
      this.nextCard.style.backgroundImage = `url(${this.cardImages[P.queue[0]]})`;
    }
    this.slots.forEach((s, i) => s.classList.toggle('poor', CARDS[P.hand[i]].cost > ess));
  }

  drawOverlay() {
    const x = this.octx;
    const dpr = this.dpr;
    x.setTransform(dpr, 0, 0, dpr, 0, 0);
    x.clearRect(0, 0, this.overlay.width, this.overlay.height);
    x.font = '700 12px "Lilita One", sans-serif';
    x.textAlign = 'center';
    for (const e of this.entities) {
      if (!e.alive) continue;
      if (e.kind === 'tower') {
        const [sx, sy] = this.project(e.x, e.core ? 5.6 : 4.4, e.z);
        const w = e.core ? 64 : 52;
        this.bar(sx - w / 2, sy, w, 9, e.hp / e.maxHp, e.team, true);
        x.fillStyle = '#fff';
        x.strokeStyle = 'rgba(0,0,0,0.8)';
        x.lineWidth = 3;
        x.font = '12px "Lilita One", sans-serif';
        x.strokeText(Math.ceil(e.hp), sx, sy - 3);
        x.fillText(Math.ceil(e.hp), sx, sy - 3);
        if (e.core && !e.active) { x.font = '11px "Lilita One", sans-serif'; x.strokeText('💤', sx + w / 2 + 8, sy + 8); x.fillText('💤', sx + w / 2 + 8, sy + 8); }
        continue;
      }
      if (e.hp >= e.maxHp && !e.maxShield && !e.lifetime) continue;
      const h = e.flying ? e.y + 1.2 : (CARDS[e.cardId].heavy ? 3.2 : e.cardId === 'swarm' ? 0.8 : e.cardId === 'totem' ? 3.1 : 1.9);
      const [sx, sy] = this.project(e.x, h, e.z);
      const w = e.cardId === 'swarm' ? 18 : CARDS[e.cardId].heavy ? 42 : 30;
      this.bar(sx - w / 2, sy, w, 5, e.hp / e.maxHp, e.team);
      if (e.maxShield && e.shield > 0) this.bar(sx - w / 2, sy - 6, w, 4, e.shield / e.maxShield, 2);
    }
    for (let i = this.texts.length - 1; i >= 0; i--) {
      const t = this.texts[i];
      t.t -= 1 / 60;
      if (t.t <= 0) { this.texts.splice(i, 1); continue; }
      const [sx, sy] = this.project(t.x, 2.2 + (1.4 - t.t) * 0.8, t.z);
      x.globalAlpha = Math.min(1, t.t * 2);
      x.font = '15px "Lilita One", sans-serif';
      x.lineWidth = 4;
      x.strokeStyle = 'rgba(0,0,0,0.85)';
      x.strokeText(t.text, sx, sy);
      x.fillStyle = t.color;
      x.fillText(t.text, sx, sy);
      x.globalAlpha = 1;
    }
  }

  bar(x0, y0, w, h, k, team, big) {
    const x = this.octx;
    x.fillStyle = 'rgba(0,0,0,0.65)';
    x.beginPath(); x.roundRect(x0 - 1.5, y0 - 1.5, w + 3, h + 3, 3); x.fill();
    x.fillStyle = team === 0 ? '#3aa0ff' : team === 1 ? '#ff4458' : '#f4c542';
    x.beginPath(); x.roundRect(x0, y0, Math.max(0, w * k), h, 2); x.fill();
    if (big) { x.fillStyle = 'rgba(255,255,255,0.25)'; x.fillRect(x0, y0, Math.max(0, w * k), h / 2.5); }
  }

  dispose() {
    window.removeEventListener('resize', this.onResize);
    window.removeEventListener('pointermove', this.onMove);
    window.removeEventListener('pointerup', this.onUp);
    this.root.removeEventListener('pointerdown', this.onTap);
    for (const el of [this.overlay, this.top, this.hand, this.banner, this.ghost]) el.remove();
    this.scene.traverse((o) => { if (o.geometry) o.geometry.dispose(); });
    this.renderer.setViewport(0, 0, this.root.clientWidth, this.root.clientHeight);
  }
}
