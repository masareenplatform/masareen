from pathlib import Path

root = Path('lib')
changed = 0
for p in root.rglob('*.dart'):
    s = p.read_text(encoding='utf-8')
    if 'GestureDetector(' not in s:
        continue
    s = s.replace('GestureDetector(', 'Clickable(')
    if p.name != 'widgets.dart' and "import 'package:masaren/widgets.dart';" not in s:
        lines = s.splitlines()
        insert_at = 0
        for i, line in enumerate(lines):
            if line.startswith('import '):
                insert_at = i + 1
        lines.insert(insert_at, "import 'package:masaren/widgets.dart';")
        s = '\n'.join(lines) + ('\n' if s.endswith('\n') else '')
    p.write_text(s, encoding='utf-8')
    changed += 1
print('changed', changed)
