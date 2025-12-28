"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
var ml_kem_js_1 = require("@noble/post-quantum/ml-kem.js");
console.log("Imports worked!");
var keys = ml_kem_js_1.ml_kem768.keygen();
console.log("Keygen worked!");
