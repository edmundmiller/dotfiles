import { Worker } from "node:worker_threads";

/** Match JavaScript regex rules off the UI thread, with a bounded execution time. */
export function matchThimbleRegex(
  rule: string,
  texts: readonly string[],
  signal?: AbortSignal
): Promise<Array<{ index: number; text: string } | null>> {
  signal?.throwIfAborted();
  return new Promise((resolve, reject) => {
    // The worker runs fixed code, never a rule as JavaScript source. A pathological
    // regex can be terminated without blocking Pi's event loop or cancellation.
    const worker = new Worker(
      `const { parentPort, workerData } = require('node:worker_threads');
       try {
         const regex = new RegExp(workerData.rule, 'u');
         parentPort.postMessage({ matches: workerData.texts.map(text => {
           const hit = regex.exec(text);
           return hit ? { index: hit.index, text: hit[0] } : null;
         }) });
       } catch (error) { parentPort.postMessage({ error: String(error.message) }); }`,
      { eval: true, workerData: { rule, texts } }
    );
    const finish = () => {
      clearTimeout(timer);
      signal?.removeEventListener("abort", abort);
      void worker.terminate();
    };
    const abort = () => {
      finish();
      reject(signal?.reason ?? new Error("Thimble regex cancelled"));
    };
    const timer = setTimeout(() => {
      finish();
      reject(new Error("Thimble regex exceeded 5 seconds. Use a simpler pattern."));
    }, 5000);
    signal?.addEventListener("abort", abort, { once: true });
    worker.once(
      "message",
      (result: { error?: string; matches: Array<{ index: number; text: string } | null> }) => {
        finish();
        if (result.error) reject(new Error(`Thimble regex does not compile: ${result.error}`));
        else resolve(result.matches);
      }
    );
    worker.once("error", (error) => {
      finish();
      reject(error);
    });
    worker.once("exit", (code) => {
      if (code !== 0) {
        finish();
        reject(new Error(`Thimble regex worker exited with status ${code}`));
      }
    });
  });
}
