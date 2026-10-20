#!/usr/bin/env python3
"""Builds mobile/assets/anatomy/body_{front,back}.svg from the upstream art.

Upstream: Ryan Graves' male muscle anatomy (Figma Community, CC BY 4.0),
as redistributed in the `advanced` style of the MIT-licensed `muscle_mapper`
package (github.com/suryamolly/muscle_mapper, lib/src/assets/advanced/).
Copies live in tool/anatomy/upstream/.

What this script does — and does not do:
  * copies every path's `d` data VERBATIM (no path is drawn, edited or
    approximated here);
  * regroups the anatomical paths into one <g id="<Muscle enum name>"> per
    body-map region, keeping each path's original anatomical id;
  * puts every other path (tendons, hands, face, unlabelled shapes, line
    work) in <g id="detail">, never highlighted;
  * records each path's upstream paint order as data-z. The art relies on
    it (e.g. trapezius_middle is the whole trapezius, with the upper and
    lower parts drawn over it), so the app paints and hit-tests by data-z;
  * replaces the grey fills with the app's look (white outlines, dark body),
    so the asset previews correctly in any SVG viewer.

The region table below is the reviewable anatomy decision. Run from the
repo's mobile/ folder:  python3 tool/anatomy/build_anatomy_assets.py
"""
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE.parent.parent / "assets" / "anatomy"

# Body-map region (= Dart `Muscle` enum name) -> upstream path ids, without
# the _l / _r side suffix (both sides are always included).
REGIONS = {
    "front": {
        "chest": ["pectoralis_major"],
        "deltAnterior": ["anterior_deltoid"],
        "deltLateral": ["lateral_deltoid"],
        "biceps": ["biceps_brachii_caput_longum", "biceps_brachii_caput_breve"],
        "triceps": ["triceps_brachii_caput_longum", "triceps_brachii_caput_laterale"],
        "forearms": [
            "flexor_digitorum_superficialis", "pronator_quadratus",
            "extensor_carpi_radialis_longus", "palmaris_longus",
            "flexor_carpi_radialis", "pronator_teres", "brachioradialis",
        ],
        # Rectus abdominis rows, top to bottom: 4, 2 | 3, 1 (1 = below navel).
        "upperAbs": ["rectus_abdominis_4", "rectus_abdominis_2"],
        "lowerAbs": ["rectus_abdominis_3", "rectus_abdominis_1"],
        "obliques": [f"external_oblique_{i}" for i in range(1, 9)],
        "adductors": ["adductor_longus", "pectineus", "gracilis"],
        "quadriceps": ["vastus_lateralis", "vastus_medialis", "rectus_femoris"],
        "traps": ["trapezius_upper"],
        "lats": ["latissimus_dorsi"],
        "glutes": ["gluteus_medius_2"],
        "hamstrings": ["semitendinosus"],
        "calves": ["gastrocnemius"],
    },
    "back": {
        "deltPosterior": ["posterior_deltoid"],
        "deltLateral": ["lateral_deltoid"],
        "triceps": [
            "triceps_brachii_caput_longum", "triceps_brachii_caput_laterale",
            "triceps_brachii_caput_mediale",
        ],
        "forearms": [
            "extensor_digitorum", "brachioradialis", "extensor_carpi_ulnaris",
            "anconeus", "flexor_carpi_ulnaris",
        ],
        "obliques": ["external_oblique_1"],
        "traps": ["trapezius_upper"],
        # The library's "middle back" group: mid/lower trapezius + infraspinatus.
        "upperBack": ["trapezius_middle", "trapezius_lower", "infraspinatus"],
        "lats": ["latissimus_dorsi"],
        "glutes": ["gluteus_maximus", "gluteus_medius_1", "gluteus_medius_2"],
        "hamstrings": [
            "biceps_femoris", "semitendinosus", "semimembranosus_1",
            "semimembranosus_2",
        ],
        "adductors": ["adductor_magnus"],
        "calves": ["gastrocnemius"],
        # No lowerBack: the art has no erector spinae path. Not drawn.
    },
}

TAG = re.compile(r"<(/?)(svg|g|path)\b([^>]*?)(/?)>", re.S)
ATTR = re.compile(r'([\w:-]+)="([^"]*)"')


def parse(svg_text):
    view_box = re.search(r'viewBox="([^"]+)"', svg_text).group(1)
    paths = []  # (id or None, d, stroke_only, z)
    for m in TAG.finditer(svg_text):
        close, tag, attrs, _ = m.groups()
        if close or tag != "path":
            continue
        a = dict(ATTR.findall(attrs))
        stroke_only = "fill" not in a and "stroke" in a
        paths.append(
            (a.get("id"), " ".join(a["d"].split()), stroke_only, len(paths))
        )
    return view_box, paths


def side_base(pid):
    return re.sub(r"_(l|r)$", "", pid)


def build(view):
    src = (HERE / "upstream" / f"male_{view}_muscle_anatomy.svg").read_text()
    view_box, paths = parse(src)
    region_of = {
        base: region
        for region, bases in REGIONS[view].items()
        for base in bases
    }
    silhouette = None
    groups = {region: [] for region in REGIONS[view]}
    detail = []
    for pid, d, stroke_only, z in paths:
        if pid == "underlayer":
            silhouette = d
            continue
        region = region_of.get(side_base(pid)) if pid and not stroke_only else None
        if region:
            groups[region].append((pid, d, z))
        else:
            detail.append((pid, d, stroke_only, z))

    missing = [
        f"{region}:{base}"
        for region, bases in REGIONS[view].items()
        for base in bases
        if not any(side_base(pid) == base for pid, _, _ in groups[region])
    ]
    if silhouette is None or missing:
        sys.exit(f"{view}: missing silhouette or ids {missing}")

    out = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view_box}" '
        f'data-view="{view}">',
        "<!-- Muscle anatomy art by Ryan Graves (Figma Community), CC BY 4.0",
        "     https://creativecommons.org/licenses/by/4.0/ . Path data unchanged;",
        "     regrouped and restyled for Grit by tool/anatomy/build_anatomy_assets.py."
        " -->",
        f'<path id="silhouette" fill="#05080C" fill-rule="evenodd" d="{silhouette}"/>',
        '<g id="detail" fill="#05080C" stroke="#FFFFFF" stroke-opacity="0.4" '
        'stroke-width="0.8">',
    ]
    for pid, d, stroke_only, z in detail:
        ident = pid or f"{view}_detail_{z}"
        kind = ' data-kind="line" fill="none"' if stroke_only else ""
        out.append(f'<path id="{ident}" data-z="{z}"{kind} d="{d}"/>')
    out.append("</g>")
    out.append(
        '<g id="muscles" fill="#05080C" stroke="#FFFFFF" stroke-opacity="0.7" '
        'stroke-width="0.9">'
    )
    for region, parts in groups.items():
        out.append(f'<g id="{region}">')
        for pid, d, z in parts:
            out.append(f'<path id="{pid}" data-z="{z}" d="{d}"/>')
        out.append("</g>")
    out.append("</g>")
    out.append("</svg>")
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / f"body_{view}.svg").write_text("\n".join(out) + "\n")
    print(
        f"{view}: {sum(len(p) for p in groups.values())} muscle paths in "
        f"{len(groups)} regions, {len(detail)} detail paths"
    )


if __name__ == "__main__":
    for v in ("front", "back"):
        build(v)
