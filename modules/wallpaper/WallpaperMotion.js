.pragma library

function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value))
}

function smoothstep(start, end, value) {
    const t = clamp((value - start) / (end - start), 0, 1)
    return t * t * (3 - 2 * t)
}

// A continuous, non-overlapping filmstrip: focus opens a wider slot rather than
// scaling over its neighbours. Fractional positions make dragging truly direct.
function card(distance, baseWidth, heroWidth, heroHeight, gap) {
    const absolute = Math.abs(distance)
    const focus = Math.max(0, 1 - absolute)
    const width = baseWidth + (heroWidth - baseWidth) * focus
    return {
        offset: distance * (baseWidth + gap)
            + Math.sign(distance) * (heroWidth - baseWidth) * 0.5 * Math.min(absolute, 1),
        width: width,
        height: heroHeight * (1 - 0.19 * Math.min(absolute / 4, 1)),
        opacity: 1 - 0.36 * Math.min(absolute / 5, 1),
        focus: focus,
    }
}

function windowStart(position, count, slots) {
    return clamp(Math.floor(position) - Math.floor(slots / 2), 0, Math.max(0, count - slots))
}

// A recycled ring, not a sliding array: advancing by one changes exactly one
// image source. The other GPU textures stay attached to the same delegates.
function slotIndex(slot, start, slots) {
    return slots ? start + ((slot - start) % slots + slots) % slots : -1
}

function filter(entries, query) {
    const needle = query.trim().toLocaleLowerCase()
    return needle ? entries.filter(entry => entry.relative.toLocaleLowerCase().includes(needle)) : entries
}
