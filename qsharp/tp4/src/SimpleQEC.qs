import Std.Arithmetic.ApplyIfLessL;
import Std.Diagnostics.Fact;

operation EncodeBitFlip(logicalQubit: Qubit, encodedQubits: Qubit[]): Unit is Adj {
    Fact(
        Length(encodedQubits) == 2,
        "There should be only 2 encoded Qubits"
    );
    // TODO
   for i in 0..Length(encodedQubits) - 1{
        CNOT(logicalQubit, encodedQubits[i]);
   }
}

operation DecodeBitFlip(logicalQubit: Qubit, encodedQubits: Qubit[]): Unit is Adj {
    Fact(
        Length(encodedQubits) == 2,
        "There should be only 2 encoded Qubits"
    );
    // TODO
    for i in 0..Length(encodedQubits) - 1 {
        CNOT(logicalQubit, encodedQubits[i]);
    }

    X(logicalQubit);
    I(encodedQubits[0]);
    I(encodedQubits[1]);

    CNOT(logicalQubit, encodedQubits[1]);
    CNOT(logicalQubit, encodedQubits[0]);
}

operation EncodePhaseFlip(logicalQubit: Qubit, encodedQubits: Qubit[]): Unit is Adj {
    Fact(
        Length(encodedQubits) == 2,
        "There should be only 2 encoded Qubits"
    );
    // TODO
    
    H(logicalQubit);
    H(encodedQubits[0]);
    H(encodedQubits[1]);

    EncodeBitFlip(logicalQubit, encodedQubits);

    H(logicalQubit);
    H(encodedQubits[0]);
    H(encodedQubits[1]);
}

operation DecodePhaseFlip(logicalQubit: Qubit, encodedQubits: Qubit[]): Unit is Adj {
    Fact(
        Length(encodedQubits) == 2,
        "There should be only 2 encoded Qubits"
    );
    // TODO

    H(logicalQubit);
    H(encodedQubits[0]);
    H(encodedQubits[1]);

    DecodeBitFlip(logicalQubit, encodedQubits);

    H(logicalQubit);
    H(encodedQubits[0]);
    H(encodedQubits[1]);
}

operation TestBitFlip(): Result[] {
    // TODO
    use encodedQbits = Qubit[2];
    use logicalQbit = Qubit();
    H(logicalQbit);

    EncodeBitFlip(logicalQbit, encodedQbits);

    DumpMachine();

    X(encodedQbits[0]);

    DecodeBitFlip(logicalQbit, encodedQbits);

    DumpMachine();
    ResetAll(encodedQbits);
    Reset(logicalQbit);
    return [Zero];
}

operation TestPhaseFlip(): Result[] {
    // TODO
    use encodedQbits = Qubit[2];
    use logicalQbit = Qubit();
    X(logicalQbit);

    EncodePhaseFlip(logicalQbit, encodedQbits);

    DumpMachine();

    DecodePhaseFlip(logicalQbit, encodedQbits);

    DumpMachine();

    ResetAll(encodedQbits);
    Reset(logicalQbit);

    return [Zero];
}


import Std.Diagnostics.DumpMachine;

