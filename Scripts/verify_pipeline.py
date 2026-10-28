#!/usr/bin/env python3
import os
import sys
import re

def test_conversion_matrix():
    print("Testing Conversion Matrix logic...")
    # Check ConversionMatrix.swift
    cm_path = "Sources/Models/ConversionMatrix.swift"
    assert os.path.exists(cm_path), f"Missing {cm_path}"
    with open(cm_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Document must not contain JPG or PNG targets
    doc_block = re.search(r'case \.document:(.*?)(case|\z)', content, re.DOTALL)
    assert doc_block, "Could not find case .document in ConversionMatrix.swift"
    doc_text = doc_block.group(1)
    assert '"JPG"' not in doc_text, "Document targets must not allow JPG"
    assert '"PNG"' not in doc_text, "Document targets must not allow PNG"
    print("  ✓ Document conversion correctly blocks JPG/PNG")

    # Image targets must include PNG, WEBP, HEIC
    img_block = re.search(r'case \.image:(.*?)(case|\z)', content, re.DOTALL)
    assert img_block, "Could not find case .image in ConversionMatrix.swift"
    img_text = img_block.group(1)
    for fmt in ["PNG", "WEBP", "HEIC", "TIFF"]:
        assert f'"{fmt}"' in img_text, f"Image targets must include {fmt}"
    print("  ✓ Image conversion supports standard formats")

def test_no_paywalls_or_limits():
    print("Testing for absence of trial code or paywalls...")
    for root, dirs, files in os.walk("Sources"):
        for file in files:
            if file.endswith(".swift"):
                path = os.path.join(root, file)
                with open(path, "r", encoding="utf-8") as f:
                    data = f.read().lower()
                    assert "20 times" not in data, f"Found trial reference in {path}"
                    assert "trialexpired" not in data, f"Found trial reference in {path}"
                    assert "paywall" not in data, f"Found paywall reference in {path}"
    print("  ✓ Confirmed 100% unlocked full version (no trial limitations)")

def test_resources_integrity():
    print("Testing essential resource files...")
    required = [
        "Resources/AppIcon.icns",
        "Resources/HighlightSound.wav",
        "Resources/MenuBarIcon.png",
        "Resources/ExifTool/tangerine_metadata.pl",
        "Package.swift",
        "Scripts/build_app.sh"
    ]
    for r in required:
        assert os.path.exists(r), f"Missing required resource: {r}"
        assert os.path.getsize(r) > 0, f"Empty file: {r}"
    print("  ✓ All required offline assets and tools exist and are valid")

def main():
    print("🍊 Tangerine CI Pipeline Validator")
    print("=" * 40)
    try:
        test_conversion_matrix()
        test_no_paywalls_or_limits()
        test_resources_integrity()
        print("=" * 40)
        print("🎉 All pipeline verification checks passed successfully!")
        return 0
    except AssertionError as e:
        print(f"❌ Verification failed: {e}", file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())
