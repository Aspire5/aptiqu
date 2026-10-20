// Runtime target verified against Node's release/security notices on 20 Oct 2026.
export function assertSupportedRuntime(version: string) {
    const [major, minor, patch] = version.split('.').map(Number);
    if (!(major === 22 && (minor > 23 || minor === 23 && patch >= 3) || major === 24 && minor >= 22))
        throw Object.assign(new Error('Production requires a supported patched Node.js 22 or 24 release; see backend/.nvmrc'), { code: 'RUNTIME_UNSUPPORTED' });
}
