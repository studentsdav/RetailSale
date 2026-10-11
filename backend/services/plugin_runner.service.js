"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.transpileTypeScript = transpileTypeScript;
exports.executePluginScript = executePluginScript;
const vm_1 = __importDefault(require("vm"));
const http_1 = __importDefault(require("http"));
const https_1 = __importDefault(require("https"));
const url_1 = require("url");
// In-memory key-value cache per plugin instance
const pluginMemStorage = new Map();
/**
 * Perform safe HTTP request without heavy external dependency
 */
function makeHttpRequest(method, requestUrl, body, headers = {}, redirectCount = 0) {
    return new Promise((resolve, reject) => {
        if (redirectCount > 5) {
            return reject(new Error(`Too many redirects (max 5) when requesting ${requestUrl}`));
        }
        try {
            const parsed = new url_1.URL(requestUrl);
            const isHttps = parsed.protocol === 'https:';
            const client = isHttps ? https_1.default : http_1.default;
            const postData = body ? (typeof body === 'string' ? body : JSON.stringify(body)) : undefined;
            if (postData && !headers['Content-Type']) {
                headers['Content-Type'] = 'application/json';
            }
            if (postData && !headers['Content-Length']) {
                headers['Content-Length'] = Buffer.byteLength(postData).toString();
            }
            const options = {
                method,
                hostname: parsed.hostname,
                port: parsed.port || (isHttps ? 443 : 80),
                path: `${parsed.pathname}${parsed.search}`,
                headers,
                timeout: 10000 // 10s max
            };
            const req = client.request(options, (res) => {
                // Automatically follow 301, 302, 307, 308 redirects (e.g. Shopify custom domain to myshopify.com)
                if ([301, 302, 307, 308].includes(res.statusCode || 0) && res.headers.location) {
                    let redirectLocation = res.headers.location;
                    if (!redirectLocation.startsWith('http://') && !redirectLocation.startsWith('https://')) {
                        redirectLocation = new url_1.URL(redirectLocation, requestUrl).toString();
                    }
                    return resolve(makeHttpRequest(method, redirectLocation, body, headers, redirectCount + 1));
                }
                let data = '';
                res.on('data', chunk => { data += chunk; });
                res.on('end', () => {
                    let parsedData = data;
                    try {
                        parsedData = JSON.parse(data);
                    }
                    catch (_) { }
                    resolve({
                        status: res.statusCode,
                        headers: res.headers,
                        data: parsedData
                    });
                });
            });
            req.on('error', (err) => reject(err));
            req.on('timeout', () => {
                req.destroy();
                reject(new Error(`Request to ${requestUrl} timed out after 10000ms`));
            });
            if (postData) {
                req.write(postData);
            }
            req.end();
        }
        catch (err) {
            reject(err);
        }
    });
}
/**
 * Transpile TypeScript to JavaScript on the fly
 */
function transpileTypeScript(tsCode) {
    try {
        let tsCompiler = null;
        try {
            tsCompiler = require("typescript");
        } catch (_) {}
        if (tsCompiler && typeof tsCompiler.transpileModule === 'function') {
            return tsCompiler.transpileModule(tsCode, {
                compilerOptions: {
                    module: tsCompiler.ModuleKind?.CommonJS ?? 1,
                    target: tsCompiler.ScriptTarget?.ES2020 ?? 7,
                    removeComments: true,
                    strict: false,
                    esModuleInterop: true
                }
            }).outputText;
        }
    }
    catch (_) { }
    // Precise TypeScript stripping for JavaScript VM execution
    let js = tsCode
        // 1. Convert ES modules export default to CommonJS
        .replace(/export\s+default\s+/g, 'module.exports.default = ')
        // 2. Remove interfaces and type aliases
        .replace(/export\s+interface\s+[\s\S]*?}/g, '')
        .replace(/export\s+type\s+[\s\S]*?;/g, '')
        // 3. Remove type annotations on function / method declarations: async onInit(a: any, b: any): Promise<any> {
        .replace(/([A-Za-z0-9_]+)\s*\(([^)]*)\)\s*(:\s*[A-Za-z0-9_<>\[\]|&\s]+)?\s*\{/g, (_match, fn, params) => {
        const cleanParams = params.replace(/:\s*[A-Za-z0-9_<>\[\]|&]+/g, '');
        return `${fn}(${cleanParams}) {`;
    })
        // 4. Remove variable type annotations: const x: string = 'y' -> const x = 'y'
        .replace(/(const|let|var)\s+([A-Za-z0-9_]+)\s*:\s*[A-Za-z0-9_<>\[\]|&]+\s*=/g, '$1 $2 =')
        // 5. Remove type casts: as any, as string
        .replace(/\s+as\s+[A-Za-z0-9_<>\[\]|&]+/g, '');
    return js;
}
/**
 * Executes a hook on a plugin code bundle in a secure sandbox
 */
async function executePluginScript(code, language, hookName, payload = {}, config = {}, outletId = 0, pluginId = 'plugin') {
    const startTime = Date.now();
    const logs = [];
    const logger = {
        info: (msg) => { logs.push(`[INFO] ${new Date().toISOString()}: ${msg}`); },
        warn: (msg) => { logs.push(`[WARN] ${new Date().toISOString()}: ${msg}`); },
        error: (msg) => { logs.push(`[ERROR] ${new Date().toISOString()}: ${msg}`); }
    };
    if (!pluginMemStorage.has(pluginId)) {
        pluginMemStorage.set(pluginId, new Map());
    }
    const memStore = pluginMemStorage.get(pluginId);
    const storage = {
        get: (k) => memStore.get(k),
        set: (k, v) => memStore.set(k, v)
    };
    const httpClient = {
        get: (url, options) => makeHttpRequest('GET', url, undefined, options?.headers || {}),
        post: (url, body, options) => makeHttpRequest('POST', url, body, options?.headers || {})
    };
    const context = {
        outletId,
        config,
        logger,
        http: httpClient,
        storage
    };
    try {
        // Step 1: Transpile if TS
        let executableJs = code;
        if (language === 'typescript') {
            executableJs = transpileTypeScript(code);
        }
        // Step 2: Prepare Sandbox
        const sandbox = {
            module: { exports: {} },
            exports: {},
            console: {
                log: (...args) => logger.info(args.map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ')),
                warn: (...args) => logger.warn(args.map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ')),
                error: (...args) => logger.error(args.map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' '))
            },
            Buffer,
            setTimeout,
            clearTimeout,
            URL: url_1.URL,
            Date,
            Math,
            JSON
        };
        sandbox.global = sandbox;
        sandbox.window = sandbox;
        vm_1.default.createContext(sandbox);
        // Step 3: Run the code to load exports
        const script = new vm_1.default.Script(executableJs, {
            filename: `${pluginId}.vm.js`,
        });
        script.runInContext(sandbox, { timeout: 5000 }); // 5s compilation/eval timeout
        // Check module.exports.default, module.exports, exports, and top-level sandbox functions
        const candidateExports = [
            sandbox.module?.exports?.default,
            sandbox.module?.exports,
            sandbox.exports?.default,
            sandbox.exports
        ];
        let targetHook = null;
        for (const candidate of candidateExports) {
            if (candidate && typeof candidate === 'object' && typeof candidate[hookName] === 'function') {
                targetHook = candidate[hookName];
                break;
            }
        }
        if (!targetHook && typeof sandbox[hookName] === 'function') {
            targetHook = sandbox[hookName];
        }
        if (!targetHook && typeof sandbox.global?.[hookName] === 'function') {
            targetHook = sandbox.global[hookName];
        }
        if (!targetHook || typeof targetHook !== 'function') {
            logger.warn(`Hook "${hookName}" is not implemented by plugin ${pluginId}.`);
            return {
                success: true,
                result: null,
                logs,
                executionTimeMs: Date.now() - startTime
            };
        }
        // Step 4: Execute the hook function
        const hookResult = await Promise.resolve(targetHook(context, payload));
        return {
            success: true,
            result: hookResult,
            logs,
            executionTimeMs: Date.now() - startTime
        };
    }
    catch (err) {
        logger.error(`Execution error: ${err.message}`);
        return {
            success: false,
            error: err.message,
            logs,
            executionTimeMs: Date.now() - startTime
        };
    }
}
module.exports = {
    transpileTypeScript,
    executePluginScript
};
exports.default = module.exports;
