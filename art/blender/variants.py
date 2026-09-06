"""Finite, seedable Blender catalogue. See art/README.md for CLI and contracts."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy
from common import ROOT, reset, render, mat
from environment import tree_oak, tree_cypress
from landscape import tree_pine, rock_cluster, gorse, bridge_stone
from buildings import house, house_cottage, house_tall
from variation import Variation

BUILDERS = dict(tree_oak=tree_oak, tree_cypress=tree_cypress, tree_pine=tree_pine,
                rock_cluster=rock_cluster, gorse=gorse, bridge_stone=bridge_stone)
HOUSES = dict(house=house, house_cottage=house_cottage, house_tall=house_tall)
LIMITS = dict(height=.12, lean=.15, trunk=.20, spread=.15, crown=.20,
              facets=.06, rock=.20, stone=.65, moss=.40)
ALLOWED = {name: set(("height", "lean", "trunk", "spread", "crown", "facets"))
           for name in ("tree_oak", "tree_cypress", "tree_pine")}
ALLOWED.update(rock_cluster={"spread", "rock", "moss"},
               gorse={"height", "spread", "crown", "facets"},
               bridge_stone={"stone", "moss"})
ALLOWED.update({name: {"stone"} for name in HOUSES})


def build(kind, seed, parameters):
    """Public authoring API; each call produces a fresh, editable Blender scene."""
    validate_parameters(kind, parameters)
    reset()
    variation = Variation(seed, parameters)
    if kind in HOUSES:
        HOUSES[kind]()
        # Extension point: only existing masonry details, never structure,
        # openings, roof, base, or footprint. Off unless explicitly generated.
        for obj in bpy.context.scene.objects:
            if obj.type == "MESH" and obj.name.startswith(("Subtle granite block face", "Subtle limewash stone face", "Subtle side masonry")):
                if variation.unit(obj.name) < parameters.get("stone", 0):
                    base = obj.data.materials[0].name
                    # Keep damp plinth stones dark; never replace with cream.
                    obj.data.materials[0] = mat("stone_dark" if base in ("stone", "stone_wet", "stone_dark") else "stone")
    else:
        BUILDERS[kind](variation)
    return variation


def validate_parameters(kind, parameters):
    if kind not in ALLOWED or set(parameters) - ALLOWED[kind]:
        raise ValueError(f"Unknown family/parameters: {kind}: {parameters}")
    for key, value in parameters.items():
        if not isinstance(value, (int, float)) or not 0 <= value <= LIMITS[key]:
            raise ValueError(f"{kind}.{key} must be between 0 and {LIMITS[key]}")


def signature(materials=True, prefix=""):
    """Evaluated geometry, including bevels; independent of GLB timestamps."""
    bpy.context.view_layer.update()
    graph = bpy.context.evaluated_depsgraph_get()
    result = []
    for obj in sorted(bpy.context.scene.objects, key=lambda o: o.name):
        if obj.type != "MESH" or not obj.name.startswith(prefix): continue
        evaluated = obj.evaluated_get(graph)
        data = evaluated.to_mesh()
        points = [tuple(round(c, 6) for c in evaluated.matrix_world @ v.co) for v in data.vertices]
        faces = [(tuple(p.vertices), data.materials[p.material_index].name if materials else "")
                 for p in data.polygons]
        result.append((obj.name, points, faces))
        evaluated.to_mesh_clear()
    return hashlib.sha256(json.dumps(result).encode()).hexdigest()


def verify(config):
    for kind, parameters in {**config["families"], **config["house_details"]}.items():
        active = {key for key, value in parameters.items() if value > 0}
        build(kind, "1530:1", parameters)
        first, geometry = signature(), signature(False)
        prefixes = {"tree_oak": ["Leaning oak trunk", "Visible fork", "Broad lobed oak canopy"],
                    "tree_pine": ["Maritime pine trunk", "High spreading pine branch", "Umbrella"],
                    "tree_cypress": ["Cypress trunk", "Short cypress branch", "Overlapping"]}.get(kind, [])
        pieces = [signature(False, p) for p in prefixes]
        build(kind, "1530:1", parameters)
        assert first == signature(), f"Non-reproducible {kind}"
        build(kind, "1531:1", parameters)
        if active:
            assert first != signature(), f"Seed has no effect: {kind}"
        else:
            assert first == signature(), f"Disabled parameters vary: {kind}"
        channels = [{"height", "lean", "trunk"}, {"height", "lean", "trunk", "spread"},
                    {"height", "spread", "crown", "facets"} | ({"lean"} if kind == "tree_cypress" else set())]
        for prefix, previous, keys in zip(prefixes, pieces, channels):
            if active & keys:
                assert previous != signature(False, prefix), f"Unchanged {kind}: {prefix}"
        if kind == "bridge_stone" or kind in HOUSES:
            assert geometry == signature(False), f"Structural variation in {kind}"
            build(kind, 0, {})
            assert geometry == signature(False), f"Canonical geometry changed: {kind}"
        elif active - {"moss", "stone"}:
            assert geometry != signature(False), f"Only color varied: {kind}"
        print(f"VARIANTS OK {kind}: repeatable, seed-sensitive, geometry contract")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=ROOT/"art/variants.json")
    parser.add_argument("--seed", type=int)
    parser.add_argument("--count", type=int, help="New variants per family, excluding canonical (1..8)")
    parser.add_argument("--assets", nargs="+", choices=list(ALLOWED))
    parser.add_argument("--output-root", type=Path, default=ROOT)
    parser.add_argument("--check", action="store_true", help="Check reproducibility/geometry; write nothing")
    args = parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    config = json.loads(args.config.read_text())
    if config["schema"] != 1: raise ValueError("Unsupported art config schema")
    if args.check:
        verify(config)
        return
    seed = config["seed"] if args.seed is None else args.seed
    count = config["count"] if args.count is None else args.count
    if type(seed) is not int: raise ValueError("seed must be an integer")
    if type(count) is not int or not 1 <= count <= 8:
        raise ValueError("count must be an integer between 1 and 8")
    families = args.assets or list(config["families"])
    parameters = {**config["families"], **config["house_details"]}
    for kind in families: validate_parameters(kind, parameters[kind])
    output = args.output_root.resolve()
    manifest_path = output/"data/model_variants.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {
        "schema": 1, "selection_version": 1,
        "families": {kind: [kind] for kind in ALLOWED}, "models": {}}
    for kind in families:
        names = [kind]
        for index in range(1, count+1):
            name = f"{kind}_v{str(seed).replace('-', 'n')}_{index:02d}"
            build(kind, f"{seed}:{index}", parameters[kind])
            digest = signature()
            bpy.context.scene["variant_recipe"] = json.dumps(dict(
                schema=1, family=kind, seed=seed, index=index, parameters=parameters[kind]))
            render(name, 512, export_model=True, output_root=output)
            names.append(name)
            manifest["models"][name] = dict(family=kind, seed=seed, index=index,
                parameters=parameters[kind], geometry_digest=digest)
        manifest["families"][kind] = names
    # Publish the catalogue only after every requested .blend/.glb/.png succeeded.
    # Older generated models stay listed for validation; no authored files deleted.
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2)+"\n")
    print(f"VARIANTS catalogue: {manifest_path}")


if __name__ == "__main__":
    main()
