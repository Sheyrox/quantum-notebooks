// # Sample
// Getting started
//
// # Description
// This is a minimal Q# program that can be used to start writing Q# code.

// This function runs grover with a secret, a number of qubits and a number of iterations
operation Grover(secret: Int, nbQubits: Int, nbIterations: Int): Result[] {
    use qs = Qubit[nbQubits];
    let oracle = GenerateGroverPhaseOracle(secret);
    // Superposition uniforme initiale
    ApplyToEach(H, qs);
    // Boucle Grover : oracle puis diffusion, répété nbIterations fois
    for _ in 1..nbIterations {
        oracle(qs);
        GroverDiffusionOperator(qs);
    }
    return MResetEachZ(qs);
}

// This function implements the Grover Diffusion Operator
operation GroverDiffusionOperator(qs: Qubit[]): Unit {
    // D = H⊗n · X⊗n · CZ · X⊗n · H⊗n
    // Le within applique H et X, puis leur adjoint automatiquement après le apply.
    // Au centre : Z multi-contrôlé (tous les qubits sauf le dernier contrôlent le dernier).
    within {
        ApplyToEachA(H, qs);
        ApplyToEachA(X, qs);
    } apply {
        Controlled Z(Most(qs), Tail(qs));
    }
}

// This function generates the Grover Phase Oracle for a single secret
function GenerateGroverPhaseOracle(secret: Int): (Qubit[] => Unit) {
    // On retourne une lambda qui capture secret dans sa closure.
    // L'ancilla est préparée dans |−⟩ par within/apply :
    // ApplyControlledOnInt(secret, X, qs, aux) flippe aux si qs == secret,
    // ce qui kicke le signe (−1) sur l'état |secret⟩ du registre.
    return (qs) => {
        use aux = Qubit();
        within {
            X(aux);
            H(aux);
        } apply {
            ApplyControlledOnInt(secret, X, qs, aux);
        }
    };
}

// This function is useless but gives the syntax needed for the function above
function smallHelp(): (Qubit[] => Unit) {
    return (qs) => {
        Message("Do stuff")
    }
}
