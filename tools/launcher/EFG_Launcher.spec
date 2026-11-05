# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['efg_launcher.py'],
    pathex=['..'],
    binaries=[],
    datas=[('efg.ico', '.'), ('launcher.json', '.'), ('noticias.json', '.'), ('web', 'web'), ('../menu_gmod/efg_menu.css', 'menu_gmod'), ('../menu_gmod/main.html', 'menu_gmod'), ('C:/Users/Oscar/Documents/GitHub1/EFG/tools/launcher/../../content/resource/fonts/mbender.ttf', 'menu_gmod'), ('C:/Users/Oscar/Documents/GitHub1/EFG/tools/launcher/../../content/materials/efgui/logo32028.png', 'menu_gmod'), ('C:/Users/Oscar/Documents/GitHub1/EFG/tools/launcher/../../content/materials/efg/menu/main_art.jpg', 'menu_gmod')],
    hiddenimports=['parche_menu_gmod', 'efg_launcher_tk'],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='EFG_Launcher',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=['efg.ico'],
)
