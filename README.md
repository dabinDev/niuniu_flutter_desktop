# niuniu_flutter_desktop

Flutter desktop/web client for the NiuNiu market workstation.

## Configuration

The client does not commit a production API host, download host, or private
keys. Provide the API endpoint at build/run time with `NIUNIU_API_BASE_URL`, or
pass `-ApiBaseUrl` to the helper PowerShell scripts. Provide an optional desktop
client download link with `NIUNIU_CLIENT_DOWNLOAD_URL` or `-ClientDownloadUrl`.

Private certificates, local runtime logs, `.env` files, and build artifacts are
ignored by git.
