// Effets sonores synthétisés (aucun fichier audio externe).
let ctx = null;
let master = null;
export let muted = false;

export function initAudio() {
  if (ctx) { if (ctx.state === 'suspended') ctx.resume(); return; }
  try {
    ctx = new (window.AudioContext || window.webkitAudioContext)();
    master = ctx.createGain();
    master.gain.value = 0.5;
    master.connect(ctx.destination);
  } catch { ctx = null; }
}

export function setMuted(v) { muted = v; if (master) master.gain.value = v ? 0 : 0.5; }

function tone(freq, dur, type = 'sine', vol = 0.3, slide = 0, delay = 0) {
  if (!ctx || muted) return;
  const t = ctx.currentTime + delay;
  const o = ctx.createOscillator();
  const g = ctx.createGain();
  o.type = type;
  o.frequency.setValueAtTime(freq, t);
  if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(20, freq + slide), t + dur);
  g.gain.setValueAtTime(vol, t);
  g.gain.exponentialRampToValueAtTime(0.001, t + dur);
  o.connect(g).connect(master);
  o.start(t);
  o.stop(t + dur + 0.02);
}

function noise(dur, vol = 0.3, freq = 1200, delay = 0) {
  if (!ctx || muted) return;
  const t = ctx.currentTime + delay;
  const len = Math.floor(ctx.sampleRate * dur);
  const buf = ctx.createBuffer(1, len, ctx.sampleRate);
  const d = buf.getChannelData(0);
  for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / len);
  const src = ctx.createBufferSource();
  src.buffer = buf;
  const f = ctx.createBiquadFilter();
  f.type = 'lowpass';
  f.frequency.value = freq;
  const g = ctx.createGain();
  g.gain.value = vol;
  src.connect(f).connect(g).connect(master);
  src.start(t);
}

export const sfx = {
  click: () => tone(660, 0.08, 'triangle', 0.25, 200),
  deploy: () => { noise(0.25, 0.25, 500); tone(220, 0.2, 'triangle', 0.2, -80); },
  sword: () => noise(0.12, 0.2, 3000),
  hit: () => tone(160, 0.1, 'square', 0.12, -60),
  arrow: () => tone(1200, 0.12, 'sine', 0.08, -800),
  fire: () => { noise(0.3, 0.2, 900); tone(300, 0.25, 'sawtooth', 0.06, -150); },
  boom: () => { noise(0.6, 0.5, 400); tone(90, 0.5, 'sine', 0.4, -50); },
  zap: () => { tone(1800, 0.15, 'sawtooth', 0.1, -1500); noise(0.15, 0.15, 6000); },
  freeze: () => { tone(1500, 0.5, 'sine', 0.15, 900); tone(2200, 0.4, 'triangle', 0.08, 600, 0.05); },
  beam: () => tone(880, 0.15, 'sine', 0.06, 300),
  towerDown: () => { noise(1.0, 0.6, 300); tone(70, 0.9, 'sine', 0.4, -30); },
  crown: () => [523, 659, 784].forEach((f, i) => tone(f, 0.25, 'triangle', 0.2, 0, i * 0.1)),
  win: () => [523, 659, 784, 1046, 784, 1046].forEach((f, i) => tone(f, 0.3, 'triangle', 0.25, 0, i * 0.14)),
  lose: () => [392, 349, 311, 262].forEach((f, i) => tone(f, 0.4, 'sawtooth', 0.12, 0, i * 0.2)),
  essence: () => tone(1046, 0.06, 'sine', 0.05),
  noEssence: () => tone(140, 0.15, 'square', 0.15),
};
