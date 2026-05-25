#!/usr/bin/env python3
"""Convert FreeDict dictd .tar.xz to TSV for the German learning app."""
import lzma
import tarfile
import re
import io
import os

archive_path = os.path.join(os.path.dirname(__file__), "deu-eng-dictd.tar.xz")
output_path = os.path.join(os.path.dirname(__file__), "..", "assets", "deu_eng_dict.tsv")

os.makedirs(os.path.dirname(output_path), exist_ok=True)

# Open the .tar.xz
with lzma.open(archive_path) as xz:
    with tarfile.open(fileobj=io.BytesIO(xz.read())) as tar:
        # Find the .dict.dz or .dict file
        dict_file = None
        index_file = None
        for m in tar.getmembers():
            if m.name.endswith('.index'):
                index_file = m
            if m.name.endswith('.dict') or m.name.endswith('.dict.dz'):
                dict_file = m
        
        print(f"Index: {index_file.name if index_file else 'not found'}")
        print(f"Dict:  {dict_file.name if dict_file else 'not found'}")
        
        if not index_file or not dict_file:
            raise RuntimeError("Could not find index or dict file in archive")
        
        # Read the dict file
        dict_data_raw = tar.extractfile(dict_file).read()
        
        # If it's .dict.dz, decompress with gzip
        if dict_file.name.endswith('.dz'):
            import gzip
            dict_data = gzip.decompress(dict_data_raw)
        else:
            dict_data = dict_data_raw
        
        # Read the index file - format: word\toffset\tlen (base64-encoded offset and len)
        index_data = tar.extractfile(index_file).read().decode('utf-8')
        
        def b64_to_int(s):
            """Convert dictd base64 encoding to integer."""
            chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
            result = 0
            for c in s:
                result = result * 64 + chars.index(c)
            return result
        
        entries = []
        for line in index_data.strip().split('\n'):
            parts = line.split('\t')
            if len(parts) != 3:
                continue
            word = parts[0]
            offset = b64_to_int(parts[1])
            length = b64_to_int(parts[2])
            
            definition = dict_data[offset:offset+length].decode('utf-8', errors='replace')
            # Clean up the definition - remove the headword line and extra whitespace
            lines = definition.strip().split('\n')
            # Skip first line if it's just the headword
            if lines and lines[0].strip().lower() == word.lower():
                lines = lines[1:]
            # Join remaining lines, replace tabs and newlines for TSV
            clean_def = ' | '.join(l.strip() for l in lines if l.strip())
            # Remove any tab characters
            clean_def = clean_def.replace('\t', ' ')
            word_clean = word.replace('\t', ' ')
            
            if word_clean and clean_def:
                entries.append(f"{word_clean}\t{clean_def}")
        
        print(f"Parsed {len(entries)} entries")
        
        with open(output_path, 'w', encoding='utf-8') as f:
            for e in entries:
                f.write(e + '\n')
        
        print(f"Written to {output_path}")
