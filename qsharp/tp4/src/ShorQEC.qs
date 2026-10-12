import SimpleQEC.DecodePhaseFlip;
import SimpleQEC.DecodeBitFlip;
import Std.Diagnostics.DumpMachine;
import SimpleQEC.EncodeBitFlip;
import SimpleQEC.EncodePhaseFlip;
import Std.Diagnostics.Fact;


operation EncodeShorCode(logicalQubit: Qubit, encodedQubits: Qubit[]): Unit is Adj {
    Fact(
        Length(encodedQubits) == 8,
        "There should be only 8 qubits"
    );
    // TODO
    EncodePhaseFlip(logicalQubit, [encodedQubits[2], encodedQubits[5]]);
    EncodeBitFlip(logicalQubit, [encodedQubits[0], encodedQubits[1]]);
    EncodeBitFlip(encodedQubits[2], [encodedQubits[3], encodedQubits[4]]);
    EncodeBitFlip(encodedQubits[5], [encodedQubits[6], encodedQubits[7]]);
}

operation DecodeShorCode(logicalQubit: Qubit, encodedQubits: Qubit[]): Unit {
    Fact(
        Length(encodedQubits) == 8,
        "There should be only 8 qubits"
    );
    // TODO
    DecodeBitFlip(logicalQubit, [encodedQubits[0], encodedQubits[1]]);
    DecodeBitFlip(encodedQubits[2], [encodedQubits[3], encodedQubits[4]]);
    DecodeBitFlip(encodedQubits[5], [encodedQubits[6], encodedQubits[7]]);
    DecodePhaseFlip(logicalQubit, [encodedQubits[2], encodedQubits[5]]);

}

operation TestShor(): Result[] {
    // TODO

    use logicalQbit = Qubit();
    use encodedQbit = Qubit[8];
    X(logicalQbit);
    EncodeShorCode(logicalQbit, encodedQbit);

    DumpMachine();

    Reset(logicalQbit);
    ResetAll(encodedQbit);
    return [Zero];
}