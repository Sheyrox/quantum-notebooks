import Std.Arithmetic.IncByI;
import Std.Math.ExpModI;
import UGate.MultiplyConstantModulo;
import Std.Diagnostics.Fact;

operation ApplyUGate(generator: Int, modulo: Int, power: Int, qs: Qubit[]): Unit is Adj + Ctl {
    // TODO

    MultiplyConstantModulo(ExpModI(generator, power, modulo), modulo, qs);

}

operation EstimateFrequency(generator: Int, modulo: Int, moduloBitSize: Int): Int {
    // TODO
    
    mutable frequency = 0;
    let bitsPrecision = 2 * moduloBitSize + 1;

    use qs = Qubit[moduloBitSize];
    X(qs[0]);

    use c = Qubit();

    for i in bitsPrecision - 1..-1..0 {
        H(c);
        Controlled ApplyUGate([c], (generator, modulo, 1<<<i, qs));
        R1Frac(frequency, bitsPrecision - 1 - i, c);
        H(c);
        let res = M(c);
        if (res == One) {
            frequency += 2^(bitsPrecision - 1 - i);
            X(c);
        }
    }
    ResetAll(qs);
    return frequency;
}

operation test1(): Unit {
    let frequency = EstimateFrequency(2, 15, 4); 
    Message($"Fréquence : {frequency}");
    let isValid = frequency == 0 or frequency == 128
    or frequency == 256 or frequency == 384;
    Fact(isValid, $"Fréquence {frequency} inattendue");
}

operation test2(): Unit {
    mutable count0 = 0; mutable count128 = 0;
    mutable count256 = 0; mutable count384 = 0;
    for _ in 1..40 {
        let freq = EstimateFrequency(2, 15, 4);
        if freq == 0 { count0 += 1; }
        elif freq == 128 { count128 += 1; }
        elif freq == 256 { count256 += 1; }
        elif freq == 384 { count384 += 1; }
    }
    Message($"0={count0}, 128={count128}, 256={count256}, 384={count384}");
}