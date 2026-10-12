// QPEPhi : estime la phase φ de la porte U = R1(2π·φ) appliquée à |1⟩.
//
// La porte R1(θ) vérifie R1(θ)|1⟩ = e^{iθ}|1⟩ et R1(θ)|0⟩ = |0⟩.
// Avec θ = 2π·φ, l'eigenvalue est e^{2πiφ}, ce qui est exactement
// le format attendu par QPE.
//
// oraclePower : puissance à laquelle appliquer U (paramètre fourni par
//               le harness de test pour explorer différentes précisions).
//
// Retourne : tableau de Result[] little-endian.
//   Phase estimée : φ̃ = (Σ b_k · 2^k) / 2^nbAncillas
//
// Test : φ = 1/3, nbAncillas = 8 → mesure attendue ≈ 85 ou 86 (= round(256/3)).

import Std.Math.PI;

operation QPEPhi(phi: Double, oraclePower: Int): Result[] {
    // On fixe le nombre d'ancillas ici (le harness peut l'adapter via oraclePower).
    let nbAncillas = oraclePower;

    // La porte U = R1(2π·φ) a |1⟩ comme eigenvecteur avec eigenvalue e^{2πiφ}.
    let gate = (q) => R1(2.0 * PI() * phi, q);

    use eigenReg = Qubit[1];

    // Prépare l'eigenvecteur |1⟩
    X(eigenReg[0]);

    // Lance QPE
    let results = QPE(gate, eigenReg, nbAncillas);

    // Remet eigenReg dans |0⟩
    Reset(eigenReg[0]);

    return results;
}
