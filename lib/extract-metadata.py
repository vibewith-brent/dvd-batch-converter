#!/usr/bin/env python3
# /// script
# dependencies = ["lxml"]
# ///

"""
Extract metadata from Yesvideo DiscMetaData.xml files.
Handles UTF-16 encoding and extracts title, order ID, brand, etc.
"""

import sys
from pathlib import Path
from lxml import etree


def extract_metadata(xml_path: str) -> dict:
    """
    Extract title and other metadata from DiscMetaData.xml (UTF-16).

    Args:
        xml_path: Path to DiscMetaData.xml file

    Returns:
        dict with keys: title, author, order_id, brand, theme
    """
    try:
        # Parse UTF-16 XML
        parser = etree.XMLParser(encoding='utf-16')
        tree = etree.parse(xml_path, parser)
        root = tree.getroot()

        # Extract fields from INFO element
        info_elem = root.find('.//INFO')

        metadata = {
            'title': info_elem.get('TITLE', 'Unknown') if info_elem is not None else 'Unknown',
            'author': info_elem.get('AUTHOR', '') if info_elem is not None else '',
            'description': info_elem.get('DESCRIPTION', '') if info_elem is not None else '',
            'order_id': root.get('ORDERID', ''),
            'disc_id': root.get('DISCID', ''),
            'brand': root.get('BRAND', ''),
            'theme': root.get('THEME', ''),
        }

        return metadata

    except FileNotFoundError:
        print(f"Error: File not found: {xml_path}", file=sys.stderr)
        return {'title': 'Unknown'}
    except Exception as e:
        print(f"Error parsing XML: {e}", file=sys.stderr)
        return {'title': 'Unknown'}


def sanitize_filename(name: str, max_length: int = 50) -> str:
    """
    Sanitize string for use in Windows-compatible filename.

    Args:
        name: String to sanitize
        max_length: Maximum length of resulting string

    Returns:
        Sanitized string safe for Windows filenames
    """
    # Remove/replace Windows-forbidden characters: : * ? " < > |
    forbidden_chars = ':*?"<>|'
    for char in forbidden_chars:
        name = name.replace(char, '')

    # Replace spaces with underscores
    name = name.replace(' ', '_')

    # Remove any other non-ASCII or problematic characters
    name = ''.join(c for c in name if c.isalnum() or c in '_-')

    # Truncate to max length
    if len(name) > max_length:
        name = name[:max_length]

    # Ensure not empty
    if not name:
        name = 'Unknown'

    return name


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: extract-metadata.py <path-to-DiscMetaData.xml> [--sanitize]")
        print("  Output: title only (for bash consumption)")
        print("  --sanitize: Output sanitized version safe for filenames")
        sys.exit(1)

    xml_path = sys.argv[1]
    sanitize = '--sanitize' in sys.argv

    metadata = extract_metadata(xml_path)
    title = metadata['title']

    if sanitize:
        title = sanitize_filename(title)

    # Output only title for bash consumption
    print(title)
