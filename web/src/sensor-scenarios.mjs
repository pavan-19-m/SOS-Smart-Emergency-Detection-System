const G = 9.80665;

function noise(index, axis = 0) {
  // Small deterministic bounded noise makes recordings repeatable.
  return Math.sin(index * 12.9898 + axis * 78.233) * 0.12;
}

function gait(index, hz, amplitude, axis = 0) {
  const t = index / 50;
  const phase = 2 * Math.PI * hz * t;
  return {
    ax: amplitude * Math.sin(phase) + noise(index, 0),
    ay: amplitude * 0.25 * Math.cos(phase + 0.7) + noise(index, 1),
    az: G + amplitude * 0.35 * Math.sin(phase + 1.1) + noise(index, 2),
    gx: 0.24 * Math.sin(phase + axis) + noise(index, 3) * 0.2,
    gy: 0.48 * Math.cos(phase * 0.5) + noise(index, 4) * 0.2,
    gz: 0.3 * Math.sin(phase * 0.7) + noise(index, 5) * 0.2,
  };
}

export const SCENARIOS = [
  { id: 'walking', label: 'Normal walking', description: 'Steady 2 Hz gait with bounded movement and rotation.' },
  { id: 'running', label: 'Running', description: 'Faster 3 Hz gait with stronger but bounded acceleration.' },
  { id: 'sudden', label: 'Sudden movement', description: 'Short movement burst over an otherwise steady gait.' },
  { id: 'impact', label: 'Impact-like event', description: 'Brief high-g sample followed by low motion; a test signal, not a crash.' },
  { id: 'fall', label: 'Fall-like sequence', description: 'Brief low-g interval, impact-like sample, orientation change and quiet tail.' },
  { id: 'stationary', label: 'Stationary', description: 'Gravity with low bounded sensor noise.' },
  { id: 'irregular', label: 'Irregular movement', description: 'Bounded multi-frequency motion and rotation.' },
  { id: 'random', label: 'Random movement', description: 'Repeatable bounded pseudo-random motion for repeatable tests.' },
  { id: 'custom', label: 'Custom input', description: 'Repeat the six axis values configured below.' },
];

export function sampleScenario(id, index, custom = {}) {
  const cycle = index % 256;
  if (id === 'walking') return gait(index, 2, 1.25);
  if (id === 'running') return gait(index, 3, 2.7);
  if (id === 'sudden') {
    const base = gait(index, 1.8, 1.0);
    if (cycle >= 96 && cycle < 102) return { ax: base.ax + 3.4 * G, ay: base.ay + 1.1, az: base.az, gx: 5.2, gy: base.gy, gz: 2.3 };
    return base;
  }
  if (id === 'impact') {
    if (cycle >= 96 && cycle < 98) return { ax: 0.4, ay: -0.8, az: 3.2 * G, gx: 5.4, gy: 1.6, gz: 2.0 };
    if (cycle >= 98 && cycle < 180) return { ax: G + noise(index, 0), ay: noise(index, 1), az: noise(index, 2), gx: noise(index, 3) * 0.2, gy: noise(index, 4) * 0.2, gz: noise(index, 5) * 0.2 };
    return gait(index, 1.8, 0.85);
  }
  if (id === 'fall') {
    if (cycle < 28) return { ax: noise(index, 0), ay: noise(index, 1), az: 0.3 * G + noise(index, 2), gx: 0.5, gy: 0.4, gz: 0.2 };
    if (cycle === 28) return { ax: 0.5, ay: 0.8, az: 3.1 * G, gx: 5.7, gy: 2.4, gz: 1.4 };
    if (cycle > 28 && cycle < 210) return { ax: G + noise(index, 0), ay: noise(index, 1), az: noise(index, 2), gx: noise(index, 3) * 0.2, gy: noise(index, 4) * 0.2, gz: noise(index, 5) * 0.2 };
    return gait(index, 1.6, 0.9);
  }
  if (id === 'stationary') return { ax: noise(index, 0), ay: noise(index, 1), az: G + noise(index, 2), gx: noise(index, 3) * 0.18, gy: noise(index, 4) * 0.18, gz: noise(index, 5) * 0.18 };
  if (id === 'irregular') {
    const t = index / 50;
    return {
      ax: 2.0 * Math.sin(2 * Math.PI * 1.1 * t) + 1.1 * Math.sin(2 * Math.PI * 2.7 * t) + noise(index, 0),
      ay: 1.4 * Math.sin(2 * Math.PI * 0.63 * t + 0.8) + noise(index, 1),
      az: G + 2.2 * Math.sin(2 * Math.PI * 1.9 * t) + noise(index, 2),
      gx: 1.4 * Math.sin(2 * Math.PI * 1.3 * t) + noise(index, 3),
      gy: 1.1 * Math.cos(2 * Math.PI * 0.83 * t) + noise(index, 4),
      gz: 0.9 * Math.sin(2 * Math.PI * 2.1 * t) + noise(index, 5),
    };
  }
  if (id === 'random') {
    const unit = (axis) => {
      const value = Math.sin((index + 1) * (12.9898 + axis * 3.17) + 78.233 * axis) * 43758.5453;
      return (value - Math.floor(value)) * 2 - 1;
    };
    return {
      ax: 3.2 * unit(1), ay: 2.0 * unit(2), az: G + 3.0 * unit(3),
      gx: 2.0 * unit(4), gy: 2.4 * unit(5), gz: 1.7 * unit(6),
    };
  }
  return {
    ax: Number(custom.ax) || 0,
    ay: Number(custom.ay) || 0,
    az: Number(custom.az ?? G) || 0,
    gx: Number(custom.gx) || 0,
    gy: Number(custom.gy) || 0,
    gz: Number(custom.gz) || 0,
  };
}
