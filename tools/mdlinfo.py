import struct, sys, os, json
def cstr(b, o):
    e = b.index(b'\0', o); return b[o:e].decode('latin1')
def info(path):
    b = open(path, 'rb').read()
    # studiohdr_t
    name = b[12:76].split(b'\0')[0].decode('latin1')
    o = 76 + 4  # length
    o += 12*6   # eyepos illum hullmin hullmax viewbbmin viewbbmax
    o += 4      # flags
    numbones, boneindex, numbonecontrollers, bonecontrollerindex, numhitboxsets, hitboxsetindex, \
    numlocalanim, localanimindex, numlocalseq, localseqindex, activitylistversion, eventsindexed, \
    numtextures, textureindex, numcdtextures, cdtextureindex, numskinref, numskinfamilies, skinindex = struct.unpack_from('<19i', b, o)
    seqs = []
    for i in range(numlocalseq):
        s = localseqindex + i * 212
        szlabel, szact, flags, activity, actweight, numevents, eventindex = struct.unpack_from('<7i', b, s + 4)
        fps = None
        # events
        ev = []
        for e in range(numevents):
            eo = s + eventindex + e * 80
            cycle, event, typ = struct.unpack_from('<fii', b, eo)
            opts = b[eo+12:eo+76].split(b'\0')[0].decode('latin1')
            szev, = struct.unpack_from('<i', b, eo + 76)
            evname = cstr(b, eo + szev) if szev else ''
            ev.append((round(cycle, 3), event, evname, opts))
        seqs.append({'label': cstr(b, s + szlabel), 'act': cstr(b, s + szact), 'events': ev})
    tex = []
    for i in range(numtextures):
        t = textureindex + i * 64
        tex.append(cstr(b, t + struct.unpack_from('<i', b, t)[0]))
    cd = [cstr(b, struct.unpack_from('<i', b, cdtextureindex + i*4)[0]) for i in range(numcdtextures)]
    skins = []
    for f in range(numskinfamilies):
        row = struct.unpack_from('<%dh' % numskinref, b, skinindex + f * numskinref * 2)
        skins.append([tex[r] for r in row])
    # bodyparts (bodygroups): numbodyparts y bodypartindex van justo tras skinindex
    numbodyparts, bodypartindex = struct.unpack_from('<2i', b, o + 19 * 4)
    bodygroups = []
    for i in range(numbodyparts):
        bp = bodypartindex + i * 16  # mstudiobodyparts_t: sznameindex, nummodels, base, modelindex
        nameoff, nummodels, _base, modelindex = struct.unpack_from('<4i', b, bp)
        models = []
        for m in range(nummodels):
            mo = bp + modelindex + m * 148  # mstudiomodel_t: name[64] al inicio, tamaño 148
            models.append(b[mo:mo + 64].split(b'\0')[0].decode('latin1'))
        bodygroups.append({'name': cstr(b, bp + nameoff), 'models': models})
    return {'file': os.path.basename(path), 'seqs': seqs, 'cd': cd, 'tex': tex, 'skins': skins, 'bodygroups': bodygroups}

# Uso: python tools/mdlinfo.py <carpeta_o_archivo.mdl> [...]
# Vuelca secuencias, texturas, skins y bodygroups (bodyparts con sus submodelos).
# Una carpeta se recorre entera (recursivo) buscando .mdl. Salida JSON por stdout.
def find_mdl(arg):
    if os.path.isdir(arg):
        for root, _, files in os.walk(arg):
            for f in sorted(files):
                if f.lower().endswith('.mdl'):
                    yield os.path.join(root, f)
    else:
        yield arg

if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit('Uso: python tools/mdlinfo.py <carpeta_o_archivo.mdl> [...]')
    paths = [p for arg in sys.argv[1:] for p in find_mdl(arg)]
    out = [info(p) for p in paths]
    print(json.dumps(out, indent=1))
