const { expect } = require('chai');
const fs = require('fs/promises');
const path = require('path');
const os = require('os');
const { spawnSync } = require('child_process');

const {
  buildMatchers,
  buildExtensionSet,
  deriveAllowedExtensions,
  collectFiles,
  isBinaryBuffer,
  renderBlock,
  safeOutputFileName,
} = require('../lib/combiner');

describe('combiner helpers', () => {
  it('bounds adversarial glob matching time', () => {
    const script = [
      "const { buildMatchers } = require('./lib/combiner');",
      "const pattern = `${Array.from({ length: 11 }, () => '**/a').join('/')}/b`;",
      "const candidate = Array(30).fill('a').join('/');",
      'if (buildMatchers([pattern])[0].match(candidate)) process.exit(2);',
    ].join('\n');

    const result = spawnSync(process.execPath, ['-e', script], {
      cwd: path.join(__dirname, '..'),
      encoding: 'utf8',
      timeout: 1000,
    });

    expect(result.error, result.error?.message).to.equal(undefined);
    expect(result.status, result.stderr).to.equal(0);
  });

  it('derives allowed extensions from include globs', () => {
    const allowed = deriveAllowedExtensions(['**/*.js', '**/*.swift', '**/*.md']);
    expect(Array.from(allowed).sort()).to.deep.equal(['js', 'md', 'swift']);
  });

  it('skips excluded extensions, large files, and binaries', async () => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), 'combiner-'));
    const outputPath = path.join(root, 'combined.txt');

    await fs.writeFile(path.join(root, 'app.js'), 'console.log("ok");');
    await fs.writeFile(path.join(root, 'notes.txt'), 'notes');
    await fs.writeFile(path.join(root, 'readme.md'), '# readme');
    await fs.writeFile(path.join(root, 'binary.bin'), Buffer.from([0x00, 0x01, 0x02]));
    await fs.writeFile(path.join(root, 'large.txt'), 'x'.repeat(2048));
    await fs.writeFile(outputPath, 'should not be included');

    const includeMatchers = buildMatchers(['**/*']);
    const excludeMatchers = buildMatchers(['**/*.md']);
    const allowedExtensions = buildExtensionSet(['js', 'txt']);
    const excludeExtensions = buildExtensionSet(['bin']);

    const files = await collectFiles(
      root,
      includeMatchers,
      excludeMatchers,
      allowedExtensions,
      excludeExtensions,
      1,
      outputPath
    );

    const relativePaths = files.map((file) => file.relativePath).sort();
    expect(relativePaths).to.deep.equal(['app.js', 'notes.txt']);
  });

  it('bounds aggregate file count and bytes', async () => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), 'combiner-limits-'));
    await fs.writeFile(path.join(root, 'a.txt'), '1234');
    await fs.writeFile(path.join(root, 'b.txt'), '5678');

    const result = await collectFiles(
      root,
      buildMatchers(['**/*']),
      [],
      buildExtensionSet(['txt']),
      new Set(),
      512,
      path.join(root, 'combined.txt'),
      { maxFiles: 1, maxBytes: 4, maxDepth: 8 }
    );

    expect(result).to.have.length(1);
    expect(result.skippedByWorkspaceLimit).to.equal(1);
  });

  it('bounds traversal depth', async () => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), 'combiner-depth-'));
    await fs.mkdir(path.join(root, 'one', 'two'), { recursive: true });
    await fs.writeFile(path.join(root, 'one', 'two', 'deep.txt'), 'deep');

    const result = await collectFiles(
      root,
      buildMatchers(['**/*']),
      [],
      buildExtensionSet(['txt']),
      new Set(),
      512,
      path.join(root, 'combined.txt'),
      { maxFiles: 10, maxBytes: 1024, maxDepth: 1 }
    );

    expect(result).to.deep.equal([]);
    expect(result.skippedByWorkspaceLimit).to.equal(1);
  });

  it('honors cancellation between files in a flat directory', async () => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), 'combiner-cancel-'));
    await fs.writeFile(path.join(root, 'a.txt'), 'a');
    await fs.writeFile(path.join(root, 'b.txt'), 'b');
    const controller = new AbortController();
    const originalStat = require('fs').promises.stat;
    let statCount = 0;
    require('fs').promises.stat = async (...args) => {
      const value = await originalStat(...args);
      statCount += 1;
      if (statCount === 1) controller.abort();
      return value;
    };

    try {
      let cancellationError;
      try {
        await collectFiles(
          root,
          buildMatchers(['**/*']),
          [],
          buildExtensionSet(['txt']),
          new Set(),
          512,
          path.join(root, 'combined.txt'),
          {
            maxFiles: 10,
            maxBytes: 1024,
            maxDepth: 8,
            maxVisitedEntries: 10,
            signal: controller.signal,
          }
        );
      } catch (error) {
        cancellationError = error;
      }
      expect(cancellationError?.message).to.equal('Combination cancelled.');
      expect(statCount).to.equal(1);
    } finally {
      require('fs').promises.stat = originalStat;
    }
  });

  it('fails closed when filtered traversal exceeds its bound', async () => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), 'combiner-visits-'));
    await fs.writeFile(path.join(root, 'b.txt'), 'b');
    await fs.writeFile(path.join(root, 'a.txt'), 'a');
    await fs.writeFile(path.join(root, 'c.log'), 'c');

    let traversalError;
    try {
      await collectFiles(
        root,
        buildMatchers(['**/*']),
        [],
        buildExtensionSet(['txt']),
        new Set(),
        512,
        path.join(root, 'combined.txt'),
        { maxFiles: 1, maxBytes: 1024, maxDepth: 8, maxVisitedEntries: 2 }
      );
    } catch (error) {
      traversalError = error;
    }
    expect(traversalError?.name).to.equal('WorkspaceLimitError');
  });

  it('selects the accepted subset deterministically', async () => {
    const root = await fs.mkdtemp(path.join(os.tmpdir(), 'combiner-order-'));
    await fs.writeFile(path.join(root, 'b.txt'), 'b');
    await fs.writeFile(path.join(root, 'a.txt'), 'a');

    const result = await collectFiles(
      root,
      buildMatchers(['**/*']),
      [],
      buildExtensionSet(['txt']),
      new Set(),
      512,
      path.join(root, 'combined.txt'),
      { maxFiles: 1, maxBytes: 1024, maxDepth: 8, maxVisitedEntries: 10 }
    );
    expect(result.map((file) => file.relativePath)).to.deep.equal(['a.txt']);
  });

  it('detects binary buffers', () => {
    expect(isBinaryBuffer(Buffer.from('plain text'))).to.equal(false);
    expect(isBinaryBuffer(Buffer.from([0x00, 0x61]))).to.equal(true);
  });

  it('renders markdown blocks with language hints', () => {
    const block = renderBlock({ relativePath: 'src/main.swift', content: 'print("hi")' }, 'md');
    expect(block).to.include('```swift');
    expect(block).to.include('## src/main.swift');
  });

  it('constrains configured output names to a file in the chosen root', () => {
    expect(safeOutputFileName('combined_code.txt')).to.equal('combined_code.txt');
    expect(safeOutputFileName('../../outside.txt')).to.equal('outside.txt');
    expect(safeOutputFileName('/tmp/outside.txt')).to.equal('outside.txt');
    expect(safeOutputFileName('')).to.equal('combined_code.txt');
    expect(safeOutputFileName('.')).to.equal('combined_code.txt');
  });
});
