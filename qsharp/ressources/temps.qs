// Section 1 — Oracle modulaire
//
// Q# uses little-endian notation.
// qs[0] is the least significant bit.
// This will bite you at least once. Probably twice.
//
// The oracle implements the unitary:
//   U_a |y⟩ = |a·y mod N⟩
//
// Its controlled power U_a^(2^k) is what QPE consumes:
// ancillas[k] controls U_a^(2^k) on the eigenstate register.
//
// For a simulator, we implement U_a as a quantum permutation:
// we compute a·y mod N classically for each basis state y,
// then swap the amplitudes of |y⟩ and |a·y mod N⟩ in the register.
// This is O(N) gates and only practical for small N (≤ 21 or so).
// A real device would use reversible arithmetic circuits (Draper adders),
// but those add hundreds of gates and obscure the algorithm.

// ─────────────────────────────────────────────────────────────────────────────
// Classical helpers (no qubits involved)
// ─────────────────────────────────────────────────────────────────────────────

// Computes base^exp mod modulus using fast exponentiation.
// Used to pre-compute a^(2^k) mod N before each controlled gate.
function ModPow(base : Int, exp : Int, modulus : Int) : Int {
    mutable result = 1;
    mutable b = base % modulus;
    mutable e = exp;
    while e > 0 {
        if e % 2 == 1 {
            set result = (result * b) % modulus;
        }
        set b = (b * b) % modulus;
        set e = e / 2;
    }
    return result;
}

// Euclid's algorithm — used in the classical post-processing.
function GCD(a : Int, b : Int) : Int {
    mutable x = a;
    mutable y = b;
    while y != 0 {
        let t = y;
        set y = x % y;
        set x = t;
    }
    return x;
}

// ─────────────────────────────────────────────────────────────────────────────
// Quantum permutation |y⟩ → |a·y mod N⟩
// ─────────────────────────────────────────────────────────────────────────────
//
// The register qs encodes y in little-endian (qs[0] = LSB).
// For y < N  : we map |y⟩ → |a·y mod N⟩
// For y ≥ N  : we leave |y⟩ unchanged (standard convention)
//
// We decompose the permutation into transpositions (swaps of two basis states)
// and implement each swap with a pair of ApplyControlledOnInt gates.
//
// Preconditions: GCD(a, N) = 1  (otherwise U_a is not invertible)
//                qs encodes an n-qubit register with 2^n ≥ N
operation MultiplyModN(a : Int, N : Int, qs : Qubit[]) : Unit is Adj + Ctl {
    let n = Length(qs);
    let size = 1 <<< n;

    // Build the permutation table: perm[y] = a·y mod N  for y < N
    //                                        y            for y ≥ N
    mutable perm = [0, size = size];
    for y in 0..size - 1 {
        if y < N {
            set perm w/= y <- (a * y) % N;
        } else {
            set perm w/= y <- y;
        }
    }

    // Decompose the permutation into cycles, then each cycle into transpositions.
    // A cycle (c0, c1, …, cm-1) decomposes as: swap(c0,c1), swap(c0,c2), …, swap(c0,cm-1)
    mutable visited = [false, size = size];
    for start in 0..size - 1 {
        if not visited[start] and perm[start] != start {
            // Collect the full cycle starting at 'start'
            mutable cycle = [start];
            mutable cur = perm[start];
            while cur != start {
                set cycle += [cur];
                set cur = perm[cur];
            }
            for idx in cycle {
                set visited w/= idx <- true;
            }
            // Apply transpositions: swap |cycle[0]⟩ ↔ |cycle[i]⟩  for i = 1..m-1
            for i in 1..Length(cycle) - 1 {
                SwapBasisStates(cycle[0], cycle[i], qs);
            }
        }
    }
}

// Swaps the amplitudes on basis states |x⟩ and |y⟩ of the register qs.
// Uses a pair of ancilla qubits to detect which branch we are in,
// then XORs the bits that differ between x and y, conditionally on each branch.
operation SwapBasisStates(x : Int, y : Int, qs : Qubit[]) : Unit is Adj + Ctl {
    let n = Length(qs);

    // Compute which bit positions differ between x and y
    mutable diffBits = [false, size = n];
    for i in 0..n - 1 {
        set diffBits w/= i <- (((x >>> i) % 2) != ((y >>> i) % 2));
    }

    // ancX = 1 iff qs == |x⟩,  ancY = 1 iff qs == |y⟩
    use ancX = Qubit();
    use ancY = Qubit();
    within {
        ApplyControlledOnInt(x, X, qs, ancX);
        ApplyControlledOnInt(y, X, qs, ancY);
    } apply {
        // If qs was |x⟩: flip the differing bits to reach |y⟩
        // If qs was |y⟩: flip the same bits to reach |x⟩
        // Both corrections flip exactly the same set of bits, so we can
        // control on (ancX OR ancY) = just apply once for each ancilla.
        for i in 0..n - 1 {
            if diffBits[i] {
                Controlled X([ancX], qs[i]);
                Controlled X([ancY], qs[i]);
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Controlled U_a^(2^k)  —  the gate QPE plugs in
// ─────────────────────────────────────────────────────────────────────────────
//
// ancilla k controls U_a^(2^k) on the eigenstate register.
// We pre-compute a^(2^k) mod N classically (it is just an integer),
// then wrap MultiplyModN in a Controlled gate.
//
// Parameters:
//   a        — base of the modular exponentiation
//   N        — modulus
//   k        — the power is 2^k
//   ctrl     — the ancilla qubit that controls this gate (ancillas[k] in QPE)
//   eigenReg — the register that holds the eigenstate |1⟩
operation ControlledUPow(a : Int, N : Int, k : Int, ctrl : Qubit, eigenReg : Qubit[]) : Unit is Adj {
    let aPow = ModPow(a, 1 <<< k, N);   // a^(2^k) mod N, computed classically
    Controlled MultiplyModN([ctrl], (aPow, N, eigenReg));
}

// ─────────────────────────────────────────────────────────────────────────────
// Test
// ─────────────────────────────────────────────────────────────────────────────
//
// Prepare |1⟩ in a 4-qubit register (enough for N=15), apply U_7 once.
// U_7 |1⟩ = |7·1 mod 15⟩ = |7⟩.
// DumpMachine should show a single amplitude on the basis state 7.
//
// Then apply U_7 three more times: 7→49 mod 15=4, 4→28 mod 15=13, 13→91 mod 15=1.
// After 4 applications we get back to |1⟩ — the period of 7^x mod 15 is 4. ✓
@EntryPoint()
operation Main() : Unit {
    import Std.Diagnostics.DumpMachine;

    use qs = Qubit[4];   // 2^4=16 ≥ 15

    // Encode |1⟩ in little-endian: qs[0]=1, rest=0
    X(qs[0]);
    Message("Initial state |1⟩ :");
    DumpMachine();

    // Apply U_7 once: |1⟩ → |7⟩
    MultiplyModN(7, 15, qs);
    Message("After U_7 |1⟩ = |7⟩ :");
    DumpMachine();

    // Apply U_7 three more times to complete the cycle
    MultiplyModN(7, 15, qs);   // |7⟩  → |4⟩   (49 mod 15 = 4)
    MultiplyModN(7, 15, qs);   // |4⟩  → |13⟩  (28 mod 15 = 13)
    MultiplyModN(7, 15, qs);   // |13⟩ → |1⟩   (91 mod 15 = 1)
    Message("After 3 more applications (back to |1⟩) :");
    DumpMachine();

    ResetAll(qs);
}
