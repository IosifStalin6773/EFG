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
    return {'file': os.path.basename(path), 'seqs': seqs, 'cd': cd, 'tex': tex, 'skins': skins}
out = [info(p) for p in sys.argv[1:]]
print(json.dumps(out, indent=1))
