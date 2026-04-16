# LAWVM - Artifact Format v1

LAWVM artifact format v1 is a minimal deterministic Tier-0 artifact package.

## Layout

artifact_root/
- artifact.json
- payload/
  - law.txt

## artifact.json fields

- schema
- artifact_type
- stamp_utc
- payload_relpath
- payload_sha256

## Rules

- artifact.json must exist
- payload file referenced by payload_relpath must exist
- payload_sha256 must equal the SHA-256 of the payload file bytes
- schema must equal lawvm.artifact.v1
- artifact_type must equal machine_law_bundle
