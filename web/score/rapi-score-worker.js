/* Fixed party calculator. All assets and computation stay on this origin. */
'use strict';
importScripts('./pyodide-0.29.3/pyodide.js');

self.onmessage = async ({ data }) => {
  try {
    const py = await loadPyodide({
      indexURL: new URL('./pyodide-0.29.3/', self.location.href).href,
      stdout: () => {}, stderr: message => console.debug(message),
    });
    const response = await fetch(new URL('./rapi-engine.zip', self.location.href));
    if (!response.ok) throw new Error(`Engine asset HTTP ${response.status}`);
    py.unpackArchive(await response.arrayBuffer(), 'zip', { extractDir: '/mimir' });
    py.globals.set('rapi_spec_json', data);
    const score = py.runPython(`
import json, sys
sys.path[:0] = ['/mimir', '/mimir/engine']
from services.nikke_score.embedded import calculate_nikke_score
calculate_nikke_score(json.loads(rapi_spec_json), '/mimir/engine')
`);
    if (typeof score !== 'number' || !Number.isFinite(score) || score < 0) {
      throw new Error('Invalid score');
    }
    self.postMessage(JSON.stringify({ score }));
  } catch (error) {
    console.error('Nikke score calculation failed', error);
    self.postMessage(JSON.stringify({ error: 'score_unavailable' }));
  }
};
