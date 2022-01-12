// Static Bit set example

#import "Basic";
Bitset :: #import "sk_Bitset";
// for now you can do this since Bitset module not written to be imported to global scope.
operator []   :: Bitset.get;
for_expansion :: Bitset.for_expansion;

main :: () {
    bits: Bitset.Bitset(10);

    for 0..bits.count-1 {
        print("index: %, value: % \n",  it, Bitset.get(bits, it) );
    }

    print("---------set--------\n");

    for 0..bits.count-1 {
        Bitset.set(*bits, it);
        print("index: %, value: % \n",  it, bits[it] ); // you can use operator []
    }

    print("---------clear--------\n");

    for bits {
        Bitset.clear(*bits, it_index);
        print("index: %, value: % \n",  it_index, it ); // Bitset also has it's own for expansion
    }

    print("---------toggle--------\n");

    for 0..bits.count-1 {
        Bitset.toggle(*bits, it);
        print("index: %, value: % \n",  it, Bitset.get(bits, it) );
    }

    print("---------clear_all--------\n");
    Bitset.clear_all(*bits);
    for 0..bits.count-1 {
        print("index: %, value: % \n",  it, Bitset.get(bits, it) );
    }

    print("---------set_all (but not 5)--------\n");
    Bitset.set_all(*bits);
    Bitset.clear(*bits, 5);
    for 0..bits.count-1 {
        print("index: %, value: % \n",  it, Bitset.get(bits, it) );
    }

    print("---------toggle_all--------\n");
    Bitset.toggle_all(*bits);
    for 0..bits.count-1 {
        print("index: %, value: % \n",  it, Bitset.get(bits, it) );
    }

    print("---------Bitset.get using [] operator --------\n");
    print("bit 5 = %\n", bits[5] );
    print("bit 6 = %\n", bits[6] );     
}