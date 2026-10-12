// # Sample
// Getting started
//
// # Description
// This is a minimal Q# program that can be used to start writing Q# code.

// This functions runs the Grover Algorithm and finds by itself the best number of iterations
import SingleGrover.GroverDiffusionOperator;
import SingleGrover.PhaseOracle;
import Std.Math.PI;
import Std.Math.Ceiling;
import Std.Math.Sqrt;
import Std.Convert.IntAsDouble;
operation Grover(secrets: Bool[][], nbQubits: Int): Result[] {
    // TODO
    let r = getNbIterations(secrets, nbQubits);
    return GroverWithIterations(secrets, nbQubits, r);
}

// This function runs the Grover Algorithm with a give number of iterations
operation GroverWithIterations(secrets: Bool[][], nbQubits: Int, nbIterations: Int): Result[] {
    // TODO
    use qs = Qubit[nbQubits];

    let oracle = GenerateGroverPhaseOracle(secrets);
    ApplyToEach(H,qs);

    for _ in 1..nbIterations {
        oracle(qs);
        GroverDiffusionOperator(qs);
    }
    DumpMachine();
    return MResetEachZ(qs);
}

// This function computes the best number of iterations
function getNbIterations(secrets: Bool[][], nbQubits: Int): Int {
    // TODO

    mutable N = 1;
    for i in 1..nbQubits {
        N *= 2;
    }
    let r = (PI() / 4.0) * Sqrt(IntAsDouble(N)/IntAsDouble(Length(secrets)));
    return Ceiling(r);

}

// This functions returns a function which is the Grover Phase oracle for multiple secrets
function GenerateGroverPhaseOracle(secrets: Bool[][]): (Qubit[] => Unit) {
    // TODO
    return (qs) => {
        use aux = Qubit();
        within {
            X(aux);
            H(aux);
        }
        apply {
            for s in secrets {
                ApplyControlledOnBitString(s, X, qs, aux)
            }
        }
    }

}

import Std.Diagnostics.DumpMachine;

    @EntryPoint()
    operation Main() : Unit {
        
        let secrets = [[true, false, true, true], [false, true, false, true], [true, true, true, true]];

        Grover(secrets, 4);
       
}