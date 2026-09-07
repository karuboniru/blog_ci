const DESKTOP_QUERY = "(min-width: 761px)";
const SIDENOTE_INLINE_START = 0.605;
const POSITION_EPSILON = 0.05;

function createController(section) {
	const notes = [...section.querySelectorAll(".marginnote")];
	return notes.length > 0 ? { notes, section } : null;
}

function resetHorizontalOffsets(controller) {
	controller.notes.forEach((note) => note.style.removeProperty("translate"));
}

function layoutController(controller) {
	const { notes, section } = controller;

	const sectionRectangle = section.getBoundingClientRect();
	const targetLeft =
		sectionRectangle.left + sectionRectangle.width * SIDENOTE_INLINE_START;
	const measurements = notes.map((note) => ({
		left: note.getBoundingClientRect().left,
		offset: Number.parseFloat(note.style.translate) || 0,
		note,
	}));

	// Clearing translations can introduce scrollbars and change the width we
	// are measuring. Correct the current position without that intermediate state.
	measurements.forEach(({ left, offset, note }) => {
		const correction = targetLeft - left;
		if (Math.abs(correction) > POSITION_EPSILON) {
			note.style.translate = `${offset + correction}px 0`;
		}
	});
}

function init() {
	const controllers = [...document.querySelectorAll("article > section")]
		.map(createController)
		.filter(Boolean);
	if (controllers.length === 0) return;

	const desktopQuery = window.matchMedia(DESKTOP_QUERY);
	let layoutFrame = 0;
	const layoutAll = () => {
		layoutFrame = 0;
		controllers.forEach(layoutController);
	};
	const scheduleLayout = () => {
		if (!desktopQuery.matches || layoutFrame) return;
		layoutFrame = requestAnimationFrame(layoutAll);
	};
	const syncMode = () => {
		if (layoutFrame) cancelAnimationFrame(layoutFrame);
		layoutFrame = 0;

		if (desktopQuery.matches) {
			scheduleLayout();
		} else {
			controllers.forEach(resetHorizontalOffsets);
		}
	};

	const noteObserver =
		typeof ResizeObserver === "function"
			? new ResizeObserver(scheduleLayout)
			: null;
	controllers.forEach((controller) => {
		noteObserver?.observe(controller.section);
		controller.notes.forEach((note) => noteObserver?.observe(note));
		controller.section.addEventListener("load", scheduleLayout, true);
		controller.section.addEventListener("toggle", scheduleLayout, true);
	});

	desktopQuery.addEventListener("change", syncMode);
	window.addEventListener("resize", scheduleLayout, { passive: true });
	window.addEventListener("pageshow", scheduleLayout);
	window.visualViewport?.addEventListener("resize", scheduleLayout, {
		passive: true,
	});
	document.fonts?.ready.then(scheduleLayout);
	document.fonts?.addEventListener("loadingdone", scheduleLayout);

	syncMode();
}

if (typeof document !== "undefined") {
	if (document.readyState === "loading") {
		document.addEventListener("DOMContentLoaded", init);
	} else {
		init();
	}
}
