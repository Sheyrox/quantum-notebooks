// Section 3 — Post-processing classique
//
// Everything in this file is classical (no qubits).
// We write it in Q# to stay in one project, but each function is pure
// and could equally be written in Python (which the analysis section will do).
//
// Pipeline:
//
//   QPE measurement m
//       │
//       ▼
//   φ̃ = m / 2^nbAncillas          ← estimated phase
//       │
//       ▼
//   ContinuedFractions(m, 2^n, N) ← best denominator r ≤ N
//       │                            approximating φ̃ = s/r
//       ▼
//   check: a^r ≡ 1 mod N ?         ← validate r is actually the period
//       │
//       ▼
//   FactorFromPeriod(r, a, N)      ← GCD(a^(r/2) ± 1, N)
//       │
//       ▼
//   (p, q)  with  p·q = N          ← non-trivial factors

// ─────────────────────────────────────────────────────────────────────────────
// 1. Continued fractions
// ─────────────────────────────────────────────────────────────────────────────
//
// Returns the best denominator r (with r ≤ maxDenom) such that
// |numerator/denominator - s/r| is minimised for some integer s.
//
// The algorithm builds the convergents p_k/q_k of the continued fraction
// expansion of numerator/denominator and stops as soon as q_k > maxDenom.
//
// Example: m=64, 2^n=256  →  φ̃ = 64/256 = 1/4
//   Continued fraction: [0; 4]  →  convergents: 0/1, 1/4
//   Returned denominator: 4  (= period of 7^x mod 15)  ✓
//
// Example: m=65, 2^n=256  →  φ̃ = 65/256  (not a simple fraction)
//   Algorithm returns the best r ≤ N, which will still be 4 in this case.
function ContinuedFractions(numerator : Int, denominator : Int, maxDenom : Int) : Int {
    if numerator == 0 {
        return 1;
    }

    // Running convergents:  h_{-1}=1, h_0=a_0  and  k_{-1}=0, k_0=1
    mutable p_prev = 1;
    mutable p_curr = numerator / denominator;
    mutable q_prev = 0;
    mutable q_curr = 1;

    mutable num = numerator % denominator;
    mutable den = denominator;
    mutable best = q_curr;

    while num != 0 {
        let a     = den / num;      // next partial quotient
        let num_new = den % num;
        let den_new = num;

        let p_new = a * p_curr + p_prev;
        let q_new = a * q_curr + q_prev;

        if q_new > maxDenom {
            // Going further would exceed the denominator bound — stop here.
            return best;
        }

        set best   = q_new;
        set p_prev = p_curr;
        set p_curr = p_new;
        set q_prev = q_curr;
        set q_curr = q_new;
        set num    = num_new;
        set den    = den_new;
    }

    return best;
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Extract the period from a single QPE measurement
// ─────────────────────────────────────────────────────────────────────────────
//
// The measurement m approximates s·2^nbAncillas/r for some integer s.
// ContinuedFractions recovers the denominator r of m/2^nbAncillas.
// We then verify that a^r ≡ 1 mod N (the true definition of "period").
//
// Returns the period r if found, 0 otherwise.
function ExtractPeriod(m : Int, nbAncillas : Int, a : Int, N : Int) : Int {
    if m == 0 {
        return 0;   // measurement 0 carries no information about the period
    }

    let twoPowN = 1 <<< nbAncillas;

    // Best denominator r of the fraction m / 2^nbAncillas
    let rCandidate = ContinuedFractions(m, twoPowN, N);

    // Verify: a^r ≡ 1 mod N ?
    if ModPow(a, rCandidate, N) == 1 {
        return rCandidate;
    }

    // Sometimes the true period is a small multiple of the candidate.
    // The most common case is r_true = 2 * rCandidate (happens when s is even).
    let rDouble = 2 * rCandidate;
    if rDouble < N and ModPow(a, rDouble, N) == 1 {
        return rDouble;
    }

    return 0;   // period not found for this measurement — try again
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Compute factors from the period
// ─────────────────────────────────────────────────────────────────────────────
//
// Given the period r of a^x mod N:
//   • r must be even
//   • a^(r/2) mod N must not equal N-1  (else a^(r/2) ≡ -1 mod N → degenerate)
//
// The candidate factors are GCD(a^(r/2) - 1, N) and GCD(a^(r/2) + 1, N).
// At least one of them must be a non-trivial factor of N.
//
// Returns (p, q) with p·q = N, or (1, N) if r is degenerate (try another a).
//
// Degenerate cases:
//   r = 0           → no period found
//   r odd           → no useful factorisation from this r
//   a^(r/2) ≡ -1 mod N  → GCD(a^(r/2) ± 1, N) = 1 or N
function FactorFromPeriod(r : Int, a : Int, N : Int) : (Int, Int) {
    if r == 0      { return (1, N); }
    if r % 2 != 0  { return (1, N); }   // r odd → degenerate, pick another a

    let halfPow = ModPow(a, r / 2, N);
    if halfPow == N - 1 { return (1, N); }   // a^(r/2) ≡ -1 mod N → degenerate

    let factor1 = GCD(halfPow - 1, N);
    let factor2 = GCD(halfPow + 1, N);

    if factor1 != 1 and factor1 != N { return (factor1, N / factor1); }
    if factor2 != 1 and factor2 != N { return (factor2, N / factor2); }

    return (1, N);   // rare: both GCDs trivial — try another a or another run
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Full Shor algorithm (quantum loop + classical post-processing)
// ─────────────────────────────────────────────────────────────────────────────
//
// Repeats QPE until a non-trivial factor is found.
// Each round succeeds with probability ≥ 4/π² ≈ 40% (QPE bound),
// so the expected number of rounds is small.
//
// Recommended test cases:
//   N=15, a=7  → r=4        → factors 3 and 5
//   N=15, a=11 → r=2        → factors 3 and 5
//   N=21, a=4  → r=3 (odd!) → degenerate, pick a=8 → r=2 → factors 3 and 7
//   N=35, a=6  → r=2        → factors 5 and 7
operation Shor(N : Int, a : Int, nbAncillas : Int) : (Int, Int) {
    import Std.Diagnostics.Fact;
    Fact(N > 2,           "N must be > 2");
    Fact(a > 1 and a < N, "a must be in ]1, N[");
    Fact(GCD(a, N) == 1,  "a and N must be coprime — otherwise GCD(a,N) is already a factor");

    mutable attempts = 0;
    mutable factor = (1, N);

    repeat {
        set attempts += 1;
        Message($"  Round {attempts}: running QPE...");

        // ── Quantum phase ────────────────────────────────────────────────────
        let results = ShorQPE(a, N, nbAncillas);
        let m = ResultArrayAsInt(results);
        Message($"    measurement m = {m}");

        // ── Classical post-processing ────────────────────────────────────────
        let r = ExtractPeriod(m, nbAncillas, a, N);
        Message($"    estimated period r = {r}");

        if r != 0 {
            let (p, q) = FactorFromPeriod(r, a, N);
            Message($"    candidate factors: {p} × {q}");
            if p != 1 and p != N {
                set factor = (p, q);
            }
        }

    } until (factor != (1, N) or attempts >= 10);

    return factor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Test
// ─────────────────────────────────────────────────────────────────────────────
//
// Demonstration of the continued fractions step in isolation.
// For N=15, a=7, nbAncillas=8 (2^8=256):
//   Exact QPE outputs: 0, 64, 128, 192
//   ContinuedFractions(64,  256, 15) = 4  → a^4 mod 15 = 1 ✓
//   ContinuedFractions(128, 256, 15) = 2  → a^2 mod 15 = 4 ✗ → try 2*2=4 ✓
//   ContinuedFractions(192, 256, 15) = 4  → a^4 mod 15 = 1 ✓
//
// Then we test the full Shor loop.
@EntryPoint()
operation Main() : Unit {
    // ── Continued fractions demo ─────────────────────────────────────────────
    Message("=== Continued fractions demo (a=7, N=15, 2^8=256) ===");
    for m in [0, 64, 128, 192] {
        let r = ExtractPeriod(m, 8, 7, 15);
        let (p, q) = FactorFromPeriod(r, 7, 15);
        Message($"  m={m}  r={r}  factors=({p},{q})");
    }

    // ── Full Shor loop ───────────────────────────────────────────────────────
    Message("");
    Message("=== Full Shor: N=15, a=7, nbAncillas=8 ===");
    let (p, q) = Shor(15, 7, 8);
    Message($"Result: {p} × {q} = {p * q}");   // expect 3 × 5 = 15  ✓
}
