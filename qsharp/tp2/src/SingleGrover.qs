// # Sample
// Getting started
//
// # Description
// This is a minimal Q# program that can be used to start writing Q# code.

// This function runs grover with a secret, a number of qubits and a number of iterations
import Std.Arrays.MostAndTail;
import Std.Arrays.Most;

operation Grover(secret: Int, nbQubits: Int, nbIterations: Int): Result[] {
    // TODO
    use qs = Qubit[nbQubits];

    let oracle = GenerateGroverPhaseOracle(secret);
    ApplyToEach(H,qs);

    for _ in 1..nbIterations {
        oracle(qs);
        GroverDiffusionOperator(qs);
    }
    return MResetEachZ(qs);
}

// This function implements the Grover Diffusion Operator
operation GroverDiffusionOperator(qs: Qubit[]): Unit {
    // TODO
    within {
        ApplyToEachA(H, qs);
        ApplyToEachA(X,qs);
    }
    apply {
        Controlled Z(MostAndTail(qs))
    }

}

// This function generates the Grover Phase Oracle for a single secret
function GenerateGroverPhaseOracle(secret: Int): (Qubit[] => Unit) {
    // TODO
    return (qs) => {
        use aux = Qubit();
        within {
            X(aux);
            H(aux);
        }
        apply {
            ApplyControlledOnInt(secret, X, qs, aux);
        }
    }
}

// This function is useless but gives the syntax needed for the function above
function smallHelp(): (Qubit[] => Unit) {
    return (qs) => {
        Message("Do stuff")
    }
}

operation MarkingOracle(qs: Qubit[], aux: Qubit, secret: Int) : Unit {
    // TODO
    ApplyControlledOnInt(secret, X, qs, aux);
}

operation PhaseOracle(qs: Qubit[], secret: Int) : Unit {
    // TODO
    use aux = Qubit();
    within {
        X(aux);
        H(aux);
    }
    apply {
        MarkingOracle(qs, aux, secret);
    }

    Reset(aux);
}

