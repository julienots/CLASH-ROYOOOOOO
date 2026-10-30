// Particules et effets visuels (pool de sprites additifs).
import * as THREE from 'three';

function radialTexture() {
  const c = document.createElement('canvas');
  c.width = c.height = 64;
  const x = c.getContext('2d');
  const g = x.createRadialGradient(32, 32, 0, 32, 32, 32);
  g.addColorStop(0, 'rgba(255,255,255,1)');
  g.addColorStop(0.35, 'rgba(255,255,255,0.7)');
  g.addColorStop(1, 'rgba(255,255,255,0)');
  x.fillStyle = g;
  x.fillRect(0, 0, 64, 64);
  return new THREE.CanvasTexture(c);
}

export class FX {
  constructor(scene) {
    this.scene = scene;
    this.tex = radialTexture();
    this.pool = [];
    this.live = [];
    this.rings = [];
    this.bolts = [];
    for (let i = 0; i < 260; i++) {
      const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: this.tex, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true }));
      s.visible = false;
      scene.add(s);
      this.pool.push(s);
    }
  }

  spawn(x, y, z, o = {}) {
    const s = this.pool.pop();
    if (!s) return;
    s.visible = true;
    s.position.set(x, y, z);
    s.material.color.set(o.color ?? 0xffffff);
    s.material.opacity = 1;
    s.material.blending = o.normal ? THREE.NormalBlending : THREE.AdditiveBlending;
    const size = o.size ?? 0.4;
    s.scale.setScalar(size);
    s.userData = { vx: o.vx ?? 0, vy: o.vy ?? 0, vz: o.vz ?? 0, life: o.life ?? 0.6, max: o.life ?? 0.6, size, grow: o.grow ?? 1, grav: o.grav ?? 0 };
    this.live.push(s);
  }

  burst(x, y, z, color, n = 12, speed = 3, size = 0.4, life = 0.6, opts = {}) {
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2;
      const v = speed * (0.4 + Math.random() * 0.6);
      this.spawn(x, y, z, { color, size: size * (0.6 + Math.random() * 0.8), life: life * (0.6 + Math.random() * 0.6),
        vx: Math.cos(a) * v, vz: Math.sin(a) * v, vy: (opts.up ?? 1) * Math.random() * speed, grav: opts.grav ?? 4, grow: opts.grow ?? 1, normal: opts.normal });
    }
  }

  dust(x, z, n = 10, r = 1) {
    this.burst(x, 0.2, z, 0xd9c7a0, n, 2 * r, 0.7 * r, 0.7, { normal: true, grav: 0, up: 0.3, grow: 2 });
  }

  explosion(x, z, r = 2, color = 0xff8a1f) {
    this.burst(x, 0.5, z, color, 26, r * 3, 0.9, 0.7, { grav: 2 });
    this.burst(x, 0.5, z, 0xfff1a0, 10, r * 1.5, 1.4, 0.35, { grav: 0 });
    this.burst(x, 0.3, z, 0x555555, 12, r * 1.4, 1.1, 1.0, { normal: true, grav: -1, grow: 2.5 });
    this.ring(x, z, r, color);
  }

  ring(x, z, r, color, dur = 0.45) {
    const mesh = new THREE.Mesh(new THREE.RingGeometry(0.8, 1, 40), new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.9, side: THREE.DoubleSide, depthWrite: false, blending: THREE.AdditiveBlending }));
    mesh.rotation.x = -Math.PI / 2;
    mesh.position.set(x, 0.12, z);
    this.scene.add(mesh);
    this.rings.push({ mesh, t: 0, dur, r });
  }

  bolt(points, color = 0x9fe8ff) {
    const pts = [];
    for (let i = 0; i < points.length - 1; i++) {
      const a = points[i], b = points[i + 1];
      for (let k = 0; k < 8; k++) {
        const t = k / 8;
        const j = k === 0 ? 0 : 0.35;
        pts.push(new THREE.Vector3(a.x + (b.x - a.x) * t + (Math.random() - 0.5) * j, a.y + (b.y - a.y) * t + (Math.random() - 0.5) * j, a.z + (b.z - a.z) * t + (Math.random() - 0.5) * j));
      }
    }
    pts.push(points[points.length - 1].clone());
    const curve = new THREE.CatmullRomCurve3(pts);
    const mesh = new THREE.Mesh(new THREE.TubeGeometry(curve, pts.length * 2, 0.06, 5), new THREE.MeshBasicMaterial({ color, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
    const core = new THREE.Mesh(new THREE.TubeGeometry(curve, pts.length * 2, 0.025, 4), new THREE.MeshBasicMaterial({ color: 0xffffff }));
    mesh.add(core);
    this.scene.add(mesh);
    this.bolts.push({ mesh, t: 0, dur: 0.22 });
    for (const p of points) this.burst(p.x, p.y, p.z, color, 5, 2, 0.4, 0.3);
  }

  beam(a, b, color) {
    const dir = new THREE.Vector3().subVectors(b, a);
    const len = dir.length();
    const mesh = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.07, len, 6, 1, true), new THREE.MeshBasicMaterial({ color, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
    mesh.position.copy(a).addScaledVector(dir, 0.5);
    mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir.normalize());
    this.scene.add(mesh);
    this.bolts.push({ mesh, t: 0, dur: 0.18 });
  }

  update(dt) {
    for (let i = this.live.length - 1; i >= 0; i--) {
      const s = this.live[i];
      const u = s.userData;
      u.life -= dt;
      if (u.life <= 0) { s.visible = false; this.live.splice(i, 1); this.pool.push(s); continue; }
      u.vy -= u.grav * dt;
      s.position.x += u.vx * dt; s.position.y += u.vy * dt; s.position.z += u.vz * dt;
      if (s.position.y < 0.05) { s.position.y = 0.05; u.vy = 0; }
      const k = u.life / u.max;
      s.material.opacity = Math.min(1, k * 1.5);
      s.scale.setScalar(u.size * (1 + (1 - k) * (u.grow - 1)));
    }
    for (let i = this.rings.length - 1; i >= 0; i--) {
      const r = this.rings[i];
      r.t += dt;
      const k = r.t / r.dur;
      r.mesh.scale.setScalar(r.r * (0.3 + k * 0.9));
      r.mesh.material.opacity = 1 - k;
      if (k >= 1) { this.scene.remove(r.mesh); r.mesh.geometry.dispose(); r.mesh.material.dispose(); this.rings.splice(i, 1); }
    }
    for (let i = this.bolts.length - 1; i >= 0; i--) {
      const b = this.bolts[i];
      b.t += dt;
      b.mesh.material.opacity = 1 - b.t / b.dur;
      if (b.t >= b.dur) {
        this.scene.remove(b.mesh);
        b.mesh.traverse((o) => { if (o.geometry) o.geometry.dispose(); if (o.material) o.material.dispose(); });
        this.bolts.splice(i, 1);
      }
    }
  }
}
