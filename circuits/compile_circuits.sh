
mkdir -p ptau
mkdir -p build

cp ~/chrome下载/powersOfTau28_hez_final_16.ptau ./ptau

circom withdraw.circom --r1cs --wasm --json -o build/

snarkjs r1cs info build/withdraw.r1cs 

#setup

snarkjs groth16 setup build/withdraw.r1cs ptau/powersOfTau28_hez_final_16.ptau build/circuit_0000.zkey

snarkjs zkey contribute build/circuit_0000.zkey build/circuit_0001.zkey --name="1st Contributor Name" -v

snarkjs zkey contribute build/circuit_0001.zkey build/circuit_0002.zkey --name="Second contribution Name" -v -e="Another random entropy"

snarkjs zkey export bellman build/circuit_0002.zkey  build/challenge_phase2_0003
snarkjs zkey bellman contribute bn128 build/challenge_phase2_0003 build/response_phase2_0003 -e="some random text"
snarkjs zkey import bellman build/circuit_0002.zkey build/response_phase2_0003 build/circuit_0003.zkey -n="Third contribution name"

snarkjs zkey verify build/withdraw.r1cs ptau/powersOfTau28_hez_final_16.ptau build/circuit_0003.zkey

snarkjs zkey beacon build/circuit_0003.zkey build/circuit_final.zkey 0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f 10 -n="Final Beacon phase2"

snarkjs zkey verify build/withdraw.r1cs ptau/powersOfTau28_hez_final_16.ptau build/circuit_final.zkey

snarkjs zkey export verificationkey build/circuit_final.zkey build/verification_key.json

snarkjs zkey export solidityverifier build/circuit_final.zkey build/verifier.sol