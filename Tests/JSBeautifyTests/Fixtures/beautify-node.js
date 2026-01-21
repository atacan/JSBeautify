#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const assetsDir = process.argv[2];
const mode = process.argv[3];
const inputPath = process.argv[4];
const optionsPath = process.argv[5];

if (!assetsDir || !mode || !inputPath) {
  console.error("Usage: beautify-node.js <assetsDir> <mode> <inputPath> [optionsPath]");
  process.exit(1);
}

const input = fs.readFileSync(inputPath, "utf8");
const options = optionsPath ? JSON.parse(fs.readFileSync(optionsPath, "utf8")) : {};

const ctx = {};
vm.createContext(ctx);
vm.runInContext("var window=this; var global=this; var self=this;", ctx);

const jsSource = fs.readFileSync(path.join(assetsDir, "beautify.min.js"), "utf8");
const cssSource = fs.readFileSync(path.join(assetsDir, "beautify-css.min.js"), "utf8");
const htmlSource = fs.readFileSync(path.join(assetsDir, "beautify-html.min.js"), "utf8");

vm.runInContext(jsSource, ctx);
vm.runInContext(cssSource, ctx);
vm.runInContext(htmlSource, ctx);

let result;
if (mode === "js") {
  result = ctx.js_beautify(input, options);
} else if (mode === "css") {
  result = ctx.css_beautify(input, options);
} else if (mode === "html") {
  result = ctx.html_beautify(input, options);
} else {
  console.error("Unknown mode:", mode);
  process.exit(1);
}

process.stdout.write(JSON.stringify(result));
