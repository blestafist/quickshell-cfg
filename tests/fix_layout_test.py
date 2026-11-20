import runpy
from pathlib import Path

convert = runpy.run_path(Path(__file__).resolve().parents[1] / 'scripts/fix-layout.py')['convert']
for latin, russian in [('ghbdtn', 'привет'), ('Ghbdtn, Vbh!', 'Приветб Мир!'),
                       ('`~ [}{] ;:\'"', 'ёЁ хЪХъ жЖэЭ'), ('Vbh/\n123 😀', 'Мир.\n123 😀')]:
    assert convert(latin) == russian
    assert convert(russian) == latin
