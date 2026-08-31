#!/usr/bin/env python3
"""
Complete standard-library server example for the Build Planner GBP1 generator.

Run:
    python example.py

Then open:
    http://127.0.0.1:8081

The browser uses the same complete form as the JavaScript, browser-Python, and
PHP examples. POST /generate receives its JSON object as build_dict, validates
server-side invariants, and calls encode_build(build_dict). This development
server has no third-party dependencies and is not a production deployment
recipe for shared hosting.
"""

import argparse
import json
import os
from http.server import SimpleHTTPRequestHandler
from pathlib import Path
from socketserver import ThreadingMixIn
from urllib.parse import urlsplit

try:
    from http.server import ThreadingHTTPServer
except ImportError:  # Python 3.6
    from http.server import HTTPServer

    class ThreadingHTTPServer(ThreadingMixIn, HTTPServer):
        daemon_threads = True

from gbp1 import encode_build

MAX_REQUEST_BYTES = 1_000_000
WEB_ROOT = Path(__file__).resolve().parent.parent
SLOT_FAMILIES = {
    "head": "armor", "shoulders": "armor", "chest": "armor",
    "hands": "armor", "waist": "armor", "legs": "armor", "feet": "armor",
    "neck": "jewelry", "ring1": "jewelry", "ring2": "jewelry",
    "frontMain": "weapon", "frontOff": "weapon",
    "backMain": "weapon", "backOff": "weapon",
}
VALID_TRAITS = {
    "armor": {11, 12, 13, 14, 15, 16, 17, 18, 19},
    "jewelry": {21, 22, 23, 30, 31, 32, 33, 34, 35},
    "weapon": {1, 2, 3, 4, 5, 6, 7, 8, 26},
}
VALID_WEAPONS = {1, 2, 3, 4, 5, 6, 8, 9, 11, 12, 13, 14, 15}
TWO_HANDED = {4, 5, 6, 8, 9, 12, 13, 15}


def validate_requirement(requirement, family, label):
    if not isinstance(requirement, dict):
        raise ValueError(f"{label} must be an object")
    trait = requirement.get("traitType")
    if trait is not None and trait not in VALID_TRAITS[family]:
        raise ValueError(f"{label} uses a trait from the wrong equipment family")
    if family == "armor":
        armor_type = requirement.get("armorType")
        if armor_type is not None and armor_type not in {1, 2, 3}:
            raise ValueError(f"{label} has an invalid armor weight")
        if "weaponType" in requirement:
            raise ValueError(f"{label} cannot use weaponType")
    elif family == "weapon":
        weapon_type = requirement.get("weaponType")
        if weapon_type is not None and weapon_type not in VALID_WEAPONS:
            raise ValueError(f"{label} has an invalid weapon type")
        if "armorType" in requirement:
            raise ValueError(f"{label} cannot use armorType")
    elif "armorType" in requirement or "weaponType" in requirement:
        raise ValueError(f"{label} cannot use an armor or weapon type")


def validate_example_build(build):
    """Apply website-level checks before the format encoder runs."""
    if not isinstance(build, dict):
        raise ValueError("build must be an object")
    setups = build.get("setups")
    if not isinstance(setups, list) or not 1 <= len(setups) <= 100:
        raise ValueError("a build requires between 1 and 100 setups")

    for setup_index, setup in enumerate(setups, 1):
        if not isinstance(setup, dict):
            raise ValueError(f"setup {setup_index} must be an object")
        equipment = setup.get("equipment") or {}
        if not isinstance(equipment, dict):
            raise ValueError(f"setup {setup_index} equipment must be an object")
        for slot, requirement in equipment.items():
            family = SLOT_FAMILIES.get(slot)
            if family is None:
                raise ValueError(f"setup {setup_index} contains an invalid equipment slot")
            validate_requirement(requirement, family, f"setup {setup_index} {slot}")

        alternatives = setup.get("alternatives") or {}
        if not isinstance(alternatives, dict):
            raise ValueError(f"setup {setup_index} alternatives must be an object")
        for slot, entries in alternatives.items():
            family = SLOT_FAMILIES.get(slot)
            if family is None or slot not in equipment:
                raise ValueError(f"setup {setup_index} alternatives require primary equipment")
            if not isinstance(entries, list) or len(entries) > 8:
                raise ValueError(f"setup {setup_index} {slot} alternatives are invalid")
            for alternative_index, requirement in enumerate(entries, 1):
                validate_requirement(
                    requirement, family,
                    f"setup {setup_index} {slot} alternative {alternative_index}",
                )

        for main_slot, off_slot in (("frontMain", "frontOff"), ("backMain", "backOff")):
            main_type = equipment.get(main_slot, {}).get("weaponType")
            if main_type in TWO_HANDED and off_slot in equipment:
                raise ValueError(f"{main_slot} is two-handed, so {off_slot} must be empty")

        attributes = (setup.get("character") or {}).get("attributes") or {}
        total = 0
        for name in ("health", "magicka", "stamina"):
            value = attributes.get(name, 0)
            if not isinstance(value, int) or isinstance(value, bool) or not 0 <= value <= 64:
                raise ValueError(f"setup {setup_index} has an invalid {name} attribute value")
            total += value
        if total > 64:
            raise ValueError(f"setup {setup_index} exceeds 64 attribute points")

    # encode_build performs the remaining format limits, required-value,
    # Champion uniqueness, slottable, checklist, and collection checks.


class ExampleHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if urlsplit(self.path).path == "/":
            self.send_response(302)
            self.send_header("Location", "/python/index.html?server=1")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        super().do_GET()

    def do_POST(self):
        if urlsplit(self.path).path != "/generate":
            self.send_json(404, {"error": "Not found"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if not 1 <= length <= MAX_REQUEST_BYTES:
                raise ValueError("request size is invalid")
            body = self.rfile.read(length)
            build_dict = json.loads(body.decode("utf-8"))
            validate_example_build(build_dict)
            self.send_json(200, {"code": encode_build(build_dict)})
        except (UnicodeDecodeError, json.JSONDecodeError, TypeError, ValueError) as error:
            self.send_json(422, {"error": str(error)})

    def send_json(self, status, value):
        body = json.dumps(value, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)


def main():
    parser = argparse.ArgumentParser(description="Run the complete GBP1 Python example")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8081)
    args = parser.parse_args()
    # Python 3.6's SimpleHTTPRequestHandler has no directory argument.
    os.chdir(str(WEB_ROOT))
    server = ThreadingHTTPServer((args.host, args.port), ExampleHandler)
    print(f"Build Planner Python example: http://{args.host}:{args.port}")
    print("Press Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
