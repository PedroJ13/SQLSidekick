const DOCUMENTATION_GROUPS = [
  {
    title: "Server",
    collapsed: true,
    names: [
      "server_overview",
      "server_properties",
      "server_databases_summary",
      "server_runtime",
      "server_configurations",
      "server_services",
      "server_logins",
      "server_role_members",
      "server_endpoints",
      "linked_servers",
      "availability_groups",
    ],
  },
  {
    title: "Database",
    names: [
      "database_overview",
      "database_properties",
      "database_scoped_configurations",
      "database_extended_properties",
    ],
  },
  { title: "Storage", names: ["database_files", "filegroups", "space_usage"] },
  { title: "Structure", names: ["schemas", "tables", "columns", "indexes", "foreign_keys"] },
  { title: "Constraints", names: ["key_constraints", "check_constraints", "default_constraints"] },
  { title: "SQL Code", names: ["views", "procedures", "functions", "triggers"] },
  {
    title: "Security",
    names: ["database_principals", "database_roles", "database_role_members", "database_permissions"],
  },
  {
    title: "Jobs",
    names: ["sql_agent_jobs", "sql_agent_job_steps", "sql_agent_job_schedules", "sql_agent_job_history"],
  },
  { title: "Analysis", names: ["review_findings", "index_usage", "index_physical_stats", "missing_indexes", "statistics"] },
];

const PROCESS_GROUPS = [
  {
    title: "Lineage maps",
    names: ["job_lineage_map", "procedure_lineage_map", "view_lineage_map", "function_lineage_map"],
  },
];

const LIVE_GROUPS = [
  {
    title: "Dashboard",
    names: ["live_dashboard"],
  },
  {
    title: "Current activity",
    names: ["live_current_requests", "live_session_resource_usage", "live_blocking", "live_root_blockers", "live_active_waits"],
  },
  {
    title: "Resource pressure",
    names: ["live_tempdb_usage", "live_log_usage"],
  },
];

const HEALTH_GROUPS = [
  {
    title: "Overview",
    names: ["health_dashboard"],
  },
];

const NAV_AREAS = [
  {
    id: "documentation",
    title: "Documentation",
    pill: "Documentation module",
    heading: "Documentation",
    emptyTitle: "Choose a section",
    emptyDescription: "Select a documentation group from the left menu to review the discovered characteristics.",
    groups: DOCUMENTATION_GROUPS,
  },
  {
    id: "processes",
    title: "Processes",
    pill: "Processes module",
    heading: "Processes",
    emptyTitle: "Processes are next",
    emptyDescription: "This area will evolve into process maps, ownership, lineage, and impact analysis after the job documentation is stable.",
    groups: PROCESS_GROUPS,
  },
  {
    id: "live",
    title: "Live",
    pill: "Live monitor",
    heading: "Live monitor",
    emptyTitle: "Choose a live check",
    emptyDescription: "Run online checks for current requests, blocking, waits, tempdb usage, and log pressure.",
    groups: LIVE_GROUPS,
  },
  {
    id: "health",
    title: "Health",
    pill: "Health module",
    heading: "Health",
    emptyTitle: "Health checks",
    emptyDescription: "Review consolidated alert status across documentation, jobs, and operational checks.",
    groups: HEALTH_GROUPS,
  },
];

const CARD_GROUPS = {
  live_dashboard: [
    {
      title: "Current status",
      fields: ["traffic_light", "pressure_level", "status_summary", "checked_at"],
    },
    {
      title: "Activity",
      fields: ["active_requests", "long_running_requests", "active_waits", "blocked_sessions", "root_blockers"],
    },
    {
      title: "Resource pressure",
      fields: ["tempdb_sessions", "max_tempdb_mb", "log_used_percent"],
    },
  ],
  server_overview: [
    {
      title: "Identity",
      fields: ["server_name", "machine_name", "instance_name", "host_platform"],
    },
    {
      title: "Version",
      fields: ["edition", "product_version", "product_level", "engine_edition", "server_collation"],
    },
    {
      title: "Inventory",
      fields: ["database_count", "server_login_count", "linked_server_count", "sql_agent_job_count"],
    },
    {
      title: "Runtime",
      fields: ["server_time", "cpu_count"],
    },
    {
      title: "Memory",
      fields: ["physical_memory_gb", "max_server_memory_gb"],
    },
  ],
  database_overview: [
    {
      title: "Identity",
      fields: ["database_name", "server_name", "owner_name", "create_date"],
    },
    {
      title: "Core settings",
      fields: ["compatibility_level", "collation_name", "recovery_model_desc", "state_desc", "page_verify_option_desc"],
    },
    {
      title: "Storage",
      fields: ["allocated_gb", "used_gb", "file_count", "filegroup_count"],
    },
    {
      title: "Structure",
      fields: [
        "schema_count",
        "table_count",
        "view_count",
        "stored_procedure_count",
        "function_count",
        "trigger_count",
        "foreign_key_count",
        "index_count",
      ],
    },
    {
      title: "Security",
      fields: ["database_user_count", "custom_role_count", "server_login_count"],
    },
  ],
  database_properties: [
    {
      title: "Identity",
      fields: ["database_name", "compatibility_level", "collation_name", "recovery_model_desc"],
    },
    {
      title: "Isolation",
      fields: ["snapshot_isolation_state_desc", "is_read_committed_snapshot_on"],
    },
    {
      title: "Statistics",
      fields: ["is_auto_create_stats_on", "is_auto_update_stats_on", "is_auto_update_stats_async_on"],
    },
    {
      title: "Safety",
      fields: ["page_verify_option_desc", "is_auto_close_on", "is_auto_shrink_on", "target_recovery_time_in_seconds"],
    },
    {
      title: "Features",
      fields: ["is_query_store_on", "is_broker_enabled", "is_cdc_enabled", "is_encrypted", "log_reuse_wait_desc"],
    },
  ],
};

const CONNECTION_DRAFT_KEY = "sqlsidekick.connectionDraft";
const SCRIPT_VERSION_KEY = "sqlsidekick.scriptVersion";
const AUTO_ALERTS_KEY = "sqlsidekick.autoAlerts";
const AGENT_CONNECTION_KEY = "sqlsidekick.agentConnection";
const PROCESS_MAP_SELECTIONS_KEY = "sqlsidekick.processMapSelections";
const LIVE_REFRESH_ENABLED_KEY = "sqlsidekick.liveRefreshEnabled";
const LIVE_REFRESH_SECONDS_KEY = "sqlsidekick.liveRefreshSeconds";
const TABLE_PAGE_SIZE = 50;
const DEFAULT_QUERY_BY_AREA = {
  live: "live_dashboard",
  processes: "job_lineage_map",
  health: "health_dashboard",
};
const HEALTH_ALERT_TARGETS = [
  { title: "Server", category: "server" },
  { title: "Database", category: "database" },
  { title: "Storage", category: "storage" },
  { title: "Structure", category: "structure" },
  { title: "SQL Code", category: "code" },
  { title: "Jobs", category: "processes" },
];
const LINEAGE_MAP_CONFIG = {
  job_lineage_map: {
    mapType: "jobs",
    label: "Job",
    defaultName: "",
    emptyTitle: "No jobs detected.",
    emptyDescription: "Check SQL Agent credentials in Settings or confirm job metadata is available.",
  },
  procedure_lineage_map: {
    mapType: "procedures",
    label: "Procedure",
    defaultName: "",
    emptyTitle: "No procedures detected.",
    emptyDescription: "The selected database did not return stored procedures for this map.",
  },
  view_lineage_map: {
    mapType: "views",
    label: "View",
    defaultName: "",
    emptyTitle: "No views detected.",
    emptyDescription: "The selected database did not return views for this map.",
  },
  function_lineage_map: {
    mapType: "functions",
    label: "Function",
    defaultName: "",
    emptyTitle: "No functions detected.",
    emptyDescription: "The selected database did not return functions for this map.",
  },
};
const AGENT_METADATA_QUERIES = new Set([
  "sql_agent_jobs",
  "sql_agent_job_steps",
  "sql_agent_job_schedules",
  "sql_agent_job_history",
  "process_inventory",
  "process_steps",
  "process_sql_objects",
  "process_recent_runs",
]);

const GROUP_CATEGORY_SLUGS = {
  Server: "server",
  Database: "database",
  Storage: "storage",
  Structure: "structure",
  Constraints: "constraints",
  "SQL Code": "code",
  "DB Users / Roles": "security",
  "SQL Agent Jobs": "jobs",
  Jobs: "processes",
  Security: "security",
  Analysis: "analysis",
  Operations: "operations",
  Additional: "additional",
  Documentation: "documentation",
  Processes: "processes",
  Lineage: "lineage",
  Live: "live",
  Overview: "health",
  Health: "health",
};

const state = {
  connection: null,
  connected: false,
  queries: [],
  activeQuery: null,
  activeArea: "documentation",
  activeGroup: "Documentation",
  rows: [],
  columns: [],
  tablePage: 1,
  filterColumn: "",
  failedQueries: new Map(),
  scriptVersion: loadScriptVersion(),
  autoAlerts: loadAutoAlerts(),
  liveRefreshEnabled: loadLiveRefreshEnabled(),
  liveRefreshSeconds: loadLiveRefreshSeconds(),
  liveRefreshTimer: null,
  liveRefreshRunning: false,
  agentConnection: loadAgentConnection(),
  healthResults: [],
  alertsSweepId: 0,
  alertsByCategory: {},
  alerts: {
    groupTitle: "",
    category: "",
    rows: [],
    columns: [],
    error: "",
  },
  processMapName: "",
  processMapNames: [],
  processMapType: "jobs",
  processMapLabel: "Job",
  processMapNameByType: loadProcessMapSelections(),
  processMapDetails: {},
};

const els = {
  connectionPage: document.querySelector("#connectionPage"),
  appPage: document.querySelector("#appPage"),
  appLayout: document.querySelector("#appLayout"),
  form: document.querySelector("#connectionForm"),
  authType: document.querySelector("#authType"),
  status: document.querySelector("#connectionStatus"),
  appStatus: document.querySelector("#appConnectionStatus"),
  serverLabel: document.querySelector("#serverLabel"),
  databaseLabel: document.querySelector("#databaseLabel"),
  userLabel: document.querySelector("#userLabel"),
  connectButton: document.querySelector("#connectButton"),
  connectionMessage: document.querySelector("#connectionMessage"),
  changeConnection: document.querySelector("#changeConnection"),
  toggleSidebar: document.querySelector("#toggleSidebar"),
  modulePill: document.querySelector("#modulePill"),
  moduleTabs: document.querySelector("#moduleTabs"),
  sidebarTitle: document.querySelector("#sidebarTitle"),
  queryList: document.querySelector("#queryList"),
  refreshQueries: document.querySelector("#refreshQueries"),
  runQuery: document.querySelector("#runQuery"),
  openAlerts: document.querySelector("#openAlerts"),
  alertBadge: document.querySelector("#alertBadge"),
  exportCsv: document.querySelector("#exportCsv"),
  openSettings: document.querySelector("#openSettings"),
  activeGroup: document.querySelector("#activeGroup"),
  title: document.querySelector("#activeTitle"),
  description: document.querySelector("#activeDescription"),
  message: document.querySelector("#message"),
  tableTools: document.querySelector("#tableTools"),
  rowCount: document.querySelector("#rowCount"),
  columnCount: document.querySelector("#columnCount"),
  filterLabel: document.querySelector("#filterLabel"),
  filterText: document.querySelector("#filterText"),
  cardView: document.querySelector("#cardView"),
  table: document.querySelector("#resultTable"),
  tableWrap: document.querySelector(".table-wrap"),
  pagination: document.querySelector("#pagination"),
  paginationInfo: document.querySelector("#paginationInfo"),
  prevPage: document.querySelector("#prevPage"),
  nextPage: document.querySelector("#nextPage"),
  tableDetailDialog: document.querySelector("#tableDetailDialog"),
  tableDetailTitle: document.querySelector("#tableDetailTitle"),
  tableDetailBody: document.querySelector("#tableDetailBody"),
  closeTableDetail: document.querySelector("#closeTableDetail"),
  detailTabs: document.querySelectorAll(".detail-tab"),
  codeDetailDialog: document.querySelector("#codeDetailDialog"),
  codeDetailTitle: document.querySelector("#codeDetailTitle"),
  codeDetailBody: document.querySelector("#codeDetailBody"),
  closeCodeDetail: document.querySelector("#closeCodeDetail"),
  processDetailDialog: document.querySelector("#processDetailDialog"),
  processDetailTitle: document.querySelector("#processDetailTitle"),
  processDetailBody: document.querySelector("#processDetailBody"),
  closeProcessDetail: document.querySelector("#closeProcessDetail"),
  processDetailTabs: document.querySelectorAll(".process-detail-tab"),
  stepObjectsDialog: document.querySelector("#stepObjectsDialog"),
  stepObjectsTitle: document.querySelector("#stepObjectsTitle"),
  stepObjectsBody: document.querySelector("#stepObjectsBody"),
  closeStepObjects: document.querySelector("#closeStepObjects"),
  mapDetailDialog: document.querySelector("#mapDetailDialog"),
  mapDetailTitle: document.querySelector("#mapDetailTitle"),
  mapDetailBody: document.querySelector("#mapDetailBody"),
  closeMapDetail: document.querySelector("#closeMapDetail"),
  alertsDialog: document.querySelector("#alertsDialog"),
  alertsTitle: document.querySelector("#alertsTitle"),
  alertsBody: document.querySelector("#alertsBody"),
  closeAlerts: document.querySelector("#closeAlerts"),
  settingsDialog: document.querySelector("#settingsDialog"),
  closeSettings: document.querySelector("#closeSettings"),
  scriptVersionInputs: document.querySelectorAll('input[name="scriptVersion"]'),
  autoAlertsInput: document.querySelector("#autoAlerts"),
  liveRefreshEnabledInput: document.querySelector("#liveRefreshEnabled"),
  liveRefreshSecondsInput: document.querySelector("#liveRefreshSeconds"),
  agentCredentialsEnabled: document.querySelector("#agentCredentialsEnabled"),
  agentDatabase: document.querySelector("#agentDatabase"),
  agentUsername: document.querySelector("#agentUsername"),
  agentPassword: document.querySelector("#agentPassword"),
};

function getConnectionPayload() {
  const form = new FormData(els.form);
  return {
    server: String(form.get("server") || ""),
    database: String(form.get("database") || ""),
    authType: String(form.get("authType") || "sql"),
    username: String(form.get("username") || ""),
    password: String(form.get("password") || ""),
    encrypt: document.querySelector("#encrypt").checked,
    trustServerCertificate: document.querySelector("#trustServerCertificate").checked,
  };
}

function fillConnectionForm(connection) {
  if (!connection) return;
  document.querySelector("#server").value = connection.server || "";
  document.querySelector("#database").value = connection.database || "";
  document.querySelector("#authType").value = connection.authType || "sql";
  document.querySelector("#username").value = connection.username || "";
  document.querySelector("#password").value = connection.password || "";
  document.querySelector("#encrypt").checked = Boolean(connection.encrypt);
  document.querySelector("#trustServerCertificate").checked = connection.trustServerCertificate !== false;
  updateAuthFields();
}

function loadConnectionDraft() {
  try {
    const raw = localStorage.getItem(CONNECTION_DRAFT_KEY);
    if (!raw) return;
    fillConnectionForm(JSON.parse(raw));
  } catch {
    localStorage.removeItem(CONNECTION_DRAFT_KEY);
  }
}

function saveConnectionDraft(connection) {
  localStorage.setItem(CONNECTION_DRAFT_KEY, JSON.stringify(connection));
}

function loadScriptVersion() {
  const version = localStorage.getItem(SCRIPT_VERSION_KEY) || "full";
  return ["light", "full"].includes(version) ? version : "full";
}

function loadAutoAlerts() {
  return localStorage.getItem(AUTO_ALERTS_KEY) === "true";
}

function loadLiveRefreshEnabled() {
  return localStorage.getItem(LIVE_REFRESH_ENABLED_KEY) === "true";
}

function loadLiveRefreshSeconds() {
  const value = Number(localStorage.getItem(LIVE_REFRESH_SECONDS_KEY) || 30);
  if (!Number.isFinite(value)) return 30;
  return Math.min(300, Math.max(5, Math.round(value)));
}

function loadAgentConnection() {
  try {
    const raw = localStorage.getItem(AGENT_CONNECTION_KEY);
    if (!raw) {
      return { enabled: false, database: "msdb", username: "", password: "" };
    }
    return { enabled: false, database: "msdb", username: "", password: "", ...JSON.parse(raw) };
  } catch {
    localStorage.removeItem(AGENT_CONNECTION_KEY);
    return { enabled: false, database: "msdb", username: "", password: "" };
  }
}

function loadProcessMapSelections() {
  try {
    const raw = localStorage.getItem(PROCESS_MAP_SELECTIONS_KEY);
    if (!raw) return {};
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    localStorage.removeItem(PROCESS_MAP_SELECTIONS_KEY);
    return {};
  }
}

function saveProcessMapSelections() {
  localStorage.setItem(PROCESS_MAP_SELECTIONS_KEY, JSON.stringify(state.processMapNameByType || {}));
}

function saveAgentConnection() {
  state.agentConnection = {
    enabled: Boolean(els.agentCredentialsEnabled?.checked),
    database: String(els.agentDatabase?.value || "msdb").trim() || "msdb",
    username: String(els.agentUsername?.value || "").trim(),
    password: String(els.agentPassword?.value || ""),
  };
  localStorage.setItem(AGENT_CONNECTION_KEY, JSON.stringify(state.agentConnection));
  updateAgentConnectionInputs();
}

function saveAutoAlerts(enabled) {
  state.autoAlerts = Boolean(enabled);
  localStorage.setItem(AUTO_ALERTS_KEY, state.autoAlerts ? "true" : "false");
  updateAutoAlertsInput();
  if (!state.autoAlerts) {
    clearAlerts();
  }
}

function saveLiveRefreshSettings() {
  state.liveRefreshEnabled = Boolean(els.liveRefreshEnabledInput?.checked);
  const seconds = Number(els.liveRefreshSecondsInput?.value || state.liveRefreshSeconds || 30);
  state.liveRefreshSeconds = Number.isFinite(seconds) ? Math.min(300, Math.max(5, Math.round(seconds))) : 30;
  localStorage.setItem(LIVE_REFRESH_ENABLED_KEY, state.liveRefreshEnabled ? "true" : "false");
  localStorage.setItem(LIVE_REFRESH_SECONDS_KEY, String(state.liveRefreshSeconds));
  updateLiveRefreshInputs();
  scheduleLiveRefresh();
}

function saveScriptVersion(version) {
  state.scriptVersion = ["light", "full"].includes(version) ? version : "full";
  localStorage.setItem(SCRIPT_VERSION_KEY, state.scriptVersion);
  updateScriptVersionInputs();
}

function updateScriptVersionInputs() {
  els.scriptVersionInputs.forEach((input) => {
    input.checked = input.value === state.scriptVersion;
  });
}

function updateAutoAlertsInput() {
  if (els.autoAlertsInput) {
    els.autoAlertsInput.checked = state.autoAlerts;
  }
}

function updateLiveRefreshInputs() {
  if (els.liveRefreshEnabledInput) {
    els.liveRefreshEnabledInput.checked = state.liveRefreshEnabled;
  }
  if (els.liveRefreshSecondsInput) {
    els.liveRefreshSecondsInput.value = String(state.liveRefreshSeconds);
    els.liveRefreshSecondsInput.disabled = !state.liveRefreshEnabled;
  }
}

function updateAgentConnectionInputs() {
  if (!els.agentCredentialsEnabled) return;
  const agent = state.agentConnection || {};
  els.agentCredentialsEnabled.checked = Boolean(agent.enabled);
  els.agentDatabase.value = agent.database || "msdb";
  els.agentUsername.value = agent.username || "";
  els.agentPassword.value = agent.password || "";
  const enabled = Boolean(agent.enabled);
  els.agentDatabase.disabled = !enabled;
  els.agentUsername.disabled = !enabled;
  els.agentPassword.disabled = !enabled;
}

function getQueryConnection(useAgent = false) {
  if (!shouldUseAgentConnection()) {
    return state.connection;
  }
  if (!useAgent) {
    return state.connection;
  }
  return {
    ...state.connection,
    database: state.agentConnection.database || "msdb",
    authType: "sql",
    username: state.agentConnection.username || "",
    password: state.agentConnection.password || "",
  };
}

function shouldUseMixedLineageQuery() {
  return ["process_lineage", "used_by_jobs"].includes(state.activeQuery?.name);
}

function shouldUseAgentMetadataQuery() {
  return AGENT_METADATA_QUERIES.has(state.activeQuery?.name);
}

function shouldUseAgentConnection() {
  return (
    state.agentConnection?.enabled &&
    state.agentConnection?.username &&
    state.agentConnection?.password
  );
}

async function api(path, options = {}) {
  const response = await fetch(path, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  const payload = await response.json();
  if (!response.ok || payload.ok === false) {
    throw new Error(payload.error || "Request failed.");
  }
  return payload;
}

function showMessage(target, text, type = "") {
  target.textContent = text;
  target.className = `message ${type}`.trim();
}

function clearMessage(target) {
  target.textContent = "";
  target.className = "message hidden";
}

function updateAuthFields() {
  const showSqlAuth = els.authType.value === "sql";
  document.querySelectorAll(".sql-auth").forEach((item) => {
    item.classList.toggle("hidden", !showSqlAuth);
  });
}

function goToApp() {
  els.connectionPage.classList.add("hidden");
  els.appPage.classList.remove("hidden");
  els.serverLabel.textContent = state.connection.server;
  els.databaseLabel.textContent = state.connection.database;
  els.userLabel.textContent = state.connection.authType === "windows" ? "Windows Integrated" : state.connection.username;
  els.appStatus.textContent = "Connected";
  els.appStatus.classList.add("ok");
}

function goToConnection() {
  clearLiveRefreshTimer();
  els.appPage.classList.add("hidden");
  els.connectionPage.classList.remove("hidden");
}

async function loadQueries() {
  renderQueryMenuLoading();
  state.failedQueries.clear();
  const payload = await api(`/api/queries?version=${encodeURIComponent(state.scriptVersion)}`);
  state.queries = payload.queries;
  state.activeQuery = null;
  state.rows = [];
  state.columns = [];
  state.tablePage = 1;
  state.filterColumn = "";
  clearAlerts();
  renderModuleTabs();
  renderQueryMenu();
  resetWorkspace();
}

async function loadDefaultConnection() {
  try {
    const payload = await api("/api/default-connection");
    if (payload.connection) {
      fillConnectionForm(payload.connection);
    }
  } catch {
    return;
  }
}

function renderQueryMenu() {
  els.queryList.innerHTML = "";
  const area = getActiveArea();
  const groups = getVisibleGroups(area);
  const usedNames = new Set(getAllQueryGroups().flatMap((group) => group.names));
  updateAreaChrome(area);

  groups.forEach((group, index) => {
    const details = document.createElement("details");
    details.className = "menu-group";
    details.dataset.category = groupCategorySlug(group.title);
    details.open = group.collapsed ? false : index < 2;

    const summary = document.createElement("summary");
    const title = document.createElement("span");
    title.className = "menu-group-title";
    title.textContent = group.title;
    const alertIcon = document.createElement("span");
    alertIcon.className = "menu-alert-icon hidden";
    alertIcon.textContent = "!";
    summary.append(title, alertIcon);
    details.appendChild(summary);

    const items = document.createElement("div");
    items.className = "menu-items";

    group.names
      .map((name) => state.queries.find((query) => query.name === name))
      .filter(Boolean)
      .forEach((query) => {
        usedNames.add(query.name);
        items.appendChild(createQueryButton(query, group.title));
      });

    if (items.children.length > 0) {
      details.appendChild(items);
      els.queryList.appendChild(details);
    }
  });

  if (els.queryList.children.length === 0) {
    const empty = document.createElement("div");
    empty.className = "module-empty";
    empty.innerHTML = `
      <strong>${escapeHtml(area.emptyTitle)}</strong>
      <span>${escapeHtml(area.emptyDescription)}</span>
    `;
    els.queryList.appendChild(empty);
  }
  renderGroupAlertBadges();
}

function renderModuleTabs() {
  if (!els.moduleTabs) return;
  els.moduleTabs.innerHTML = "";
  NAV_AREAS.forEach((area) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "module-tab";
    button.dataset.area = area.id;
    button.textContent = area.title;
    button.classList.toggle("active", area.id === state.activeArea);
    button.addEventListener("click", () => {
      switchArea(area.id);
    });
    els.moduleTabs.appendChild(button);
  });
}

async function switchArea(areaId) {
  if (state.activeArea === areaId) return;
  clearLiveRefreshTimer();
  state.activeArea = areaId;
  state.activeQuery = null;
  state.rows = [];
  state.columns = [];
  state.tablePage = 1;
  state.filterColumn = "";
  renderModuleTabs();
  renderQueryMenu();
  resetWorkspace();
  await runDefaultQueryForArea(areaId);
  scheduleLiveRefresh();
}

function getActiveArea() {
  return NAV_AREAS.find((area) => area.id === state.activeArea) || NAV_AREAS[0];
}

function getAllQueryGroups() {
  return NAV_AREAS.flatMap((area) => area.groups);
}

function getVisibleGroups(area = getActiveArea()) {
  return area.groups.filter((group) => group.names.some((name) => state.queries.some((query) => query.name === name)));
}

async function runDefaultQueryForArea(areaId) {
  if (!state.connected) return;
  const defaultName = DEFAULT_QUERY_BY_AREA[areaId];
  if (!defaultName || !state.queries.some((query) => query.name === defaultName)) return;
  const group = getVisibleGroups(getActiveArea()).find((item) => item.names.includes(defaultName));
  if (!group) return;
  await selectAndRunQuery(defaultName, group.title);
}

function updateAreaChrome(area = getActiveArea()) {
  if (els.modulePill) els.modulePill.textContent = area.pill;
  if (els.sidebarTitle) els.sidebarTitle.textContent = area.heading;
}

function renderQueryMenuLoading() {
  if (!els.queryList) return;
  els.queryList.innerHTML = `
    <div class="menu-loading">
      <div class="loading-spinner" aria-hidden="true"></div>
      <span>Refreshing menu</span>
    </div>
  `;
}

function createQueryButton(query, groupTitle) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = "query-item";
  button.dataset.name = query.name;
  button.dataset.group = groupTitle;
  const failedReason = state.failedQueries.get(query.name);
  if (failedReason) {
    button.classList.add("failed");
    button.disabled = true;
    button.title = failedReason;
  } else {
    button.title = query.description;
  }
  button.innerHTML = `
    <span class="query-state-icon" aria-hidden="true">${failedReason ? "!" : ""}</span>
    <span class="query-copy">
      <strong>${escapeHtml(query.title)}</strong>
    </span>
  `;
  button.addEventListener("click", () => selectAndRunQuery(query.name, groupTitle));
  return button;
}

async function selectAndRunQuery(name, groupTitle) {
  setActiveQuery(name, groupTitle);
  if (state.connected) {
    setCurrentAlertsFromGroup(groupTitle);
    if (state.autoAlerts && !getStoredAlerts(groupTitle)) {
      runAlertCheck(groupTitle);
    }
    await runActiveQuery();
  } else {
    showMessage(els.message, "Connect first, then select a section to load its data.", "error");
  }
}

function setActiveQuery(name, groupTitle) {
  state.activeQuery = state.queries.find((query) => query.name === name);
  state.activeGroup = groupTitle;
  state.rows = [];
  state.columns = [];
  state.tablePage = 1;
  state.filterColumn = "";
  els.filterText.value = "";
  document.querySelectorAll(".query-item").forEach((item) => {
    item.classList.toggle("active", item.dataset.name === name);
  });
  els.activeGroup.textContent = groupTitle;
  els.title.textContent = state.activeQuery.title;
  els.description.textContent = state.activeQuery.description;
  els.runQuery.disabled = !state.connected;
  els.rowCount.textContent = "0";
  els.columnCount.textContent = "0";
  els.exportCsv.disabled = true;
  els.cardView.classList.add("hidden");
  els.tableWrap.classList.remove("hidden");
  els.tableTools.classList.add("hidden");
  els.pagination.classList.add("hidden");
  renderLoadingState();
  clearMessage(els.message);
}

async function runAllAlerts() {
  if (!state.autoAlerts || !state.connected || !state.connection) {
    return;
  }
  const sweepId = state.alertsSweepId + 1;
  state.alertsSweepId = sweepId;
  state.alertsByCategory = {};
  setCurrentAlertsFromGroup(state.activeGroup);
  renderGroupAlertBadges();

  await Promise.all(getAlertableGroups().map((group) => runAlertCheck(group.title, sweepId)));
}

async function runAlertCheck(groupTitle, sweepId = state.alertsSweepId) {
  if (!state.autoAlerts || !state.connected || !state.connection) {
    return;
  }
  const category = groupCategorySlug(groupTitle);
  if (!category || ["additional", "documentation", "health", "live"].includes(category)) {
    return;
  }

  try {
    const payload = await api("/api/run-alerts", {
      method: "POST",
      body: JSON.stringify({
        connection: category === "processes" && shouldUseAgentConnection() ? getQueryConnection(true) : state.connection,
        category,
      }),
    });
    const resultSet = payload.resultSets?.[0] || { columns: [], rows: [] };
    if (sweepId !== state.alertsSweepId) return;
    state.alertsByCategory[category] = {
      groupTitle,
      category,
      rows: resultSet.rows || [],
      columns: resultSet.columns || [],
      error: "",
    };
  } catch (error) {
    if (sweepId !== state.alertsSweepId) return;
    state.alertsByCategory[category] = {
      groupTitle,
      category,
      rows: [],
      columns: [],
      error: error.message,
    };
  }
  renderGroupAlertBadges();
  if (state.activeGroup === groupTitle) {
    setCurrentAlertsFromGroup(groupTitle);
  }
}

function groupCategorySlug(groupTitle) {
  return GROUP_CATEGORY_SLUGS[groupTitle] || String(groupTitle || "").toLowerCase().replaceAll(" ", "_");
}

function getAlertableGroups() {
  return getAllQueryGroups().filter((group) => {
    const category = groupCategorySlug(group.title);
    if (!category || ["additional", "documentation", "health", "live"].includes(category)) return false;
    return group.names.some((name) => state.queries.some((query) => query.name === name));
  });
}

function getStoredAlerts(groupTitle) {
  return state.alertsByCategory[groupCategorySlug(groupTitle)];
}

function setCurrentAlertsFromGroup(groupTitle) {
  const category = groupCategorySlug(groupTitle);
  state.alerts = state.alertsByCategory[category] || {
    groupTitle,
    category,
    rows: [],
    columns: [],
    error: "",
  };
  renderAlertIndicator();
}

function renderGroupAlertBadges() {
  document.querySelectorAll(".menu-group").forEach((group) => {
    const category = group.dataset.category;
    const alertState = state.alertsByCategory[category];
    const icon = group.querySelector(".menu-alert-icon");
    if (!icon) return;
    const hasAlerts = Boolean(alertState?.rows?.length);
    const hasError = Boolean(alertState?.error);
    const severity = getHighestAlertSeverity(alertState);
    icon.classList.toggle("hidden", !hasAlerts && !hasError);
    icon.classList.toggle("failed", hasError);
    setSeverityClasses(icon, severity);
    icon.title = hasError ? "Alert check failed" : "Alerts detected";
  });
}

function clearAlerts() {
  state.alertsSweepId += 1;
  state.alertsByCategory = {};
  state.alerts = { groupTitle: "", category: "", rows: [], columns: [], error: "" };
  els.openAlerts.classList.add("hidden");
  els.openAlerts.classList.remove("has-alerts", "failed");
  els.alertBadge.textContent = "0";
  renderGroupAlertBadges();
}

function renderAlertIndicator() {
  const hasRows = state.alerts.rows.length > 0;
  const hasError = Boolean(state.alerts.error);
  const severity = getHighestAlertSeverity(state.alerts);
  els.openAlerts.classList.toggle("hidden", !hasRows && !hasError);
  els.openAlerts.classList.toggle("has-alerts", hasRows);
  els.openAlerts.classList.toggle("failed", hasError);
  setSeverityClasses(els.openAlerts, severity);
  els.openAlerts.title = hasError ? "Alert check failed" : `Open ${state.alerts.rows.length} alerts`;
  els.openAlerts.setAttribute("aria-label", els.openAlerts.title);
  els.alertBadge.textContent = hasError ? "!" : String(state.alerts.rows.length);
}

function getHighestAlertSeverity(alertState) {
  const firstRow = alertState?.rows?.[0];
  const explicitSeverity = normalizeAlertSeverity(firstRow?.highest_detected_severity);
  if (explicitSeverity !== "unknown") {
    return explicitSeverity;
  }
  const ranks = { high: 1, medium: 2, low: 3, unknown: 4 };
  return (alertState?.rows || []).reduce((highest, row) => {
    const severity = normalizeAlertSeverity(row.severity);
    return ranks[severity] < ranks[highest] ? severity : highest;
  }, "unknown");
}

function normalizeAlertSeverity(value) {
  const severity = String(value || "").trim().toLowerCase();
  return ["high", "medium", "low"].includes(severity) ? severity : "unknown";
}

function setSeverityClasses(element, severity) {
  element.classList.remove("severity-high", "severity-medium", "severity-low", "severity-unknown");
  element.classList.add(`severity-${severity || "unknown"}`);
}

function openAlertsPanel() {
  els.alertsTitle.textContent = state.alerts.groupTitle ? `${state.alerts.groupTitle} alerts` : "Alerts";
  if (state.alerts.error) {
    els.alertsBody.innerHTML = `<div class="alert-error">${escapeHtml(state.alerts.error)}</div>`;
    els.alertsDialog.showModal();
    return;
  }
  if (state.alerts.rows.length === 0) {
    els.alertsBody.innerHTML = `<div class="empty">No active alerts.</div>`;
    els.alertsDialog.showModal();
    return;
  }
  els.alertsBody.innerHTML = renderAlertsTable();
  els.alertsDialog.showModal();
}

function renderAlertsTable() {
  const visibleColumns = state.alerts.columns.filter((column) => column !== "highest_detected_severity");
  const headers = visibleColumns.map((column) => `<th>${escapeHtml(labelize(column))}</th>`).join("");
  const rows = state.alerts.rows
    .map((row) => {
      const severity = String(row.severity || "").toLowerCase();
      const cells = visibleColumns
        .map((column) => `<td>${escapeHtml(formatValue(row[column]))}</td>`)
        .join("");
      return `<tr class="alert-row alert-${escapeHtml(severity)}">${cells}</tr>`;
    })
    .join("");
  return `
    <div class="alerts-summary">
      <strong>${state.alerts.rows.length}</strong>
      <span>active alerts detected for this category.</span>
    </div>
    <div class="alerts-table-wrap">
      <table class="alerts-table">
        <thead><tr>${headers}</tr></thead>
        <tbody>${rows}</tbody>
      </table>
    </div>
  `;
}

async function testConnection(event) {
  event.preventDefault();
  clearMessage(els.connectionMessage);
  state.connection = getConnectionPayload();
  saveConnectionDraft(state.connection);
  els.status.textContent = "Testing...";
  els.status.classList.remove("ok");
  els.connectButton.disabled = true;
  els.connectButton.textContent = "Testing...";
  try {
    await api("/api/test-connection", {
      method: "POST",
      body: JSON.stringify({ connection: state.connection }),
    });
    state.connected = true;
    els.status.textContent = "Connected";
    els.status.classList.add("ok");
    els.runQuery.disabled = !state.activeQuery;
    showMessage(els.connectionMessage, "Connection successful. Opening the explorer.", "success");
    goToApp();
    if (!state.activeQuery && state.queries.length > 0) {
      const firstDatabaseQuery = state.queries.find((query) => query.name === "database_overview") || state.queries[0];
      setActiveQuery(firstDatabaseQuery.name, "Database");
      runAllAlerts();
      await runActiveQuery();
    }
  } catch (error) {
    state.connected = false;
    els.status.textContent = "Disconnected";
    els.status.classList.remove("ok");
    els.runQuery.disabled = true;
    showMessage(els.connectionMessage, error.message, "error");
  } finally {
    els.connectButton.disabled = false;
    els.connectButton.textContent = "Test and enter";
  }
}

async function runActiveQuery() {
  if (!state.activeQuery || !state.connection) return;
  clearLiveRefreshTimer();
  clearMessage(els.message);
  els.cardView.classList.add("hidden");
  els.tableWrap.classList.remove("hidden");
  renderLoadingState();
  els.runQuery.disabled = true;
  els.runQuery.innerHTML = `<span class="icon-loading-dot" aria-hidden="true"></span>`;
  try {
    if (LINEAGE_MAP_CONFIG[state.activeQuery.name]) {
      await runProcessLineageMap();
      return;
    }
    if (isHealthQuery()) {
      await runHealthView();
      return;
    }
    const isMixedLineage = shouldUseMixedLineageQuery();
    if (isMixedLineage && !shouldUseAgentConnection()) {
      state.columns = [];
      state.rows = [];
      renderResults();
      renderEmptyTable("Configure SQL Agent credentials in Settings to run this lineage section.");
      showMessage(els.message, "This lineage section needs the dedicated SQL Agent login configured in Settings.", "error");
      return;
    }
    const useAgentMetadata = shouldUseAgentMetadataQuery() && shouldUseAgentConnection();
    const payload = await api(isMixedLineage ? "/api/run-lineage-query" : "/api/run-query", {
      method: "POST",
      body: JSON.stringify({
        connection: useAgentMetadata ? getQueryConnection(true) : getQueryConnection(),
        agentConnection: shouldUseAgentConnection() ? getQueryConnection(true) : null,
        queryName: state.activeQuery.name,
        scriptVersion: state.scriptVersion,
      }),
    });
    const resultSet = payload.resultSets?.[0] || { columns: [], rows: [] };
    state.columns = resultSet.columns || [];
    state.rows = resultSet.rows || [];
    state.tablePage = 1;
    state.filterColumn = getDefaultFilterColumn();
    updateTableFilterUI();
    if (isMixedLineage && state.rows.length === 0) {
      renderResults();
      renderEmptyTable("No lineage rows found. Check SQL Agent credentials and job step visibility.");
      showMessage(els.message, "No lineage rows were returned. Verify the SQL Agent login can read job steps.", "error");
    } else {
      renderResults();
      clearMessage(els.message);
    }
  } catch (error) {
    markQueryFailed(state.activeQuery.name, error.message);
    showMessage(els.message, error.message, "error");
  } finally {
    els.runQuery.disabled = !state.connected || state.failedQueries.has(state.activeQuery?.name);
    els.runQuery.innerHTML = `<span class="icon-refresh" aria-hidden="true">↻</span>`;
  }
}

function isLiveQuery(queryName = state.activeQuery?.name) {
  return String(queryName || "").startsWith("live_");
}

function clearLiveRefreshTimer() {
  if (!state.liveRefreshTimer) return;
  clearTimeout(state.liveRefreshTimer);
  state.liveRefreshTimer = null;
}

function scheduleLiveRefresh() {
  clearLiveRefreshTimer();
  if (!state.liveRefreshEnabled || !state.connected || state.activeArea !== "live" || !isLiveQuery()) {
    return;
  }
  state.liveRefreshTimer = setTimeout(async () => {
    if (state.liveRefreshRunning) return;
    state.liveRefreshRunning = true;
    try {
      await runActiveQuery();
    } finally {
      state.liveRefreshRunning = false;
    }
  }, state.liveRefreshSeconds * 1000);
}

function markQueryFailed(queryName, reason) {
  state.failedQueries.set(queryName, reason || "Query failed.");
  const button = Array.from(document.querySelectorAll(".query-item")).find((item) => item.dataset.name === queryName);
  if (!button) return;
  button.classList.add("failed");
  button.disabled = true;
  button.title = state.failedQueries.get(queryName);
  const icon = button.querySelector(".query-state-icon");
  if (icon) icon.textContent = "!";
  if (state.activeQuery?.name === queryName) {
    els.runQuery.disabled = true;
  }
}

function isHealthQuery() {
  return state.activeQuery?.name === "health_dashboard";
}

async function runHealthView() {
  const healthResults = await fetchHealthAlerts();
  state.healthResults = healthResults;
  state.columns = [];
  state.rows = [];
  els.message.classList.add("hidden");
  els.tableTools.classList.add("hidden");
  els.tableWrap.classList.add("hidden");
  els.pagination.classList.add("hidden");
  els.exportCsv.disabled = true;
  els.rowCount.textContent = String(healthResults.reduce((sum, result) => sum + result.rows.length, 0));
  els.columnCount.textContent = String(HEALTH_ALERT_TARGETS.length);
  els.cardView.classList.remove("hidden");
  els.cardView.innerHTML = renderHealthDashboard(healthResults);
  bindHealthDashboardControls();
  clearMessage(els.message);
}

async function fetchHealthAlerts() {
  const results = await Promise.all(
    HEALTH_ALERT_TARGETS.map(async (target) => {
      try {
        const payload = await api("/api/run-alerts", {
          method: "POST",
          body: JSON.stringify({
            connection: target.category === "processes" && shouldUseAgentConnection() ? getQueryConnection(true) : state.connection,
            category: target.category,
          }),
        });
        const resultSet = payload.resultSets?.[0] || { columns: [], rows: [] };
        state.alertsByCategory[target.category] = {
          groupTitle: target.title,
          category: target.category,
          rows: resultSet.rows || [],
          columns: resultSet.columns || [],
          error: "",
        };
        return {
          ...target,
          rows: resultSet.rows || [],
          columns: resultSet.columns || [],
          error: "",
        };
      } catch (error) {
        state.alertsByCategory[target.category] = {
          groupTitle: target.title,
          category: target.category,
          rows: [],
          columns: [],
          error: error.message,
        };
        return { ...target, rows: [], columns: [], error: error.message };
      }
    })
  );
  renderGroupAlertBadges();
  setCurrentAlertsFromGroup(state.activeGroup);
  return results;
}

function renderHealthDashboard(results) {
  const totalAlerts = results.reduce((sum, result) => sum + result.rows.length, 0);
  const highAlerts = countHealthSeverity(results, "high");
  const mediumAlerts = countHealthSeverity(results, "medium");
  const lowAlerts = countHealthSeverity(results, "low");
  const failedChecks = results.filter((result) => result.error).length;
  const overallSeverity = failedChecks > 0 ? "unknown" : highAlerts > 0 ? "high" : mediumAlerts > 0 ? "medium" : lowAlerts > 0 ? "low" : "good";
  const statusText = failedChecks > 0
    ? `${failedChecks} health check(s) could not run.`
    : totalAlerts > 0
      ? `${totalAlerts} active alert(s) detected.`
      : "No active basic alerts detected.";
  return `
    <section class="health-summary health-${escapeHtml(overallSeverity)}">
      <div>
        <span class="health-eyebrow">Overall status</span>
        <strong>${escapeHtml(formatHealthStatus(overallSeverity))}</strong>
        <p>${escapeHtml(statusText)}</p>
      </div>
      <div class="health-summary-actions">
        <button class="health-view-all" type="button" data-health-all title="View all alerts" aria-label="View all alerts">
          <span aria-hidden="true">i</span>
        </button>
        <div class="health-totals">
          ${renderHealthTotal("High", highAlerts, "high")}
          ${renderHealthTotal("Medium", mediumAlerts, "medium")}
          ${renderHealthTotal("Low", lowAlerts, "low")}
        </div>
      </div>
    </section>
    <section class="health-category-grid">
      ${results.map((result) => renderHealthCategoryCard(result)).join("")}
    </section>
  `;
}

function renderHealthTotal(label, count, severity) {
  return `
    <button class="health-total severity-${escapeHtml(severity)}" type="button" data-health-severity="${escapeHtml(severity)}" title="${escapeHtml(label)}" aria-label="${escapeHtml(label)} alerts: ${escapeHtml(count)}">
      <strong>${escapeHtml(count)}</strong>
    </button>
  `;
}

function renderHealthCategoryCard(result) {
  const severity = result.error ? "unknown" : getHighestAlertSeverity(result);
  const count = result.rows.length;
  const status = result.error ? "Check failed" : "OK";
  const topAlert = result.error || result.rows[0]?.alert_name || "No active alerts.";
  return `
    <button class="health-category-card health-${escapeHtml(severity)}" type="button" data-health-category="${escapeHtml(result.category)}" title="View ${escapeHtml(result.title)} alerts">
      <div class="health-card-head">
        <span class="health-dot severity-${escapeHtml(severity)}"></span>
        <strong>${escapeHtml(result.title)}${count > 0 ? ` (${escapeHtml(count)})` : ""}</strong>
      </div>
      <p>${escapeHtml(result.error ? status : topAlert)}</p>
    </button>
  `;
}

function bindHealthDashboardControls() {
  els.cardView.querySelectorAll("[data-health-category]").forEach((button) => {
    button.addEventListener("click", () => {
      const category = button.dataset.healthCategory;
      const result = state.healthResults.find((item) => item.category === category);
      if (!result) return;
      openHealthAlerts(result.title, [result]);
    });
  });
  els.cardView.querySelectorAll("[data-health-severity]").forEach((button) => {
    button.addEventListener("click", () => {
      const severity = button.dataset.healthSeverity;
      openHealthAlerts(labelize(severity), state.healthResults, severity);
    });
  });
  const allButton = els.cardView.querySelector("[data-health-all]");
  if (allButton) {
    allButton.addEventListener("click", () => openHealthAlerts("All health", state.healthResults));
  }
}

function openHealthAlerts(title, results, severity = "") {
  const rows = results.flatMap((result) =>
    result.rows
      .filter((row) => !severity || normalizeAlertSeverity(row.severity) === severity)
      .map((row) => ({
        source_area: result.title,
        ...row,
      }))
  );
  const columns = getHealthAlertColumns(rows);
  state.alerts = {
    groupTitle: title,
    category: "health",
    rows,
    columns,
    error: "",
  };
  openAlertsPanel();
}

function getHealthAlertColumns(rows) {
  const orderedColumns = ["source_area", "severity", "alert_category", "alert_name", "active_count"];
  const extraColumns = Array.from(new Set(rows.flatMap((row) => Object.keys(row)))).filter(
    (column) => !orderedColumns.includes(column)
  );
  return orderedColumns.filter((column) => rows.some((row) => Object.hasOwn(row, column))).concat(extraColumns);
}

function countHealthSeverity(results, severity) {
  return results.reduce(
    (sum, result) => sum + result.rows.filter((row) => normalizeAlertSeverity(row.severity) === severity).length,
    0
  );
}

function formatHealthStatus(severity) {
  if (severity === "high") return "Needs attention";
  if (severity === "medium") return "Review soon";
  if (severity === "low") return "Minor findings";
  if (severity === "unknown") return "Incomplete";
  return "Healthy";
}

function resetWorkspace() {
  const area = getActiveArea();
  updateAreaChrome(area);
  els.activeGroup.textContent = area.title;
  els.title.textContent = area.emptyTitle;
  els.description.textContent = area.emptyDescription;
  els.runQuery.disabled = true;
  els.exportCsv.disabled = true;
  clearAlerts();
  els.tableTools.classList.add("hidden");
  els.cardView.classList.add("hidden");
  els.tableWrap.classList.remove("hidden");
  els.pagination.classList.add("hidden");
  renderEmptyTable("No results yet.");
  clearMessage(els.message);
}

function renderResults() {
  if (state.rows.length === 0) {
    els.message.classList.add("hidden");
    els.tableTools.classList.add("hidden");
    els.cardView.classList.add("hidden");
    els.tableWrap.classList.remove("hidden");
    els.exportCsv.disabled = true;
    els.rowCount.textContent = "0";
    els.columnCount.textContent = String(state.columns.length);
    renderEmptyTable("No rows to display.");
    scheduleLiveRefresh();
    return;
  }
  if (state.rows.length <= 1 && shouldRenderSingleRowAsCard()) {
    renderCards();
    scheduleLiveRefresh();
    return;
  }
  els.message.classList.remove("hidden");
  els.tableTools.classList.remove("hidden");
  els.cardView.classList.add("hidden");
  els.tableWrap.classList.remove("hidden");
  renderTable();
  scheduleLiveRefresh();
}

function shouldRenderSingleRowAsCard() {
  return Boolean(CARD_GROUPS[state.activeQuery?.name]);
}

async function runProcessLineageMap(processName = null) {
  const config = LINEAGE_MAP_CONFIG[state.activeQuery?.name] || LINEAGE_MAP_CONFIG.job_lineage_map;
  const requestedName = processName ?? state.processMapNameByType?.[config.mapType] ?? config.defaultName;
  state.processMapType = config.mapType;
  state.processMapLabel = config.label;
  state.processMapName = requestedName;
  const payload = await api("/api/process-lineage-map", {
    method: "POST",
    body: JSON.stringify({
      connection: getQueryConnection(),
      agentConnection: config.mapType === "jobs" && shouldUseAgentConnection() ? getQueryConnection(true) : null,
      processName: requestedName,
      mapType: config.mapType,
    }),
  });
  state.processMapName = payload.processName || requestedName;
  state.processMapNameByType = {
    ...(state.processMapNameByType || {}),
    [config.mapType]: state.processMapName,
  };
  saveProcessMapSelections();
  if (payload.availableProcesses?.length) {
    state.processMapNames = payload.availableProcesses;
  } else {
    state.processMapNames = [];
  }
  const resultSet = payload.resultSets?.[0] || { columns: [], rows: [] };
  state.columns = resultSet.columns || [];
  state.rows = resultSet.rows || [];
  state.tablePage = 1;
  state.filterColumn = "";
  els.exportCsv.disabled = true;
  els.tableTools.classList.add("hidden");
  els.pagination.classList.add("hidden");
  els.tableWrap.classList.add("hidden");
  els.cardView.classList.remove("hidden");
  els.cardView.innerHTML = renderProcessLineageMap(
    state.processMapName,
    state.rows,
    payload.processObjects || [],
    payload.tableFeatures || [],
    config
  );
  bindProcessMapControls();
  clearMessage(els.message);
}

function renderProcessLineageMap(processName, rows, processObjects, tableFeatures = [], config = LINEAGE_MAP_CONFIG.job_lineage_map) {
  state.processMapDetails = {};
  const tree = buildProcessLineageTree(processName, rows, processObjects, tableFeatures);
  if (tree.steps.length === 0) {
    return `
      <div class="process-map-empty">
        <strong>${escapeHtml(config.emptyTitle || `No lineage detected for ${processName}.`)}</strong>
        <span>${escapeHtml(config.emptyDescription || "No SQL objects were returned for this map.")}</span>
      </div>
    `;
  }

  const impact = summarizeProcessMapImpact(tree);

  return `
    <section class="process-map">
      <div class="process-map-head">
        <div>
          <span class="map-kicker">Focused online map</span>
          <h3>${escapeHtml(processName)}</h3>
        </div>
        <div class="map-stats" aria-label="Map summary">
          <span><strong>${impact.stepCount}</strong> ${config.mapType === "jobs" ? "steps" : "roots"}</span>
          <span><strong>${impact.objectCount}</strong> SQL objects</span>
          <span><strong>${impact.tableCount}</strong> tables</span>
          <span><strong>${impact.triggerCount}</strong> triggers</span>
          <span><strong>${impact.computedColumnCount}</strong> computed</span>
          <span class="${impact.dynamicSqlCount ? "stat-warning" : ""}"><strong>${impact.dynamicSqlCount}</strong> dynamic</span>
          <span class="${impact.unresolvedCount ? "stat-warning" : ""}"><strong>${impact.unresolvedCount}</strong> unresolved</span>
          <span class="${impact.partialDependencyCount ? "stat-warning" : ""}"><strong>${impact.partialDependencyCount}</strong> partial</span>
        </div>
      </div>
      <div class="process-map-actions">
        <div class="process-picker">
          <label class="process-picker-label" for="processMapSearch">${escapeHtml(config.label || "Object")}</label>
          <input
            id="processMapSearch"
            class="process-picker-input"
            type="search"
            value="${escapeHtml(processName)}"
            placeholder="Search ${escapeHtml(String(config.label || "object").toLowerCase())}..."
            autocomplete="off"
          />
          <button type="button" class="process-picker-menu-button" title="Show ${escapeHtml(String(config.label || "object").toLowerCase())}s" aria-label="Show ${escapeHtml(String(config.label || "object").toLowerCase())}s">▾</button>
          <div class="process-picker-menu hidden">
            ${state.processMapNames.map((name) => `
              <button type="button" class="process-picker-option" data-process-name="${escapeHtml(name)}">${escapeHtml(name)}</button>
            `).join("")}
          </div>
          <button type="button" class="process-picker-go">Load</button>
        </div>
        <div class="process-map-button-group">
          <div class="legend-control">
            <button type="button" class="legend-toggle-button" title="Confidence legend" aria-label="Confidence legend">i</button>
            <div class="confidence-legend hidden">
              <span><strong>High</strong> catalog dependency resolved</span>
              <span><strong>Medium</strong> object found, dependency partial</span>
              <span><strong>Low</strong> parsed from job text only</span>
              <span><strong>Dynamic</strong> SQL text may hide objects</span>
              <span><strong>Unresolved</strong> object not found or metadata hidden</span>
            </div>
          </div>
          <button type="button" class="map-toggle-button" data-map-action="expand" title="Expand all" aria-label="Expand all">+</button>
          <button type="button" class="map-toggle-button" data-map-action="collapse" title="Collapse all" aria-label="Collapse all">-</button>
        </div>
      </div>
      ${renderProcessLineageGraph(tree, config)}
      <div class="process-tree">
        ${tree.steps.map(renderProcessMapStep).join("")}
      </div>
    </section>
  `;
}

function renderProcessLineageGraph(tree, config) {
  const graph = buildProcessLineageGraph(tree, config);
  if (graph.nodes.length === 0) return "";
  const width = graph.width;
  const height = graph.height;
  return `
    <details class="lineage-graph" aria-label="Lineage graph" open>
      <summary class="lineage-graph-head">
        <span class="node-caret" aria-hidden="true"></span>
        <strong>Visual lineage</strong>
        <span>${escapeHtml(graph.caption)}</span>
      </summary>
      <div class="lineage-graph-scroll">
        <svg viewBox="0 0 ${width} ${height}" role="img" aria-label="Lineage graph preview">
          <defs>
            <marker id="lineageArrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
              <path d="M 0 0 L 10 5 L 0 10 z"></path>
            </marker>
          </defs>
          ${graph.links.map((link) => renderGraphLink(link, graph.nodeMap)).join("")}
          ${graph.nodes.map(renderGraphNode).join("")}
        </svg>
      </div>
      ${graph.truncated ? `<div class="lineage-graph-note">Graph preview limited to the first ${graph.limit} nodes. The full detail remains in the tree below.</div>` : ""}
    </details>
  `;
}

function buildProcessLineageGraph(tree, config) {
  const maxNodes = 80;
  const columnWidth = 260;
  const rowHeight = 72;
  const nodeWidth = 190;
  const nodeHeight = 42;
  const nodes = [];
  const links = [];
  const seen = new Set();
  const columnRows = [0, 0, 0, 0, 0];
  let truncated = false;

  const addNode = (id, label, kind, column) => {
    if (seen.has(id)) return id;
    if (nodes.length >= maxNodes) {
      truncated = true;
      return id;
    }
    seen.add(id);
    const row = columnRows[column] || 0;
    columnRows[column] = row + 1;
    nodes.push({
      id,
      label,
      kind,
      x: 28 + column * columnWidth,
      y: 28 + row * rowHeight,
      width: nodeWidth,
      height: nodeHeight,
    });
    return id;
  };
  const addLink = (from, to) => {
    if (!seen.has(from) || !seen.has(to)) return;
    links.push({ from, to });
  };

  const rootId = addNode("root", tree.processName, config.mapType === "jobs" ? "job" : "root", 0);
  tree.steps.forEach((step) => {
    const stepId = `step:${step.stepOrder}`;
    addNode(stepId, config.mapType === "jobs" ? `Step ${step.stepOrder}: ${step.stepName}` : step.stepName, "step", 1);
    addLink(rootId, stepId);
    step.objects.forEach((object) => {
      const objectId = `object:${step.stepOrder}:${object.schemaName}.${object.objectName}`;
      addNode(
        objectId,
        `${object.schemaName}.${object.objectName}`,
        object.isResolved === false || object.resolutionStatus === "Unresolved object" ? "unresolved" : "object",
        2
      );
      addLink(stepId, objectId);
      if (object.hasDynamicSql || object.lineageNotes?.length) {
        const warningId = `warning:${step.stepOrder}:${object.schemaName}.${object.objectName}`;
        const warningLabel = object.hasDynamicSql ? "Dynamic SQL / partial lineage" : "Lineage warning";
        addNode(warningId, warningLabel, "warning", 3);
        addLink(objectId, warningId);
      }
      object.tables.forEach((table) => {
        const tableId = `table:${table.schemaName}.${table.objectName}`;
        const tableKind = String(table.confidence || "").toLowerCase() === "high" ? "table" : "partial-table";
        addNode(tableId, `${table.schemaName}.${table.objectName}`, tableKind, 3);
        addLink(objectId, tableId);
        table.features?.forEach((feature) => {
          const featureId = `feature:${table.schemaName}.${table.objectName}:${feature.kind}:${feature.schemaName}.${feature.objectName}`;
          const featureType = formatTableFeatureType(feature);
          addNode(featureId, `${featureType.badge} ${feature.objectName}`, featureType.kind === "trigger" ? "trigger" : "computed", 4);
          addLink(tableId, featureId);
        });
      });
    });
  });

  const nodeMap = new Map(nodes.map((node) => [node.id, node]));
  const usedColumns = Math.max(...nodes.map((node) => Math.floor((node.x - 28) / columnWidth)), 0) + 1;
  return {
    nodes,
    links,
    nodeMap,
    truncated,
    limit: maxNodes,
    width: Math.max(720, 28 + usedColumns * columnWidth),
    height: Math.max(180, 28 + Math.max(...columnRows, 1) * rowHeight),
    caption: `${nodes.length} nodes, ${links.length} links`,
  };
}

function renderGraphLink(link, nodeMap) {
  const from = nodeMap.get(link.from);
  const to = nodeMap.get(link.to);
  if (!from || !to) return "";
  const startX = from.x + from.width;
  const startY = from.y + from.height / 2;
  const endX = to.x;
  const endY = to.y + to.height / 2;
  const mid = Math.max(36, (endX - startX) / 2);
  return `<path class="lineage-link" d="M ${startX} ${startY} C ${startX + mid} ${startY}, ${endX - mid} ${endY}, ${endX} ${endY}"></path>`;
}

function renderGraphNode(node) {
  return `
    <g class="lineage-node lineage-node-${escapeHtml(node.kind)}" transform="translate(${node.x} ${node.y})">
      <title>${escapeHtml(node.label)}</title>
      <rect width="${node.width}" height="${node.height}" rx="7"></rect>
      <text x="12" y="25">${escapeHtml(truncateMiddle(node.label, 28))}</text>
    </g>
  `;
}

function buildProcessLineageTree(processName, rows, processObjects, tableFeatures = []) {
  const steps = new Map();
  const featuresByTable = new Map();
  tableFeatures.forEach((feature) => {
    const tableSchema = feature.table_schema || "dbo";
    const tableName = feature.table_name || "";
    if (!tableName) return;
    const tableKey = `${tableSchema}.${tableName}`.toLowerCase();
    if (!featuresByTable.has(tableKey)) featuresByTable.set(tableKey, []);
    featuresByTable.get(tableKey).push({
      kind: feature.feature_kind || "",
      schemaName: feature.feature_schema || tableSchema,
      objectName: feature.feature_name || "",
      type: feature.feature_type || "",
      status: feature.status || "",
      events: feature.events || "",
      referencedColumns: feature.referenced_columns || "",
      definition: feature.definition || "",
    });
  });
  const addObject = (raw) => {
    const stepOrder = raw.step_order ?? raw.step_id ?? "-";
    const stepKey = String(stepOrder);
    if (!steps.has(stepKey)) {
      steps.set(stepKey, {
        stepOrder,
        stepName: raw.step_name || `Step ${stepOrder}`,
        dbName: raw.database_name || "",
        objects: new Map(),
      });
    }
    const step = steps.get(stepKey);
    const schemaName = raw.called_schema || raw.schema_name || "dbo";
    const objectName = raw.called_object_name || raw.object_name || "";
    if (!objectName) return null;
    const objectKey = `${schemaName}.${objectName}`;
    if (!step.objects.has(objectKey)) {
      step.objects.set(objectKey, {
        schemaName,
        objectName,
        objectType: raw.object_type || raw.called_object_type || "SQL object",
        confidence: raw.confidence || "",
        resolutionStatus: raw.resolution_status || "",
        isResolved: normalizeSqlBoolean(raw.is_resolved, raw.resolution_status !== "Unresolved object"),
        hasDynamicSql: normalizeSqlBoolean(raw.has_dynamic_sql, false),
        lineageNotes: uniqueValues([raw.lineage_note]),
        calledDefinition: raw.called_definition || "",
        commandFragments: uniqueFragments([raw.command_preview]),
        tables: new Map(),
      });
    } else if (raw.command_preview || raw.called_definition || raw.lineage_note || raw.resolution_status || raw.has_dynamic_sql !== undefined) {
      const existing = step.objects.get(objectKey);
      existing.commandFragments = uniqueFragments([...(existing.commandFragments || []), raw.command_preview]);
      existing.calledDefinition = existing.calledDefinition || raw.called_definition || "";
      existing.confidence = strongestConfidence(existing.confidence, raw.confidence);
      existing.resolutionStatus = existing.resolutionStatus || raw.resolution_status || "";
      existing.isResolved = existing.isResolved && normalizeSqlBoolean(raw.is_resolved, existing.isResolved);
      existing.hasDynamicSql = existing.hasDynamicSql || normalizeSqlBoolean(raw.has_dynamic_sql, false);
      existing.lineageNotes = uniqueValues([...(existing.lineageNotes || []), raw.lineage_note]);
    }
    return step.objects.get(objectKey);
  };

  processObjects.forEach((raw) => addObject(raw));
  rows.forEach((row) => {
    const object = addObject(row);
    if (!object) return;
    const referencedType = String(row.referenced_type || "").toUpperCase();
    const referencedObject = row.referenced_object || "";
    if (!referencedObject || !referencedType.includes("TABLE")) return;
    const tableSchema = row.referenced_schema || "dbo";
    const tableKey = `${tableSchema}.${referencedObject}`;
    const codeFragments = extractCodeFragments(row.called_definition || object.calledDefinition, tableSchema, referencedObject);
    object.tables.set(tableKey, {
      schemaName: tableSchema,
      objectName: referencedObject,
      type: row.referenced_type || "USER_TABLE",
      confidence: row.confidence || object.confidence || "",
      lineageNotes: uniqueValues([row.lineage_note]),
      features: featuresByTable.get(tableKey.toLowerCase()) || [],
      commandFragments: uniqueFragments([
        ...((object.tables.get(tableKey)?.commandFragments) || []),
        ...codeFragments,
      ]),
    });
  });

  const tree = {
    processName,
    steps: Array.from(steps.values())
      .sort((a, b) => Number(a.stepOrder) - Number(b.stepOrder))
      .map((step) => ({
        ...step,
        objects: Array.from(step.objects.values()).map((object) => ({
          ...object,
          tables: Array.from(object.tables.values()).sort((a, b) =>
            `${a.schemaName}.${a.objectName}`.localeCompare(`${b.schemaName}.${b.objectName}`)
          ),
        })),
      })),
  };
  attachReverseTableUsages(tree);
  return tree;
}

function summarizeProcessMapImpact(tree) {
  const objects = new Set();
  const tables = new Set();
  const triggers = new Set();
  const computedColumns = new Set();
  const partialDependencies = new Set();
  const dynamicSql = new Set();
  const unresolved = new Set();
  tree.steps.forEach((step) => {
    step.objects.forEach((object) => {
      const objectKey = `${object.schemaName}.${object.objectName}`.toLowerCase();
      objects.add(objectKey);
      if (object.hasDynamicSql) dynamicSql.add(objectKey);
      if (object.isResolved === false || object.resolutionStatus === "Unresolved object") unresolved.add(objectKey);
      if (String(object.confidence || "").toLowerCase() !== "high") {
        partialDependencies.add(`object:${step.stepOrder}:${object.schemaName}.${object.objectName}`.toLowerCase());
      }
      object.tables.forEach((table) => {
        tables.add(`${table.schemaName}.${table.objectName}`.toLowerCase());
        if (String(table.confidence || "").toLowerCase() !== "high") {
          partialDependencies.add(`table:${table.schemaName}.${table.objectName}`.toLowerCase());
        }
        table.features?.forEach((feature) => {
          const featureKey = `${table.schemaName}.${table.objectName}.${feature.schemaName}.${feature.objectName}`.toLowerCase();
          if (String(feature.kind || "").toLowerCase() === "trigger") {
            triggers.add(featureKey);
          } else {
            computedColumns.add(featureKey);
          }
        });
      });
    });
  });
  return {
    stepCount: tree.steps.length,
    objectCount: objects.size,
    tableCount: tables.size,
    triggerCount: triggers.size,
    computedColumnCount: computedColumns.size,
    dynamicSqlCount: dynamicSql.size,
    unresolvedCount: unresolved.size,
    partialDependencyCount: partialDependencies.size,
  };
}

function attachReverseTableUsages(tree) {
  const usagesByTable = new Map();
  tree.steps.forEach((step) => {
    step.objects.forEach((object) => {
      const objectType = formatObjectType(object.objectType).label;
      object.tables.forEach((table) => {
        const tableKey = `${table.schemaName}.${table.objectName}`.toLowerCase();
        if (!usagesByTable.has(tableKey)) usagesByTable.set(tableKey, []);
        usagesByTable.get(tableKey).push({
          processName: tree.processName,
          stepOrder: step.stepOrder,
          stepName: step.stepName,
          dbName: step.dbName,
          objectName: `${object.schemaName}.${object.objectName}`,
          objectType,
          confidence: table.confidence || object.confidence || "",
        });
      });
    });
  });

  tree.steps.forEach((step) => {
    step.objects.forEach((object) => {
      object.tables.forEach((table) => {
        const tableKey = `${table.schemaName}.${table.objectName}`.toLowerCase();
        table.usedBy = uniqueTableUsages(usagesByTable.get(tableKey) || []);
      });
    });
  });
}

function uniqueTableUsages(usages) {
  const seen = new Set();
  const output = [];
  usages.forEach((usage) => {
    const key = `${usage.stepOrder}|${usage.objectName}|${usage.dbName}`;
    if (seen.has(key)) return;
    seen.add(key);
    output.push(usage);
  });
  return output.sort((a, b) => {
    const byStep = Number(a.stepOrder) - Number(b.stepOrder);
    if (!Number.isNaN(byStep) && byStep !== 0) return byStep;
    return String(a.objectName).localeCompare(String(b.objectName));
  });
}

function renderProcessMapStep(step) {
  return `
    <details class="process-step-node" open>
      <summary>
        <span class="node-caret" aria-hidden="true"></span>
        <span class="node-badge">Step ${escapeHtml(step.stepOrder)}</span>
        <strong>${escapeHtml(step.stepName)}</strong>
        ${step.dbName ? `<span class="node-muted">${escapeHtml(step.dbName)}</span>` : ""}
      </summary>
      <div class="process-object-list">
        ${
          step.objects.length > 0
            ? step.objects.map((object) => renderProcessMapObject(object, step)).join("")
            : renderMapEmptyState(
                "No SQL objects detected.",
                "This step may not be T-SQL, may use dynamic SQL, or the current login may not see object metadata."
              )
        }
      </div>
    </details>
  `;
}

function renderProcessMapObject(object, step) {
  const objectType = formatObjectType(object.objectType);
  const detailKey = registerProcessMapDetail({
    kind: "SQL Object",
    name: `${object.schemaName}.${object.objectName}`,
    type: objectType.label,
    confidence: object.confidence,
    processName: state.processMapName,
    stepOrder: step.stepOrder,
    stepName: step.stepName,
    dbName: step.dbName,
    resolutionStatus: object.resolutionStatus,
    hasDynamicSql: object.hasDynamicSql,
    lineageNotes: object.lineageNotes || [],
    commandFragments: object.commandFragments || [],
    fragmentTitle: "Job command fragments",
  });
  const objectWarnings = renderLineageNotes([
    object.hasDynamicSql ? "Dynamic SQL detected; lineage may be incomplete." : "",
    ...(object.lineageNotes || []),
  ]);
  return `
    <details class="process-object-node" open>
      <summary>
        <span class="node-caret" aria-hidden="true"></span>
        <span class="node-badge sql-object">${escapeHtml(objectType.badge)}</span>
        <strong>${escapeHtml(object.schemaName)}.${escapeHtml(object.objectName)}</strong>
        <span class="node-muted">${escapeHtml(objectType.label)}</span>
        ${object.confidence ? `<span class="confidence-pill" title="${escapeHtml(confidenceDescription(object.confidence))}">Confidence: ${escapeHtml(object.confidence)}</span>` : ""}
        ${object.resolutionStatus ? `<span class="lineage-status-pill ${object.isResolved === false ? "lineage-status-warn" : ""}">${escapeHtml(object.resolutionStatus)}</span>` : ""}
        <button type="button" class="map-detail-button" data-detail-key="${escapeHtml(detailKey)}" title="Show detail" aria-label="Show detail">i</button>
      </summary>
      ${objectWarnings}
      <div class="referenced-table-list">
        ${
          object.tables.length > 0
            ? object.tables.map((table) => renderProcessMapTable(table, object, step)).join("")
            : renderMapEmptyState(
                "No referenced tables found in catalog metadata.",
                "Dynamic SQL, temp tables, cross-database references, encrypted modules, or permissions can hide dependencies."
              )
        }
      </div>
    </details>
  `;
}

function renderProcessMapTable(table, object, step) {
  const tableType = formatObjectType(table.type || "USER_TABLE");
  const detailKey = registerProcessMapDetail({
    kind: "Referenced Table",
    name: `${table.schemaName}.${table.objectName}`,
    type: tableType.label,
    confidence: table.confidence,
    processName: state.processMapName,
    stepOrder: step.stepOrder,
    stepName: step.stepName,
    dbName: step.dbName,
    parentObject: `${object.schemaName}.${object.objectName}`,
    usedBy: table.usedBy || [],
    lineageNotes: table.lineageNotes || [],
    commandFragments: table.commandFragments || object.commandFragments || [],
    fragmentTitle: "Procedure code fragments",
  });
  const tableWarnings = renderLineageNotes(table.lineageNotes || []);
  return `
    <details class="table-node-shell" open>
      <summary class="table-node">
        <span class="node-caret" aria-hidden="true"></span>
        <span class="node-badge table-object">${escapeHtml(tableType.badge)}</span>
        <strong>${escapeHtml(table.schemaName)}.${escapeHtml(table.objectName)}</strong>
        <span class="node-muted">${escapeHtml(tableType.label)}</span>
        ${table.confidence ? `<span class="confidence-pill" title="${escapeHtml(confidenceDescription(table.confidence))}">Confidence: ${escapeHtml(table.confidence)}</span>` : ""}
        <button type="button" class="map-detail-button" data-detail-key="${escapeHtml(detailKey)}" title="Show detail" aria-label="Show detail">i</button>
      </summary>
      ${tableWarnings}
      ${
        table.features?.length
          ? `<div class="table-feature-list">${table.features.map((feature) => renderTableFeature(feature, table, object, step)).join("")}</div>`
          : ""
      }
    </details>
  `;
}

function renderTableFeature(feature, table, object, step) {
  const featureType = formatTableFeatureType(feature);
  const featureName = featureType.kind === "computed_column"
    ? `${table.schemaName}.${table.objectName}.${feature.objectName}`
    : `${feature.schemaName}.${feature.objectName}`;
  const detailKey = registerProcessMapDetail({
    kind: featureType.detailKind,
    name: featureName,
    type: feature.type || featureType.label,
    status: feature.status,
    events: feature.events,
    referencedColumns: feature.referencedColumns,
    processName: state.processMapName,
    stepOrder: step.stepOrder,
    stepName: step.stepName,
    dbName: step.dbName,
    parentObject: `${table.schemaName}.${table.objectName}`,
    parentLabel: "Table",
    calledObject: `${object.schemaName}.${object.objectName}`,
    commandFragments: uniqueFragments([feature.definition]),
    fragmentTitle: featureType.fragmentTitle,
  });
  return `
    <div class="table-feature-node">
      <span class="node-badge ${escapeHtml(featureType.className)}">${escapeHtml(featureType.badge)}</span>
      <strong>${escapeHtml(featureName)}</strong>
      <span class="node-muted">${escapeHtml(feature.status || featureType.label)}</span>
      ${feature.events ? `<span class="node-muted">${escapeHtml(feature.events)}</span>` : ""}
      <button type="button" class="map-detail-button" data-detail-key="${escapeHtml(detailKey)}" title="Show detail" aria-label="Show detail">i</button>
    </div>
  `;
}

function bindProcessMapControls() {
  const searchInput = document.querySelector("#processMapSearch");
  const loadButton = document.querySelector(".process-picker-go");
  const menuButton = document.querySelector(".process-picker-menu-button");
  const menu = document.querySelector(".process-picker-menu");
  const filterProcessOptions = (showAll = false) => {
    const filter = String(searchInput?.value || "").toLowerCase();
    document.querySelectorAll(".process-picker-option").forEach((option) => {
      const name = String(option.dataset.processName || "");
      option.classList.toggle("hidden", !showAll && Boolean(filter) && !name.toLowerCase().includes(filter));
    });
  };
  const loadSelectedProcess = async () => {
    const processName = String(searchInput?.value || "").trim();
    if (!processName || processName === state.processMapName) return;
    els.cardView.innerHTML = renderMapLoadingState(processName);
    try {
      await runProcessLineageMap(processName);
    } catch (error) {
      showMessage(els.message, error.message, "error");
    }
  };
  const showMenu = (showAll = false) => {
    filterProcessOptions(showAll);
    menu?.classList.remove("hidden");
  };
  const hideMenu = () => {
    menu?.classList.add("hidden");
  };
  menuButton?.addEventListener("click", () => {
    if (menu?.classList.contains("hidden")) {
      showMenu(true);
      searchInput?.focus();
    } else {
      hideMenu();
    }
  });
  searchInput?.addEventListener("focus", () => showMenu(true));
  searchInput?.addEventListener("input", () => showMenu(false));
  loadButton?.addEventListener("click", loadSelectedProcess);
  searchInput?.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault();
      loadSelectedProcess();
    } else if (event.key === "Escape") {
      hideMenu();
    }
  });
  searchInput?.addEventListener("change", () => {
    if (state.processMapNames.includes(searchInput.value)) {
      loadSelectedProcess();
    }
  });
  document.querySelectorAll(".process-picker-option").forEach((option) => {
    option.addEventListener("click", () => {
      if (searchInput) {
        searchInput.value = option.dataset.processName || "";
      }
      hideMenu();
      loadSelectedProcess();
    });
  });
  document.querySelectorAll(".map-toggle-button").forEach((button) => {
    button.addEventListener("click", () => {
      const open = button.dataset.mapAction === "expand";
      document.querySelectorAll(".process-map details").forEach((details) => {
        details.open = open;
      });
    });
  });
  document.querySelectorAll(".legend-toggle-button").forEach((button) => {
    button.addEventListener("click", () => {
      const legend = button.parentElement?.querySelector(".confidence-legend");
      legend?.classList.toggle("hidden");
    });
  });
  document.querySelectorAll(".map-detail-button").forEach((button) => {
    button.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      renderProcessMapDetail(button.dataset.detailKey || "");
    });
  });
}

function registerProcessMapDetail(detail) {
  const key = `detail_${Object.keys(state.processMapDetails).length + 1}`;
  state.processMapDetails[key] = detail;
  return key;
}

function renderMapLoadingState(name) {
  return `
    <div class="process-map-empty process-map-loading">
      <div class="loading-state">
        <div class="loading-spinner" aria-hidden="true"></div>
        <div>
          <strong>Loading ${escapeHtml(name)}</strong>
          <span>Building the online lineage map.</span>
        </div>
        <div class="loading-bar" aria-hidden="true"><span></span></div>
      </div>
    </div>
  `;
}

function renderMapEmptyState(title, description) {
  return `
    <div class="node-empty">
      <strong>${escapeHtml(title)}</strong>
      <span>${escapeHtml(description)}</span>
    </div>
  `;
}

function renderProcessMapDetail(detailKey) {
  const detail = state.processMapDetails[detailKey];
  if (!els.mapDetailDialog || !els.mapDetailTitle || !els.mapDetailBody || !detail) return;
  const fragments = uniqueFragments(detail.commandFragments || []);
  els.mapDetailTitle.textContent = detail.name || "Map detail";
  els.mapDetailBody.innerHTML = `
    <div class="map-detail-head">
      <div>
        <span class="map-kicker">${escapeHtml(detail.kind || "Detail")}</span>
        <h4>${escapeHtml(detail.name || "-")}</h4>
      </div>
      ${detail.confidence ? `<span class="confidence-pill" title="${escapeHtml(confidenceDescription(detail.confidence))}">Confidence: ${escapeHtml(detail.confidence)}</span>` : ""}
    </div>
    <div class="map-detail-grid">
      <div><strong>Type</strong><span>${escapeHtml(detail.type || "-")}</span></div>
      <div><strong>Job</strong><span>${escapeHtml(detail.processName || "-")}</span></div>
      <div><strong>Step</strong><span>${escapeHtml(formatStepLabel(detail))}</span></div>
      <div><strong>DB</strong><span>${escapeHtml(detail.dbName || "-")}</span></div>
      ${detail.parentObject ? `<div><strong>${escapeHtml(detail.parentLabel || "Called Object")}</strong><span>${escapeHtml(detail.parentObject)}</span></div>` : ""}
      ${detail.calledObject ? `<div><strong>SQL Object</strong><span>${escapeHtml(detail.calledObject)}</span></div>` : ""}
      ${detail.resolutionStatus ? `<div><strong>Resolution</strong><span>${escapeHtml(detail.resolutionStatus)}</span></div>` : ""}
      ${detail.hasDynamicSql ? `<div><strong>Dynamic SQL</strong><span>Detected</span></div>` : ""}
      ${detail.status ? `<div><strong>Status</strong><span>${escapeHtml(detail.status)}</span></div>` : ""}
      ${detail.events ? `<div><strong>Events</strong><span>${escapeHtml(detail.events)}</span></div>` : ""}
      ${detail.referencedColumns ? `<div><strong>Columns</strong><span>${escapeHtml(detail.referencedColumns)}</span></div>` : ""}
    </div>
    ${renderLineageNotes(detail.lineageNotes || [])}
    <div class="map-fragments">
      <strong>${escapeHtml(detail.fragmentTitle || "Command fragments")}</strong>
      ${
        fragments.length > 0
          ? fragments.map(renderCodeFragment).join("")
          : `<div class="node-empty">No command fragment available.</div>`
      }
    </div>
    ${renderMapUsedBy(detail.usedBy || [])}
  `;
  els.mapDetailDialog.showModal();
}

function renderMapUsedBy(usages) {
  if (!usages.length) return "";
  return `
    <div class="map-used-by">
      <strong>Used by in this map</strong>
      <div class="map-used-by-list">
        ${usages.map((usage) => `
          <div class="map-used-by-item">
            <span class="node-badge sql-object">${escapeHtml(formatObjectType(usage.objectType).badge)}</span>
            <div>
              <strong>${escapeHtml(usage.objectName || "-")}</strong>
              <span>${escapeHtml(formatStepLabel(usage))}${usage.dbName ? ` · ${escapeHtml(usage.dbName)}` : ""}${usage.confidence ? ` · Confidence: ${escapeHtml(usage.confidence)}` : ""}</span>
            </div>
          </div>
        `).join("")}
      </div>
    </div>
  `;
}

function formatStepLabel(detail) {
  const order = detail.stepOrder ? `Step ${detail.stepOrder}` : "Step";
  return detail.stepName ? `${order} - ${detail.stepName}` : order;
}

function uniqueValues(values) {
  return Array.from(new Set((values || []).filter((value) => value !== null && value !== undefined && value !== "")));
}

function normalizeSqlBoolean(value, fallback = false) {
  if (value === true || value === 1 || value === "1") return true;
  if (value === false || value === 0 || value === "0") return false;
  return fallback;
}

function strongestConfidence(current, next) {
  const rank = { low: 1, medium: 2, high: 3 };
  const currentRank = rank[String(current || "").toLowerCase()] || 0;
  const nextRank = rank[String(next || "").toLowerCase()] || 0;
  return nextRank > currentRank ? next : current;
}

function renderLineageNotes(notes) {
  const values = uniqueValues(notes);
  if (!values.length) return "";
  return `
    <div class="lineage-note-list">
      ${values.map((note) => `<span>${escapeHtml(note)}</span>`).join("")}
    </div>
  `;
}

function truncateMiddle(value, maxLength) {
  const text = String(value || "");
  if (text.length <= maxLength) return text;
  const keep = Math.max(4, Math.floor((maxLength - 1) / 2));
  return `${text.slice(0, keep)}…${text.slice(-keep)}`;
}

function normalizeFragment(fragment) {
  if (fragment && typeof fragment === "object") {
    const text = String(fragment.text || "").trim();
    if (!text) return null;
    return {
      text,
      lineNumber: fragment.lineNumber || null,
      lineRange: fragment.lineRange || "",
    };
  }
  const text = String(fragment || "").trim();
  return text ? { text, lineNumber: null, lineRange: "" } : null;
}

function uniqueFragments(fragments) {
  const seen = new Set();
  const normalized = [];
  (fragments || []).forEach((fragment) => {
    const item = normalizeFragment(fragment);
    if (!item) return;
    const key = `${item.lineNumber || ""}|${item.text}`;
    if (seen.has(key)) return;
    seen.add(key);
    normalized.push(item);
  });
  return normalized;
}

function renderCodeFragment(fragment) {
  const lineLabel = fragment.lineNumber
    ? `Line ${fragment.lineNumber}${fragment.lineRange ? ` (${fragment.lineRange})` : ""}`
    : "Command";
  return `
    <div class="code-fragment">
      <span class="fragment-line-label">${escapeHtml(lineLabel)}</span>
      <pre>${escapeHtml(fragment.text)}</pre>
    </div>
  `;
}

function extractCodeFragments(definition, schemaName, objectName) {
  const source = String(definition || "");
  const object = String(objectName || "").trim();
  if (!source || !object || object.length < 2) return [];

  const schema = String(schemaName || "dbo").trim() || "dbo";
  const candidates = uniqueValues([
    `${schema}.${object}`,
    `[${schema}].[${object}]`,
    `${schema}].[${object}`,
    `[${schema}].${object}`,
    object,
    `[${object}]`,
  ]).map(normalizeSqlSearchText);

  const lines = source.replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n");
  const fragments = [];
  const usedRanges = new Set();

  lines.forEach((line, index) => {
    const normalizedLine = normalizeSqlSearchText(line);
    if (!candidates.some((candidate) => candidate && normalizedLine.includes(candidate))) return;

    const start = Math.max(0, index - 2);
    const end = Math.min(lines.length - 1, index + 2);
    const key = `${start}:${end}`;
    if (usedRanges.has(key)) return;
    usedRanges.add(key);
    fragments.push({
      text: lines.slice(start, end + 1).join("\n").trim(),
      lineNumber: index + 1,
      lineRange: `${start + 1}-${end + 1}`,
    });
  });

  return fragments.slice(0, 12);
}

function normalizeSqlSearchText(value) {
  return String(value || "")
    .toLowerCase()
    .replaceAll("[", "")
    .replaceAll("]", "")
    .replace(/\s+/g, " ")
    .trim();
}

function formatObjectType(value) {
  const normalized = String(value || "SQL object").replaceAll("_", " ").toLowerCase();
  if (normalized.includes("procedure")) return { badge: "PROC", label: "Stored procedure" };
  if (normalized.includes("view")) return { badge: "VIEW", label: "View" };
  if (normalized.includes("function")) return { badge: "FUNC", label: "Function" };
  if (normalized.includes("trigger")) return { badge: "TRG", label: "Trigger" };
  if (normalized.includes("table")) return { badge: "TABLE", label: "Table" };
  return { badge: "SQL", label: labelize(value || "SQL object") };
}

function formatTableFeatureType(feature) {
  const kind = String(feature?.kind || "").toLowerCase();
  if (kind === "trigger") {
    return {
      kind,
      badge: "TRG",
      label: "Trigger",
      detailKind: "Table Trigger",
      className: "trigger-object",
      fragmentTitle: "Trigger definition",
    };
  }
  return {
    kind: "computed_column",
    badge: "CALC",
    label: "Computed column",
    detailKind: "Computed Column",
    className: "computed-object",
    fragmentTitle: "Computed column expression",
  };
}

function confidenceDescription(value) {
  const normalized = String(value || "").toLowerCase();
  if (normalized === "high") return "SQL Server catalog dependency resolved the referenced object.";
  if (normalized === "medium") return "The SQL object was detected, but table dependency information is partial.";
  if (normalized === "low") return "The object was parsed from job command text only.";
  return "Detection confidence.";
}

function renderCards() {
  const row = state.rows[0] || {};
  els.rowCount.textContent = String(state.rows.length);
  els.columnCount.textContent = String(state.columns.length);
  els.exportCsv.disabled = state.rows.length === 0;
  els.message.classList.add("hidden");
  els.tableTools.classList.add("hidden");
  els.tableWrap.classList.add("hidden");
  els.pagination.classList.add("hidden");
  els.cardView.classList.remove("hidden");
  els.cardView.innerHTML = "";

  if (state.columns.length === 0) {
    els.cardView.innerHTML = `<div class="empty card-empty">No values to display.</div>`;
    return;
  }

  const groups = getCardGroups();
  groups.forEach((group) => {
    const section = document.createElement("section");
    section.className = "multirow-card";
    const title = document.createElement("h3");
    title.textContent = group.title;
    const titleIndicator = renderCardTitleIndicator(group, row);
    if (titleIndicator) title.appendChild(titleIndicator);
    const metrics = document.createElement("div");
    metrics.className = "multirow-metrics";

    group.fields.forEach((field) => {
      if (!state.columns.includes(field)) return;
      if (state.activeQuery?.name === "live_dashboard" && field === "traffic_light") return;
      const metric = document.createElement("div");
      metric.className = "multirow-metric";
      if (field === "traffic_light") metric.classList.add("traffic-light-metric");
      if (field === "pressure_level") metric.classList.add("pressure-thermometer-metric");
      const liveTarget = liveDashboardTargetForField(field, row);
      if (liveTarget) {
        metric.classList.add("live-dashboard-link");
        metric.dataset.liveTarget = liveTarget;
        metric.title = `Open ${labelize(liveTarget)}`;
      }
      const gaugeClass = dashboardGaugeClass(field);
      if (gaugeClass) {
        metric.classList.add("dashboard-gauge-metric", gaugeClass);
        metric.style.setProperty("--gauge-fill", dashboardGaugeFill(field, row[field]));
        metric.style.setProperty("--gauge-angle", dashboardGaugeAngle(field, row[field]));
      }
      const statusClass = dashboardStatusClass(field, row[field]);
      if (statusClass) metric.classList.add(statusClass);
      const value = document.createElement("strong");
      value.textContent = formatValue(row[field]);
      value.title = value.textContent;
      value.className = value.textContent.length > 20 ? "compact-value" : "";
      const label = document.createElement("span");
      label.textContent = field === "traffic_light" ? "Traffic Light" : labelize(field);
      metric.append(value, label);
      metrics.appendChild(metric);
    });

    if (metrics.children.length > 0) {
      section.append(title, metrics);
      els.cardView.appendChild(section);
    }
  });
  if (state.activeQuery?.name === "live_dashboard") {
    bindLiveDashboardControls();
  }
}

function bindLiveDashboardControls() {
  els.cardView.querySelectorAll("[data-live-target]").forEach((item) => {
    item.addEventListener("click", () => {
      const queryName = item.dataset.liveTarget;
      const group = getVisibleGroups(getActiveArea()).find((candidate) => candidate.names.includes(queryName));
      if (!queryName || !group) return;
      selectAndRunQuery(queryName, group.title);
    });
  });
}

function liveDashboardTargetForField(field, row) {
  if (state.activeQuery?.name !== "live_dashboard") return "";
  const directTargets = {
    active_requests: "live_current_requests",
    long_running_requests: "live_current_requests",
    active_waits: "live_active_waits",
    blocked_sessions: "live_blocking",
    root_blockers: "live_root_blockers",
    tempdb_sessions: "live_tempdb_usage",
    max_tempdb_mb: "live_tempdb_usage",
    log_used_percent: "live_log_usage",
  };
  if (directTargets[field]) return directTargets[field];
  if (["pressure_level", "status_summary"].includes(field)) {
    if (Number(row.blocked_sessions || 0) > 0) return "live_blocking";
    if (Number(row.root_blockers || 0) > 0) return "live_root_blockers";
    if (Number(row.active_waits || 0) > 0) return "live_active_waits";
    if (Number(row.long_running_requests || 0) > 0 || Number(row.active_requests || 0) > 0) return "live_current_requests";
    if (Number(row.max_tempdb_mb || 0) >= 256 || Number(row.tempdb_sessions || 0) > 0) return "live_tempdb_usage";
    if (Number(row.log_used_percent || 0) >= 75) return "live_log_usage";
  }
  return "";
}

function renderCardTitleIndicator(group, row) {
  if (state.activeQuery?.name !== "live_dashboard" || !group.fields.includes("traffic_light")) return null;
  const indicator = document.createElement("span");
  indicator.className = `title-traffic-light ${dashboardStatusClass("traffic_light", row.traffic_light) || ""}`;
  indicator.title = `Traffic Light: ${formatValue(row.traffic_light)}`;
  indicator.setAttribute("aria-label", `Traffic Light: ${formatValue(row.traffic_light)}`);
  return indicator;
}

function getCardGroups() {
  const configured = CARD_GROUPS[state.activeQuery?.name] || [];
  if (configured.length > 0) return configured;
  return [{ title: "Details", fields: state.columns }];
}

function dashboardStatusClass(field, value) {
  const fieldName = String(field || "").toLowerCase();
  const numericValue = Number(value);
  if (fieldName === "log_used_percent" && Number.isFinite(numericValue)) {
    if (numericValue >= 90) return "metric-critical";
    if (numericValue >= 75) return "metric-warning";
    return "metric-good";
  }
  if (fieldName === "max_tempdb_mb" && Number.isFinite(numericValue)) {
    if (numericValue >= 1024) return "metric-critical";
    if (numericValue >= 256) return "metric-warning";
    return "metric-good";
  }
  if (fieldName === "tempdb_sessions" && Number.isFinite(numericValue)) {
    if (numericValue >= 10) return "metric-critical";
    if (numericValue >= 3) return "metric-warning";
    return "metric-good";
  }
  if (!fieldName.includes("status") && !fieldName.includes("level") && !fieldName.includes("traffic_light")) {
    return "";
  }
  const normalized = String(value || "").trim().toLowerCase();
  if (["red", "critical", "high", "error", "permission"].includes(normalized)) return "metric-critical";
  if (["yellow", "warning", "medium"].includes(normalized)) return "metric-warning";
  if (["green", "good", "low", "ok", "normal"].includes(normalized)) return "metric-good";
  return "";
}

function dashboardGaugeClass(field) {
  const name = String(field || "").toLowerCase();
  if (["tempdb_sessions", "max_tempdb_mb", "log_used_percent"].includes(name)) return `gauge-${name.replaceAll("_", "-")}`;
  return "";
}

function dashboardGaugeFill(field, value) {
  const numericValue = Number(value);
  if (!Number.isFinite(numericValue) || numericValue <= 0) return "4%";
  if (field === "log_used_percent") return `${Math.max(4, Math.min(100, numericValue))}%`;
  if (field === "max_tempdb_mb") return `${Math.max(4, Math.min(100, (numericValue / 1024) * 100))}%`;
  if (field === "tempdb_sessions") return `${Math.max(4, Math.min(100, numericValue * 10))}%`;
  return "4%";
}

function dashboardGaugeAngle(field, value) {
  const fill = Number.parseFloat(dashboardGaugeFill(field, value));
  const clamped = Number.isFinite(fill) ? Math.max(0, Math.min(100, fill)) : 0;
  return `${-90 + (clamped * 1.8)}deg`;
}

function renderTable() {
  const filter = els.filterText.value.trim().toLowerCase();
  const rows = filter
    ? state.rows.filter((row) => rowMatchesFilter(row, filter))
    : state.rows;
  const totalPages = Math.max(1, Math.ceil(rows.length / TABLE_PAGE_SIZE));
  state.tablePage = Math.min(Math.max(1, state.tablePage), totalPages);
  const startIndex = (state.tablePage - 1) * TABLE_PAGE_SIZE;
  const visibleRows = rows.slice(startIndex, startIndex + TABLE_PAGE_SIZE);

  els.rowCount.textContent = String(rows.length);
  els.columnCount.textContent = String(state.columns.length);
  els.exportCsv.disabled = rows.length === 0;
  els.tableTools.classList.remove("hidden");
  els.cardView.classList.add("hidden");
  els.tableWrap.classList.remove("hidden");
  updatePagination(rows.length, totalPages, startIndex, visibleRows.length);

  const thead = els.table.querySelector("thead");
  const tbody = els.table.querySelector("tbody");
  thead.innerHTML = "";
  tbody.innerHTML = "";

  if (state.columns.length === 0) {
    renderEmptyTable("No columns to display.");
    return;
  }

  const headRow = document.createElement("tr");
  if (hasRowDetail()) {
    const detailTh = document.createElement("th");
    detailTh.textContent = "";
    detailTh.className = "row-action-header";
    headRow.appendChild(detailTh);
  }
  state.columns.forEach((column) => {
    const th = document.createElement("th");
    th.textContent = labelize(column);
    th.title = column;
    headRow.appendChild(th);
  });
  thead.appendChild(headRow);

  if (rows.length === 0) {
    const td = document.createElement("td");
    td.className = "empty";
    td.colSpan = state.columns.length + (hasRowDetail() ? 1 : 0);
    td.textContent = "No rows to display.";
    const tr = document.createElement("tr");
    tr.appendChild(td);
    tbody.appendChild(tr);
    return;
  }

  visibleRows.forEach((row) => {
    const tr = document.createElement("tr");
    if (hasRowDetail()) {
      const actionTd = document.createElement("td");
      actionTd.className = "row-action-cell";
      const button = document.createElement("button");
      button.type = "button";
      button.className = "row-detail-button";
      button.title = getRowDetailTitle();
      button.setAttribute("aria-label", button.title);
      button.textContent = "i";
      button.addEventListener("click", () => {
        if (isTablesQuery()) {
          openTableDetail(row);
        } else if (isCodeQuery()) {
          openCodeDetail(row);
        } else if (isProcessInventoryQuery()) {
          openProcessDetail(row);
        }
      });
      actionTd.appendChild(button);
      tr.appendChild(actionTd);
    }
    state.columns.forEach((column) => {
      const td = document.createElement("td");
      td.textContent = row[column] ?? "";
      tr.appendChild(td);
    });
    tbody.appendChild(tr);
  });
}

function rowMatchesFilter(row, filter) {
  if (state.filterColumn && state.columns.includes(state.filterColumn)) {
    return String(row[state.filterColumn] ?? "").toLowerCase().includes(filter);
  }
  return state.columns.some((column) => String(row[column] ?? "").toLowerCase().includes(filter));
}

function getDefaultFilterColumn() {
  const preferredByQuery = {
    tables: ["table_name"],
    procedures: ["procedure_name", "object_name"],
    views: ["view_name", "object_name"],
    functions: ["function_name", "object_name"],
    triggers: ["trigger_name", "object_name"],
    columns: ["column_name", "object_name", "table_name"],
    indexes: ["index_name", "table_name"],
    foreign_keys: ["foreign_key_name", "parent_table", "referenced_table"],
    schemas: ["schema_name"],
    database_files: ["logical_name", "physical_name"],
    filegroups: ["filegroup_name"],
    server_databases_summary: ["database_name"],
    database_scoped_configurations: ["configuration_name"],
    database_extended_properties: ["property_name"],
    database_principals: ["principal_name", "user_name", "name"],
    database_roles: ["role_name", "name"],
    database_role_members: ["role_name", "member_name"],
    database_permissions: ["grantee_name", "principal_name", "permission_name"],
    server_logins: ["login_name", "name"],
    server_role_members: ["member_name", "role_name"],
    linked_servers: ["linked_server_name", "name"],
    server_configurations: ["configuration_name", "name"],
    server_services: ["service_name", "servicename"],
    sql_agent_jobs: ["job_name", "name"],
    sql_agent_job_steps: ["job_name", "step_name"],
    sql_agent_job_schedules: ["job_name", "schedule_name"],
    sql_agent_job_history: ["job_name"],
    process_inventory: ["process_name"],
    process_steps: ["process_name", "step_name"],
    process_sql_objects: ["process_name", "object_name", "schema_name"],
    process_recent_runs: ["process_name", "run_status"],
    object_references: ["source_object", "target_object", "source_schema", "target_schema"],
    table_usage: ["table_name", "used_by_object", "table_schema"],
    process_lineage: ["process_name", "called_object_name", "referenced_object"],
    used_by_jobs: ["referenced_object", "process_name", "called_object_name"],
    live_dashboard: ["traffic_light", "pressure_level", "status_summary"],
    live_current_requests: ["session_id", "database_name", "login_name", "program_name", "wait_type"],
    live_session_resource_usage: ["session_id", "database_name", "login_name", "program_name"],
    live_blocking: ["session_id", "blocking_session_id", "database_name", "wait_type"],
    live_root_blockers: ["blocking_session_id", "login_name", "program_name"],
    live_active_waits: ["session_id", "database_name", "wait_type", "login_name"],
    live_tempdb_usage: ["session_id", "database_name", "login_name", "program_name"],
    live_log_usage: ["database_name", "pressure_level"],
  };
  const candidates = preferredByQuery[state.activeQuery?.name] || [];
  return candidates.find((column) => state.columns.includes(column)) || inferNameColumn();
}

function inferNameColumn() {
  return (
    state.columns.find((column) => column.endsWith("_name")) ||
    state.columns.find((column) => column === "name") ||
    ""
  );
}

function updateTableFilterUI() {
  const label = state.filterColumn ? `Filter by ${labelize(state.filterColumn)}` : "Filter";
  els.filterLabel.textContent = label;
  els.filterText.placeholder = state.filterColumn ? `filter ${labelize(state.filterColumn).toLowerCase()}...` : "filter results...";
}

function isTablesQuery() {
  return state.activeQuery?.name === "tables";
}

function isCodeQuery() {
  return ["views", "procedures", "functions", "triggers"].includes(state.activeQuery?.name);
}

function isProcessInventoryQuery() {
  return state.activeQuery?.name === "process_inventory";
}

function hasRowDetail() {
  return isTablesQuery() || isCodeQuery() || isProcessInventoryQuery();
}

function getRowDetailTitle() {
  if (isTablesQuery()) return "Open table detail";
  if (isCodeQuery()) return "Open SQL code detail";
  if (isProcessInventoryQuery()) return "Open process detail";
  return "Open detail";
}

async function openTableDetail(row) {
  const schemaName = row.schema_name;
  const tableName = row.table_name;
  if (!schemaName || !tableName || !state.connection) return;

  els.tableDetailTitle.textContent = `${schemaName}.${tableName}`;
  setActiveDetailTab("columns");
  els.tableDetailBody.innerHTML = `
    <div class="detail-loading">
      <div class="loading-spinner" aria-hidden="true"></div>
      <span>Loading table detail</span>
    </div>
  `;
  els.tableDetailDialog.showModal();

  try {
    const payload = await api("/api/table-detail", {
      method: "POST",
      body: JSON.stringify({
        connection: state.connection,
        schemaName,
        tableName,
      }),
    });
    const detail = {
      columns: payload.resultSets?.[0] || { columns: [], rows: [] },
      indexes: payload.resultSets?.[1] || { columns: [], rows: [] },
      foreignKeys: payload.resultSets?.[2] || { columns: [], rows: [] },
      sqlCode: payload.resultSets?.[3] || { columns: [], rows: [] },
    };
    els.tableDetailDialog.dataset.detail = JSON.stringify(detail);
    renderTableDetailTab("columns");
  } catch (error) {
    els.tableDetailBody.innerHTML = `<div class="alert-error">${escapeHtml(error.message)}</div>`;
  }
}

async function openCodeDetail(row) {
  const schemaName = row.schema_name;
  const objectName = getCodeObjectName(row);
  if (!schemaName || !objectName || !state.connection) return;

  els.codeDetailTitle.textContent = `${schemaName}.${objectName}`;
  els.codeDetailBody.innerHTML = `
    <div class="detail-loading">
      <div class="loading-spinner" aria-hidden="true"></div>
      <span>Loading referenced objects</span>
    </div>
  `;
  els.codeDetailDialog.showModal();

  try {
    const payload = await api("/api/code-object-detail", {
      method: "POST",
      body: JSON.stringify({
        connection: state.connection,
        schemaName,
        objectName,
      }),
    });
    const resultSet = payload.resultSets?.[0] || { columns: [], rows: [] };
    els.codeDetailBody.innerHTML = renderDetailResultSet(resultSet);
  } catch (error) {
    els.codeDetailBody.innerHTML = `<div class="alert-error">${escapeHtml(error.message)}</div>`;
  }
}

async function openProcessDetail(row) {
  const processName = row.process_name;
  if (!processName || !state.connection) return;

  els.processDetailTitle.textContent = processName;
  setActiveProcessDetailTab("overview");
  els.processDetailBody.innerHTML = `
    <div class="detail-loading">
      <div class="loading-spinner" aria-hidden="true"></div>
      <span>Loading process detail</span>
    </div>
  `;
  els.processDetailDialog.showModal();

  try {
    const primaryPayload = await api("/api/process-detail", {
      method: "POST",
      body: JSON.stringify({
        connection: getQueryConnection(),
        processName,
        jobId: row.job_id || "",
      }),
    });
    let stepsResultSet = primaryPayload.resultSets?.[1] || { columns: [], rows: [] };

    if (shouldUseAgentConnection()) {
      try {
        const agentPayload = await api("/api/process-detail", {
          method: "POST",
          body: JSON.stringify({
            connection: getQueryConnection(true),
            processName,
            jobId: row.job_id || "",
          }),
        });
        stepsResultSet = agentPayload.resultSets?.[1] || stepsResultSet;
      } catch {
        stepsResultSet = primaryPayload.resultSets?.[1] || { columns: [], rows: [] };
      }
    }

    const detail = {
      overview: primaryPayload.resultSets?.[0] || { columns: [], rows: [] },
      steps: stepsResultSet,
      sqlObjects: primaryPayload.resultSets?.[2] || { columns: [], rows: [] },
      recentRuns: primaryPayload.resultSets?.[3] || { columns: [], rows: [] },
      processName,
      jobId: row.job_id || "",
    };
    els.processDetailDialog.dataset.detail = JSON.stringify(detail);
    renderProcessDetailTab("overview");
  } catch (error) {
    els.processDetailBody.innerHTML = `<div class="alert-error">${escapeHtml(error.message)}</div>`;
  }
}

async function openProcessStepSqlObjects(row) {
  const detail = JSON.parse(els.processDetailDialog.dataset.detail || "{}");
  const processName = detail.processName;
  const jobId = detail.jobId || "";
  const stepOrder = Number(row.step_order || row.step_id || 0);
  if (!processName || !stepOrder || !state.connection) return;

  els.stepObjectsTitle.textContent = `${processName} - Step ${stepOrder}`;
  els.stepObjectsBody.innerHTML = `
    <div class="detail-loading">
      <div class="loading-spinner" aria-hidden="true"></div>
      <span>Loading SQL objects</span>
    </div>
  `;
  els.stepObjectsDialog.showModal();

  try {
    const payload = await api("/api/process-step-sql-objects", {
      method: "POST",
      body: JSON.stringify({
        connection: getQueryConnection(true),
        processName,
        jobId,
        stepOrder,
      }),
    });
    const resultSet = payload.resultSets?.[0] || { columns: [], rows: [] };
    els.stepObjectsBody.innerHTML = renderDetailResultSet(resultSet);
  } catch (error) {
    els.stepObjectsBody.innerHTML = `<div class="alert-error">${escapeHtml(error.message)}</div>`;
  }
}

function getCodeObjectName(row) {
  const nameColumns = {
    views: "view_name",
    procedures: "procedure_name",
    functions: "function_name",
    triggers: "trigger_name",
  };
  return row[nameColumns[state.activeQuery?.name]] || row.object_name || "";
}

function setActiveDetailTab(tabName) {
  els.detailTabs.forEach((tab) => {
    tab.classList.toggle("active", tab.dataset.tab === tabName);
  });
}

function renderTableDetailTab(tabName) {
  setActiveDetailTab(tabName);
  const detail = JSON.parse(els.tableDetailDialog.dataset.detail || "{}");
  const resultSet = detail[tabName] || { columns: [], rows: [] };
  els.tableDetailBody.innerHTML = renderDetailResultSet(resultSet);
}

function setActiveProcessDetailTab(tabName) {
  els.processDetailTabs.forEach((tab) => {
    tab.classList.toggle("active", tab.dataset.tab === tabName);
  });
}

function renderProcessDetailTab(tabName) {
  setActiveProcessDetailTab(tabName);
  const detail = JSON.parse(els.processDetailDialog.dataset.detail || "{}");
  const resultSet = detail[tabName] || { columns: [], rows: [] };
  els.processDetailBody.innerHTML = tabName === "steps" ? renderProcessStepsResultSet(resultSet) : renderDetailResultSet(resultSet);
}

function renderProcessStepsResultSet(resultSet) {
  const columns = resultSet.columns || [];
  const rows = resultSet.rows || [];
  if (columns.length === 0) {
    return `<div class="empty">No step columns to display.</div>`;
  }
  if (rows.length === 0) {
    return `<div class="empty">No steps to display.</div>`;
  }
  const headers = [`<th class="row-action-header"></th>`, ...columns.map((column) => `<th>${escapeHtml(labelize(column))}</th>`)].join("");
  const body = rows
    .map((row, index) => {
      const encoded = encodeURIComponent(JSON.stringify(row));
      const cells = columns.map((column) => `<td>${escapeHtml(formatValue(row[column]))}</td>`).join("");
      return `
        <tr>
          <td class="row-action-cell">
            <button type="button" class="row-detail-button process-step-object-button" data-row="${encoded}" title="Open SQL objects" aria-label="Open SQL objects">i</button>
          </td>
          ${cells}
        </tr>
      `;
    })
    .join("");
  setTimeout(() => {
    document.querySelectorAll(".process-step-object-button").forEach((button) => {
      button.addEventListener("click", () => {
        openProcessStepSqlObjects(JSON.parse(decodeURIComponent(button.dataset.row || "%7B%7D")));
      });
    });
  }, 0);
  return `
    <div class="detail-table-wrap">
      <table class="detail-table">
        <thead><tr>${headers}</tr></thead>
        <tbody>${body}</tbody>
      </table>
    </div>
  `;
}

function renderDetailResultSet(resultSet) {
  const columns = resultSet.columns || [];
  const rows = resultSet.rows || [];
  if (columns.length === 0) {
    return `<div class="empty">No detail columns to display.</div>`;
  }
  if (rows.length === 0) {
    return `<div class="empty">No rows to display.</div>`;
  }
  const headers = columns.map((column) => `<th>${escapeHtml(labelize(column))}</th>`).join("");
  const body = rows
    .map((row) => {
      const cells = columns.map((column) => `<td>${escapeHtml(formatValue(row[column]))}</td>`).join("");
      return `<tr>${cells}</tr>`;
    })
    .join("");
  return `
    <div class="detail-table-wrap">
      <table class="detail-table">
        <thead><tr>${headers}</tr></thead>
        <tbody>${body}</tbody>
      </table>
    </div>
  `;
}

function updatePagination(totalRows, totalPages, startIndex, visibleCount) {
  els.pagination.classList.toggle("hidden", totalRows <= TABLE_PAGE_SIZE);
  if (totalRows <= TABLE_PAGE_SIZE) {
    return;
  }
  const endIndex = startIndex + visibleCount;
  els.paginationInfo.textContent = `Rows ${startIndex + 1}-${endIndex} of ${totalRows} | Page ${state.tablePage} of ${totalPages}`;
  els.prevPage.disabled = state.tablePage <= 1;
  els.nextPage.disabled = state.tablePage >= totalPages;
}

function changePage(delta) {
  state.tablePage += delta;
  renderTable();
}

function renderEmptyTable(message) {
  const thead = els.table.querySelector("thead");
  const tbody = els.table.querySelector("tbody");
  thead.innerHTML = "";
  tbody.innerHTML = `<tr><td class="empty">${escapeHtml(message)}</td></tr>`;
  els.pagination.classList.add("hidden");
}

function renderLoadingState() {
  const thead = els.table.querySelector("thead");
  const tbody = els.table.querySelector("tbody");
  thead.innerHTML = "";
  tbody.innerHTML = `
    <tr>
      <td class="empty">
        <div class="loading-state">
          <div class="loading-spinner" aria-hidden="true"></div>
          <div>
            <strong>Loading section data</strong>
            <span>Running the SQL query and preparing the result view.</span>
          </div>
          <div class="loading-bar" aria-hidden="true"><span></span></div>
        </div>
      </td>
    </tr>
  `;
}

function exportCsv() {
  const lines = [
    state.columns.map((column) => csvValue(labelize(column))).join(","),
    ...state.rows.map((row) => state.columns.map((column) => csvValue(row[column])).join(",")),
  ];
  const blob = new Blob([lines.join("\n")], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = `${state.activeQuery?.name || "sqlsidekick"}.csv`;
  link.click();
  URL.revokeObjectURL(url);
}

function csvValue(value) {
  const text = String(value ?? "");
  return `"${text.replaceAll('"', '""')}"`;
}

function labelize(value) {
  return String(value)
    .replaceAll("_", " ")
    .replace(/\b\w/g, (char) => char.toUpperCase())
    .replace(/\bDatabase\b/g, "DB")
    .replace(/\bGb\b/g, "GB")
    .replace(/\bMb\b/g, "MB")
    .replace(/\bSql\b/g, "SQL")
    .replace(/\bId\b/g, "ID")
    .replace(/\bCpu\b/g, "CPU")
    .replace(/\bDml\b/g, "DML")
    .replace(/\bDdl\b/g, "DDL")
    .replace(/\bDmv\b/g, "DMV")
    .replace(/\bHadr\b/g, "HADR")
    .replace(/\bAnsi\b/g, "ANSI")
    .replace(/\bIo\b/g, "IO")
    .replace(/\bUrl\b/g, "URL")
    .replace(/\bXml\b/g, "XML")
    .replace(/\bJson\b/g, "JSON")
    .replace(/\bRpc\b/g, "RPC")
    .replace(/\bTcp\b/g, "TCP");
}

function formatValue(value) {
  if (value === null || value === undefined || value === "") return "-";
  if (typeof value === "boolean") return value ? "Yes" : "No";
  return String(value);
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

els.form.addEventListener("submit", testConnection);
els.authType.addEventListener("change", updateAuthFields);
els.refreshQueries.addEventListener("click", loadQueries);
els.runQuery.addEventListener("click", async () => {
  if (state.autoAlerts) {
    runAlertCheck(state.activeGroup);
  }
  await runActiveQuery();
});
els.exportCsv.addEventListener("click", exportCsv);
els.filterText.addEventListener("input", () => {
  state.tablePage = 1;
  renderTable();
});
els.prevPage.addEventListener("click", () => changePage(-1));
els.nextPage.addEventListener("click", () => changePage(1));
els.openAlerts.addEventListener("click", openAlertsPanel);
els.closeAlerts.addEventListener("click", () => els.alertsDialog.close());
els.closeTableDetail.addEventListener("click", () => els.tableDetailDialog.close());
els.closeCodeDetail.addEventListener("click", () => els.codeDetailDialog.close());
els.closeProcessDetail.addEventListener("click", () => els.processDetailDialog.close());
els.closeStepObjects.addEventListener("click", () => els.stepObjectsDialog.close());
els.closeMapDetail.addEventListener("click", () => els.mapDetailDialog.close());
els.detailTabs.forEach((tab) => {
  tab.addEventListener("click", () => renderTableDetailTab(tab.dataset.tab));
});
els.processDetailTabs.forEach((tab) => {
  tab.addEventListener("click", () => renderProcessDetailTab(tab.dataset.tab));
});
els.openSettings.addEventListener("click", () => {
  updateScriptVersionInputs();
  updateAutoAlertsInput();
  updateLiveRefreshInputs();
  updateAgentConnectionInputs();
  els.settingsDialog.showModal();
});
els.closeSettings.addEventListener("click", () => els.settingsDialog.close());
els.autoAlertsInput.addEventListener("change", () => {
  saveAutoAlerts(els.autoAlertsInput.checked);
  if (state.autoAlerts && state.connected && state.activeQuery) {
    runAllAlerts();
  }
});
els.liveRefreshEnabledInput.addEventListener("change", saveLiveRefreshSettings);
els.liveRefreshSecondsInput.addEventListener("input", saveLiveRefreshSettings);
els.agentCredentialsEnabled.addEventListener("change", saveAgentConnection);
els.agentDatabase.addEventListener("input", saveAgentConnection);
els.agentUsername.addEventListener("input", saveAgentConnection);
els.agentPassword.addEventListener("input", saveAgentConnection);
els.scriptVersionInputs.forEach((input) => {
  input.addEventListener("change", async () => {
    saveScriptVersion(input.value);
    await loadQueries();
    if (state.connected) {
      const firstDatabaseQuery = state.queries.find((query) => query.name === "database_overview") || state.queries[0];
      if (firstDatabaseQuery) {
        state.activeArea = "documentation";
        renderModuleTabs();
        renderQueryMenu();
        setActiveQuery(firstDatabaseQuery.name, firstDatabaseQuery.name === "database_overview" ? "Database" : "Documentation");
        runAllAlerts();
        await runActiveQuery();
      }
    }
    els.settingsDialog.close();
  });
});
els.changeConnection.addEventListener("click", goToConnection);
els.toggleSidebar.addEventListener("click", () => {
  els.appLayout.classList.toggle("sidebar-collapsed");
});

async function initializeApp() {
  updateAuthFields();
  updateScriptVersionInputs();
  updateAutoAlertsInput();
  updateLiveRefreshInputs();
  updateAgentConnectionInputs();
  loadConnectionDraft();
  await loadDefaultConnection();
  await loadQueries();
}

initializeApp().catch((error) => {
  showMessage(els.connectionMessage, error.message, "error");
});
