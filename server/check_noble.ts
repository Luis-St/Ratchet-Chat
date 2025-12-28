
import { ml_kem768 } from '@noble/post-quantum/ml-kem.js';

console.log("Imports worked!");
const keys = ml_kem768.keygen();
console.log("Keygen worked!");
