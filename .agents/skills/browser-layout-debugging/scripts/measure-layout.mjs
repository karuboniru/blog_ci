#!/usr/bin/env node

const defaults = {
  browser: "",
  port: "",
  urlSubstring: "",
  selectors: "body",
  styles: "display,position,float,width,marginRight,paddingInlineStart",
  timeoutMs: "10000",
};

function usage() {
  console.error(`Usage:
  measure-layout.mjs --browser chrome|firefox --port PORT [options]

Options:
  --url-substring TEXT   Select the open page whose URL contains TEXT
  --selectors LIST       Comma-separated CSS selectors (default: body)
  --styles LIST          Comma-separated computed-style properties
  --timeout-ms NUMBER    Connection/request timeout (default: 10000)`);
}

function parseArgs(argv) {
  const options = { ...defaults };
  const keyMap = {
    "browser": "browser",
    "port": "port",
    "url-substring": "urlSubstring",
    "selectors": "selectors",
    "styles": "styles",
    "timeout-ms": "timeoutMs",
  };

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--help" || argument === "-h") {
      usage();
      process.exit(0);
    }
    if (!argument.startsWith("--")) {
      throw new Error(`Unexpected argument: ${argument}`);
    }

    const equalsIndex = argument.indexOf("=");
    const rawKey = argument.slice(2, equalsIndex === -1 ? undefined : equalsIndex);
    const key = keyMap[rawKey];
    if (!key) {
      throw new Error(`Unknown option: --${rawKey}`);
    }

    const value = equalsIndex === -1 ? argv[++index] : argument.slice(equalsIndex + 1);
    if (!value || value.startsWith("--")) {
      throw new Error(`Missing value for --${rawKey}`);
    }
    options[key] = value;
  }

  if (!["chrome", "firefox"].includes(options.browser)) {
    throw new Error("--browser must be chrome or firefox");
  }
  if (!/^\d+$/.test(options.port)) {
    throw new Error("--port must be a positive integer");
  }
  const timeoutMs = Number(options.timeoutMs);
  if (!Number.isFinite(timeoutMs) || timeoutMs <= 0) {
    throw new Error("--timeout-ms must be a positive number");
  }

  return {
    ...options,
    timeoutMs,
    selectors: options.selectors.split(",").map((value) => value.trim()).filter(Boolean),
    styles: options.styles.split(",").map((value) => value.trim()).filter(Boolean),
  };
}

function withTimeout(promise, timeoutMs, label) {
  let timeout;
  const rejected = new Promise((_, reject) => {
    timeout = setTimeout(() => reject(new Error(`${label} timed out after ${timeoutMs}ms`)), timeoutMs);
  });
  return Promise.race([promise, rejected]).finally(() => clearTimeout(timeout));
}

async function openSocket(url, timeoutMs) {
  return withTimeout(new Promise((resolve, reject) => {
    const socket = new WebSocket(url);
    socket.addEventListener("open", () => resolve(socket), { once: true });
    socket.addEventListener("error", () => reject(new Error(`Could not connect to ${url}`)), { once: true });
  }), timeoutMs, `WebSocket connection to ${url}`);
}

function createRpc(socket) {
  let nextId = 1;
  const pending = new Map();

  socket.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);
    if (message.id === undefined || !pending.has(message.id)) {
      return;
    }
    const { resolve, reject } = pending.get(message.id);
    pending.delete(message.id);
    if (message.type === "error" || message.error) {
      reject(new Error(JSON.stringify(message)));
    } else {
      resolve(message.result);
    }
  });

  return (method, params = {}) => new Promise((resolve, reject) => {
    const id = nextId++;
    pending.set(id, { resolve, reject });
    socket.send(JSON.stringify({ id, method, params }));
  });
}

function probeExpression(selectors, styleNames) {
  return `JSON.stringify((() => {
    const selectors = ${JSON.stringify(selectors)};
    const styleNames = ${JSON.stringify(styleNames)};
    const elements = {};
    for (const selector of selectors) {
      elements[selector] = [...document.querySelectorAll(selector)].map((element) => {
        const rectangle = element.getBoundingClientRect();
        const computed = getComputedStyle(element);
        return {
          tag: element.tagName,
          id: element.id,
          className: element.className,
          rect: {
            x: rectangle.x,
            y: rectangle.y,
            top: rectangle.top,
            right: rectangle.right,
            bottom: rectangle.bottom,
            left: rectangle.left,
            width: rectangle.width,
            height: rectangle.height,
          },
          styles: Object.fromEntries(styleNames.map((name) => [name, computed[name]])),
        };
      });
    }
    return {
      url: location.href,
      userAgent: navigator.userAgent,
      viewport: { width: innerWidth, height: innerHeight, devicePixelRatio },
      elements,
    };
  })())`;
}

function flattenContexts(contexts) {
  return contexts.flatMap((context) => [context, ...flattenContexts(context.children || [])]);
}

function selectByUrl(items, urlSubstring, getUrl) {
  const candidates = items.filter((item) => {
    const url = getUrl(item);
    return url && !url.startsWith("chrome-extension:") && !url.startsWith("about:");
  });
  const selected = urlSubstring
    ? candidates.find((item) => getUrl(item).includes(urlSubstring))
    : candidates[0];
  if (!selected) {
    throw new Error(`No open page matched ${JSON.stringify(urlSubstring)}`);
  }
  return selected;
}

async function measureChrome(options, expression) {
  const response = await withTimeout(
    fetch(`http://127.0.0.1:${options.port}/json/list`),
    options.timeoutMs,
    "Chrome target discovery",
  );
  if (!response.ok) {
    throw new Error(`Chrome target discovery returned HTTP ${response.status}`);
  }
  const targets = await response.json();
  const target = selectByUrl(
    targets.filter((item) => item.type === "page"),
    options.urlSubstring,
    (item) => item.url,
  );
  const socket = await openSocket(target.webSocketDebuggerUrl, options.timeoutMs);
  const call = createRpc(socket);
  try {
    const result = await withTimeout(
      call("Runtime.evaluate", { expression, returnByValue: true }),
      options.timeoutMs,
      "Chrome Runtime.evaluate",
    );
    if (result.exceptionDetails) {
      throw new Error(result.exceptionDetails.text || "Chrome evaluation failed");
    }
    return JSON.parse(result.result.value);
  } finally {
    socket.close();
  }
}

async function measureFirefox(options, expression) {
  const socket = await openSocket(`ws://127.0.0.1:${options.port}/session`, options.timeoutMs);
  const call = createRpc(socket);
  let sessionStarted = false;
  try {
    await withTimeout(call("session.new", { capabilities: {} }), options.timeoutMs, "Firefox session.new");
    sessionStarted = true;
    const tree = await withTimeout(call("browsingContext.getTree", {}), options.timeoutMs, "Firefox context discovery");
    const context = selectByUrl(flattenContexts(tree.contexts), options.urlSubstring, (item) => item.url);
    const result = await withTimeout(call("script.evaluate", {
      expression,
      target: { context: context.context },
      awaitPromise: false,
      resultOwnership: "none",
    }), options.timeoutMs, "Firefox script.evaluate");
    if (result.result.type !== "string") {
      throw new Error(`Unexpected Firefox result: ${JSON.stringify(result.result)}`);
    }
    return JSON.parse(result.result.value);
  } finally {
    if (sessionStarted) {
      try {
        await withTimeout(call("session.end", {}), options.timeoutMs, "Firefox session.end");
      } catch (error) {
        console.error(`Warning: ${error.message}`);
      }
    }
    socket.close();
  }
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const expression = probeExpression(options.selectors, options.styles);
  const result = options.browser === "chrome"
    ? await measureChrome(options, expression)
    : await measureFirefox(options, expression);
  console.log(JSON.stringify(result, null, 2));
}

main().catch((error) => {
  console.error(`measure-layout: ${error.message}`);
  process.exitCode = 1;
});
