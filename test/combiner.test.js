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

  it('detects binary buffers', () => {
    expect(isBinaryBuffer(Buffer.from('plain text'))).to.equal(false);
    expect(isBinaryBuffer(Buffer.from([0x00, 0x61]))).to.equal(true);
  });

  it('renders markdown blocks with language hints', () => {
    const block = renderBlock({ relativePath: 'src/main.swift', content: 'print("hi")' }, 'md');
    expect(block).to.include('```swift');
    expect(block).to.include('## src/main.swift');
  });
});
