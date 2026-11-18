const fs = require('fs/promises');
const os = require('os');
const path = require('path');
const { pathToFileURL } = require('url');
const { spawn } = require('child_process');

function sofficeCommand() {
  const configured = String(process.env.SOFFICE_PATH || '').trim();
  if (configured) return configured;

  // Linux containers normally expose `soffice` on PATH. Windows local
  // development installs it in one of these locations instead. Use the
  // console launcher on Windows: soffice.exe is a GUI launcher and can exit
  // with code 1 when Node starts it headlessly.
  const windowsCandidates = [
    'C:\\Program Files\\LibreOffice\\program\\soffice.com',
    'C:\\Program Files (x86)\\LibreOffice\\program\\soffice.com',
    'C:\\Program Files\\LibreOffice\\program\\soffice.exe',
    'C:\\Program Files (x86)\\LibreOffice\\program\\soffice.exe',
  ];
  return windowsCandidates.find((candidate) => require('fs').existsSync(candidate)) || 'soffice';
}

function run(command, args, cwd) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { cwd, windowsHide: true });
    let stderr = '';
    const timer = setTimeout(() => {
      child.kill('SIGKILL');
      reject(new Error('Report rendering timed out.'));
    }, 90000);
    child.stderr.on('data', (chunk) => { stderr += chunk; });
    child.on('error', (error) => { clearTimeout(timer); reject(error); });
    child.on('close', (code) => {
      clearTimeout(timer);
      if (code === 0) return resolve();
      return reject(new Error(stderr.trim() || `${command} exited with code ${code}.`));
    });
  });
}

async function withRenderedPpt(pptBuffer, work) {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'godigital-full-report-'));
  try {
    const pptPath = path.join(directory, 'full-report.pptx');
    const pdfPath = path.join(directory, 'full-report.pdf');
    await fs.writeFile(pptPath, pptBuffer);
    try {
      // Give each conversion an isolated LibreOffice profile. A shared or
      // locked desktop profile causes headless soffice to terminate on
      // Windows even when the executable itself is installed correctly.
      const profile = path.join(directory, 'libreoffice-profile');
      await fs.mkdir(profile);
      await run(sofficeCommand(), [
        `-env:UserInstallation=${pathToFileURL(profile).href}`,
        '--headless',
        '--nologo',
        '--nodefault',
        '--nolockcheck',
        '--norestore',
        '--convert-to',
        'pdf:impress_pdf_Export',
        '--outdir',
        directory,
        pptPath,
      ], directory);
      await fs.access(pdfPath);
    } catch (error) {
      if (error?.code === 'ENOENT') {
        throw new Error('PDF and Word export require LibreOffice on the server. Install LibreOffice or set SOFFICE_PATH, then restart the backend. PowerPoint export does not require LibreOffice.');
      }
      throw error;
    }
    return await work({ directory, pdfPath, pdf: await fs.readFile(pdfPath) });
  } finally {
    await fs.rm(directory, { recursive: true, force: true });
  }
}

async function renderPdfPages(pdfPath, directory) {
  const prefix = path.join(directory, 'page');
  await run('pdftoppm', ['-png', '-r', '150', pdfPath, prefix], directory);
  const pages = (await fs.readdir(directory))
    .filter((name) => /^page-\d+\.png$/.test(name))
    .sort((a, b) => Number(a.match(/\d+/)[0]) - Number(b.match(/\d+/)[0]));
  return Promise.all(pages.map((name) => fs.readFile(path.join(directory, name))));
}

module.exports = { withRenderedPpt, renderPdfPages };
