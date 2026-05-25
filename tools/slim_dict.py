#!/usr/bin/env python3
"""Slim down the dictionary TSV - keep just word and core definition."""
import re
import os

input_path = os.path.join(os.path.dirname(__file__), "..", "assets", "deu_eng_dict.tsv")
output_path = os.path.join(os.path.dirname(__file__), "..", "assets", "deu_eng_dict.tsv")

entries = []
seen = set()

with open(input_path, 'r', encoding='utf-8') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        parts = line.split('\t', 1)
        if len(parts) != 2:
            continue
        word, definition = parts
        word = word.strip()
        
        # Skip multi-word phrases (more than 4 words) to keep it manageable
        if len(word.split()) > 4:
            continue
        
        # Clean definition: extract just the English translation
        # Pattern: … word /pronunciation/ <pos> | translation | Notes...
        # We want just the translation part
        
        # Remove leading "… " or "…"
        definition = re.sub(r'^…\s*', '', definition)
        
        # Remove the German headword echo at start (everything up to first /)
        # Extract parts separated by |
        parts_def = [p.strip() for p in definition.split('|')]
        
        # Filter out Note:, Synonym:, see:, Antonym: parts
        translations = []
        for p in parts_def:
            if re.match(r'(Note|Synonym|see|Antonym|Hypernym|Hyponym)s?:', p, re.IGNORECASE):
                continue
            # Remove pronunciation /.../ 
            p = re.sub(r'/[^/]+/', '', p)
            # Remove <pos> tags
            p = re.sub(r'<[^>]+>', '', p)
            # Remove "… " prefix
            p = re.sub(r'^…\s*', '', p)
            p = p.strip()
            if p and not p.startswith('{'):
                translations.append(p)
        
        if not translations:
            continue
        
        # Take first 2 translations max
        clean_def = '; '.join(translations[:2])
        
        # Normalize word to lowercase for dedup
        word_lower = word.lower().strip()
        if word_lower in seen:
            continue
        seen.add(word_lower)
        
        if word_lower and clean_def:
            entries.append(f"{word_lower}\t{clean_def}")

print(f"Slimmed to {len(entries)} entries")

with open(output_path, 'w', encoding='utf-8') as f:
    for e in sorted(entries):
        f.write(e + '\n')

size_mb = os.path.getsize(output_path) / (1024*1024)
print(f"File size: {size_mb:.2f} MB")
