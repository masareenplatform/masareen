from pathlib import Path
import re

root = Path('lib')
files = list(root.rglob('*.dart'))
changed = 0
inserted = 0
for p in files:
    s = p.read_text(encoding='utf-8')
    out = []
    i = 0
    local = 0
    while True:
        j = s.find('GestureDetector(', i)
        if j < 0:
            out.append(s[i:])
            break
        out.append(s[i:j + len('GestureDetector(')])
        line_start = s.rfind('\n', 0, j) + 1
        indent = re.match(r'\s*', s[line_start:j]).group(0)
        look = s[j:j + 700]
        if ('mouseCursor:' not in look and
                re.search(r'onTap:|onLongPress:|onDoubleTap:', look)):
            out.append('\n' + indent + '  mouseCursor: SystemMouseCursors.click,')
            local += 1
        i = j + len('GestureDetector(')
    if local:
        changed += 1
        inserted += local
        p.write_text(''.join(out), encoding='utf-8')
print('files', changed, 'inserted', inserted)

