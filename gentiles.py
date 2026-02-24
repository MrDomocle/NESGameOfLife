def tile(t, i):
    if (i == 0): return [t]
    nt0 = t.copy()
    nt0.append(0)
    nt1 = t.copy()
    nt1.append(1)
    return [*tile(nt0, i-1), *tile(nt1, i-1)]
    
with open("gol.chr", "wb") as f:
    for t in tile([],4):
        print(t)
        b1 = t[1]*240+t[0]*15
        b2 = t[2]*240+t[3]*15
        
        f.write(b1.to_bytes(1))
        f.write(b1.to_bytes(1))
        f.write(b1.to_bytes(1))
        f.write(b1.to_bytes(1))
        f.write(b2.to_bytes(1))
        f.write(b2.to_bytes(1))
        f.write(b2.to_bytes(1))
        f.write(b2.to_bytes(1))
        f.write((0).to_bytes(1))
        f.write((0).to_bytes(1))
        f.write((0).to_bytes(1))
        f.write((0).to_bytes(1))
        f.write((0).to_bytes(1))
        f.write((0).to_bytes(1))
        f.write((0).to_bytes(1))
        f.write((0).to_bytes(1))
        
            
    