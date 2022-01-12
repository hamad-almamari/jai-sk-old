// Static Bit Set
//
// NOTE: Some of this Code taken from "Bit_Array" module.
/*
Usage:

Bitset        :: #import "fw_Bitset";
operator []   :: Bitset.get;
for_expansion :: Bitset.for_expansion;
*/

Bitset :: struct (count: int) {
    TYPE :: #this;
    N    :: (count + 63) >> 6;
    buffer: [N] int;
}

set :: (using bitset: *Bitset, i: int) {
    assert(i < count);
    buffer[i >> 6] |= (1 << (i & 63));
}

clear :: (using bitset: *Bitset, i: int) {
    assert(i < count);
    buffer[i >> 6] &= ~(1 << (i & 63));
}

toggle :: (using bitset: *Bitset, i: int) {
    assert(i < count);
    buffer[i >> 6] ^= (1 << (i & 63));
}

get :: (using bitset: Bitset, i: int) -> bool {
    assert(i < count);
    return cast(bool) (buffer[i >> 6] & (1 << (i & 63)));
}

// for now you can do this since this module not written to be imported to global scope.
// Bitset :: #import "fw_Bitset";
// operator [] :: Bitset.get;
/*
operator [] :: (using bitset: Bitset, i: int) -> bool {
    assert(i < count);
    return cast(bool) (buffer[i >> 6] & (1 << (i & 63)));
}
*/

set_all :: (using bitset: *Bitset) {
    memset(buffer.data, 0xFF, N * size_of(int));
}

clear_all :: (using bitset: *Bitset) {
    memset(buffer.data, 0, N * size_of(int));
}

toggle_all :: (using bitset: *Bitset) {
    for * buffer { <<it ^= 0xFFFFFFFF_FFFFFFFF; }
}

// for now you can do this since this module not written to be imported to global scope.
// Bitset :: #import "fw_Bitset";
// for_expansion :: for_expansion;
for_expansion :: (bitset: *$T/Bitset, body: Code, flags: For_Flags) #expand {
    #assert(!(flags & .POINTER));
    DO_REVERSE :: cast(bool) (flags & .REVERSE);
    for <=DO_REVERSE `it_index: 0..bitset.count-1 {
        `it := inline get(<<bitset, it_index);
        #insert (remove=#assert(false)) body;
    }
}

#scope_file
#import "Basic";