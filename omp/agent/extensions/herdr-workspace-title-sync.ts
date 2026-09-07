// @ts-nocheck

const paneId = process.env.HERDR_PANE_ID;
const enabled = process.env.HERDR_ENV === "1" && !!paneId;

export default function (pi) {
  if (!enabled) return;

  const herdr = process.env.HERDR_BIN_PATH || "herdr";
  let workspaceId;
  let lastTitle;
  let syncing = false;
  let timerStarted = false;

  async function resolveWorkspace() {
    if (workspaceId) return workspaceId;
    const result = await pi.exec(herdr, ["pane", "get", paneId], { timeout: 3000 });
    if (result.code !== 0) return;
    workspaceId = JSON.parse(result.stdout).result?.pane?.workspace_id;
    return workspaceId;
  }

  async function syncTitle() {
    const title = pi.getSessionName()?.trim();
    if (!title || title === lastTitle || syncing) return;

    syncing = true;
    try {
      const targetWorkspace = await resolveWorkspace();
      if (!targetWorkspace) return;
      const result = await pi.exec(herdr, ["workspace", "rename", targetWorkspace, title], {
        timeout: 3000,
      });
      if (result.code === 0) lastTitle = title;
    } finally {
      syncing = false;
    }
  }

  function startSync(ctx) {
    if (!timerStarted) {
      timerStarted = true;
      ctx.setInterval(syncTitle, 500);
    }
    ctx.setTimeout(syncTitle, 100);
  }

  pi.on("session_start", (_event, ctx) => startSync(ctx));
  pi.on("input", (_event, ctx) => startSync(ctx));

  pi.on("session_switch", () => {
    lastTitle = undefined;
    void syncTitle();
  });
}
