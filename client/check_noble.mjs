import { ml_kem768 } from '@noble/post-quantum/ml-kem.js';
import { ml_dsa65 } from '@noble/post-quantum/ml-dsa.js';

console.log("Checking ML-KEM keygen...");
const kemKeys = ml_kem768.keygen();

console.log("Checking ML-DSA keygen...");
const dsaKeys = ml_dsa65.keygen();

const msg = new Uint8Array([1, 2, 3]);
// Swapped arguments: msg first, secretKey second
const sig = ml_dsa65.sign(msg, dsaKeys.secretKey);
console.log("Signature length:", sig.length);
// Hypothesis: verify(signature, message, publicKey)
// const valid = ml_dsa65.verify(dsaKeys.publicKey, msg, sig); // This failed.
const valid2 = ml_dsa65.verify(sig, msg, dsaKeys.publicKey); // Trying this order: sig, msg, pk.
console.log("Signature valid (sig, msg, pk):", valid2);

const { cipherText, sharedSecret } = ml_kem768.encapsulate(kemKeys.publicKey);
console.log("KEM Ciphertext length:", cipherText.length);
console.log("KEM Shared Secret length:", sharedSecret.length);

const sharedSecret2 = ml_kem768.decapsulate(cipherText, kemKeys.secretKey);
console.log("Secrets match:", sharedSecret.toString() === sharedSecret2.toString());