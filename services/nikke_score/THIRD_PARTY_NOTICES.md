# Third-party sources

The calculator is fetched at the commit in `engine_lock.json`. Its original `LICENSE` remains in the engine checkout and in the container image. The fixed growth profiles derive from that calculator's defaults.

Source: https://github.com/Jgaram/nikke-calc

MIT License

Copyright (c) 2026 Jgaram

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

The enikk GraphQL field layout was checked against Jgaram/nikke-analysis
(`a5b00ff1da716364cd9c8e44de82c8c8e1f1fa31`, CC0 1.0) and a direct response from
https://enikk.app/api/graphql. Stored aggregation metadata credits enikk as
the data provider. No nikke-calc-app code was copied.

## Embedded web runtime

The web app ships unmodified Pyodide 0.29.3 runtime files from the official npm
`pyodide@0.29.3` package. Pyodide is licensed under MPL-2.0; the license is in
`web/score/pyodide-0.29.3/LICENSE`. Corresponding source is available at
https://github.com/pyodide/pyodide/tree/0.29.3 .

The included CPython 3.13.2 standard library/runtime is covered by the license
in `web/score/pyodide-0.29.3/LICENSE-PYTHON`; source is available at
https://github.com/python/cpython/tree/v3.13.2 .

The engine's original MIT license is also included inside `rapi-engine.zip`.
`web/score/bundle-manifest.json` records the exact shipped files and hashes.
