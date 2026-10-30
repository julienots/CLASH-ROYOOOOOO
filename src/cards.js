// Catalogue des cartes originales d'Essence Arena (SuperEssence Studio).
// Unités de distance : 1 = une case de l'arène. Temps en secondes.

export const RARITY = {
  common: { label: 'Commune', color: '#9fb4c8' },
  rare: { label: 'Rare', color: '#ffb02e' },
  epic: { label: 'Épique', color: '#c55cff' },
  legendary: { label: 'Légendaire', color: '#4ff0d2' },
};

export const CARDS = {
  blade: {
    name: 'Lame Spectrale', type: 'unit', cost: 3, rarity: 'rare',
    desc: 'Assassin fantôme très rapide. Sa première frappe inflige le double de dégâts.',
    hp: 720, dmg: 165, hitSpeed: 1.0, speed: 2.3, range: 0.9, radius: 0.45,
    targets: 'ground', attack: 'melee', firstStrike: 2,
  },
  golem: {
    name: 'Golem de Basalte', type: 'unit', cost: 6, rarity: 'epic',
    desc: 'Colosse de roche en fusion qui ne vise que les bâtiments. Se brise en 2 Éclats à sa mort.',
    hp: 3600, dmg: 230, hitSpeed: 1.6, speed: 0.85, range: 1.0, radius: 0.95,
    targets: 'buildings', attack: 'melee', onDeath: { spawn: 'shard', count: 2 }, heavy: true,
  },
  shard: {
    name: 'Éclat de Basalte', type: 'unit', cost: 0, rarity: 'common', hidden: true,
    hp: 700, dmg: 70, hitSpeed: 1.2, speed: 1.1, range: 0.8, radius: 0.5,
    targets: 'buildings', attack: 'melee',
  },
  archers: {
    name: 'Archères Sylvaines', type: 'unit', cost: 3, rarity: 'common', count: 2,
    desc: 'Duo d’archères elfiques. Touchent les unités aériennes et terrestres.',
    hp: 300, dmg: 95, hitSpeed: 1.0, speed: 1.4, range: 5.2, radius: 0.4,
    targets: 'both', attack: 'arrow',
  },
  pyro: {
    name: 'Pyromancien', type: 'unit', cost: 5, rarity: 'rare',
    desc: 'Lance des boules de feu qui explosent en zone.',
    hp: 640, dmg: 210, hitSpeed: 1.7, speed: 1.2, range: 5.0, radius: 0.45,
    targets: 'both', attack: 'fireball', splash: 1.5,
  },
  swarm: {
    name: 'Nuée de Scarabées', type: 'unit', cost: 2, rarity: 'common', count: 6,
    desc: 'Six scarabées-gemmes voraces. Fragiles mais nombreux.',
    hp: 85, dmg: 70, hitSpeed: 0.9, speed: 2.1, range: 0.6, radius: 0.3,
    targets: 'ground', attack: 'melee',
  },
  storm: {
    name: 'Titan de l’Orage', type: 'unit', cost: 7, rarity: 'legendary',
    desc: 'Géant blindé dont la foudre rebondit sur 3 cibles.',
    hp: 2900, dmg: 250, hitSpeed: 1.9, speed: 0.9, range: 4.5, radius: 0.9,
    targets: 'both', attack: 'chain', chains: 3, heavy: true,
  },
  shield: {
    name: 'Gardienne d’Airain', type: 'unit', cost: 4, rarity: 'common',
    desc: 'Chevalière robuste protégée par un bouclier de 450 PV.',
    hp: 1450, shield: 450, dmg: 175, hitSpeed: 1.2, speed: 1.25, range: 1.0, radius: 0.5,
    targets: 'ground', attack: 'melee',
  },
  sapper: {
    name: 'Sapeur Fou', type: 'unit', cost: 2, rarity: 'rare',
    desc: 'Fonce sur un bâtiment et explose avec son tonneau de poudre.',
    hp: 320, dmg: 480, hitSpeed: 0.1, speed: 2.6, range: 0.8, radius: 0.4,
    targets: 'buildings', attack: 'kamikaze', splash: 2.0,
  },
  drake: {
    name: 'Chevaucheur de Drake', type: 'unit', cost: 5, rarity: 'epic', flying: true,
    desc: 'Monture volante qui crache un souffle de feu en zone.',
    hp: 1050, dmg: 140, hitSpeed: 1.5, speed: 1.5, range: 3.0, radius: 0.7,
    targets: 'both', attack: 'breath', splash: 1.3,
  },
  totem: {
    name: 'Totem Arcanique', type: 'building', cost: 4, rarity: 'rare',
    desc: 'Obélisque défensif qui tire un rayon d’essence. Dure 30 s.',
    hp: 1150, dmg: 125, hitSpeed: 0.9, range: 6.0, radius: 0.8, lifetime: 30,
    targets: 'both', attack: 'beam',
  },
  meteor: {
    name: 'Météore', type: 'spell', cost: 4, rarity: 'rare',
    desc: 'Un rocher en fusion s’écrase sur la zone ciblée.',
    radius: 2.5, dmg: 560, towerMult: 0.35, delay: 0.9,
  },
  frost: {
    name: 'Nova de Givre', type: 'spell', cost: 3, rarity: 'epic',
    desc: 'Explosion glaciale qui gèle tout pendant 3 s.',
    radius: 3.0, dmg: 110, towerMult: 0.4, freeze: 3, delay: 0,
  },
};

export const PLAYABLE = Object.keys(CARDS).filter((k) => !CARDS[k].hidden);

export const DEFAULT_DECK = ['blade', 'golem', 'archers', 'pyro', 'swarm', 'shield', 'meteor', 'frost'];

export const TOWER = {
  side: { hp: 2100, dmg: 85, hitSpeed: 0.8, range: 7.5, radius: 1.3 },
  core: { hp: 3600, dmg: 105, hitSpeed: 1.0, range: 7.2, radius: 1.8 },
};
