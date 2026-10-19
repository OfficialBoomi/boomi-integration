#!/usr/bin/env python3
"""
Boomi Profile Inspection Tool

Extracts mappable field metadata from large Boomi profile files,
providing hierarchical paths to disambiguate duplicate field names.

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

FIELD_TAGS = {"XMLElement", "XMLAttribute",
              "EdiLoop", "EdiSegment", "EdiDataElement",
              "FlatFileRecord", "FlatFileElements", "FlatFileElement"}

JSON_TAGS = {"JSONRootValue", "JSONObject", "JSONObjectEntry", "JSONArray", "JSONArrayElement"}
# A JSON field is a value node with no object/array child
JSON_CONTAINER_TAGS = {"JSONObject", "JSONArray"}

# GUI JSON import truncates profiles at this many isMappable="true" nodes
JSON_NODE_LIMIT = 5000


def local_tag(element: ET.Element) -> str:
    return element.tag.split("}")[-1] if "}" in element.tag else element.tag


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
        if local_tag(child) in FIELD_TAGS:
            extract_fields(child, current_path, fields)

    return fields


def extract_json_nodes(element: ET.Element, path: str = "", array_keys: List[str] = None,
                       nodes: List[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
    """Walk every JSON node in document order, recording its path and enclosing array elements."""
    if array_keys is None:
        array_keys = []
    if nodes is None:
        nodes = []

    tag_name = local_tag(element)
    name = element.get("name", "")
    key = element.get("key", "")
    current_path = f"{path}/{name}" if path else name

    # Includes the node itself when it repeats
    if tag_name == "JSONArrayElement":
        array_keys = array_keys + [key]

    is_container = tag_name in JSON_CONTAINER_TAGS or any(
        local_tag(child) in JSON_CONTAINER_TAGS for child in element)

    node = {
        "key": key,
        "name": name,
        "path": current_path,
        "type": element.get("dataType", ""),
        "order": len(nodes),
        "isField": element.get("isMappable") == "true" and bool(name) and not is_container
    }
    if array_keys:
        node["arrayKeys"] = array_keys
    if tag_name == "JSONArrayElement":
        node["minOccurs"] = int(element.get("minOccurs", "0"))
        node["maxOccurs"] = int(element.get("maxOccurs", "-1"))
    nodes.append(node)

    for child in element:
        if local_tag(child) in JSON_TAGS:
            extract_json_nodes(child, current_path, array_keys, nodes)

    return nodes


def parse_expression(element: ET.Element, node_paths: Dict[str, str]) -> Dict[str, Any]:
    if local_tag(element) == "TagExpression":
        identifier_key = element.get("identifierKey", "")
        expression = {
            "identifierName": element.get("identifierName", ""),
            "identifierType": element.get("identifierType", ""),
            "identifierKey": identifier_key,
            "identifierValues": [v.text or "" for v in element if local_tag(v) == "identifierValue"]
        }
        if identifier_key in node_paths:
            expression["identifierPath"] = node_paths[identifier_key]
        if element.get("operator"):
            expression["operator"] = element.get("operator")
        return expression

    return {
        "operator": element.get("operator", ""),
        "expressions": [parse_expression(child, node_paths) for child in element
                        if local_tag(child) in ("TagExpression", "GroupingExpression")]
    }


def extract_tag_lists(profile_element: ET.Element, node_paths: Dict[str, str]) -> List[Dict[str, Any]]:
    tag_lists_element = profile_element.find("tagLists")
    if tag_lists_element is None:
        return []

    tag_lists = []
    for tag_list in tag_lists_element:
        if local_tag(tag_list) != "TagList":
            continue
        entry = {"listKey": tag_list.get("listKey", "")}
        element_key = tag_list.get("elementKey")
        if element_key:
            entry["elementKey"] = element_key
            if element_key in node_paths:
                entry["elementPath"] = node_paths[element_key]
        # Listed as-is; the composite parentListKey/refListKey form is not interpreted
        for attr in ("parentListKey", "refListKey"):
            if tag_list.get(attr, "-1") != "-1":
                entry[attr] = tag_list.get(attr)
        grouping = tag_list.find("GroupingExpression")
        if grouping is not None:
            entry["expression"] = parse_expression(grouping, node_paths)
        tag_lists.append(entry)

    return tag_lists


def parse_json_profile(profile_element: ET.Element, data_elements: ET.Element,
                       include_all: bool) -> Dict[str, Any]:
    nodes = []
    for child in data_elements:
        if local_tag(child) in JSON_TAGS:
            extract_json_nodes(child, "", None, nodes)

    fields = []
    for node in nodes:
        if not (include_all or node["isField"]):
            continue
        field = {k: v for k, v in node.items() if k != "isField"}
        if include_all and not node["isField"]:
            field["field"] = False
        fields.append(field)

    tag_lists = extract_tag_lists(profile_element, {n["key"]: n["path"] for n in nodes if n["key"]})

    truncation_warning = None
    mappable = [el for el in data_elements.iter() if el.get("isMappable") == "true"]
    if len(mappable) == JSON_NODE_LIMIT:
        last = mappable[-1]
        truncation_warning = (
            f"WARNING: Profile has exactly {JSON_NODE_LIMIT} mappable nodes, the GUI JSON import limit. "
            f"It was likely truncated on GUI import; fields after the last node kept "
            f"(key {last.get('key', '')}, name '{last.get('name', '')}') are missing."
        )

    return {"fields": fields, "tagLists": tag_lists, "truncationWarning": truncation_warning}


def parse_xml_profile(file_path: Path, include_all: bool = False) -> Dict[str, Any]:
    tree = ET.parse(file_path)
    root = tree.getroot()

    profile_id = root.get("componentId", "")
    profile_name = root.get("name", "")
    profile_type = root.get("type", "")

    profile_element = None
    for ptype in ["XMLProfile", "EdiProfile", "FlatFileProfile", "JSONProfile"]:
        profile_element = root.find(f".//{ptype}")
        if profile_element is not None:
            break

    if profile_element is None:
        raise ValueError(f"No supported profile type found in {file_path}")

    data_elements = profile_element.find("DataElements")
    if data_elements is None:
        raise ValueError(f"No DataElements found in profile")

    result = {
        "profile": {"id": profile_id, "name": profile_name, "type": profile_type},
        "isJson": local_tag(profile_element) == "JSONProfile",
        "tagLists": [],
        "truncationWarning": None
    }

    if result["isJson"]:
        result.update(parse_json_profile(profile_element, data_elements, include_all))
    else:
        fields = []
        for child in data_elements:
            if local_tag(child) in FIELD_TAGS:
                extract_fields(child, "", fields)
        result["fields"] = fields

    result["fieldCount"] = len(result["fields"])
    return result


def resolve_path(file_path_str: str) -> Path:
    """Resolve a component file path (absolute or relative to cwd)."""
    path = Path(file_path_str)
    if path.is_absolute():
        return path
    cwd_path = Path.cwd() / file_path_str
    if cwd_path.exists():
        return cwd_path
    return cwd_path


USAGE = """Usage: python3 scripts/boomi-profile-inspect.py <profile_path> [--all]

Writes a searchable field inventory of an XML, EDI, Flat File, or JSON profile.

Required:
  <profile_path>   Profile component XML (absolute, or relative to the current directory)

Options:
  --all            JSON profiles only: also list container nodes, written to
                   distilled_<ProfileName>_all.json

Side effects: writes distilled_<ProfileName>.json next to the source profile XML."""


def main():
    args = sys.argv[1:]
    if "--help" in args or "-h" in args:
        print(USAGE)
        sys.exit(0)

    include_all = "--all" in args
    positional = [a for a in args if a != "--all"]

    if len(positional) < 1:
        print(USAGE)
        sys.exit(1)

    profile_path = resolve_path(positional[0])

    if not profile_path.exists():
        print(f"ERROR: Profile not found: {profile_path}")
        sys.exit(1)

    try:
        result = parse_xml_profile(profile_path, include_all)

        compact_fields = [{k: v for k, v in f.items() if k != "comments" and (k != "purpose" or v)}
                          for f in result["fields"]]

        compact_result = {
            "profile": result["profile"],
            "fieldCount": len(compact_fields),
            "fields": compact_fields
        }
        if result["tagLists"]:
            compact_result["tagLists"] = result["tagLists"]

        # Output sits next to the source profile XML — same folder, regardless of profile sub-type
        profile_name = result["profile"]["name"]
        safe_name = re.sub(r'[<>:"/\\|?*]', '_', profile_name).strip('. ')
        all_suffix = "_all" if include_all and result["isJson"] else ""
        output_path = profile_path.parent / f"distilled_{safe_name}{all_suffix}.json"

        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(compact_result, f, indent=2)

        if include_all and not result["isJson"]:
            print("NOTE: --all applies to JSON profiles only; ignored for this profile")
        noun = "nodes" if all_suffix else "fields"
        tag_list_note = f" and {len(result['tagLists'])} tagLists" if result["tagLists"] else ""
        print(f"Extracted {compact_result['fieldCount']} {noun}{tag_list_note} from '{profile_name}'")
        print(f"Output: {output_path}")
        if result["truncationWarning"]:
            print(result["truncationWarning"])
        sys.exit(0)

    except Exception as e:
        print(f"ERROR: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
