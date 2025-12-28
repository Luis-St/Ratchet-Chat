
const { ml_kem768 } = require('@noble/post-quantum/ml-kem');
const { ml_dsa65 } = require('@noble/post-quantum/ml-dsa');

console.log("Checking ML-KEM keygen...");
const kemKeys = ml_kem768.keygen();
console.log("Keys type:", typeof kemKeys);
console.log("Has publicKey?", kemKeys.publicKey ? "yes" : "no");
console.log("Has secretKey?", kemKeys.secretKey ? "yes" : "no");
if (kemKeys.publicKey) console.log("Public Key length:", kemKeys.publicKey.length);
if (kemKeys.secretKey) console.log("Secret Key length:", kemKeys.secretKey.length);

console.log("Checking ML-DSA keygen...");
const dsaKeys = ml_dsa65.keygen();
console.log("Keys type:", typeof dsaKeys);
console.log("Has publicKey?", dsaKeys.publicKey ? "yes" : "no");
console.log("Has secretKey?", dsaKeys.secretKey ? "yes" : "no");
if (dsaKeys.publicKey) console.log("Public Key length:", dsaKeys.publicKey.length);
if (dsaKeys.secretKey) console.log("Secret Key length:", dsaKeys.secretKey.length);

const msg = new Uint8Array([1, 2, 3]);
const sig = ml_dsa65.sign(dsaKeys.secretKey, msg);
console.log("Signature length:", sig.length);
const valid = ml_dsa65.verify(dsaKeys.publicKey, msg, sig);
console.log("Signature valid:", valid);

const { cipherText, sharedSecret } = ml_kem768.encapsulate(kemKeys.publicKey);
console.log("KEM Ciphertext length:", cipherText.length);
console.log("KEM Shared Secret length:", sharedSecret.length);

const sharedSecret2 = ml_kem768.decapsulate(cipherText, kemKeys.secretKey);
console.log("Secrets match:", sharedSecret.toString() === sharedSecret2.toString());
