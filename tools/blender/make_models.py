"""Modèles Blender de Clash of Things (générés par script, exportés en glTF binaire).

Usage : blender -b --python tools/blender/make_models.py -- godot/assets/models/blender
Chaque modèle est construit par code (métaballes, modificateurs, matériaux PBR) puis exporté en .glb.
Les matériaux nommés « Team » / « TeamGlow » sont recolorés par le jeu selon l'équipe.
"""
import math
import os
import random
import sys

import bpy
import bmesh
from mathutils import Vector, Euler

OUT = sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else 'out'
os.makedirs(OUT, exist_ok=True)
random.seed(11)


# ------------------------------------------------------------------ utilitaires
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30


def material(name, color, rough=0.55, metal=0.0, emit=None, emit_strength=2.0, alpha=1.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    if emit:
        b.inputs['Emission Color'].default_value = (*emit, 1)
        b.inputs['Emission Strength'].default_value = emit_strength
    if alpha < 1.0:
        b.inputs['Alpha'].default_value = alpha
        m.blend_method = 'BLEND'
    return m


def hexc(h):
    h = h.lstrip('#')
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x ** 2.2 for x in c)  # sRGB -> linéaire


def link(obj):
    bpy.context.collection.objects.link(obj)
    return obj


def activate(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def apply_mods(obj):
    activate(obj)
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def smooth(obj, angle=60):
    activate(obj)
    bpy.ops.object.shade_smooth()
    if hasattr(obj.data, 'use_auto_smooth'):
        obj.data.use_auto_smooth = True
        obj.data.auto_smooth_angle = math.radians(angle)


def metaball_mesh(name, elements, resolution=0.08, mat=None):
    """elements : liste de (position, rayon, (sx, sy, sz) ou None)."""
    mb = bpy.data.metaballs.new(name + '_mb')
    mb.resolution = resolution
    mb.render_resolution = resolution
    mb.threshold = 0.6
    obj = link(bpy.data.objects.new(name + '_mbo', mb))
    for pos, r, size in elements:
        el = mb.elements.new()
        el.co = Vector(pos)
        el.radius = r
        if size:
            el.type = 'ELLIPSOID'
            el.size_x, el.size_y, el.size_z = size
    bpy.context.view_layer.update()
    activate(obj)
    bpy.ops.object.convert(target='MESH')
    mesh_obj = bpy.context.view_layer.objects.active
    mesh_obj.name = name
    if mat:
        mesh_obj.data.materials.clear()
        mesh_obj.data.materials.append(mat)
    smooth(mesh_obj, 80)
    return mesh_obj


def prim(kind, name, mat=None, **kw):
    getattr(bpy.ops.mesh, 'primitive_' + kind + '_add')(**kw)
    o = bpy.context.view_layer.objects.active
    o.name = name
    if mat:
        o.data.materials.append(mat)
    return o


def empty(name, loc=(0, 0, 0), parent=None):
    e = link(bpy.data.objects.new(name, None))
    e.location = loc
    if parent:
        e.parent = parent
    return e


def parent_keep(child, parent):
    bpy.context.view_layer.update()
    m = child.matrix_world.copy()
    child.parent = parent
    child.matrix_world = m


def key_rot(obj, frame, rot):
    obj.rotation_mode = 'XYZ'
    obj.rotation_euler = Euler(rot)
    obj.keyframe_insert('rotation_euler', frame=frame)


def key_loc(obj, frame, loc):
    obj.location = Vector(loc)
    obj.keyframe_insert('location', frame=frame)


def key_scale(obj, frame, s):
    obj.scale = Vector(s)
    obj.keyframe_insert('scale', frame=frame)


def push_track(objs, track_name):
    """Range les actions courantes de chaque objet dans une piste NLA du même nom (fusionnées à l'export)."""
    for o in objs:
        ad = o.animation_data
        if not ad or not ad.action:
            continue
        act = ad.action
        act.name = f'{track_name}_{o.name}'
        tr = ad.nla_tracks.new()
        tr.name = track_name
        tr.strips.new(track_name, int(act.frame_range[0]), act)
        ad.action = None


def export(name, objects=None):
    path = os.path.join(OUT, name + '.glb')
    if objects is not None:
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:
            o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=objects is not None,
                              export_apply=True, export_animations=True, export_animation_mode='NLA_TRACKS',
                              export_yup=True, export_extras=False)
    print('EXPORT', path)


# ------------------------------------------------------------------ dragon
def make_dragon():
    reset()
    scale_m = material('Scales', hexc('#3e9b5a'), 0.45)
    belly_m = material('Belly', hexc('#f0d08a'), 0.6)
    horn_m = material('Horn', hexc('#f4efe2'), 0.35)
    wing_m = material('Team', hexc('#d9dde6'), 0.55)
    bone_m = material('WingBone', hexc('#2f7a45'), 0.5)
    eye_m = material('Eye', hexc('#ffd23f'), 0.2, emit=hexc('#ffd23f'), emit_strength=4.0)
    saddle_m = material('Saddle', hexc('#7a3f1f'), 0.7)
    gold_m = material('Gold', hexc('#e8b33a'), 0.3, 0.8)

    # En Blender : Y = avant, Z = haut. L'export glTF (+Y up) donne l'avant sur -Z ;
    # on fait donc pointer le museau vers -Y pour qu'il regarde +Z dans le jeu.
    root = empty('Dragon')
    body_pivot = empty('BodyPivot', (0, 0, 0), root)
    body = metaball_mesh('Body', [
        ((0, 0.0, 0), 0.75, (1.0, 1.5, 0.95)),
        ((0, -0.7, 0.15), 0.55, (0.9, 1.1, 0.9)),
        ((0, 0.8, -0.05), 0.5, (0.8, 1.2, 0.8)),
    ], 0.07, scale_m)
    parent_keep(body, body_pivot)
    belly = metaball_mesh('Belly', [((0, 0.0, -0.32), 0.62, (0.85, 1.4, 0.55)), ((0, -0.6, -0.15), 0.45, (0.8, 1.0, 0.6))], 0.07, belly_m)
    parent_keep(belly, body_pivot)
    # dorsales
    for i in range(6):
        y = 0.9 - i * 0.35
        sp = prim('cone', f'Spike{i}', horn_m, vertices=6, radius1=0.12, depth=0.32, location=(0, y, 0.72 - abs(y + 0.2) * 0.12))
        sp.rotation_euler = (math.radians(-25), 0, 0)
        parent_keep(sp, body_pivot)
    # selle et harnais
    saddle = metaball_mesh('Saddle', [((0, -0.15, 0.62), 0.38, (1.0, 1.1, 0.35))], 0.06, saddle_m)
    parent_keep(saddle, body_pivot)
    for x in (-0.6, 0.6):
        st = prim('torus', 'Strap', gold_m, major_radius=0.1, minor_radius=0.03, location=(x, -0.15, 0.25))
        st.rotation_euler = (0, math.radians(90), 0)
        parent_keep(st, body_pivot)
    seat = empty('Seat', (0, -0.15, 0.8), body_pivot)

    # cou + tête
    neck = empty('Neck', (0, -1.0, 0.35), body_pivot)
    neck_mesh = metaball_mesh('NeckMesh', [((0, -1.15, 0.55), 0.35, None), ((0, -1.4, 0.85), 0.3, None), ((0, -1.6, 1.1), 0.28, None)], 0.06, scale_m)
    parent_keep(neck_mesh, neck)
    head = empty('Head', (0, -1.75, 1.25), neck)
    skull = metaball_mesh('Skull', [((0, -1.8, 1.32), 0.38, (1.0, 1.0, 0.9)), ((0, -2.25, 1.2), 0.28, (0.85, 1.4, 0.7))], 0.05, scale_m)
    parent_keep(skull, head)
    jaw = empty('Jaw', (0, -1.85, 1.1), head)
    jaw_mesh = metaball_mesh('JawMesh', [((0, -2.2, 1.0), 0.22, (0.85, 1.5, 0.45))], 0.05, belly_m)
    parent_keep(jaw_mesh, jaw)
    for x in (-0.2, 0.2):
        horn = prim('cone', 'HornL' if x < 0 else 'HornR', horn_m, vertices=10, radius1=0.09, depth=0.6, location=(x, -1.6, 1.68))
        horn.rotation_euler = (math.radians(-55), 0, math.radians(15 if x < 0 else -15))
        parent_keep(horn, head)
        eye = prim('uv_sphere', 'Eye', eye_m, segments=12, ring_count=8, radius=0.075, location=(x * 1.1, -2.05, 1.42))
        parent_keep(eye, head)
        nost = prim('uv_sphere', 'Nostril', horn_m, segments=8, ring_count=6, radius=0.035, location=(x * 0.45, -2.6, 1.32))
        parent_keep(nost, head)
    mouth = empty('Mouth', (0, -2.6, 1.15), head)

    # queue articulée
    tails = []
    prev = body_pivot
    for i in range(3):
        t = empty(f'Tail{i}', (0, 1.1 + i * 0.6, -0.05 - i * 0.05), prev)
        seg = metaball_mesh(f'TailMesh{i}', [((0, 1.35 + i * 0.6, -0.05 - i * 0.05), 0.3 - i * 0.07, (0.9, 1.4, 0.9))], 0.05, scale_m)
        parent_keep(seg, t)
        tails.append(t)
        prev = t
    tip = prim('cone', 'TailTip', wing_m, vertices=4, radius1=0.22, depth=0.45, location=(0, 3.0, -0.2))
    tip.rotation_euler = (math.radians(-90), 0, 0)
    tip.scale = (1.0, 0.25, 1.0)
    parent_keep(tip, tails[-1])

    # pattes
    for x in (-0.5, 0.5):
        for y in (-0.55, 0.6):
            leg = metaball_mesh('Leg', [((x * 0.9, y, -0.4), 0.3, None), ((x, y, -0.62), 0.26, None), ((x * 1.05, y - 0.05, -0.85), 0.22, None)], 0.05, scale_m)
            parent_keep(leg, body_pivot)
            for c in (-0.08, 0.0, 0.08):
                cl = prim('cone', 'Claw', horn_m, vertices=6, radius1=0.04, depth=0.14, location=(x + c, y - 0.17, -0.98))
                cl.rotation_euler = (math.radians(-80), 0, 0)
                parent_keep(cl, body_pivot)

    # ailes : os + membrane (couleur d'équipe)
    wings = []
    for side in (-1, 1):
        w = empty('WingL' if side < 0 else 'WingR', (side * 0.55, -0.35, 0.5), body_pivot)
        verts = [(0, 0, 0), (side * 1.2, -0.3, 0.45), (side * 2.6, 0.1, 0.55), (side * 2.3, 0.7, 0.2), (side * 1.7, 0.6, 0.0),
                 (side * 1.3, 1.0, -0.05), (side * 0.6, 0.8, -0.05), (side * 0.15, 0.6, 0)]
        mesh = bpy.data.meshes.new('Membrane')
        bm = bmesh.new()
        bv = [bm.verts.new(Vector(v) + w.location) for v in verts]
        bm.faces.new(bv if side > 0 else list(reversed(bv)))
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        bm.to_mesh(mesh)
        mem = link(bpy.data.objects.new('Membrane', mesh))
        mem.data.materials.append(wing_m)
        sol = mem.modifiers.new('sol', 'SOLIDIFY')
        sol.thickness = 0.05
        sub = mem.modifiers.new('sub', 'SUBSURF')
        sub.levels = 2
        apply_mods(mem)
        smooth(mem, 70)
        parent_keep(mem, w)
        for a, b in ((verts[0], verts[2]), (verts[1], verts[3]), (verts[1], verts[5])):
            p0 = Vector(a) + w.location
            p1 = Vector(b) + w.location
            d = p1 - p0
            bonecyl = prim('cylinder', 'WingBone', bone_m, vertices=8, radius=0.05, depth=d.length, location=(p0 + p1) / 2)
            bonecyl.rotation_mode = 'QUATERNION'
            bonecyl.rotation_quaternion = d.to_track_quat('Z', 'Y')
            parent_keep(bonecyl, w)
        claw = prim('cone', 'WingClaw', horn_m, vertices=6, radius1=0.06, depth=0.2, location=Vector(verts[2]) + w.location)
        parent_keep(claw, w)
        wings.append((w, side))

    anim_objs = [root, body_pivot, neck, head, jaw] + tails + [w for w, _ in wings]
    rest = {o.name: (o.location.copy(), o.rotation_euler.copy()) for o in anim_objs}

    def reset_pose(f):
        for o in anim_objs:
            key_loc(o, f, rest[o.name][0])
            key_rot(o, f, rest[o.name][1])

    def wing_cycle(f0, length, amp, speed=1.0):
        steps = 8
        for i in range(steps + 1):
            f = f0 + i * length / steps
            ph = i / steps * 2 * math.pi * speed
            for w, side in wings:
                key_rot(w, f, (0, side * -amp * math.sin(ph) * -1, side * 0.15 * math.cos(ph)))
            key_loc(body_pivot, f, (0, 0, 0.12 * math.cos(ph)))
            for k, t in enumerate(tails):
                key_rot(t, f, (0.08 * math.sin(ph + k), 0, 0.25 * math.sin(ph * 0.5 + k * 0.8)))

    # Idle : battements lents
    wing_cycle(1, 40, 0.55)
    for o in (neck, head):
        key_rot(o, 1, (0, 0, 0)); key_rot(o, 20, (0.08, 0, 0.05)); key_rot(o, 41, (0, 0, 0))
    push_track(anim_objs, 'Idle')
    # Fly : battements amples et rapides
    wing_cycle(1, 24, 0.85)
    for o in (neck, head):
        key_rot(o, 1, (-0.1, 0, 0)); key_rot(o, 25, (-0.1, 0, 0))
    push_track(anim_objs, 'Fly')
    # Attack : la tête recule puis crache (mâchoire ouverte)
    wing_cycle(1, 30, 0.6)
    key_rot(neck, 1, (0, 0, 0)); key_rot(neck, 9, (0.35, 0, 0)); key_rot(neck, 15, (-0.45, 0, 0)); key_rot(neck, 30, (0, 0, 0))
    key_rot(head, 1, (0, 0, 0)); key_rot(head, 9, (0.3, 0, 0)); key_rot(head, 15, (-0.25, 0, 0)); key_rot(head, 30, (0, 0, 0))
    key_rot(jaw, 1, (0, 0, 0)); key_rot(jaw, 12, (0, 0, 0)); key_rot(jaw, 15, (0.55, 0, 0)); key_rot(jaw, 24, (0.45, 0, 0)); key_rot(jaw, 30, (0, 0, 0))
    push_track(anim_objs, 'Attack')
    # Death_A : tombe en vrille
    reset_pose(1)
    key_loc(root, 1, (0, 0, 0)); key_loc(root, 24, (0, 0, -2.4))
    key_rot(root, 1, (0, 0, 0)); key_rot(root, 24, (0.6, 0, 1.4))
    for w, side in wings:
        key_rot(w, 1, (0, 0, 0)); key_rot(w, 24, (0, side * 0.9, 0))
    push_track(anim_objs, 'Death_A')
    export('dragon')


# ------------------------------------------------------------------ totem
def make_totem():
    reset()
    stone = material('Stone', hexc('#8a8f9c'), 0.85)
    dark = material('StoneDark', hexc('#5e6270'), 0.9)
    glow = material('TeamGlow', hexc('#6fd0ff'), 0.3, emit=hexc('#6fd0ff'), emit_strength=3.0)
    gold = material('Gold', hexc('#e8b33a'), 0.3, 0.85)
    parts = []
    base = prim('cylinder', 'Base', dark, vertices=8, radius=1.0, depth=0.35, location=(0, 0, 0.17))
    parts.append(base)
    step = prim('cylinder', 'Step', stone, vertices=8, radius=0.8, depth=0.25, location=(0, 0, 0.45))
    parts.append(step)
    ob = prim('cylinder', 'Obelisk', stone, vertices=4, radius=0.5, depth=2.0, location=(0, 0, 1.55))
    ob.rotation_euler = (0, 0, math.radians(45))
    activate(ob)
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(ob.data)
    for v in bm.verts:
        if v.co.z > 0:
            v.co.x *= 0.65
            v.co.y *= 0.65
    bmesh.update_edit_mesh(ob.data)
    bpy.ops.object.mode_set(mode='OBJECT')
    ob.modifiers.new('bevel', 'BEVEL').width = 0.05
    apply_mods(ob)
    parts.append(ob)
    cap = prim('cone', 'Cap', gold, vertices=4, radius1=0.42, depth=0.45, location=(0, 0, 2.78))
    cap.rotation_euler = (0, 0, math.radians(45))
    parts.append(cap)
    for i in range(4):
        a = i * math.pi / 2
        for k in range(3):
            r = prim('cube', 'Rune', glow, size=1, location=(math.cos(a) * 0.45 - math.cos(a) * k * 0.02, math.sin(a) * 0.45 - math.sin(a) * k * 0.02, 1.0 + k * 0.45))
            r.scale = (0.06 if abs(math.cos(a)) < 0.5 else 0.03, 0.06 if abs(math.cos(a)) > 0.5 else 0.03, 0.22)
            r.scale = (0.03 + 0.05 * abs(math.sin(a)), 0.03 + 0.05 * abs(math.cos(a)), 0.2)
            parts.append(r)
    for i in range(6):
        a = i / 6 * 2 * math.pi
        rk = prim('ico_sphere', 'Rock', dark, subdivisions=1, radius=random.uniform(0.15, 0.3), location=(math.cos(a) * 1.05, math.sin(a) * 1.05, 0.15))
        parts.append(rk)
    crystal_pivot = empty('Crystal', (0, 0, 3.6))
    cr = prim('ico_sphere', 'CrystalMesh', glow, subdivisions=1, radius=0.42, location=(0, 0, 3.6))
    cr.scale = (0.7, 0.7, 1.4)
    parent_keep(cr, crystal_pivot)
    for i in range(3):
        a = i / 3 * 2 * math.pi
        sh = prim('ico_sphere', 'Shard', glow, subdivisions=1, radius=0.12, location=(math.cos(a) * 0.75, math.sin(a) * 0.75, 3.4))
        sh.scale = (0.6, 0.6, 1.5)
        parent_keep(sh, crystal_pivot)
    for o in parts:
        smooth(o, 30)
    key_rot(crystal_pivot, 1, (0, 0, 0)); key_loc(crystal_pivot, 1, (0, 0, 3.6))
    key_rot(crystal_pivot, 31, (0, 0, math.pi)); key_loc(crystal_pivot, 31, (0, 0, 3.8))
    key_rot(crystal_pivot, 61, (0, 0, 2 * math.pi)); key_loc(crystal_pivot, 61, (0, 0, 3.6))
    for fc in crystal_pivot.animation_data.action.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = 'LINEAR' if fc.data_path == 'rotation_euler' else 'BEZIER'
    push_track([crystal_pivot], 'Idle')
    export('totem')


# ------------------------------------------------------------------ sorts
def displaced_rock(name, radius, strength, mat, subdiv=3, seed=0):
    r = prim('ico_sphere', name, mat, subdivisions=subdiv, radius=radius)
    tex = bpy.data.textures.new(name + '_tex', 'VORONOI')
    tex.noise_scale = 0.45
    d = r.modifiers.new('disp', 'DISPLACE')
    d.texture = tex
    d.strength = strength
    apply_mods(r)
    for v in r.data.vertices:
        v.co *= 1 + random.uniform(-0.04, 0.04)
    return r


def make_meteor():
    reset()
    rock = material('Rock', hexc('#3a2a22'), 0.9)
    lava = material('Lava', hexc('#ff4a00'), 0.4, emit=hexc('#ff3c00'), emit_strength=2.2)
    m = displaced_rock('Meteor', 0.8, 0.35, rock)
    m.data.materials.append(lava)
    # fissures de lave : faces au hasard
    for p in m.data.polygons:
        if random.random() < 0.08:
            p.material_index = 1
    smooth(m, 35)
    export('meteor')


def make_frost():
    reset()
    ice = material('Ice', hexc('#aeeaff'), 0.08, 0.1, emit=hexc('#4fc3ff'), emit_strength=0.6, alpha=0.85)
    core = material('IceCore', hexc('#ffffff'), 0.1, emit=hexc('#dff6ff'), emit_strength=3.0)
    for i in range(9):
        h = random.uniform(0.9, 2.0)
        c = prim('cylinder', 'Crystal', ice, vertices=6, radius=random.uniform(0.12, 0.22), depth=h, location=(0, 0, h / 2))
        activate(c)
        bpy.ops.object.mode_set(mode='EDIT')
        bm = bmesh.from_edit_mesh(c.data)
        top = [v for v in bm.verts if v.co.z > 0]
        bmesh.ops.pointmerge(bm, verts=top, merge_co=Vector((0, 0, h / 2 + 0.3)))
        bmesh.update_edit_mesh(c.data)
        bpy.ops.object.mode_set(mode='OBJECT')
        a = i / 9 * 2 * math.pi
        c.location = (math.cos(a) * 0.25 * (i % 3), math.sin(a) * 0.25 * (i % 3), 0)
        c.rotation_euler = (random.uniform(-0.45, 0.45), random.uniform(-0.45, 0.45), random.uniform(0, 3))
    prim('ico_sphere', 'Core', core, subdivisions=2, radius=0.25, location=(0, 0, 0.3))
    export('frost')


def make_potion():
    reset()
    glass = material('Glass', hexc('#e9c6ff'), 0.05, 0.0, alpha=0.45)
    liquid = material('Liquid', hexc('#c23cf0'), 0.2, emit=hexc('#d24bff'), emit_strength=2.5)
    cork = material('Cork', hexc('#8b5a2b'), 0.8)
    gold = material('Gold', hexc('#e8b33a'), 0.3, 0.85)
    # profil de fiole tourné (modificateur Screw)
    prof = [(0.0, 0.0), (0.45, 0.02), (0.6, 0.35), (0.55, 0.75), (0.2, 1.0), (0.17, 1.35), (0.22, 1.42)]
    mesh = bpy.data.meshes.new('Bottle')
    bm = bmesh.new()
    vs = [bm.verts.new((x, 0, z)) for x, z in prof]
    for a, b in zip(vs, vs[1:]):
        bm.edges.new((a, b))
    bm.to_mesh(mesh)
    bottle = link(bpy.data.objects.new('Bottle', mesh))
    bottle.data.materials.append(glass)
    sc = bottle.modifiers.new('screw', 'SCREW')
    sc.steps = 32
    sc.render_steps = 32
    sol = bottle.modifiers.new('sol', 'SOLIDIFY')
    sol.thickness = 0.03
    apply_mods(bottle)
    smooth(bottle, 60)
    liq = prim('uv_sphere', 'Liquid', liquid, segments=24, ring_count=12, radius=0.52, location=(0, 0, 0.38))
    liq.scale = (1, 1, 0.75)
    prim('cylinder', 'Cork', cork, vertices=16, radius=0.19, depth=0.25, location=(0, 0, 1.5))
    t = prim('torus', 'Ring', gold, major_radius=0.2, minor_radius=0.035, location=(0, 0, 1.22))
    for i in range(6):
        prim('uv_sphere', 'Bubble', liquid, segments=8, ring_count=6, radius=random.uniform(0.04, 0.08),
             location=(random.uniform(-0.2, 0.2), random.uniform(-0.2, 0.2), random.uniform(0.4, 0.9)))
    export('potion')


def make_arrow():
    reset()
    wood = material('Wood', hexc('#8b5a2b'), 0.7)
    steel = material('Steel', hexc('#dfe6ee'), 0.25, 0.85)
    feather = material('Feather', hexc('#f2ece0'), 0.8)
    shaft = prim('cylinder', 'Shaft', wood, vertices=8, radius=0.03, depth=1.3, location=(0, 0, 0))
    tip = prim('cone', 'Tip', steel, vertices=4, radius1=0.08, depth=0.25, location=(0, 0, -0.77))
    tip.rotation_euler = (math.pi, 0, 0)
    for i in range(3):
        f = prim('cube', 'Fletch', feather, size=1, location=(0, 0, 0.5))
        f.scale = (0.01, 0.09, 0.14)
        f.rotation_euler = (0, 0, i * 2 * math.pi / 3)
        f.location = (math.cos(i * 2.094) * 0.07, math.sin(i * 2.094) * 0.07, 0.52)
    export('arrow')


# ------------------------------------------------------------------ île flottante
def make_island():
    reset()
    rock = material('Rock', hexc('#8a6b4a'), 0.95)
    rock_dark = material('RockDark', hexc('#5e4732'), 0.95)
    grass = material('Grass', hexc('#58b847'), 0.95)
    root = prim('uv_sphere', 'IslandRock', rock, segments=48, ring_count=24, radius=1.0)
    root.scale = (15.5, 23.0, 13.0)
    activate(root)
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(root.data)
    # on garde la moitié basse, étirée en pointe irrégulière
    for v in list(bm.verts):
        if v.co.z > 0.01:
            v.co.z = 0.0
    for v in bm.verts:
        if v.co.z < 0:
            k = -v.co.z / 13.0
            shrink = 1.0 - k * 0.55
            v.co.x *= shrink
            v.co.y *= shrink
            v.co.z *= 1.0 + k * 0.4
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.01)
    bmesh.update_edit_mesh(root.data)
    bpy.ops.object.mode_set(mode='OBJECT')
    tex = bpy.data.textures.new('cliff', 'VORONOI')
    tex.noise_scale = 3.0
    d = root.modifiers.new('disp', 'DISPLACE')
    d.texture = tex
    d.strength = 2.2
    tex2 = bpy.data.textures.new('cliff2', 'CLOUDS')
    tex2.noise_scale = 1.2
    d2 = root.modifiers.new('disp2', 'DISPLACE')
    d2.texture = tex2
    d2.strength = 1.4
    apply_mods(root)
    # le dessus reste plat (le terrain de jeu repose dessus)
    for v in root.data.vertices:
        if v.co.z > -0.6:
            v.co.z = min(v.co.z, -0.35)
    root.data.materials.append(rock_dark)
    for p in root.data.polygons:
        if p.center.z < -6 and random.random() < 0.5:
            p.material_index = 1
    smooth(root, 40)
    top = prim('cylinder', 'IslandGrass', grass, vertices=48, radius=1.0, depth=0.7, location=(0, 0, -0.35))
    top.scale = (15.3, 22.7, 1)
    activate(top)
    bpy.ops.object.transform_apply(scale=True)
    tex3 = bpy.data.textures.new('rim', 'CLOUDS')
    tex3.noise_scale = 0.8
    d3 = top.modifiers.new('rim', 'DISPLACE')
    d3.texture = tex3
    d3.strength = 0.25
    apply_mods(top)
    # rochers suspendus et petits îlots
    for i in range(10):
        a = random.uniform(0, 2 * math.pi)
        r = displaced_rock('Floating', random.uniform(0.8, 1.8), 0.4, rock, subdiv=2)
        r.location = (math.cos(a) * random.uniform(14, 20), math.sin(a) * random.uniform(20, 28), random.uniform(-9, -3))
    export('island')


# ------------------------------------------------------------------ coffres
CHEST_STYLES = {
    'wood': {'body': '#9a5f2e', 'body2': '#83501f', 'metal': '#5d6470', 'metal_rough': 0.45, 'metal_k': 0.8, 'lock': '#4a505c', 'gem': None, 'emblem': None},
    'silver': {'body': '#4f6f9a', 'body2': '#3f5d86', 'metal': '#d6dde8', 'metal_rough': 0.25, 'metal_k': 0.95, 'lock': '#aeb8c8', 'gem': '#6fd0ff', 'emblem': None},
    'gold': {'body': '#a8322a', 'body2': '#8c2620', 'metal': '#f2bf3a', 'metal_rough': 0.25, 'metal_k': 0.95, 'lock': '#f2bf3a', 'gem': '#3ee07a', 'emblem': 'studs'},
    'magic': {'body': '#5a2a9a', 'body2': '#47207d', 'metal': '#f2bf3a', 'metal_rough': 0.25, 'metal_k': 0.95, 'lock': '#f2bf3a', 'gem': '#d24bff', 'emblem': 'crystals'},
    'crown': {'body': '#2f5fd0', 'body2': '#244cae', 'metal': '#f6c945', 'metal_rough': 0.2, 'metal_k': 1.0, 'lock': '#f6c945', 'gem': '#ff4a6a', 'emblem': 'crown'},
}


def half_cylinder(name, radius, length, mat, segments=28):
    """Demi-cylindre couché selon X (dessus arrondi), fermé aux extrémités."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=segments, radius=radius, depth=length, rotation=(0, math.radians(90), 0))
    o = bpy.context.view_layer.objects.active
    o.name = name
    bpy.ops.object.transform_apply(rotation=True)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, 0), plane_no=(0, 0, 1), clear_inner=True)
    edges = [e for e in bm.edges if e.is_boundary]
    bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bm.to_mesh(o.data)
    bm.free()
    o.data.materials.append(mat)
    return o


def bevel(o, w=0.03, seg=2):
    b = o.modifiers.new('bevel', 'BEVEL')
    b.width = w
    b.segments = seg
    b.limit_method = 'ANGLE'
    apply_mods(o)


def make_chest(kind):
    reset()
    st = CHEST_STYLES[kind]
    wood = material('Body', hexc(st['body']), 0.7)
    wood2 = material('Body2', hexc(st['body2']), 0.75)
    metal = material('Metal', hexc(st['metal']), 0.35, st['metal_k'] * 0.45)
    lockm = material('Lock', hexc(st['lock']), 0.35, 0.45)
    dark = material('Dark', hexc('#1a1410'), 0.9)
    inner = material('Inner', hexc('#2a1a10'), 0.95)
    glow = material('Glow', hexc('#ffc93a'), 0.3, emit=hexc('#ffb21a'), emit_strength=1.6)
    gem = material('Gem', hexc(st['gem']), 0.1, 0.2, emit=hexc(st['gem']), emit_strength=2.5) if st['gem'] else None

    W, D, H = 1.6, 1.05, 0.85   # largeur (X), profondeur (Y), hauteur caisse (Z)
    root = empty('Chest')
    body_pv = empty('BodyPivot', (0, 0, 0), root)
    parts_body = []
    # caisse en planches horizontales
    for i in range(3):
        pl = prim('cube', f'Plank{i}', wood if i % 2 == 0 else wood2, size=1, location=(0, 0, 0.14 + i * 0.27))
        pl.scale = (W - 0.04, D - 0.04, 0.25)
        bpy.ops.object.transform_apply(scale=True)
        bevel(pl, 0.03)
        parts_body.append(pl)
    # intérieur sombre visible à l'ouverture + lueur du trésor
    inn = prim('cube', 'InnerTop', inner, size=1, location=(0, 0, H - 0.02))
    inn.scale = (W - 0.16, D - 0.16, 0.04)
    parts_body.append(inn)
    treasure = prim('uv_sphere', 'Treasure', glow, segments=16, ring_count=8, radius=0.42, location=(0, 0, H - 0.05))
    treasure.scale = (1.6, 0.9, 0.35)
    parts_body.append(treasure)
    # socle et cerclages
    base = prim('cube', 'Base', metal, size=1, location=(0, 0, 0.03))
    base.scale = (W + 0.08, D + 0.08, 0.08)
    bpy.ops.object.transform_apply(scale=True)
    bevel(base, 0.025)
    parts_body.append(base)
    rim = prim('cube', 'Rim', metal, size=1, location=(0, 0, H))
    rim.scale = (W + 0.06, D + 0.06, 0.08)
    bpy.ops.object.transform_apply(scale=True)
    bevel(rim, 0.025)
    parts_body.append(rim)
    for x in (-W * 0.33, W * 0.33):
        band = prim('cube', 'Band', metal, size=1, location=(x, 0, H / 2))
        band.scale = (0.14, D + 0.05, H + 0.02)
        bpy.ops.object.transform_apply(scale=True)
        bevel(band, 0.02)
        parts_body.append(band)
        for z in (0.2, 0.45, 0.7):
            for y in (-1, 1):
                r = prim('uv_sphere', 'Rivet', metal, segments=10, ring_count=6, radius=0.035, location=(x, y * (D / 2 + 0.03), z))
                parts_body.append(r)
    # coins renforcés
    for sx in (-1, 1):
        for sy in (-1, 1):
            c = prim('cube', 'Corner', metal, size=1, location=(sx * (W / 2 - 0.02), sy * (D / 2 - 0.02), H / 2))
            c.scale = (0.12, 0.12, H + 0.04)
            bpy.ops.object.transform_apply(scale=True)
            bevel(c, 0.025)
            parts_body.append(c)
    # serrure à l'avant (-Y)
    plate = prim('cube', 'LockPlate', lockm, size=1, location=(0, -D / 2 - 0.04, H - 0.12))
    plate.scale = (0.34, 0.08, 0.36)
    bpy.ops.object.transform_apply(scale=True)
    bevel(plate, 0.04, 3)
    parts_body.append(plate)
    kh = prim('cylinder', 'Keyhole', dark, vertices=12, radius=0.045, depth=0.04, location=(0, -D / 2 - 0.085, H - 0.08), rotation=(math.radians(90), 0, 0))
    parts_body.append(kh)
    kh2 = prim('cube', 'KeySlot', dark, size=1, location=(0, -D / 2 - 0.085, H - 0.16))
    kh2.scale = (0.03, 0.04, 0.1)
    parts_body.append(kh2)
    if gem:
        g = prim('ico_sphere', 'LockGem', gem, subdivisions=1, radius=0.07, location=(0, -D / 2 - 0.09, H - 0.25))
        g.scale = (1, 0.6, 1)
        parts_body.append(g)
    if st['emblem'] == 'studs':
        for x in (-0.55, -0.15, 0.15, 0.55):
            for z in (0.15, 0.42):
                stud = prim('uv_sphere', 'Stud', metal, segments=10, ring_count=6, radius=0.05, location=(x, -D / 2 - 0.02, z))
                parts_body.append(stud)
    for o in parts_body:
        smooth(o, 35)
        parent_keep(o, body_pv)

    # couvercle arrondi, pivot à la charnière arrière (+Y)
    lid_pv = empty('LidPivot', (0, D / 2, H), body_pv)
    lid_parts = []
    lid = half_cylinder('Lid', D / 2 + 0.02, W - 0.04, wood)
    lid.location = (0, 0, H + 0.04)
    lid.scale = (1, 1, 0.8)
    bpy.context.view_layer.update()
    lid_parts.append(lid)
    for x in (-W * 0.33, W * 0.33):
        lb = half_cylinder('LidBand', D / 2 + 0.06, 0.15, metal)
        lb.location = (x, 0, H + 0.04)
        lb.scale = (1, 1, 0.8)
        lid_parts.append(lb)
    for x in (-W / 2 + 0.03, W / 2 - 0.03):
        cap = half_cylinder('LidCap', D / 2 + 0.06, 0.1, metal)
        cap.location = (x, 0, H + 0.04)
        cap.scale = (1, 1, 0.8)
        lid_parts.append(cap)
    lrim = prim('cube', 'LidRim', metal, size=1, location=(0, 0, H + 0.06))
    lrim.scale = (W + 0.06, D + 0.08, 0.06)
    bpy.ops.object.transform_apply(scale=True)
    lid_parts.append(lrim)
    hasp = prim('cube', 'Hasp', lockm, size=1, location=(0, -D / 2 - 0.05, H + 0.02))
    hasp.scale = (0.2, 0.06, 0.24)
    bpy.ops.object.transform_apply(scale=True)
    bevel(hasp, 0.03, 2)
    lid_parts.append(hasp)
    top_z = H + 0.04 + (D / 2 + 0.06) * 0.8
    if st['emblem'] == 'crystals':
        for i, (x, s) in enumerate(((-0.35, 0.8), (0.0, 1.2), (0.35, 0.8))):
            cr = prim('ico_sphere', 'Crystal', gem, subdivisions=1, radius=0.13 * s, location=(x, 0, top_z + 0.12 * s))
            cr.scale = (0.7, 0.7, 1.6)
            cr.rotation_euler = (0, (i - 1) * 0.35, 0)
            lid_parts.append(cr)
    elif st['emblem'] == 'crown':
        cb = prim('cylinder', 'CrownBand', metal, vertices=24, radius=0.28, depth=0.14, location=(0, 0, top_z + 0.05))
        lid_parts.append(cb)
        for i in range(5):
            a = i / 5 * 2 * math.pi
            sp = prim('cone', 'CrownSpike', metal, vertices=8, radius1=0.07, depth=0.24, location=(math.cos(a) * 0.24, math.sin(a) * 0.24, top_z + 0.22))
            lid_parts.append(sp)
            jw = prim('uv_sphere', 'CrownGem', gem, segments=8, ring_count=6, radius=0.04, location=(math.cos(a) * 0.24, math.sin(a) * 0.24, top_z + 0.36))
            lid_parts.append(jw)
        cg = prim('ico_sphere', 'CrownJewel', gem, subdivisions=1, radius=0.07, location=(0, -0.28, top_z + 0.05))
        lid_parts.append(cg)
    elif st['emblem'] == 'studs' or kind == 'silver':
        em = prim('cylinder', 'Emblem', metal, vertices=24, radius=0.16, depth=0.05, location=(0, -0.25, top_z - 0.08), rotation=(math.radians(60), 0, 0))
        lid_parts.append(em)
        if gem:
            eg = prim('ico_sphere', 'EmblemGem', gem, subdivisions=1, radius=0.07, location=(0, -0.29, top_z - 0.05))
            lid_parts.append(eg)
    for o in lid_parts:
        smooth(o, 35)
        parent_keep(o, lid_pv)

    objs = [root, body_pv, lid_pv]
    rest_lid = lid_pv.location.copy()

    def pose(f, lid_rot=0.0, sq=(1, 1, 1), rz=0.0, lz=0.0):
        key_rot(lid_pv, f, (lid_rot, 0, 0))
        key_loc(lid_pv, f, (rest_lid.x, rest_lid.y, rest_lid.z + lz))
        key_scale(body_pv, f, sq)
        key_rot(root, f, (0, 0, rz))

    # Idle : respiration douce, le couvercle se soulève à peine (lueur visible)
    pose(1); pose(30, -0.06, (1.02, 1.02, 0.97)); pose(61)
    push_track(objs, 'Idle')
    # Shake : anticipation qui tremble de plus en plus
    for i, a in enumerate((0, 0.1, -0.12, 0.15, -0.17, 0.2, -0.2, 0.0)):
        pose(1 + i * 3, -0.05 * (i % 2), (1.0 + 0.04 * (i % 2), 1.0 + 0.04 * (i % 2), 1.0 - 0.06 * (i % 2)), a)
    push_track(objs, 'Shake')
    # Open : écrasement, le couvercle s'envole en arrière avec rebond
    pose(1, 0, (1, 1, 1))
    pose(5, 0, (1.15, 1.15, 0.78))
    pose(9, -2.25, (0.92, 0.92, 1.18), 0, 0.15)
    pose(14, -1.75, (1.04, 1.04, 0.96))
    pose(19, -1.98, (1, 1, 1))
    pose(24, -1.9, (1, 1, 1))
    push_track(objs, 'Open')
    # Opened : reste ouvert (boucle légère)
    pose(1, -1.9); pose(30, -1.86, (1.01, 1.01, 0.99)); pose(61, -1.9)
    push_track(objs, 'Opened')
    export('chest_' + kind)


def make_chests():
    for k in CHEST_STYLES:
        make_chest(k)


if __name__ == '__main__':
    only = sys.argv[sys.argv.index('--') + 2:] if '--' in sys.argv else []
    for fn in (make_dragon, make_totem, make_meteor, make_frost, make_potion, make_arrow, make_island, make_chests):
        if not only or fn.__name__ in only:
            fn()
