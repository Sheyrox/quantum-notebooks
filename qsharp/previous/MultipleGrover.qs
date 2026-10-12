// # Sample
// Getting started
//
// # Description
// This is a minimal Q# program that can be used to start writing Q# code.

import SingleGrover.GroverDiffusionOperator;
import Std.Math.Sqrt;
import Std.Math.PI;
import Std.Math.Ceiling;
import Std.Convert.IntAsDouble;

// This functions runs the Grover Algorithm and finds by itself the best number of iterations
operation Grover(secrets: Bool[][], nbQubits: Int): Result[] {
    let nbIterations = getNbIterations(secrets, nbQubits);
    return GroverWithIterations(secrets, nbQubits, nbIterations);
}

// This function runs the Grover Algorithm with a give number of iterations
operation GroverWithIterations(secrets: Bool[][], nbQubits: Int, nbIterations: Int): Result[] {
    use qs = Qubit[nbQubits];
    let oracle = GenerateGroverPhaseOracle(secrets);
    ApplyToEach(H, qs);
    for _ in 1..nbIterations {
        oracle(qs);
        GroverDiffusionOperator(qs);
    }
    return MResetEachZ(qs);
}

// This function computes the best number of iterations
function getNbIterations(secrets: Bool[][], nbQubits: Int): Int {
    // r ≈ (π/4) · sqrt(N/M)  avec N = 2^nbQubits, M = nombre de secrets
    let N = IntAsDouble(1 <<< nbQubits);
    let M = IntAsDouble(Length(secrets));
    return Ceiling(PI() / 4.0 * Sqrt(N / M));
}

// This functions returns a function which is the Grover Phase oracle for multiple secrets
function GenerateGroverPhaseOracle(secrets: Bool[][]): (Qubit[] => Unit) {
    // Une seule ancilla dans |−⟩, on boucle sur tous les secrets dans le apply.
    // Chaque ApplyControlledOnBitString flippe l'ancilla si qs correspond au secret,
    // accumulant le kickback de phase (−1) pour chacun des états marqués.
    return (qs) => {
        use aux = Qubit();
        within {
            X(aux);
            H(aux);
        } apply {
            for s in secrets {
                ApplyControlledOnBitString(s, X, qs, aux);
            }
        }
    };
}
