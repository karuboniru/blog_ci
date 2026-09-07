import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("../assets/sidenote-layout.mjs", import.meta.url), "utf8");
const { layoutController, resetHorizontalOffsets } = vm.runInNewContext(
	source + "\n({ layoutController, resetHorizontalOffsets })",
);

function fixture() {
	let translation = "200px 0";
	let scrollbar = false;
	const geometry = { left: 100, width: 1000, noteLeft: 400 };
	const section = {
		getBoundingClientRect: () => ({
			left: geometry.left,
			width: geometry.width - (scrollbar ? 15 : 0),
		}),
	};
	const note = {
		style: {
			get translate() { return translation; },
			set translate(value) { translation = value; scrollbar = false; },
			removeProperty() { translation = ""; scrollbar = true; },
		},
		getBoundingClientRect: () => ({
			left: geometry.noteLeft + (Number.parseFloat(translation) || 0),
			top: 200,
		}),
	};
	return { notes: [note], section, geometry };
}

test("aligns without transient scrollbars or accumulating offsets", () => {
	const controller = fixture();
	for (let pass = 0; pass < 3; pass++) {
		layoutController(controller);
		assert.equal(controller.notes[0].getBoundingClientRect().left, 705);
		assert.equal(controller.notes[0].getBoundingClientRect().top, 200);
	}
});

test("corrects after a width change and clears offsets for mobile", () => {
	const controller = fixture();
	layoutController(controller);
	controller.geometry.width = 1200;
	controller.geometry.noteLeft = 450;
	layoutController(controller);
	assert.equal(controller.notes[0].getBoundingClientRect().left, 826);
	resetHorizontalOffsets(controller);
	assert.equal(controller.notes[0].style.translate, "");
});
