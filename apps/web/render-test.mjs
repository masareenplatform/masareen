import { JSDOM } from "jsdom";
import fs from "fs";

const jsPath = "dist/assets/" + fs.readdirSync("dist/assets").find(f => f.endsWith(".js"));
const code = fs.readFileSync(jsPath, "utf8");

const errors = [];
const dom = new JSDOM(`<!DOCTYPE html><html><body><div id="root"></div></body></html>`, {
  runScripts: "outside-only",
  url: "http://masareen.mediahubnetwork.net/",
  pretendToBeVisual: true,
});
const { window } = dom;
window.matchMedia = window.matchMedia || (() => ({ matches: false, addListener(){}, removeListener(){}, addEventListener(){}, removeEventListener(){} }));
window.scrollTo = () => {};
window.addEventListener("error", e => errors.push("window.error: " + (e.error?.stack || e.message)));
const origErr = console.error;
console.error = (...a) => { errors.push("console.error: " + a.map(String).join(" ")); };

try {
  const fn = new dom.window.Function(code);
  fn.call(window);
} catch (e) {
  errors.push("THROW: " + (e.stack || e.message));
}
// give microtasks a tick
await new Promise(r => setTimeout(r, 300));
const rootHtml = window.document.getElementById("root").innerHTML;
console.log("=== ROOT LENGTH:", rootHtml.length, "===");
console.log("=== ROOT SNIPPET ===");
console.log(rootHtml.slice(0, 600));
console.log("=== ERRORS (" + errors.length + ") ===");
errors.slice(0, 10).forEach(e => console.log(e.slice(0, 500)));
