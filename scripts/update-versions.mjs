#!/usr/bin/env node

import { appendFile, writeFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const versionsFile = path.join(repoRoot, 'versions.env');

async function githubJson(url) {
    const response = await fetch(url, {
        headers: { Accept: 'application/vnd.github+json', 'User-Agent': 'openchamber-docker-updater' },
    });
    if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
    return response.json();
}

function stableTag(release, project) {
    if (!/^v\d+\.\d+\.\d+$/.test(release.tag_name || '')) {
        throw new Error(`${project} latest release is not a stable semver tag: ${release.tag_name}`);
    }
    return release.tag_name;
}

function assetDigest(release, name) {
    const digest = release.assets?.find((asset) => asset.name === name)?.digest;
    if (!/^sha256:[0-9a-f]{64}$/.test(digest || '')) {
        throw new Error(`Missing SHA-256 digest for ${name}`);
    }
    return digest.slice('sha256:'.length);
}

const [openchamberRelease, opencodeRelease] = await Promise.all([
    githubJson('https://api.github.com/repos/openchamber/openchamber/releases/latest'),
    githubJson('https://api.github.com/repos/anomalyco/opencode/releases/latest'),
]);

const openchamberRef = stableTag(openchamberRelease, 'OpenChamber');
const opencodeRef = stableTag(opencodeRelease, 'OpenCode');
const openchamberVersion = openchamberRef.slice(1);

const content = [
    `OPENCHAMBER_VERSION=${openchamberVersion}`,
    `OPENCHAMBER_PACKAGE_SHA256=${assetDigest(openchamberRelease, `openchamber-web-${openchamberVersion}.tgz`)}`,
    `OPENCODE_VERSION=${opencodeRef.slice(1)}`,
    `OPENCODE_AMD64_SHA256=${assetDigest(opencodeRelease, 'opencode-linux-x64-musl.tar.gz')}`,
    '',
].join('\n');

await writeFile(versionsFile, content);

if (process.env.GITHUB_OUTPUT) {
    let changed = true;
    try {
        execFileSync('git', ['diff', '--quiet', '--', 'versions.env'], { cwd: repoRoot });
        changed = false;
    } catch (error) {
        if (error.status !== 1) throw error;
    }
    await appendFile(process.env.GITHUB_OUTPUT, `changed=${changed}\n`);
}
