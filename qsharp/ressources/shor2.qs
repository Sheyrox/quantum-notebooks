// Section 2 — QPE de Shor
//
// This file plugs the modular oracle from Section 1 into the QPE circuit
// from TP3. The structure is identical to QPEPhi: the only change is that
// the gate U is now ControlledUPow instead of R1(2π·φ).
//
// Circuit (little-endian ancilla convention, same as TP3 section 2.2):
//
//   ancillas[0] ──H──●──────────────── IQFT ── M   controls U^(2^0)
//   ancillas[1] ──H────●─────────────── IQFT ── M   controls U^(2^1)
//   …
//   ancillas[n-1] ─H──────────●──────── IQFT ── M   controls U^(2^{n-1})
//                             │
//   eigenReg ──|1⟩───────────────────────────────── untouched (eigenstate)
//
// After IQFT, read ancillas as a little-endian integer m.
// Estimated phase: φ̃ = m / 2^nbAncillas ≈ s/r  for some integer s.
// The period r is then recovered by continued fractions (Section 3).

import Std.Diagnostics.Fact;

// ─────────────────────────────────────────────────────────────────────────────
// Helper: number of bits needed to represent n (= ⌊log₂(n)⌋ + 1)
// ─────────────────────────────────────────────────────────────────────────────
function BitLength(n : Int) : Int {
    mutable k = 0;
    mutable v = n;
    while v > 0 {
        set k += 1;
        set v = v >>> 1;
    }
    return k;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: convert a Result[] (little-endian) to an Int
//   results[0] = bit of weight 2^0, results[k] = bit of weight 2^k
// ─────────────────────────────────────────────────────────────────────────────
function ResultArrayAsInt(results : Result[]) : Int {
    mutable value = 0;
    for k in 0..Length(results) - 1 {
        if results[k] == One {
            set value += 1 <<< k;
        }
    }
    return value;
}

// ─────────────────────────────────────────────────────────────────────────────
// ShorQPE — QPE for Shor's algorithm
//
// Parameters:
//   a          — base (must satisfy GCD(a, N) = 1 and 1 < a < N)
//   N          — integer to factor
//   nbAncillas — number of ancilla qubits = precision in bits
//                (use 8 for N=15, more for larger N)
//
// Returns: Result[] in little-endian.
//   Convert to integer m = Σ bk·2^k, then φ̃ = m / 2^nbAncillas ≈ s/r.
//
// Test: a=7, N=15, nbAncillas=8.
//   Period of 7^x mod 15 is r=4.
//   QPE should return values close to 0, 64, 128, 192  (multiples of 256/4).
//   As fractions: 0/4, 1/4, 2/4, 3/4. ✓
// ─────────────────────────────────────────────────────────────────────────────
operation ShorQPE(a : Int, N : Int, nbAncillas : Int) : Result[] {
    Fact(nbAncillas >= 1, "Need at least 1 ancilla qubit");
    Fact(a > 1 and a < N,  "a must be in ]1, N[");
    Fact(GCD(a, N) == 1,   "a and N must be coprime");

    // The eigenstate register must be large enough to encode {0, …, N-1}
    let nEigen = BitLength(N - 1);

    use ancillas = Qubit[nbAncillas];
    use eigenReg = Qubit[nEigen];

    // ── Step 1: prepare the eigenstate |1⟩ ───────────────────────────────────
    // |1⟩ is a uniform superposition of all eigenvectors of U_a,
    // which is sufficient for QPE (the measurement collapses onto one of them).
    // In little-endian: qs[0] = 1, rest = 0  →  integer value 1.
    X(eigenReg[0]);

    // ── Step 2: put ancillas in uniform superposition ─────────────────────────
    ApplyToEach(H, ancillas);

    // ── Step 3: controlled U^(2^k), one per ancilla ───────────────────────────
    // ancillas[k] controls U_a^(2^k) on eigenReg.
    // Phase kickback writes 2^k · φ onto ancilla k when it is in |1⟩.
    for k in 0..nbAncillas - 1 {
        ControlledUPow(a, N, k, ancillas[k], eigenReg);
    }

    // ── Step 4: inverse QFT on the ancilla register ───────────────────────────
    // Adjoint QFT is free because QFT is declared "is Adj" in QFT.qs.
    Adjoint QFT(ancillas);

    // ── Step 5: measure and release ───────────────────────────────────────────
    // eigenReg may be entangled with ancillas if r does not divide 2^nbAncillas
    // exactly — reset it unconditionally.
    let results = MResetEachZ(ancillas);
    ResetAll(eigenReg);

    return results;
}

// ─────────────────────────────────────────────────────────────────────────────
// Test
// ─────────────────────────────────────────────────────────────────────────────
//
// Run ShorQPE several times and print m and φ̃ = m/256.
// For a=7, N=15, the four expected clusters are:
//   m ≈ 0   → φ̃ = 0/4
//   m ≈ 64  → φ̃ = 1/4
//   m ≈ 128 → φ̃ = 2/4
//   m ≈ 192 → φ̃ = 3/4
// All four appear with equal probability (~25% each).
// If you only see m=0, the oracle is returning a global phase, not U_a.
// If you see a uniform distribution over all 256 values, check the IQFT.
@EntryPoint()
operation Main() : Unit {
    let a = 7;
    let N = 15;
    let nbAncillas = 8;

    Message($"Shor QPE: a={a}, N={N}, nbAncillas={nbAncillas}");
    Message($"Expected measurements: 0, 64, 128, 192  (period r=4, 2^8/4=64)");
    Message("");

    for _ in 1..12 {
        let results = ShorQPE(a, N, nbAncillas);
        let m = ResultArrayAsInt(results);
        Message($"  m = {m}  →  φ̃ = {m} / {1 <<< nbAncillas}");
    }
}
