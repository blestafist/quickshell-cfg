.pragma library

function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value))
}

function smoothstep(start, end, value) {
    const t = clamp((value - start) / (end - start), 0, 1)
    return t * t * (3 - 2 * t)
}

// Exact damped-spring integration: the trajectory does not depend on refresh
// rate, and changing the target preserves both position and velocity.
function spring(position, velocity, target, seconds, frequency, damping) {
    const displacement = position - target
    const decay = Math.exp(-damping * frequency * seconds)
    let nextPosition
    let nextVelocity
    if (damping < 1) {
        const dampedFrequency = frequency * Math.sqrt(1 - damping * damping)
        const phase = dampedFrequency * seconds
        const sine = Math.sin(phase)
        const cosine = Math.cos(phase)
        const coefficient = (velocity + damping * frequency * displacement) / dampedFrequency
        nextPosition = target + decay * (displacement * cosine + coefficient * sine)
        nextVelocity = decay * (velocity * cosine
            - (damping * frequency * velocity + frequency * frequency * displacement) / dampedFrequency * sine)
    } else {
        const coefficient = velocity + frequency * displacement
        nextPosition = target + (displacement + coefficient * seconds) * decay
        nextVelocity = (velocity - frequency * coefficient * seconds) * decay
    }
    return { position: nextPosition, velocity: nextVelocity }
}

function settled(position, velocity, target) {
    return Math.abs(position - target) < 0.0008 && Math.abs(velocity) < 0.012
}

// The crown grows before the shoulders. While they catch up, a narrower neck
// and rounder crown turn the silhouette into a bead rather than a scaled box.
function geometry(width, height, inset, rise, spread) {
    const progress = clamp(spread, 0, 1)
    const center = width / 2
    const fullHalf = Math.max(0, center - inset)
    const seedHalf = Math.min(14, fullHalf)
    const half = Math.min(Math.max(0, center - 4),
        seedHalf + (fullHalf - seedHalf) * clamp(spread, 0, 1.025))
    const visibleHeight = height * clamp(rise, 0, 1.08)
    const neck = half * (0.52 + 0.48 * smoothstep(0.18, 1, progress))
    const join = Math.max(0, Math.min(inset, visibleHeight * 0.45, center - neck))
    const radius = Math.max(0, Math.min(half, visibleHeight * 0.48,
        36 + half * (1 - progress) * 0.65))
    const top = height - visibleHeight
    const sideLength = Math.max(0, visibleHeight - radius - join)
    return {
        center: center,
        top: top,
        bottom: height,
        left: center - half,
        right: center + half,
        radius: radius,
        neckLeft: center - neck,
        neckRight: center + neck,
        join: join,
        sideLength: sideLength,
        clipWidth: Math.min(fullHalf * 2, neck * 2),
    }
}
