package main

import (
	"encoding/base64"
	"fmt"
	"os"
	"sort"
)

var (
	b64A = "BynQtpeUyWTXKGTrGhdV2Q=="
	b64B = "tVMd3L1CKM4wFmyxEEEUV2bY"
	b64C = "4Fdzw1k="
	b64E = "vtv3f5aKY0jGQglP9a1AGw=="

	expA = []byte{0x07, 0x29, 0xd0, 0xb6, 0x97, 0x94, 0xc9, 0x64, 0xd7, 0x28, 0x64, 0xeb, 0x1a, 0x17, 0x55, 0xd9}
	expB = []byte{0xb5, 0x53, 0x1d, 0xdc, 0xbd, 0x42, 0x28, 0xce, 0x30, 0x16, 0x6c, 0xb1, 0x10, 0x41, 0x14, 0x57, 0x66, 0xd8}
	expC = []byte{0xe0, 0x57, 0x73, 0xc3, 0x59}
	expE = []byte{0xbe, 0xdb, 0xf7, 0x7f, 0x96, 0x8a, 0x63, 0x48, 0xc6, 0x42, 0x09, 0x4f, 0xf5, 0xad, 0x40, 0x1b}
)

type verifier struct {
	passed int
	failed int
}

func (v *verifier) check(name string, ok bool, details string) {
	if ok {
		v.passed++
		fmt.Printf("PASS %-32s %s\n", name, details)
		return
	}
	v.failed++
	fmt.Printf("FAIL %-32s %s\n", name, details)
}

func mustDecode(s string) []byte {
	b, err := base64.StdEncoding.DecodeString(s)
	if err != nil {
		panic(err)
	}
	return b
}

func eq(a, b []byte) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func hexBytes(b []byte) string {
	out := ""
	for i, x := range b {
		if i > 0 {
			out += " "
		}
		out += fmt.Sprintf("%02x", x)
	}
	return out
}

func main() {
	v := &verifier{}

	A := mustDecode(b64A)
	B := mustDecode(b64B)
	C := mustDecode(b64C)
	E := mustDecode(b64E)

	v.check("base64 A", eq(A, expA), hexBytes(A))
	v.check("base64 B", eq(B, expB), hexBytes(B))
	v.check("base64 C", eq(C, expC), hexBytes(C))
	v.check("base64 E", eq(E, expE), hexBytes(E))

	Hdr := B[0:3]
	G1 := B[3:6]
	G2 := B[6:9]
	G3 := B[9:12]
	G4 := B[12:15]
	G5 := B[15:18]
	groups := [][]byte{G1, G2, G3, G4, G5}

	v.check("B partition Hdr", eq(Hdr, []byte{0xb5, 0x53, 0x1d}), hexBytes(Hdr))
	v.check("B partition G1", eq(G1, []byte{0xdc, 0xbd, 0x42}), hexBytes(G1))
	v.check("B partition G2", eq(G2, []byte{0x28, 0xce, 0x30}), hexBytes(G2))
	v.check("B partition G3", eq(G3, []byte{0x16, 0x6c, 0xb1}), hexBytes(G3))
	v.check("B partition G4", eq(G4, []byte{0x10, 0x41, 0x14}), hexBytes(G4))
	v.check("B partition G5", eq(G5, []byte{0x57, 0x66, 0xd8}), hexBytes(G5))

	selectors := []int{}
	for i, x := range E {
		if int(x) < len(B) {
			selectors = append(selectors, i)
		}
	}
	v.check("E unique direct selector", len(selectors) == 1 && selectors[0] == 10 && E[10] == 0x09, fmt.Sprintf("indices=%v value=%02x", selectors, E[10]))
	v.check("selector extracts G3", eq(B[E[10]:E[10]+3], G3), hexBytes(B[E[10]:E[10]+3]))

	mask := (G3[0] ^ G3[2]) & 0x07
	out := G3[1] ^ mask
	v.check("kernel mask", mask == 0x07, fmt.Sprintf("mask=%02x", mask))
	v.check("kernel output", out == 0x6b, fmt.Sprintf("out=%02x", out))
	v.check("bridge kernel->E[3]", out^G4[2] == E[3], fmt.Sprintf("%02x ^ %02x = %02x", out, G4[2], out^G4[2]))
	v.check("selector bridge", E[10]^G4[2] == Hdr[2], fmt.Sprintf("%02x ^ %02x = %02x", E[10], G4[2], E[10]^G4[2]))
	v.check("header OR relation", G3[2]|G4[2] == Hdr[0], fmt.Sprintf("%02x | %02x = %02x", G3[2], G4[2], G3[2]|G4[2]))
	v.check("G4 contained in Hdr", (Hdr[0]&G4[0] == G4[0]) && (Hdr[1]&G4[1] == G4[1]) && (Hdr[2]&G4[2] == G4[2]), fmt.Sprintf("Hdr&G4=%02x %02x %02x", Hdr[0]&G4[0], Hdr[1]&G4[1], Hdr[2]&G4[2]))

	seq := make([]byte, len(E))
	for i, x := range E {
		seq[i] = groups[int(x)%5][int(x)%3]
	}
	expSeq := []byte{0xbd, 0x57, 0x6c, 0x6c, 0xdc, 0x10, 0x57, 0x16, 0x10, 0x28, 0x57, 0x66, 0x42, 0x14, 0x66, 0x16}
	v.check("selector sequence", eq(seq, expSeq), hexBytes(seq))

	printable := map[byte]bool{}
	for _, x := range B {
		if x >= 0x20 && x <= 0x7e {
			printable[x] = true
		}
	}
	keys := make([]int, 0, len(printable))
	for x := range printable {
		keys = append(keys, int(x))
	}
	sort.Ints(keys)
	printableHex := ""
	for i, x := range keys {
		if i > 0 {
			printableHex += " "
		}
		printableHex += fmt.Sprintf("%02x", x)
	}
	v.check("printable subset B", printableHex == "28 30 41 42 53 57 66 6c", printableHex)

	type pair struct{ i, j int }
	pairs := []pair{}
	for i := 0; i < len(A); i++ {
		for j := i + 1; j < len(A); j++ {
			d := int(A[i]) - int(A[j])
			if d < 0 {
				d = -d
			}
			if d <= 1 && printable[seq[i]] && printable[seq[j]] {
				pairs = append(pairs, pair{i, j})
			}
		}
	}
	v.check("unique adjacency pair", len(pairs) == 1 && pairs[0] == (pair{1, 9}), fmt.Sprintf("pairs=%v A=(%02x,%02x)", pairs, A[9], A[1]))

	concat := b64A + b64B + b64C + b64E
	projection := concat[40:44]
	decodedProjection := mustDecode(projection)
	v.check("base64 projection to G4", projection == "EEEU" && eq(decodedProjection, G4), fmt.Sprintf("%s -> %s", projection, hexBytes(decodedProjection)))

	derivedA := map[int]byte{
		0:  mask,
		1:  Hdr[1] >> 1,
		2:  G3[2] ^ mask ^ G5[1],
		3:  G3[2] ^ mask,
		4:  E[4] | mask,
		5:  Hdr[0] & G1[0],
		6:  G5[2] ^ G3[0] ^ mask,
		7:  E[6] ^ mask,
		8:  ^G2[0],
		9:  G2[0],
		11: G2[2] ^ E[1],
		12: Hdr[2] ^ mask,
		13: G4[0] ^ mask,
		14: G4[0] | G4[1] | G4[2],
		15: Hdr[0] ^ G3[1],
	}
	okA := true
	for i, x := range derivedA {
		if A[i] != x {
			okA = false
		}
	}
	v.check("A-field derivations", okA, "A[10] intentionally not derived")
	v.check("A[10] duplicates A[7]", A[10] == A[7], fmt.Sprintf("A[10]=%02x A[7]=%02x", A[10], A[7]))

	v.check("secondary G2[1]^G3[2]", G2[1]^G3[2] == E[3], fmt.Sprintf("%02x", G2[1]^G3[2]))
	v.check("secondary G5[1]^G5[2]", G5[1]^G5[2] == E[0], fmt.Sprintf("%02x", G5[1]^G5[2]))
	v.check("secondary G3[0]+G4[1]", byte(uint16(G3[0])+uint16(G4[1])) == G5[0], fmt.Sprintf("%02x", byte(uint16(G3[0])+uint16(G4[1]))))
	v.check("secondary G3[1]+G3[2]", byte(uint16(G3[1])+uint16(G3[2])) == Hdr[2], fmt.Sprintf("%02x", byte(uint16(G3[1])+uint16(G3[2]))))

	fmt.Printf("\n%d passed, %d failed\n", v.passed, v.failed)
	if v.failed > 0 {
		os.Exit(1)
	}
}
