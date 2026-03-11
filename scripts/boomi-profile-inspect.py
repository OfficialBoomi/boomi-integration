#!/usr/bin/env python3
"""
Boomi Profile Inspection Tool

Extracts mappable field metadata from large Boomi profile files,
providing hierarchical paths to disambiguate duplicate field names.

Supports: XML, EDI, and Flat File profiles.

Output: JSON inventory with element IDs and full paths for each field.

Note: This is the one tool that remains Python — recursive XML tree
walking is awkward in bash. It uses only stdlib (no pip dependencies).
"""

import sys
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import List, Dict, Any


def extract_fields(element: ET.Element, path: str = "", fields: List[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
    if fields is None:
        fields = []

    name = element.get("name", "")
    key = element.get("key", "")
    current_path = f"{path}/{name}" if path else name

    if element.get("isMappable") == "true" and name:
        fields.append({
            "key": key,
            "name": name,
            "path": current_path,
            "type": element.get("dataType", ""),
            "purpose": element.get("elementPurpose", ""),
            "comments": element.get("comments", "")
        })

    for child in element:
        tag_name = child.tag.split("}")[-1] if "}" in child.tag else child.tag
        if tag_name in ["XMLElement", "XMLAttribute",
                        "EdiLoop", "EdiSegment", "EdiDataElement",
                        "FlatFileRecord", "FlatFileElements", "FlatFileElement"]:
            extract_fields(child, current_path, fields)

    return fields


def parse_xml_profile(file_path: Path) -> Dict[str, Any]:
    tree = ET.parse(file_path)
    root = tree.getroot()

    profile_id = root.get("componentId", "")
    profile_name = root.get("name", "")
    profile_type = root.get("type", "")

    profile_element = None
    for ptype in ["XMLProfile", "EdiProfile", "FlatFileProfile"]:
        profile_element = root.find(f".//{ptype}")
        if profile_element is not None:
            break

    if profile_element is None:
        raise ValueError(f"No supported profile type found in {file_path}")

    data_elements = profile_element.find("DataElements")
    if data_elements is None:
        raise ValueError(f"No DataElements found in profile")

    fields = []
    for child in data_elements:
        tag_name = child.tag.split("}")[-1] if "}" in child.tag else child.tag
        if tag_name in ["XMLElement", "XMLAttribute",
                        "EdiLoop", "EdiSegment", "EdiDataElement",
                        "FlatFileRecord", "FlatFileElements", "FlatFileElement"]:
            extract_fields(child, "", fields)

    return {
        "profile": {"id": profile_id, "name": profile_name, "type": profile_type},
        "fieldCount": len(fields),
        "fields": fields
    }


def resolve_path(file_path_str: str) -> Path:
    """Resolve a component file path (absolute or relative to cwd)."""
    path = Path(file_path_str)
    if path.is_absolute():
        return path
    cwd_path = Path.cwd() / file_path_str
    if cwd_path.exists():
        return cwd_path
    return cwd_path


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/boomi-profile-inspect.py <profile_path>")
        sys.exit(1)

    profile_path = resolve_path(sys.argv[1])

    if not profile_path.exists():
        print(f"ERROR: Profile not found: {profile_path}")
        sys.exit(1)

    try:
        result = parse_xml_profile(profile_path)

        compact_fields = []
        for f in result["fields"]:
            entry = {"key": f["key"], "name": f["name"], "path": f["path"], "type": f["type"]}
            if f.get("purpose"):
                entry["purpose"] = f["purpose"]
            compact_fields.append(entry)

        compact_result = {
            "profile": result["profile"],
            "fieldCount": len(compact_fields),
            "fields": compact_fields
        }

        # Output to active-development/profiles/distilled_<name>.json
        profile_name = result["profile"]["name"]
        safe_name = re.sub(r'[<>:"/\\|?*]', '_', profile_name).strip('. ')
        profiles_dir = Path.cwd() / "active-development" / "profiles"
        profiles_dir.mkdir(parents=True, exist_ok=True)
        output_path = profiles_dir / f"distilled_{safe_name}.json"

        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(compact_result, f, indent=2)

        print(f"Extracted {compact_result['fieldCount']} fields from '{profile_name}'")
        print(f"Output: {output_path}")
        sys.exit(0)

    except Exception as e:
        print(f"ERROR: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
